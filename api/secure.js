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
    "vega x", "cryptic", "scriptware", "arceus x", "roblox"
];

const FORWARD_BASE_URL = "https://ur-4.vercel.app";

function log(event, data) {
    const line = { evt: event, ts: Date.now(), ...data };
    console.log(JSON.stringify(line));
}

function err(event, e, extra) {
    const line = {
        evt: event,
        ts: Date.now(),
        err: String(e && e.message ? e.message : e),
        ...(extra || {}),
    };
    console.error(JSON.stringify(line));
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

async function getBanList() {
    const now = Date.now();
    if (banCache.data && now - banCache.at < BAN_CACHE_TTL_MS) {
        return banCache.data;
    }
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
        return {
            action: "report",
            reason: "ua_mismatch",
            ua,
            claimed: claimedExecutor,
        };
    }

    return { action: "none", reason: "ok" };
}

async function forwardBanReport(payload) {
    try {
        log("ban_forward.start", {
            reason: payload.reason,
            hwid: maskHwid(payload.hwid),
        });
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

async function readBody(req) {
    if (!req) return null;

    const b = req.body;
    if (b !== undefined && b !== null) {
        if (typeof b === "object" && typeof b.getReader !== "function" && !Buffer.isBuffer(b)) return b;
        if (typeof b === "string") { try { return JSON.parse(b); } catch { return null; } }
        if (Buffer.isBuffer(b)) { try { return JSON.parse(b.toString("utf8")); } catch { return null; } }
        if (typeof b === "object" && typeof b.getReader === "function") {
            try { const text = await new Response(b).text(); return JSON.parse(text); } catch { return null; }
        }
    }

    if (typeof req.json === "function") {
        try { return await req.json(); } catch {}
    }
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
    if (typeof req.headers.get === "function") {
        return String(req.headers.get(name) || "");
    }
    const raw = req.headers[name] || req.headers[name.toLowerCase()];
    return raw ? String(raw) : "";
}

async function createSession(body, req) {
    const { hwid, executor, placeId, jobId, userId, userName, displayName } = body || {};
    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        err("session.missing_hwid", null, {
            hasHwid: !!hwid,
            hwidLen: typeof hwid === "string" ? hwid.length : 0,
        });
        return { status: 400, body: { err: "missing_hwid" } };
    }

    const banEntry = await checkBanned(hwid);
    if (banEntry) {
        log("session.banned", { hwid: maskHwid(hwid), reason: banEntry.reason || "banned" });
        return {
            status: 403,
            body: { err: "banned", reason: banEntry.reason || "banned" },
        };
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
        log("session.created", {
            hwid: maskHwid(hwid),
            token: maskToken(token),
            user: String(userName || "?").slice(0, 40),
        });
    } catch (e) {
        err("session.store_failed", e, { hwid: maskHwid(hwid) });
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
    } catch (e) {
        err("session.read_failed", e, { token: maskToken(token) });
        return null;
    }
    if (!s || s.hwid !== hwid) return null;
    if (Math.floor(Date.now() / 1000) > s.expiresAt) {
        await db.del(`sess:${token}`).catch(() => {});
        log("session.expired", { token: maskToken(token) });
        return null;
    }
    return s;
}

async function buildPayload(session, token, hwid) {
    if (!PAYLOAD_REPO_TOKEN) {
        err("payload.token_missing");
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
        err("payload.fetch_failed", e, { token: maskToken(token) });
        return { status: 500, body: { err: "payload_fetch", msg: String(e) } };
    }

    if (!plaintext || plaintext.length < 10) {
        err("payload.empty", null, { length: plaintext ? plaintext.length : 0 });
        return { status: 500, body: { err: "payload_empty" } };
    }

    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const buf = Buffer.from(plaintext, "utf8");
    const out = Buffer.alloc(buf.length);
    for (let i = 0; i < buf.length; i++) {
        out[i] = buf[i] ^ key[i % key.length];
    }

    log("payload.delivered", {
        token: maskToken(token),
        hwid: maskHwid(hwid),
        bytes: out.length,
    });

    return { status: 200, body: out, isBinary: true };
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
        return {
            status: 200,
            body: buf,
            contentType: assetCache.contentType,
            isBinary: true,
        };
    } catch (e) {
        err("asset.fetch_failed", e);
        return { status: 500, body: { err: "asset_fetch", msg: String(e) } };
    }
}

async function buildScript(scriptPath, token, hwid) {
    const norm = String(scriptPath || "").replace(/^\/+/, "");
    if (!norm || norm.includes("..") || norm.length > 200) {
        err("script.bad_path", null, { path: norm.slice(0, 80) });
        return { status: 400, body: { err: "bad_path" } };
    }
    const allowed = SCRIPT_ALLOWED_PREFIXES.some(
        (p) => norm === p || norm.startsWith(p)
    );
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
            log("script.fetched", {
                path: norm,
                bytes: isBinaryContent ? plaintext.length : plaintext.length,
            });
        } catch (e) {
            err("script.fetch_failed", e, { path: norm });
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

    log("script.delivered", {
        path: norm,
        token: maskToken(token),
        hwid: maskHwid(hwid),
        bytes: out.length,
    });

    return {
        status: 200,
        body: out,
        contentType: "application/octet-stream",
        isBinary: true,
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
            const token = url.searchParams.get("s");
            const hwid = getHeader(req, "x-hwid");

            if (!token || !hwid) {
                log("payload.no_session", { hasToken: !!token, hasHwid: !!hwid });
                return sendJson(res, 403, { err: "no_session" });
            }

            const session = await getSession(token, hwid);
            if (!session) {
                log("payload.invalid_session", { token: maskToken(token), hwid: maskHwid(hwid) });
                return sendJson(res, 403, { err: "invalid_session" });
            }

            const result = await buildPayload(session, token, hwid);
            if (result.isBinary) {
                return sendBinary(res, 200, {
                    "Content-Type": "application/octet-stream",
                    "Cache-Control": "no-store",
                }, result.body);
            }
            return sendJson(res, result.status, result.body);
        }

        if (
            (path === "/api/asset/kitagawa" ||
                (path === "/api/secure" && route === "asset_kitagawa")) &&
            req.method === "GET"
        ) {
            const token = url.searchParams.get("s");
            const hwid = getHeader(req, "x-hwid");

            if (!token || !hwid) {
                log("asset.no_session", { hasToken: !!token, hasHwid: !!hwid });
                return sendJson(res, 403, { err: "no_session" });
            }

            const session = await getSession(token, hwid);
            if (!session) {
                log("asset.invalid_session", { token: maskToken(token), hwid: maskHwid(hwid) });
                return sendJson(res, 403, { err: "invalid_session" });
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
            const token = url.searchParams.get("s");
            const hwid = getHeader(req, "x-hwid");

            if (!token || !hwid) {
                log("script.no_session", { hasToken: !!token, hasHwid: !!hwid });
                return sendJson(res, 403, { err: "no_session" });
            }

            const session = await getSession(token, hwid);
            if (!session) {
                log("script.invalid_session", { token: maskToken(token), hwid: maskHwid(hwid) });
                return sendJson(res, 403, { err: "invalid_session" });
            }

            const rawPath = url.searchParams.get("__path") || "";
            let scriptPath = rawPath;
            try { scriptPath = decodeURIComponent(rawPath); } catch {}
            const result = await buildScript(scriptPath, token, hwid);
            if (result.isBinary) {
                return sendBinary(res, 200, {
                    "Content-Type": "application/octet-stream",
                    "Cache-Control": "no-store",
                }, result.body);
            }
            return sendJson(res, result.status, result.body);
        }

        err("route.not_found", null, { path });
        return sendJson(res, 404, { err: "not_found", path });
    } catch (e) {
        err("handler.uncaught", e, { stack: e && e.stack ? String(e.stack).slice(0, 500) : null });
        return sendJson(res, 500, { err: "internal" });
    }
}
