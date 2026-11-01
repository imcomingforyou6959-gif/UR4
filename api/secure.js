import { Redis } from "@upstash/redis";
import crypto from "node:crypto";

const db = Redis.fromEnv();

const SESSION_TTL = 300;
const PAYLOAD_RAW_URL =
    "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Loadstring.lua";

function getHeader(req, name) {
    if (!req || !req.headers) return null;
    if (typeof req.headers.get === "function") return req.headers.get(name);
    const lower = name.toLowerCase();
    for (const k of Object.keys(req.headers)) {
        if (k.toLowerCase() === lower) return req.headers[k];
    }
    return null;
}

async function createSession(body) {
    const { hwid, executor, placeId, jobId, userId, userName } = body || {};

    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        return { status: 400, body: { err: "missing_hwid" } };
    }

    try {
        const url = "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Storage/HWID.json";
        const res = await fetch(url, { cache: "no-store" });
        if (res.ok) {
            const data = await res.json();
            const bans = (data && data.banned_hwids) || {};
            if (bans[hwid]) {
                return { status: 403, body: { err: "banned", reason: bans[hwid].reason || "banned" } };
            }
        }
    } catch {}

    const token = crypto.randomBytes(32).toString("hex");
    const nonce = crypto.randomBytes(12).toString("hex");
    const expiresAt = Math.floor(Date.now() / 1000) + SESSION_TTL;

    try {
        await db.set(
            `sess:${token}`,
            {
                hwid, nonce, expiresAt,
                executor: String(executor || ""),
                placeId: Number(placeId) || 0,
                jobId: String(jobId || ""),
                userId: Number(userId) || 0,
                userName: String(userName || ""),
            },
            { ex: SESSION_TTL }
        );
        console.log(`[secure] STORED sess:${token.slice(0, 8)} hwid:${hwid.slice(0, 12)} nonce:${nonce.slice(0, 8)}`);
    } catch (e) {
        return { status: 503, body: { err: "session_store", msg: String(e) } };
    }

    return { status: 200, body: { token, nonce, expiresAt } };
}

async function getSession(token, hwid) {
    if (!token || !hwid) return null;
    let s;
    try {
        s = await db.get(`sess:${token}`);
        if (typeof s === "string") {
            try { s = JSON.parse(s); } catch {}
        }
        console.log(`[secure] READ sess:${token.slice(0, 8)} value:${JSON.stringify(s)}`);
    } catch (e) {
        console.log(`[secure] redis get error: ${String(e)}`);
        return null;
    }
    if (!s || s.hwid !== hwid) return null;
    if (Math.floor(Date.now() / 1000) > s.expiresAt) {
        await db.del(`sess:${token}`).catch(() => {});
        return null;
    }
    return s;
}

async function buildEncryptedPayload(session, token, hwid) {
    let plaintext;
    try {
        const res = await fetch(PAYLOAD_RAW_URL, { cache: "no-store" });
        if (!res.ok) throw new Error(`raw ${res.status}`);
        plaintext = await res.text();
    } catch (e) {
        return { status: 500, body: { err: "payload_fetch", msg: String(e) } };
    }

    if (!plaintext || plaintext.length < 10) {
        return { status: 500, body: { err: "payload_empty" } };
    }

    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const nonce = Buffer.from(session.nonce, "hex");
    const iv = Buffer.concat([Buffer.alloc(4, 0), nonce]);

    const cipher = crypto.createCipheriv("chacha20", key, iv);
    const encrypted = Buffer.concat([
        cipher.update(Buffer.from(plaintext, "utf8")),
        cipher.final(),
    ]);

    return { status: 200, body: encrypted, isBinary: true };
}

export default async function handler(req, res) {
    const url = new URL(req.url, `https://${req.headers.host || "localhost"}`);
    const path = url.pathname;
    const route = url.searchParams.get("__route");

    // Resolve which action to run
    let action = null;
    if (route === "session_init") action = "session_init";
    else if (route === "session_verify") action = "session_verify";
    else if (route === "payload_enc") action = "payload_enc";
    else if (path === "/api/session/init") action = "session_init";
    else if (path === "/api/session/verify") action = "session_verify";
    else if (path === "/api/payload.enc") action = "payload_enc";

    console.log(`[secure] path=${path} route=${route} action=${action} method=${req.method}`);

    if (action === "session_init" && req.method === "POST") {
        let body = req.body;
        if (typeof body === "string") {
            try { body = JSON.parse(body); } catch { body = null; }
        }
        if (!body || typeof body !== "object") {
            return res.status(400).json({ err: "bad_json" });
        }
        const result = await createSession(body);
        return res.status(result.status).json(result.body);
    }

    if (action === "payload_enc" && req.method === "GET") {
        const token = url.searchParams.get("s");
        const hwid = getHeader(req, "x-hwid");

        if (!token || !hwid) {
            return res.status(403).json({ err: "no_session" });
        }

        const session = await getSession(token, hwid);
        if (!session) {
            return res.status(403).json({ err: "invalid_session" });
        }

        const result = await buildEncryptedPayload(session, token, hwid);
        if (result.isBinary) {
            res.setHeader("Content-Type", "application/octet-stream");
            res.setHeader("Cache-Control", "no-store");
            return res.status(200).send(result.body);
        }
        return res.status(result.status).json(result.body);
    }

    if (action === "session_verify" && req.method === "GET") {
        const token = getHeader(req, "x-session");
        const hwid = getHeader(req, "x-hwid");
        const session = await getSession(token, hwid);
        if (!session) {
            return res.status(401).json({ err: "invalid_session" });
        }
        return res.status(200).json({
            ok: true,
            hwid: session.hwid,
            expiresAt: session.expiresAt,
            userId: session.userId,
            userName: session.userName,
        });
    }

    return res.status(404).json({ err: "not_found", path, route, method: req.method });
}
