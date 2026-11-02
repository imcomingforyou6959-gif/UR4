import { Redis } from "@upstash/redis";
import crypto from "node:crypto";

const db = Redis.fromEnv();

const SESSION_TTL = 300;
const PAYLOAD_REPO_TOKEN = process.env.REPOTK;
const PAYLOAD_REPO = process.env.PAYLOAD_REPO || "imcomingforyou6959-gif/hosting";
const PAYLOAD_PATH = process.env.PAYLOAD_PATH || "constructs/Loadstring.lua";
const HWID_JSON_URL =
    "https://raw.githubusercontent.com/madeformeanduu/vaild/refs/heads/main/Storage/HWID.json";

const ASSET_URL =
    "https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/main/assets/images/kitagawa.webp";
const ASSET_CACHE_TTL_MS = 3600 * 1000;
let assetCache = { data: null, at: 0, contentType: "image/webp" };

const SCRIPT_OWNER = "imcomingforyou6959-gif";
const SCRIPT_REPO = "UR4";
const SCRIPT_BRANCH = "main";
const SCRIPT_ALLOWED_PREFIXES = [
    "Adonis.lua", "Library.lua",
    "addons/", "Rendering/", "Supporting/",
];
const SCRIPT_CACHE_TTL_MS = 5 * 60 * 1000;
const scriptCache = new Map();

async function createSession(body) {
    const { hwid, executor, placeId, jobId, userId, userName } = body || {};
    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        return { status: 400, body: { err: "missing_hwid" } };
    }
    try {
        const res = await fetch(HWID_JSON_URL, { cache: "no-store" });
        if (res.ok) {
            const data = await res.json();
            const bans = (data && data.banned_hwids) || {};
            if (bans[hwid]) {
                return {
                    status: 403,
                    body: { err: "banned", reason: bans[hwid].reason || "banned" },
                };
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
                hwid,
                nonce,
                expiresAt,
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

async function buildPayload(session, token, hwid) {
    if (!PAYLOAD_REPO_TOKEN) {
        return { status: 500, body: { err: "payload_token_missing" } };
    }

    let plaintext;
    try {
        const res = await fetch(
            `https://api.github.com/repos/${PAYLOAD_REPO}/contents/${PAYLOAD_PATH}`,
            {
                headers: {
                    Authorization: `Bearer ${PAYLOAD_REPO_TOKEN}`,
                    Accept: "application/vnd.github.v3.raw",
                },
                cache: "no-store",
            }
        );
        if (!res.ok) throw new Error(`gh ${res.status}`);
        plaintext = await res.text();
    } catch (e) {
        return { status: 500, body: { err: "payload_fetch", msg: String(e) } };
    }

    if (!plaintext || plaintext.length < 10) {
        return { status: 500, body: { err: "payload_empty" } };
    }

    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const buf = Buffer.from(plaintext, "utf8");
    const out = Buffer.alloc(buf.length);
    for (let i = 0; i < buf.length; i++) {
        out[i] = buf[i] ^ key[i % key.length];
    }

    return { status: 200, body: out, isBinary: true };
}

async function buildAsset() {
    const now = Date.now();
    if (assetCache.data && now - assetCache.at < ASSET_CACHE_TTL_MS) {
        return {
            status: 200,
            body: assetCache.data,
            contentType: assetCache.contentType,
            isBinary: true,
        };
    }

    try {
        const res = await fetch(ASSET_URL, { cache: "no-store" });
        if (!res.ok) throw new Error(`raw ${res.status}`);
        const buf = Buffer.from(await res.arrayBuffer());
        assetCache = {
            data: buf,
            at: now,
            contentType: res.headers.get("content-type") || "image/webp",
        };
        return {
            status: 200,
            body: buf,
            contentType: assetCache.contentType,
            isBinary: true,
        };
    } catch (e) {
        return { status: 500, body: { err: "asset_fetch", msg: String(e) } };
    }
}

async function buildScript(scriptPath, token, hwid) {
    const norm = String(scriptPath || "").replace(/^\/+/, "");
    if (!norm || norm.includes("..") || norm.length > 200) {
        return { status: 400, body: { err: "bad_path" } };
    }
    const allowed = SCRIPT_ALLOWED_PREFIXES.some(
        (p) => norm === p || norm.startsWith(p)
    );
    if (!allowed) {
        return { status: 403, body: { err: "path_not_allowed" } };
    }

    const now = Date.now();
    const cached = scriptCache.get(norm);
    let plaintext;

    if (cached && now - cached.at < SCRIPT_CACHE_TTL_MS) {
        plaintext = cached.data;
    } else {
        const url =
            `https://raw.githubusercontent.com/${SCRIPT_OWNER}/${SCRIPT_REPO}/` +
            `${SCRIPT_BRANCH}/${norm}`;

        try {
            const res = await fetch(url, { cache: "no-store" });
            if (!res.ok) throw new Error(`raw ${res.status}`);
            plaintext = await res.text();
            if (!plaintext || plaintext.length < 5) throw new Error("empty");
            scriptCache.set(norm, { data: plaintext, at: now });
        } catch (e) {
            return { status: 500, body: { err: "script_fetch", msg: String(e) } };
        }
    }

    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const buf = Buffer.from(plaintext, "utf8");
    const out = Buffer.alloc(buf.length);
    for (let i = 0; i < buf.length; i++) {
        out[i] = buf[i] ^ key[i % key.length];
    }

    return {
        status: 200,
        body: out,
        contentType: "application/octet-stream",
        isBinary: true,
    };
}

export default async function handler(req, res) {
    const url = new URL(req.url, `https://${req.headers.host || "localhost"}`);
    const path = url.pathname;
    const route = url.searchParams.get("__route");

    if (
        (path === "/api/session/init" ||
            (path === "/api/secure" && route === "session_init")) &&
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
        (path === "/api/payload.enc" ||
            (path === "/api/secure" && route === "payload_enc")) &&
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

        const result = await buildPayload(session, token, hwid);
        if (result.isBinary) {
            res.setHeader("Content-Type", "application/octet-stream");
            res.setHeader("Cache-Control", "no-store");
            return res.status(200).send(result.body);
        }
        return res.status(result.status).json(result.body);
    }

    if (
        (path === "/api/asset/kitagawa" ||
            (path === "/api/secure" && route === "asset_kitagawa")) &&
        req.method === "GET"
    ) {
        const result = await buildAsset();
        if (result.isBinary) {
            res.setHeader("Content-Type", result.contentType);
            res.setHeader("Cache-Control", "public, max-age=3600");
            return res.status(200).send(result.body);
        }
        return res.status(result.status).json(result.body);
    }

    if (route === "script_proxy" && req.method === "GET") {
        const token = url.searchParams.get("s");
        const hwid = req.headers["x-hwid"];

        if (!token || !hwid) {
            return res.status(403).json({ err: "no_session" });
        }

        const session = await getSession(token, hwid);
        if (!session) {
            return res.status(403).json({ err: "invalid_session" });
        }

        const rawPath = url.searchParams.get("__path") || "";
        let scriptPath = rawPath;
        try { scriptPath = decodeURIComponent(rawPath); } catch {}
        const result = await buildScript(scriptPath, token, hwid);
        if (result.isBinary) {
            res.setHeader("Content-Type", "application/octet-stream");
            res.setHeader("Cache-Control", "no-store");
            return res.status(200).send(result.body);
        }
        return res.status(result.status).json(result.body);
    }

    return res.status(404).json({ err: "not_found", path });
}
