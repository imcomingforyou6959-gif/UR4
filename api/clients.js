import { Redis } from "@upstash/redis";
import { validate } from "./secure.js";

const db = Redis.fromEnv();
const BOT_SECRET = process.env.BOT_SECRET;
const TTL = 60;
const MIN_HEARTBEAT = 30;

const FALLBACK_HOOK = process.env.FALLBACK_HOOK || process.env.DISCORD_WEBHOOK_URL;
const FALLBACK_COL = 0x9b59b6;
const FALLBACK_WINDOW = 300;
const FALLBACK_COOLDOWN = 1800;

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
}

function log(event, data) {
    console.log(JSON.stringify({ evt: event, ts: Date.now(), ...data }));
}

function err(event, e, extra) {
    console.error(JSON.stringify({
        evt: event,
        ts: Date.now(),
        err: String(e && e.message ? e.message : e),
        ...(extra || {}),
    }));
}

async function fireFallback(payload) {
    if (!FALLBACK_HOOK) {
        err("clients.fallback.no_hook", "FALLBACK_HOOK missing in env");
        return { ok: false, why: "no_hook" };
    }
    const embed = {
        username: "heartbeat watcher",
        embeds: [{
            title: "Client heartbeat — no execution log",
            color: FALLBACK_COL,
            fields: [
                { name: "HWID",     value: "`" + clean(payload.hwid, 128) + "`", inline: false },
                { name: "User",     value: clean(payload.username, 64),          inline: true },
                { name: "Display",  value: clean(payload.displayName, 64),       inline: true },
                { name: "UID",      value: String(payload.userId),               inline: true },
                { name: "Executor", value: clean(payload.executor, 64),          inline: true },
                { name: "Game",     value: clean(payload.gameName, 128),         inline: true },
                { name: "Place",    value: String(payload.placeId),              inline: true },
                { name: "Job",      value: clean(payload.jobId, 40),             inline: true },
                { name: "When",     value: `<t:${Math.floor(payload.seen / 1000)}:R>`, inline: false },
            ],
            footer: { text: "payload never reached /send" },
        }],
    };
    log("clients.fallback.dispatch", {
        hwid: payload.hwid,
        user: payload.username,
        executor: payload.executor,
    });
    try {
        const res = await fetch(FALLBACK_HOOK, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(embed),
        });
        const body = await res.text().catch(() => "");
        log("clients.fallback.hook_response", {
            hwid: payload.hwid,
            status: res.status,
            ok: res.ok,
            body: body.slice(0, 200),
        });
        return { ok: res.ok, status: res.status };
    } catch (e) {
        err("clients.fallback.hook_threw", e, { hwid: payload.hwid });
        return { ok: false, why: String(e) };
    }
}

async function maybeFallback(payload) {
    const hwid = payload.hwid;
    if (!hwid) return null;

    const sentKey = `sent:${hwid}`;
    let sent;
    try {
        sent = await db.get(sentKey);
    } catch (e) {
        err("clients.fallback.sent_get_failed", e, { hwid });
        return null;
    }
    if (sent) {
        log("clients.fallback.skip_sent", { hwid });
        return null;
    }

    const since = Date.now() - FALLBACK_WINDOW * 1000;
    let recent;
    try {
        recent = await db.get(`seen:${hwid}`);
    } catch (e) {
        err("clients.fallback.seen_get_failed", e, { hwid });
        return null;
    }

    const firstSeen = Number(recent) || 0;
    if (!firstSeen) {
        try {
            await db.set(`seen:${hwid}`, String(Date.now()), { ex: FALLBACK_WINDOW });
        } catch (e) {
            err("clients.fallback.seen_set_failed", e, { hwid });
        }
        log("clients.fallback.window_armed", {
            hwid,
            windowSeconds: FALLBACK_WINDOW,
        });
        return null;
    }

    const ageSeconds = Math.floor((Date.now() - firstSeen) / 1000);
    if (firstSeen > since) {
        log("clients.fallback.skip_grace", {
            hwid,
            ageSeconds,
            remaining: Math.max(0, Math.floor((firstSeen - since) / 1000)),
        });
        return null;
    }

    const coolKey = `fallback:${hwid}`;
    let cooling;
    try {
        cooling = await db.get(coolKey);
    } catch (e) {
        err("clients.fallback.cooldown_get_failed", e, { hwid });
        return null;
    }
    if (cooling) {
        log("clients.fallback.skip_cooldown", { hwid });
        return null;
    }

    try {
        await db.set(coolKey, "1", { ex: FALLBACK_COOLDOWN });
    } catch (e) {
        err("clients.fallback.cooldown_set_failed", e, { hwid });
    }

    log("clients.fallback.firing", {
        hwid,
        ageSeconds,
        cooldownSeconds: FALLBACK_COOLDOWN,
    });
    return await fireFallback(payload);
}

async function readBody(req) {
    if (!req) return null;

    let b;
    try {
        b = req.body;
    } catch {
        b = undefined;
    }

    if (b !== undefined && b !== null) {
        if (typeof b === "object" && typeof b.getReader !== "function" && !Buffer.isBuffer(b)) return b;
        if (typeof b === "string") { try { return JSON.parse(b); } catch { return null; } }
        if (Buffer.isBuffer(b)) { try { return JSON.parse(b.toString("utf8")); } catch { return null; } }
        if (typeof b === "object" && typeof b.getReader === "function") {
            try { return JSON.parse(await new Response(b).text()); } catch { return null; }
        }
    }

    if (typeof req.json === "function") { try { return await req.json(); } catch {} }
    if (typeof req.text === "function") {
        try { const t = await req.text(); return t ? JSON.parse(t) : null; } catch {}
    }
    if (typeof req.on === "function") {
        try {
            const text = await new Promise((resolve, reject) => {
                const chunks = [];
                req.on("data", (c) => chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c)));
                req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
                req.on("error", reject);
            });
            return text ? JSON.parse(text) : null;
        } catch { return null; }
    }
    return null;
}

function getHeader(req, name) {
    if (!req || !req.headers) return "";
    if (typeof req.headers.get === "function") return String(req.headers.get(name) || "");
    const raw = req.headers[name] || req.headers[name.toLowerCase()];
    return raw ? String(raw) : "";
}

async function handleList(req) {
    log("clients.list.requested", {});
    const secret = getHeader(req, "x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) {
        log("clients.list.unauthorized", {
            hasSecret: !!secret,
            secretConfigured: !!BOT_SECRET,
        });
        return Response.json({ err: "unauthorized" }, { status: 401 });
    }

    let keys;
    try {
        keys = await db.keys("client:*");
    } catch (e) {
        err("clients.list.keys_failed", e);
        return Response.json({ err: "redis_error", msg: String(e) }, { status: 500 });
    }

    if (!keys || keys.length === 0) {
        log("clients.list.empty", {});
        return Response.json({ ok: true, count: 0, clients: [] });
    }

    log("clients.list.scanning", { keys: keys.length });

    const rows = await Promise.all(keys.map(async (k) => {
        const v = await db.get(k).catch(() => null);
        if (!v) return null;
        try {
            return typeof v === "string" ? JSON.parse(v) : v;
        } catch {
            err("clients.list.bad_json", "parse failed", { key: k });
            return null;
        }
    }));

    const now = Date.now();
    const live = rows.filter(r => r && (now - (r.seen || 0)) < TTL * 1000);
    live.sort((a, b) => b.seen - a.seen);

    log("clients.list.done", {
        scanned: keys.length,
        live: live.length,
        dropped: keys.length - live.length,
    });

    return Response.json({ ok: true, count: live.length, clients: live });
}

async function handleHeartbeat(req, body) {
    const hwid = clean(String(body.hwid || ""), 128);
    if (!hwid) {
        err("clients.write.missing_hwid", "no hwid in body", { bodyKeys: Object.keys(body || {}) });
        return Response.json({ err: "missing_hwid" }, { status: 400 });
    }

    const key = `client:${hwid}`;
    const prev = await db.get(key).catch((e) => {
        err("clients.write.prev_get_failed", e, { hwid });
        return null;
    });

    if (prev) {
        try {
            const p = typeof prev === "string" ? JSON.parse(prev) : prev;
            if (p && p.seen && Date.now() - p.seen < MIN_HEARTBEAT * 1000) {
                const ago = Math.floor((Date.now() - p.seen) / 1000);
                log("clients.write.throttled", {
                    hwid,
                    agoSeconds: ago,
                    minSeconds: MIN_HEARTBEAT,
                });
                return Response.json({ ok: true, skipped: true });
            }
        } catch (e) {
            err("clients.write.prev_bad_json", e, { hwid });
        }
    }

    const payload = {
        hwid,
        username: clean(String(body.username || "?"), 64),
        displayName: clean(String(body.displayName || "?"), 64),
        userId: Number(body.userId) || 0,
        executor: clean(String(body.executor || "?"), 64),
        gameName: clean(String(body.gameName || "?"), 128),
        placeId: Number(body.placeId) || 0,
        jobId: clean(String(body.jobId || ""), 40),
        seen: Date.now(),
    };

    try {
        await db.set(key, JSON.stringify(payload), { ex: TTL });
    } catch (e) {
        err("clients.write.set_failed", e, { hwid });
        return Response.json({ err: "redis_error", msg: String(e) }, { status: 500 });
    }

    log("clients.write.stored", {
        hwid,
        user: payload.username,
        executor: payload.executor,
        game: payload.gameName,
    });

    let fallback = null;
    try {
        fallback = await maybeFallback(payload);
    } catch (e) {
        err("clients.fallback.uncaught", e, { hwid });
    }

    return Response.json({ ok: true, fallback });
}

export async function POST(req) {
    const body = await readBody(req);

    if (!body || typeof body !== "object") {
        err("clients.bad_json", "could not parse body");
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    if (body.action === "list") {
        return handleList(req);
    }

    const v = await validate(req, body);
    if (!v.ok) {
        log("clients.write.unauthorized", {
            why: v.why,
            hwid: getHeader(req, "x-hwid").slice(0, 8) + "…",
        });
        return Response.json({ err: "unauthorized", why: v.why }, { status: 403 });
    }

    return handleHeartbeat(req, body);
}
