import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();

const BOT_SECRET = process.env.BOT_SECRET;
const TTL = 60;

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
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

    await db.set(`client:${hwid}`, JSON.stringify(payload), { ex: TTL });

    return Response.json({ ok: true });
}
