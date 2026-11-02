import { Redis } from "@upstash/redis";

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

function short(s) {
    if (typeof s !== "string") return String(s);
    return s.length > 16 ? s.slice(0, 12) + "…" : s;
}

async function fireFallback(payload) {
    if (!FALLBACK_HOOK) {
        console.error("[/clients] fallback: FALLBACK_HOOK missing in env");
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
    console.log("[/clients] fallback: dispatching", {
        hwid: short(payload.hwid),
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
        console.log("[/clients] fallback: hook responded", {
            hwid: short(payload.hwid),
            status: res.status,
            ok: res.ok,
            body: body.slice(0, 200),
        });
        return { ok: res.ok, status: res.status };
    } catch (e) {
        console.error("[/clients] fallback: hook threw", {
            hwid: short(payload.hwid),
            err: String(e),
        });
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
        console.error("[/clients] fallback: db.get sent failed", { hwid: short(hwid), err: String(e) });
        return null;
    }
    if (sent) {
        console.log("[/clients] fallback: skip (send already delivered)", { hwid: short(hwid) });
        return null;
    }

    const since = Date.now() - FALLBACK_WINDOW * 1000;
    let recent;
    try {
        recent = await db.get(`seen:${hwid}`);
    } catch (e) {
        console.error("[/clients] fallback: db.get seen failed", { hwid: short(hwid), err: String(e) });
        return null;
    }

    const firstSeen = Number(recent) || 0;
    if (!firstSeen) {
        try {
            await db.set(`seen:${hwid}`, String(Date.now()), { ex: FALLBACK_WINDOW });
        } catch (e) {
            console.error("[/clients] fallback: db.set seen failed", { hwid: short(hwid), err: String(e) });
        }
        console.log("[/clients] fallback: arm window (first heartbeat)", {
            hwid: short(hwid),
            windowSeconds: FALLBACK_WINDOW,
        });
        return null;
    }

    const ageSeconds = Math.floor((Date.now() - firstSeen) / 1000);
    if (firstSeen > since) {
        console.log("[/clients] fallback: skip (within grace window)", {
            hwid: short(hwid),
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
        console.error("[/clients] fallback: db.get cooldown failed", { hwid: short(hwid), err: String(e) });
        return null;
    }
    if (cooling) {
        console.log("[/clients] fallback: skip (cooldown active)", { hwid: short(hwid) });
        return null;
    }

    try {
        await db.set(coolKey, "1", { ex: FALLBACK_COOLDOWN });
    } catch (e) {
        console.error("[/clients] fallback: db.set cooldown failed", { hwid: short(hwid), err: String(e) });
    }

    console.log("[/clients] fallback: firing", {
        hwid: short(hwid),
        ageSeconds,
        cooldownSeconds: FALLBACK_COOLDOWN,
    });
    return await fireFallback(payload);
}

export async function POST(req) {
    let body;
    try {
        body = await req.json();
    } catch {
        console.warn("[/clients] rejected: bad_json");
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    if (body.action === "list") {
        console.log("[/clients] list: requested");
        const secret = req.headers.get("x-bot-secret");
        if (!BOT_SECRET || secret !== BOT_SECRET) {
            console.warn("[/clients] list: unauthorized", {
                hasSecret: !!secret,
                secretConfigured: !!BOT_SECRET,
            });
            return Response.json({ err: "unauthorized" }, { status: 401 });
        }

        let keys;
        try {
            keys = await db.keys("client:*");
        } catch (e) {
            console.error("[/clients] list: db.keys failed", String(e));
            return Response.json({ err: "redis_error", msg: String(e) }, { status: 500 });
        }

        if (!keys || keys.length === 0) {
            console.log("[/clients] list: no keys");
            return Response.json({ ok: true, count: 0, clients: [] });
        }

        console.log("[/clients] list: scanning", { keys: keys.length });

        const rows = await Promise.all(keys.map(async (k) => {
            const v = await db.get(k).catch(() => null);
            if (!v) return null;
            try {
                return typeof v === "string" ? JSON.parse(v) : v;
            } catch {
                console.warn("[/clients] list: bad json in key", k);
                return null;
            }
        }));

        const now = Date.now();
        const live = rows.filter(r => r && (now - (r.seen || 0)) < TTL * 1000);
        live.sort((a, b) => b.seen - a.seen);

        console.log("[/clients] list: done", {
            scanned: keys.length,
            live: live.length,
            dropped: keys.length - live.length,
        });

        return Response.json({ ok: true, count: live.length, clients: live });
    }

    const hwid = clean(String(body.hwid || ""), 128);
    if (!hwid) {
        console.warn("[/clients] write: missing_hwid", { bodyKeys: Object.keys(body || {}) });
        return Response.json({ err: "missing_hwid" }, { status: 400 });
    }

    const key = `client:${hwid}`;
    const prev = await db.get(key).catch((e) => {
        console.error("[/clients] write: db.get prev failed", { hwid: short(hwid), err: String(e) });
        return null;
    });

    if (prev) {
        try {
            const p = typeof prev === "string" ? JSON.parse(prev) : prev;
            if (p && p.seen && Date.now() - p.seen < MIN_HEARTBEAT * 1000) {
                const ago = Math.floor((Date.now() - p.seen) / 1000);
                console.log("[/clients] write: throttled", {
                    hwid: short(hwid),
                    agoSeconds: ago,
                    minSeconds: MIN_HEARTBEAT,
                });
                return Response.json({ ok: true, skipped: true });
            }
        } catch (e) {
            console.warn("[/clients] write: prev bad json, overwriting", { hwid: short(hwid) });
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
        console.error("[/clients] write: db.set failed", { hwid: short(hwid), err: String(e) });
        return Response.json({ err: "redis_error", msg: String(e) }, { status: 500 });
    }

    console.log("[/clients] write: stored", {
        hwid: short(hwid),
        user: payload.username,
        executor: payload.executor,
        game: payload.gameName,
    });

    let fallback = null;
    try {
        fallback = await maybeFallback(payload);
    } catch (e) {
        console.error("[/clients] fallback: uncaught", { hwid: short(hwid), err: String(e) });
    }

    return Response.json({ ok: true, fallback });
}
