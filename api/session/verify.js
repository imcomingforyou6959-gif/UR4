import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();

export async function requireSession(req) {
    const token = req.headers.get("x-session");
    const hwid = req.headers.get("x-hwid");

    if (!token || !hwid) {
        return {
            denied: new Response(
                JSON.stringify({ err: "no_session" }),
                { status: 401, headers: { "Content-Type": "application/json" } }
            ),
        };
    }

    let session;
    try {
        session = await db.get(`sess:${token}`);
    } catch (e) {
        return {
            denied: new Response(
                JSON.stringify({ err: "session_store", msg: String(e) }),
                { status: 503, headers: { "Content-Type": "application/json" } }
            ),
        };
    }

    if (!session || session.hwid !== hwid) {
        return {
            denied: new Response(
                JSON.stringify({ err: "invalid_session" }),
                { status: 401, headers: { "Content-Type": "application/json" } }
            ),
        };
    }

    if (Math.floor(Date.now() / 1000) > session.expiresAt) {
        await db.del(`sess:${token}`).catch(() => {});
        return {
            denied: new Response(
                JSON.stringify({ err: "session_expired" }),
                { status: 401, headers: { "Content-Type": "application/json" } }
            ),
        };
    }

    return { session, denied: null };
}
