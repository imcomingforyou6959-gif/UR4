import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();

function getHeader(req, name) {
    if (!req || !req.headers) return null;
    if (typeof req.headers.get === "function") return req.headers.get(name);
    const lower = name.toLowerCase();
    for (const k of Object.keys(req.headers)) {
        if (k.toLowerCase() === lower) return req.headers[k];
    }
    return null;
}

export async function requireSession(req) {
    const token = getHeader(req, "x-session");
    const hwid = getHeader(req, "x-hwid");

    console.log(`[verify] token=${token ? token.slice(0, 8) : "nil"} hwid=${hwid ? hwid.slice(0, 12) : "nil"} headerType=${req && req.headers && typeof req.headers.get === "function" ? "Headers" : "object"}`);

    if (!token || !hwid) {
        return {
            denied: new Response(JSON.stringify({ err: "no_session" }),
                { status: 401, headers: { "Content-Type": "application/json" } }),
        };
    }

    let session;
    try {
        session = await db.get(`sess:${token}`);
        if (typeof session === "string") {
            try { session = JSON.parse(session); } catch {}
        }
        console.log(`[verify] session=${JSON.stringify(session)}`);
    } catch (e) {
        console.log(`[verify] redis error: ${String(e)}`);
        return {
            denied: new Response(JSON.stringify({ err: "session_store", msg: String(e) }),
                { status: 503, headers: { "Content-Type": "application/json" } }),
        };
    }

    if (!session) {
        console.log(`[verify] DENIED session nil`);
        return {
            denied: new Response(JSON.stringify({ err: "invalid_session" }),
                { status: 401, headers: { "Content-Type": "application/json" } }),
        };
    }

    if (session.hwid !== hwid) {
        console.log(`[verify] DENIED hwid mismatch stored=${session.hwid} sent=${hwid}`);
        return {
            denied: new Response(JSON.stringify({ err: "invalid_session" }),
                { status: 401, headers: { "Content-Type": "application/json" } }),
        };
    }

    if (Math.floor(Date.now() / 1000) > session.expiresAt) {
        await db.del(`sess:${token}`).catch(() => {});
        return {
            denied: new Response(JSON.stringify({ err: "session_expired" }),
                { status: 401, headers: { "Content-Type": "application/json" } }),
        };
    }

    console.log(`[verify] OK user=${session.userName}`);
    return { session, denied: null };
}
