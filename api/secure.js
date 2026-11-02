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
    "addons/", "Rendering/", "Supporting/", "assets/",
];
const SCRIPT_CACHE_TTL_MS = 5 * 60 * 1000;
const scriptCache = new Map();

let banCache = { data: null, at: 0 };
const BAN_CACHE_TTL_MS = 3000;

const HARD_BLOCK_UAS = [
    "curl/", "wget/", "python-requests/", "python-urllib/",
    "aiohttp/", "httpx/", "postmanruntime/", "insomnia/",
    "node-fetch/", "axios/", "got/", "go-http-client/",
    "okhttp/", "java/", "libwww-perl/", "httpie/",
];

const KNOWN_EXECUTORS = [
    "delta", "solara", "awp", "krnl", "wave", "synapse", "sirhurt",
    "fluxus", "hydrogen", "argon", "nihon", "xeno", "electron",
    "codex", "trigon", "valyse", "swift", "void", "jjsploit",
    "oxygen", "celery", "rce", "vexon", "sirius",
    "volt", "potassium", "synapse z", "madium", "seliware", "real",
    "isaeva", "velocity", "volcano", "cosmic", "macsploit", "opiumware",
    "vega x", "cryptic", "scriptware", "arceus x"
];

const FORWARD_BASE_URL = "https://ur-4.vercel.app";

async function getBanList() {
    const now = Date.now();
    if (banCache.data && now - banCache.at < BAN_CACHE_TTL_MS) {
        return banCache.data;
    }
    try {
        const res = await fetch(HWID_JSON_URL, { cache: "no-store" });
        if (!res.ok) return banCache.data || null;
        const data = await res.json();
        banCache = { data, at: now };
        return data;
    } catch {
        return banCache.data || null;
    }
}

async function checkBanned(hwid) {
    if (!hwid || typeof hwid !== "string") return null;
    const data = await getBanList();
    if (data) {
        const bans = (data && data.banned_hwids) || {};
        if (bans[hwid]) return bans[hwid];
    }
    try {
        const flag = await db.get(`banflag:${hwid}`);
        if (flag) {
            const reason = typeof flag === "string" ? JSON.parse(flag).reason : flag.reason;
            return { reason: reason || "flagged" };
        }
    } catch {}
    return null;
}

function classifyUA(ua, claimedExecutor) {
    const uaLower = String(ua || "").toLowerCase().trim();
    const claimedLower = String(claimedExecutor || "").toLowerCase().trim();

    // No UA at all — don't report, just let it through
    if (!uaLower) return { action: "none", reason: "no_ua" };

    // 1) Hard block: known scripted/bot clients
    for (const block of HARD_BLOCK_UAS) {
        if (uaLower.startsWith(block) || uaLower.includes(block)) {
            return { action: "block", reason: "hard_block_ua:" + block };
        }
    }

    // Detect which known executor (if any) the UA actually matches
    const uaExecutor = KNOWN_EXECUTORS.find((e) => uaLower.includes(e)) || null;
    const claimedExecutorKnown = claimedLower
        ? KNOWN_EXECUTORS.find((e) => claimedLower.includes(e)) || null
        : null;

    // 2) Report ONLY on genuine spoofing:
    //    - claim names a known executor, UA names a DIFFERENT known executor
    if (claimedExecutorKnown && uaExecutor && uaExecutor !== claimedExecutorKnown) {
        return {
            action: "report",
            reason: "ua_mismatch",
            ua,
            claimed: claimedExecutor,
        };
    }

    // 3) Everything else (normal Roblox clients, browsers, unknown UAs,
    //    matching executor UAs, no known executor in either) => allow, no report
    return { action: "none", reason: "ok" };
}

async function forwardBanReport(payload) {
    try {
        await fetch(FORWARD_BASE_URL + "/api/blacklist/report", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        });
    } catch {}
}

async function createSession(body, req) {
    const { hwid, executor, placeId, jobId, userId, userName, displayName } = body || {};
    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        return { status: 400, body: { err: "missing_hwid" } };
    }

    const banEntry = await checkBanned(hwid);
    if (banEntry) {
        return {
            status: 403,
            body: { err: "banned", reason: banEntry.reason || "banned" },
        };
    }

    const ua = String(req?.headers?.get?.("user-agent") || req?.headers?.["user-agent"] || "");
    const uaClass = classifyUA(ua, executor);

    if (uaClass.action === "block") {
        forwardBanReport({
            hwid,
            username: String(userName || "?"),
            displayName: String(displayName || userName || "?"),
            userId: Number(userId) || 0,
            placeId: Number(placeId) || 0,
            jobId: String(jobId || ""),
            executor: String(executor || ""),
            timestamp: Math.floor(Date.now() / 1000),
            reason: uaClass.reason,
            ua,
            claimedExecutor: String(executor || ""),
        });
        return { status: 403, body: { err: "blocked_ua" } };
    }

    if (uaClass.action === "report") {
        forwardBanReport({
            hwid,
            username: String(userName || "?"),
            displayName: String(displayName || userName || "?"),
            userId: Number(userId) || 0,
            placeId: Number(placeId) || 0,
            jobId: String(jobId || ""),
            executor: String(executor || ""),
            timestamp: Math.floor(Date.now() / 1000),
            reason: uaClass.reason,
            ua,
            claimedExecutor: uaClass.claimed || String(executor || ""),
        });

        if (uaClass.reason === "ua_mismatch") {
            try {
                await db.set(
                    `banflag:${hwid}`,
                    {
                        reason: "ua_mismatch:claimed=" + String(uaClass.claimed || "?") + " ua=" + ua.substring(0, 100),
                        at: Date.now(),
                    },
                    { ex: 86400 }
                );
            } catch {}
        }
    }

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
                ua: ua.substring(0, 256),
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
    const isAsset = norm.startsWith("assets/");
    let plaintext;
    let isBinaryContent = false;

    if (cached && now - cached.at < SCRIPT_CACHE_TTL_MS) {
        plaintext = cached.data;
        isBinaryContent = cached.isBinaryContent || false;
    } else {
        const url =
            `https://raw.githubusercontent.com/${SCRIPT_OWNER}/${SCRIPT_REPO}/` +
            `${SCRIPT_BRANCH}/${norm}`;

        try {
            const res = await fetch(url, { cache: "no-store" });
            if (!res.ok) throw new Error(`raw ${res.status}`);
            if (isAsset) {
                plaintext = Buffer.from(await res.arrayBuffer());
                isBinaryContent = true;
            } else {
                plaintext = await res.text();
                if (!plaintext || plaintext.length < 5) throw new Error("empty");
            }
            scriptCache.set(norm, { data: plaintext, at: now, isBinaryContent });
        } catch (e) {
            return { status: 500, body: { err: "script_fetch", msg: String(e) } };
        }
    }

    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const buf = isBinaryContent
        ? Buffer.from(plaintext)
        : Buffer.from(plaintext, "utf8");
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
        const result = await createSession(body, req);
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
        const token = url.searchParams.get("s");
        const hwid = req.headers["x-hwid"];

        if (!token || !hwid) {
            return res.status(403).json({ err: "no_session" });
        }

        const session = await getSession(token, hwid);
        if (!session) {
            return res.status(403).json({ err: "invalid_session" });
        }

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
