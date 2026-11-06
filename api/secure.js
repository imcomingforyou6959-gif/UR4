import { Redis } from "@upstash/redis";
import crypto from "node:crypto";

const db = Redis.fromEnv();

const SESSION_TTL = 300;
const NONCE_TTL = 60;
const PAD_TTL = 60;
const MAX_TS_DRIFT_MS = 30_000;

const RATE_SESSION_PER_MIN = 60;
const RATE_HWID_PER_HOUR = 10;
const RATE_IP_PER_MIN = 120;

const MASTER_SECRET = process.env.MASTER_SECRET || "";
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
    "vega x", "cryptic", "scriptware", "arceus x", "roblox"
];

const FORWARD_BASE_URL = "https://ur-4.vercel.app";

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

function maskHwid(hwid) {
    const s = String(hwid || "");
    if (s.length <= 6) return "***";
    return s.slice(0, 4) + "…" + s.slice(-2);
}

function maskToken(token) {
    const s = String(token || "");
    if (s.length <= 10) return "***";
    return s.slice(0, 4) + "…" + s.slice(-4);
}

function hmacSha256(key, message) {
    return crypto.createHmac("sha256", key).update(message).digest("hex");
}

function timingSafeEqualHex(a, b) {
    const ba = Buffer.from(String(a || ""), "hex");
    const bb = Buffer.from(String(b || ""), "hex");
    if (ba.length !== bb.length || ba.length === 0) return false;
    return crypto.timingSafeEqual(ba, bb);
}

function hkdfSha256(ikm, salt, info, length = 32) {
    return Buffer.from(crypto.hkdfSync(
        "sha256",
        Buffer.isBuffer(ikm) ? ikm : Buffer.from(ikm, "utf8"),
        Buffer.isBuffer(salt) ? salt : Buffer.from(salt || "", "utf8"),
        Buffer.isBuffer(info) ? info : Buffer.from(info || "", "utf8"),
        length
    ));
}

function generateX25519() {
    return crypto.generateKeyPairSync("x25519");
}

function exportPublicKey(key) {
    return key.export({ format: "der", type: "spki" }).toString("base64");
}

function importPublicKey(b64) {
    return crypto.createPublicKey({
        key: Buffer.from(b64, "base64"),
        format: "der",
        type: "spki",
    });
}

function diffieHellman(privateKey, publicKey) {
    return crypto.diffieHellman({ privateKey, publicKey });
}

function aesGcmEncrypt(key, plaintext) {
    const nonce = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
    const ct = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    return {
        nonce_b64: nonce.toString("base64"),
        ciphertext_b64: ct.toString("base64"),
        tag_b64: cipher.getAuthTag().toString("base64"),
    };
}

function randomHex(bytes = 16) {
    return crypto.randomBytes(bytes).toString("hex");
}

function randomBytes(length) {
    return crypto.randomBytes(length);
}

function xorBuffers(a, b) {
    if (a.length !== b.length) throw new Error("xor length mismatch");
    const out = Buffer.alloc(a.length);
    for (let i = 0; i < a.length; i++) out[i] = a[i] ^ b[i];
    return out;
}

function deriveFallbackSessionKey(masterSecretHex, sessionId, hwid) {
    return hkdfSha256(
        Buffer.from(masterSecretHex, "hex"),
        Buffer.from(sessionId, "hex"),
        Buffer.from(`rawr-session-v2|${hwid}`, "utf8"),
        32
    );
}

async function getBanList() {
    const now = Date.now();
    if (banCache.data && now - banCache.at < BAN_CACHE_TTL_MS) return banCache.data;
    try {
        const res = await fetch(HWID_JSON_URL, { cache: "no-store" });
        if (!res.ok) {
            err("banlist.fetch_failed", `status ${res.status}`);
            return banCache.data || null;
        }
        const data = await res.json();
        banCache = { data, at: now };
        return data;
    } catch (e) {
        err("banlist.fetch_threw", e);
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
    } catch (e) {
        err("banlist.flag_read_failed", e, { hwid: maskHwid(hwid) });
    }
    return null;
}

function classifyUA(ua, claimedExecutor) {
    const uaLower = String(ua || "").toLowerCase().trim();
    const claimedLower = String(claimedExecutor || "").toLowerCase().trim();

    if (!uaLower) return { action: "none", reason: "no_ua" };

    for (const block of HARD_BLOCK_UAS) {
        if (uaLower.startsWith(block) || uaLower.includes(block)) {
            return { action: "block", reason: "hard_block_ua:" + block };
        }
    }

    const uaExecutor = KNOWN_EXECUTORS.find((e) => uaLower.includes(e)) || null;
    const claimedExecutorKnown = claimedLower
        ? KNOWN_EXECUTORS.find((e) => claimedLower.includes(e)) || null
        : null;

    if (claimedExecutorKnown && uaExecutor && uaExecutor !== claimedExecutorKnown) {
        return { action: "report", reason: "ua_mismatch", ua, claimed: claimedExecutor };
    }

    return { action: "none", reason: "ok" };
}

async function forwardBanReport(payload) {
    try {
        log("ban_forward.start", { reason: payload.reason, hwid: maskHwid(payload.hwid) });
        const res = await fetch(FORWARD_BASE_URL + "/api/blacklist/report", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        });
        const bodyText = await res.text().catch(() => "");
        if (res.ok) {
            log("ban_forward.ok", {
                status: res.status,
                reason: payload.reason,
                hwid: maskHwid(payload.hwid),
            });
        } else {
            err("ban_forward.rejected", `status ${res.status}`, {
                status: res.status,
                body: bodyText.slice(0, 300),
            });
        }
    } catch (e) {
        err("ban_forward.threw", e);
    }
}

async function bumpLimit(key, max, windowSec) {
    try {
        const count = await db.incr(key);
        if (count === 1) await db.expire(key, windowSec);
        return count <= max;
    } catch (e) {
        err("ratelimit.redis_failed", e, { key });
        return true;
    }
}

async function checkRateLimits(sessionId, hwid, ip) {
    if (sessionId) {
        if (!(await bumpLimit(`rate:sess:${sessionId}`, RATE_SESSION_PER_MIN, 60))) {
            return { ok: false, why: "session_rate" };
        }
    }
    if (hwid) {
        if (!(await bumpLimit(`rate:hwid:${hwid}`, RATE_HWID_PER_HOUR, 3600))) {
            return { ok: false, why: "hwid_rate" };
        }
    }
    if (ip) {
        if (!(await bumpLimit(`rate:ip:${ip}`, RATE_IP_PER_MIN, 60))) {
            return { ok: false, why: "ip_rate" };
        }
    }
    return { ok: true };
}

async function readBody(req) {
    if (!req) return null;
    const b = req.body;
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

async function getSession(sessionId) {
    if (!sessionId) return null;
    let s;
    try {
        s = await db.get(`sess:${sessionId}`);
        if (typeof s === "string") { try { s = JSON.parse(s); } catch { return null; } }
    } catch (e) {
        err("session.read_failed", e, { sessionId: maskToken(sessionId) });
        return null;
    }
    if (!s || !s.expiresAt || s.expiresAt < Date.now()) return null;
    return s;
}

async function validate(req, body) {
    const sessionId = getHeader(req, "x-session");
    const nonce = getHeader(req, "x-nonce");
    const tsRaw = getHeader(req, "x-timestamp");
    const sig = getHeader(req, "x-signature");
    const hwid = getHeader(req, "x-hwid");

    if (!sessionId || !nonce || !tsRaw || !sig || !hwid) {
        return { ok: false, why: "missing_headers" };
    }

    const ts = Number(tsRaw);
    if (!Number.isFinite(ts) || Math.abs(Date.now() - ts) > MAX_TS_DRIFT_MS) {
        return { ok: false, why: "stale_timestamp" };
    }

    const session = await getSession(sessionId);
    if (!session) return { ok: false, why: "no_session" };
    if (session.hwid !== hwid) return { ok: false, why: "hwid_mismatch" };

    const nonceKey = `nonce:${sessionId}:${nonce}`;
    try {
        const seen = await db.get(nonceKey);
        if (seen) return { ok: false, why: "replay" };
        await db.set(nonceKey, "1", { ex: NONCE_TTL });
    } catch (e) {
        err("auth.nonce_failed", e, { sessionId: maskToken(sessionId) });
        return { ok: false, why: "nonce_store" };
    }

    const url = new URL(req.url, "https://ur-4.vercel.app");
    const bodyHash = hmacSha256("", JSON.stringify(body || {}));
    const expected = hmacSha256(
        Buffer.from(session.session_key_hex, "hex"),
        `${req.method}|${url.pathname}|${nonce}|${ts}|${bodyHash}`
    );

    if (!timingSafeEqualHex(sig, expected)) {
        return { ok: false, why: "bad_signature" };
    }

    const rate = await checkRateLimits(sessionId, hwid, null);
    if (!rate.ok) return { ok: false, why: rate.why };

    return { ok: true, session };
}

export { validate };

async function createSession(body, req) {
    const { hwid, executor, placeId, jobId, userId, userName, displayName, client_pub_b64 } = body || {};
    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        err("session.missing_hwid", null, {
            hasHwid: !!hwid,
            hwidLen: typeof hwid === "string" ? hwid.length : 0,
        });
        return { status: 400, body: { err: "missing_hwid" } };
    }

    const ip = String(getHeader(req, "x-forwarded-for") || "").split(",")[0].trim();

    const rate = await checkRateLimits(null, hwid, ip);
    if (!rate.ok) {
        log("session.rate_limited", { hwid: maskHwid(hwid), why: rate.why });
        return { status: 429, body: { err: "rate_limited", why: rate.why } };
    }

    const banEntry = await checkBanned(hwid);
    if (banEntry) {
        log("session.banned", { hwid: maskHwid(hwid), reason: banEntry.reason || "banned" });
        return { status: 403, body: { err: "banned", reason: banEntry.reason || "banned" } };
    }

    const ua = getHeader(req, "user-agent");
    const uaClass = classifyUA(ua, executor);

    log("session.ua_classified", {
        hwid: maskHwid(hwid),
        action: uaClass.action,
        reason: uaClass.reason,
        ua: ua.slice(0, 80),
        claimed: String(executor || "").slice(0, 40),
    });

    if (uaClass.action === "block") {
        await forwardBanReport({
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
        await forwardBanReport({
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
            } catch (e) {
                err("session.flag_write_failed", e, { hwid: maskHwid(hwid) });
            }
        }
    }

    const sessionId = randomHex(16);
    let sessionKey;
    let serverPubB64 = null;
    let mode = "fallback";

    if (client_pub_b64) {
        try {
            const clientPub = importPublicKey(client_pub_b64);
            const { publicKey: serverPub, privateKey: serverPriv } = generateX25519();
            const shared = diffieHellman(serverPriv, clientPub);
            sessionKey = hkdfSha256(
                shared,
                Buffer.from(sessionId, "hex"),
                Buffer.from("rawr-session-v2", "utf8"),
                32
            );
            serverPubB64 = exportPublicKey(serverPub);
            mode = "x25519";
        } catch (e) {
            err("session.x25519_failed", e, { hwid: maskHwid(hwid) });
            if (!MASTER_SECRET) {
                return { status: 500, body: { err: "crypto_unavailable" } };
            }
            sessionKey = deriveFallbackSessionKey(MASTER_SECRET, sessionId, hwid);
            mode = "fallback";
        }
    } else {
        if (!MASTER_SECRET) {
            return { status: 500, body: { err: "crypto_unavailable" } };
        }
        sessionKey = deriveFallbackSessionKey(MASTER_SECRET, sessionId, hwid);
        mode = "fallback";
    }

    const expiresAt = Date.now() + SESSION_TTL * 1000;

    try {
        await db.set(
            `sess:${sessionId}`,
            {
                hwid,
                session_key_hex: sessionKey.toString("hex"),
                expiresAt,
                executor: String(executor || ""),
                ua: ua.substring(0, 256),
                placeId: Number(placeId) || 0,
                jobId: String(jobId || ""),
                userId: Number(userId) || 0,
                userName: String(userName || ""),
                mode,
            },
            { ex: SESSION_TTL }
        );
        log("session.created", {
            hwid: maskHwid(hwid),
            sessionId: maskToken(sessionId),
            mode,
            user: String(userName || "?").slice(0, 40),
        });
    } catch (e) {
        err("session.store_failed", e, { hwid: maskHwid(hwid) });
        return { status: 503, body: { err: "session_store", msg: String(e) } };
    }

    return {
        status: 200,
        body: {
            session_id: sessionId,
            session_key_hex: mode === "fallback" ? sessionKey.toString("hex") : undefined,
            server_pub_b64: serverPubB64,
            mode,
            expires_at: expiresAt,
        },
    };
}

async function fetchPrivateFile(repo, path, token) {
    const res = await fetch(
        `https://api.github.com/repos/${repo}/contents/${path}`,
        {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: "application/vnd.github.v3.raw",
            },
            cache: "no-store",
        }
    );
    if (!res.ok) throw new Error(`gh ${res.status}`);
    return await res.text();
}

async function buildPayload(session, sessionId, hwid) {
    if (!PAYLOAD_REPO_TOKEN) {
        err("payload.token_missing");
        return { status: 500, body: { err: "payload_token_missing" } };
    }

    let plaintext;
    try {
        plaintext = await fetchPrivateFile(PAYLOAD_REPO, PAYLOAD_PATH, PAYLOAD_REPO_TOKEN);
    } catch (e) {
        err("payload.fetch_failed", e, { sessionId: maskToken(sessionId) });
        return { status: 500, body: { err: "payload_fetch", msg: String(e) } };
    }

    if (!plaintext || plaintext.length < 10) {
        err("payload.empty", null, { length: plaintext ? plaintext.length : 0 });
        return { status: 500, body: { err: "payload_empty" } };
    }

    const sessionKey = Buffer.from(session.session_key_hex, "hex");
    const buf = Buffer.from(plaintext, "utf8");
    const pad = randomBytes(buf.length);
    const xored = xorBuffers(buf, pad);
    const padEnc = aesGcmEncrypt(sessionKey, pad);

    const padId = randomHex(16);
    try {
        await db.set(
            `pad:${padId}`,
            { one_time: true, session_id: sessionId, at: Date.now() },
            { ex: PAD_TTL }
        );
    } catch (e) {
        err("payload.pad_store_failed", e, { sessionId: maskToken(sessionId) });
        return { status: 500, body: { err: "pad_store" } };
    }

    log("payload.delivered", {
        sessionId: maskToken(sessionId),
        hwid: maskHwid(hwid),
        bytes: xored.length,
        padId: maskToken(padId),
    });

    return {
        status: 200,
        body: {
            pad_id: padId,
            nonce_b64: padEnc.nonce_b64,
            encrypted_pad_b64: padEnc.ciphertext_b64,
            tag_b64: padEnc.tag_b64,
            ciphertext_b64: xored.toString("base64"),
            ttl: PAD_TTL,
        },
    };
}

async function buildAsset() {
    const now = Date.now();
    if (assetCache.data && now - assetCache.at < ASSET_CACHE_TTL_MS) {
        log("asset.cache_hit", { bytes: assetCache.data.length });
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
        log("asset.fetched", { bytes: buf.length });
        return { status: 200, body: buf, contentType: assetCache.contentType, isBinary: true };
    } catch (e) {
        err("asset.fetch_failed", e);
        return { status: 500, body: { err: "asset_fetch", msg: String(e) } };
    }
}

async function buildScript(scriptPath, session, sessionId, hwid) {
    const norm = String(scriptPath || "").replace(/^\/+/, "");
    if (!norm || norm.includes("..") || norm.length > 200) {
        err("script.bad_path", null, { path: norm.slice(0, 80) });
        return { status: 400, body: { err: "bad_path" } };
    }
    const allowed = SCRIPT_ALLOWED_PREFIXES.some((p) => norm === p || norm.startsWith(p));
    if (!allowed) {
        err("script.path_not_allowed", null, { path: norm.slice(0, 80) });
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
        log("script.cache_hit", { path: norm });
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
            log("script.fetched", { path: norm, bytes: plaintext.length });
        } catch (e) {
            err("script.fetch_failed", e, { path: norm });
            return { status: 500, body: { err: "script_fetch", msg: String(e) } };
        }
    }

    const sessionKey = Buffer.from(session.session_key_hex, "hex");
    const buf = isBinaryContent ? Buffer.from(plaintext) : Buffer.from(plaintext, "utf8");
    const pad = randomBytes(buf.length);
    const xored = xorBuffers(buf, pad);
    const padEnc = aesGcmEncrypt(sessionKey, pad);

    const padId = randomHex(16);
    try {
        await db.set(
            `pad:${padId}`,
            { one_time: true, session_id: sessionId, at: Date.now() },
            { ex: PAD_TTL }
        );
    } catch (e) {
        err("script.pad_store_failed", e, { sessionId: maskToken(sessionId) });
        return { status: 500, body: { err: "pad_store" } };
    }

    log("script.delivered", {
        path: norm,
        sessionId: maskToken(sessionId),
        hwid: maskHwid(hwid),
        bytes: xored.length,
        padId: maskToken(padId),
    });

    return {
        status: 200,
        body: {
            pad_id: padId,
            nonce_b64: padEnc.nonce_b64,
            encrypted_pad_b64: padEnc.ciphertext_b64,
            tag_b64: padEnc.tag_b64,
            ciphertext_b64: xored.toString("base64"),
            ttl: PAD_TTL,
        },
    };
}

function sendJson(res, status, obj) {
    if (res && typeof res.status === "function" && typeof res.json === "function") {
        return res.status(status).json(obj);
    }
    if (res && typeof res.setHeader === "function") {
        res.statusCode = status;
        res.setHeader("Content-Type", "application/json");
        if (typeof res.end === "function") {
            res.end(JSON.stringify(obj));
            return;
        }
    }
    return new Response(JSON.stringify(obj), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

function sendBinary(res, status, headers, body) {
    if (res && typeof res.setHeader === "function" && typeof res.send === "function") {
        res.statusCode = status;
        for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
        return res.send(body);
    }
    if (res && typeof res.setHeader === "function" && typeof res.end === "function") {
        res.statusCode = status;
        for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
        return res.end(body);
    }
    return new Response(body, { status, headers });
}

export default async function handler(req, res) {
    try {
        const host = getHeader(req, "host") || "localhost";
        let url;
        try { url = new URL(req.url, `https://${host}`); }
        catch { url = new URL(req.url); }
        const path = url.pathname;
        const route = url.searchParams.get("__route");

        if (
            (path === "/api/session/init" ||
                (path === "/api/secure" && route === "session_init")) &&
            req.method === "POST"
        ) {
            const body = await readBody(req);
            if (!body || typeof body !== "object") {
                err("session.bad_body", null, { route, method: req.method });
                return sendJson(res, 400, { err: "bad_json" });
            }
            const result = await createSession(body, req);
            return sendJson(res, result.status, result.body);
        }

        if (
            (path === "/api/payload.enc" ||
                (path === "/api/secure" && route === "payload_enc")) &&
            req.method === "GET"
        ) {
            const v = await validate(req, null);
            if (!v.ok) {
                log("payload.invalid", { why: v.why, hwid: maskHwid(getHeader(req, "x-hwid")) });
                return sendJson(res, 403, { err: v.why });
            }
            const result = await buildPayload(v.session, getHeader(req, "x-session"), getHeader(req, "x-hwid"));
            return sendJson(res, result.status, result.body);
        }

        if (
            (path === "/api/asset/kitagawa" ||
                (path === "/api/secure" && route === "asset_kitagawa")) &&
            req.method === "GET"
        ) {
            const v = await validate(req, null);
            if (!v.ok) {
                log("asset.invalid", { why: v.why, hwid: maskHwid(getHeader(req, "x-hwid")) });
                return sendJson(res, 403, { err: v.why });
            }
            const result = await buildAsset();
            if (result.isBinary) {
                return sendBinary(res, 200, {
                    "Content-Type": result.contentType,
                    "Cache-Control": "public, max-age=3600",
                }, result.body);
            }
            return sendJson(res, result.status, result.body);
        }

        if (route === "script_proxy" && req.method === "GET") {
            const v = await validate(req, null);
            if (!v.ok) {
                log("script.invalid", { why: v.why, hwid: maskHwid(getHeader(req, "x-hwid")) });
                return sendJson(res, 403, { err: v.why });
            }
            const rawPath = url.searchParams.get("__path") || "";
            let scriptPath = rawPath;
            try { scriptPath = decodeURIComponent(rawPath); } catch {}
            const result = await buildScript(
                scriptPath,
                v.session,
                getHeader(req, "x-session"),
                getHeader(req, "x-hwid")
            );
            return sendJson(res, result.status, result.body);
        }

        err("route.not_found", null, { path });
        return sendJson(res, 404, { err: "not_found", path });
    } catch (e) {
        err("handler.uncaught", e, { stack: e && e.stack ? String(e.stack).slice(0, 500) : null });
        return sendJson(res, 500, { err: "internal" });
    }
}
