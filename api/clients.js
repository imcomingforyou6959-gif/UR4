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

async function fireFallback(payload) {
    if (!FALLBACK_HOOK) {
        console.error("[/clients] FALLBACK_HOOK missing");
        return { ok: false, why: "no_hook" };
    }
    const embed = {
        username: "heartbeat watcher",
        embeds: [{
            title: "Client heartbeat — no execution log",
            color: FALLBACK_COL,
            fields: [
                { name: "HWID",       value: "`" + clean(payload.hwid, 128) + "`", inline: false },
                { name: "User",       value: clean(payload.username, 64),          inline: true },
                { name: "Display",    value: clean(payload.displayName, 64),       inline: true },
                { name: "UID",        value: String(payload.userId),               inline: true },
                { name: "Executor",   value: clean(payload.executor, 64),          inline: true },
                { name: "Game",       value: clean(payload.gameName, 128),         inline: true },
                { name: "Place",      value: String(payload.placeId),              inline: true },
                { name: "Job",        value: clean(payload.jobId, 40),             inline: true },
                { name: "When",       value: `<t:${Math.floor(payload.seen / 1000)}:R>`, inline: false },
            ],
            footer: { text: "payload never reached /send" },
        }],
    };
    try {
        const res = await fetch(FALLBACK_HOOK, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(embed),
        });
        const body = await res.text().catch(() => "");
        console.error("[/clients] fallback hook responded", { status: res.status, body: body.slice(0, 300) });
        return { ok: res.ok, status: res.status };
    } catch (e) {
        console.error("[/clients] fallback hook threw", String(e));
        return { ok: false, why: String(e) };
    }
}

async function maybeFallback(payload) {
    const hwid = payload.hwid;
    if (!hwid) return null;

    const sentKey = `sent:${hwid}`;
    const sent = await db.get(sentKey).catch(() => null);
    if (sent) return null;

    const since = Date.now() - FALLBACK_WINDOW * 1000;
    const recent = await db.get(`seen:${hwid}`).catch(() => null);
    const firstSeen = Number(recent) || 0;
    if (!firstSeen) {
        await db.set(`seen:${hwid}`, String(Date.now()), { ex: FALLBACK_WINDOW }).catch(() => {});
        return null;
    }
    if (firstSeen > since) return null;

    const coolKey = `fallback:${hwid}`;
    const cooling = await db.get(coolKey).catch(() => null);
    if (cooling) return null;

    await db.set(coolKey, "1", { ex: FALLBACK_COOLDOWN }).catch(() => {});
    return await fireFallback(payload);
}

export async function POST(req) {
    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    if (body.action === "list") {
        const secret = req.headers.get("x-bot-secret");
        if (!BOT_SECRET || secret !== BOT_SECRET) {
            return Response.json({ err: "unauthorized" }, { status: 401 });
        }

        const keys = await db.keys("client:*");
        if (!keys || keys.length === 0) {
            return Response.json({ ok: true, count: 0, clients: [] });
        }

        const rows = await Promise.all(keys.map(async (k) => {
            const v = await db.get(k);
            if (!v) return null;
            try { return typeof v === "string" ? JSON.parse(v) : v; }
            catch { return null; }
        }));

        const now = Date.now();
        const live = rows.filter(r => r && (now - (r.seen || 0)) < TTL * 1000);
        live.sort((a, b) => b.seen - a.seen);

        return Response.json({ ok: true, count: live.length, clients: live });
    }

    const hwid = clean(String(body.hwid || ""), 128);
    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

    const key = `client:${hwid}`;
    const prev = await db.get(key).catch(() => null);
    if (prev) {
        try {
            const p = typeof prev === "string" ? JSON.parse(prev) : prev;
            if (p && p.seen && Date.now() - p.seen < MIN_HEARTBEAT * 1000) {
                return Response.json({ ok: true, skipped: true });
            }
        } catch {}
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

    await db.set(key, JSON.stringify(payload), { ex: TTL });

    let fallback = null;
    try {
        fallback = await maybeFallback(payload);
    } catch (e) {
        console.error("[/clients] fallback check failed", String(e));
    }

    return Response.json({ ok: true, fallback });
}
