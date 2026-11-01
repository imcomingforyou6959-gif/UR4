import { Redis } from "@upstash/redis";
import crypto from "node:crypto";

const db = Redis.fromEnv();

const SESSION_TTL = 300;
const PAYLOAD_RAW_URL =
    "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Loadstring.lua";

async function createSession(body) {
    const { hwid, executor, placeId, jobId, userId, userName } = body || {};

    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        return { status: 400, body: { err: "missing_hwid" } };
    }

    try {
        const url = "https://raw.githubusercontent.com/madeformeanduu/vaild/refs/heads/main/Storage/HWID.json";
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
    } catch {
        return null;
    }
    if (!s || s.hwid !== hwid) return null;
    if (Math.floor(Date.now() / 1000) > s.expiresAt) {
        await db.del(`sess:${token}`).catch(() => {});
        return null;
    }
    return s;
}

// XOR with session-derived key. Fast, adequate for network-level protection.
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

    // 32-byte key from sha256(token + "|" + hwid)
    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const plainBuf = Buffer.from(plaintext, "utf8");
    const out = Buffer.alloc(plainBuf.length);
    for (let i = 0; i < plainBuf.length; i++) {
        out[i] = plainBuf[i] ^ key[i % key.length];
    }

    return { status: 200, body: out, isBinary: true };
}

export default async function handler(req, res) {
    const url = new URL(req.url, `https://${req.headers.host || "localhost"}`);
    const path = url.pathname;
    const route = url.searchParams.get("__route");

    if (
        (path === "/api/session/init" || (path === "/api/secure" && route === "session_init")) &&
        req.method === "POST"
    ) {
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

    if (
        (path === "/api/payload.enc" || (path === "/api/secure" && route === "payload_enc")) &&
        req.method === "GET"
    ) {
        const token = url.searchParams.get("s");
        const hwid = req.headers["x-hwid"];

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

    return res.status(404).json({ err: "not_found", path });
}
