import { Redis } from "@upstash/redis";
import { validate } from "./secure.js";

const db = Redis.fromEnv();

const NAMES = [
    "⚓ Display Name",
    "🔗 Username",
    "📌 User ID",
    "🌐 Server",
    "📍 Region",
    "🧩 Executor",
    "🔢 Version",
    "🆔 HWID",
    "Device",
    "⏱️ Timestamp",
    "🔗 Join Link",
];

const TITLE = "Execution Logs";
const FOOT = "Dev <3 | New";
const COLOR = 0xffbdd2;
const USER = "one love for security";
const VAL_MAX = 1024;
const THUMB_MAX = 512;

const BAN_HOOK = process.env.BAN_HOOK || process.env.ALT_HOOK || process.env.DISCORD_WEBHOOK_URL;
const BAN_COL = 0xff4444;

const ALLOWED_REASONS = /^(ua_mismatch|hard_block_ua:.+|AUTH_NETWORK|SEND_FAILED|SEND_HTTP_\d+|JSON_ENCODE|TOKEN_FAILED|UNKNOWN)$/;

const BATCH_WINDOW_MS = 2000;
const BATCH_TTL_SEC = 60;

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

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
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

function check(emb) {
    if (!emb || typeof emb !== "object") return { ok: false, why: "no_embed" };
    if (emb.title !== TITLE) return { ok: false, why: "bad_title" };
    if (emb.color !== COLOR) return { ok: false, why: "bad_color" };
    if (!emb.footer || emb.footer.text !== FOOT) return { ok: false, why: "bad_footer" };
    if (!Array.isArray(emb.fields)) return { ok: false, why: "no_fields" };
    if (emb.fields.length !== NAMES.length) return { ok: false, why: "field_count" };

    for (let i = 0; i < NAMES.length; i++) {
        const f = emb.fields[i];
        if (!f || f.name !== NAMES[i]) return { ok: false, why: `field_${i}` };
        if (typeof f.value !== "string" || f.value.length > VAL_MAX) {
            return { ok: false, why: `val_${i}` };
        }
        if (f.inline !== true && f.inline !== false) {
            return { ok: false, why: `inline_${i}` };
        }
    }

    if (!emb.thumbnail || typeof emb.thumbnail.url !== "string") {
        return { ok: false, why: "bad_thumb" };
    }

    const thumbUrl = emb.thumbnail.url.trim() === ""
        ? "https://cdn.discordapp.com/embed/avatars/0.png"
        : emb.thumbnail.url;

    return {
        ok: true,
        out: {
            title: TITLE,
            color: COLOR,
            footer: { text: FOOT },
            thumbnail: { url: clean(thumbUrl, THUMB_MAX) },
            fields: emb.fields.map((f, i) => ({
                name: NAMES[i],
                value: clean(f.value, VAL_MAX),
                inline: f.inline,
            })),
        },
    };
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

async function sendToDiscord(out) {
    const url = process.env.DISCORD_WEBHOOK_URL;
    if (!url) {
        err("send.webhook_missing");
        return { ok: false, status: 0, err: "no_webhook_env" };
    }

    const payloadBytes = Buffer.byteLength(JSON.stringify(out), "utf8");

    for (let attempt = 1; attempt <= 3; attempt++) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 8000);
        try {
            const res = await fetch(url, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(out),
                signal: controller.signal,
            });
            clearTimeout(timer);
            const bodyText = await res.text().catch(() => "");
            log("send.discord_response", { attempt, status: res.status, bytes: payloadBytes });

            if (res.status === 429) {
                let wait = 1;
                try {
                    const j = JSON.parse(bodyText);
                    if (j && typeof j.retry_after === "number") wait = j.retry_after;
                } catch {}
                await new Promise(r => setTimeout(r, Math.min(wait * 1000, 5000)));
                continue;
            }

            if (!res.ok) {
                err("send.discord_rejected", `status ${res.status}`, {
                    attempt,
                    status: res.status,
                    body: bodyText.slice(0, 300),
                });
            }
            return { ok: res.ok, status: res.status };
        } catch (e) {
            clearTimeout(timer);
            err("send.discord_fetch_failed", e, { attempt });
            if (attempt === 3) return { ok: false, status: 0, err: String(e) };
            await new Promise(r => setTimeout(r, 300 * attempt));
        }
    }
    err("send.discord_retries_exhausted");
    return { ok: false, status: 429, err: "exhausted_retries" };
}

async function sendBatchEmbed(items) {
    if (!items || items.length === 0) {
        log("report.batch_empty");
        return;
    }
    if (!BAN_HOOK) {
        err("report.ban_hook_missing");
        return;
    }

    const latest = items[items.length - 1];
    const reasons = new Set(items.map((i) => String(i.reason || "").split(":")[0]));
    const hasHardBlock = [...reasons].some((r) => r === "hard_block_ua");
    const hasMismatch   = [...reasons].some((r) => r === "ua_mismatch");

    let title;
    if (items.length === 1) {
        title = hasHardBlock ? "Blacklisted Client" : "Executor Spoof";
    } else {
        if (hasHardBlock && hasMismatch) title = `Detection Batch (${items.length})`;
        else if (hasHardBlock)            title = `Blacklisted Clients (${items.length})`;
        else                              title = `Executor Spoofs (${items.length})`;
    }

    const fields = [
        { name: "HWID",    value: clean(String(latest.hwid), 128), inline: false },
        { name: "User",    value: clean(String(latest.user || "?"), 64), inline: true },
        { name: "Display", value: clean(String(latest.disp || "?"), 64), inline: true },
        { name: "UID",     value: String(latest.uid), inline: true },
        { name: "Exec",    value: clean(String(latest.exec || "?"), 64), inline: true },
        { name: "Place",   value: String(latest.pid || 0), inline: true },
        { name: "Job",     value: clean(String(latest.jid || "?"), 40), inline: true },
        { name: "When",    value: `<t:${latest.when || Math.floor(Date.now() / 1000)}:R>`, inline: false },
    ];

    if (items.length === 1) {
        const it = items[0];
        if (it.reason)  fields.push({ name: "Reason", value: clean(String(it.reason), 128), inline: false });
        if (it.ua)      fields.push({ name: "User-Agent", value: "`" + clean(String(it.ua), 200) + "`", inline: false });
        if (it.claimed) fields.push({ name: "Claimed Executor", value: clean(String(it.claimed), 64), inline: true });
    } else {
        const lines = items.slice(-10).map((it) => {
            const uaShort = it.ua ? "`" + clean(String(it.ua), 60) + "`" : "_(no ua)_";
            const claim   = it.claimed ? ` claimed=\`${clean(String(it.claimed), 32)}\`` : "";
            return `• **${clean(String(it.reason || "?"), 40)}**${claim}\n  ${uaShort}`;
        });
        if (items.length > 10) lines.push(`_…and ${items.length - 10} more in this window_`);
        fields.push({ name: `Detections (${items.length})`, value: lines.join("\n").slice(0, 1024), inline: false });
    }

    const embed = {
        username: "a soft spot for love",
        embeds: [{
            title,
            color: BAN_COL,
            fields,
            footer: { text: "i hope im secure" },
        }],
    };

    log("report.dispatching", {
        count: items.length,
        title,
        hwid: maskHwid(latest.hwid),
        reasons: [...reasons],
    });

    try {
        const res = await fetch(BAN_HOOK, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(embed),
        });
        const bodyText = await res.text().catch(() => "");
        if (res.status === 204 || res.ok) {
            log("report.delivered", { count: items.length, status: res.status });
        } else {
            err("report.discord_rejected", `status ${res.status}`, {
                count: items.length,
                status: res.status,
                body: bodyText.slice(0, 300),
            });
        }
    } catch (e) {
        err("report.discord_fetch_failed", e, { count: items.length });
    }
}

async function reportBan(b) {
    if (!b || typeof b !== "object") {
        err("report.bad_body");
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    const hwid = b.hwid, un = b.username, dn = b.displayName, uid = b.userId;
    const pid = b.placeId, jid = b.jobId, ts = b.timestamp, ex = b.executor;
    const reason = String(b.reason || "");
    const ua = b.ua;
    const claimed = b.claimedExecutor;

    if (!hwid || !uid) {
        err("report.missing_fields", null, { hasHwid: !!hwid, hasUid: !!uid });
        return Response.json({ err: "missing" }, { status: 400 });
    }

    if (!ALLOWED_REASONS.test(reason)) {
        log("report.reason_ignored", { reason, hwid: maskHwid(hwid) });
        return Response.json({ ok: true, ignored: true, reason });
    }

    const entry = {
        hwid:    clean(String(hwid), 128),
        user:    clean(String(un || "?"), 64),
        disp:    clean(String(dn || "?"), 64),
        uid:     String(uid),
        exec:    clean(String(ex || "?"), 64),
        pid:     String(pid || 0),
        jid:     clean(String(jid || "?"), 40),
        when:    Number(ts) || Math.floor(Date.now() / 1000),
        reason:  clean(reason, 128),
        ua:      clean(String(ua || ""), 200),
        claimed: clean(String(claimed || ""), 64),
    };

    const bufKey   = `banbuf:${hwid}`;
    const flushKey = `banbuf:${hwid}:flush`;

    try {
        await db.rpush(bufKey, JSON.stringify(entry));
        await db.expire(bufKey, BATCH_TTL_SEC);
        log("report.buffered", {
            hwid: maskHwid(hwid),
            reason,
            buffer: bufKey.replace(hwid, maskHwid(hwid)),
        });
    } catch (e) {
        err("report.buffer_write_failed", e, { hwid: maskHwid(hwid) });
        return Response.json({ err: "buffer_write" }, { status: 500 });
    }

    let got;
    try {
        got = await db.set(flushKey, "1", { nx: true, ex: BATCH_TTL_SEC });
    } catch (e) {
        err("report.flush_lock_failed", e, { hwid: maskHwid(hwid) });
        return Response.json({ ok: true, buffered: true });
    }

    const ownsFlush = (got === "OK" || got === true || (got && typeof got === "object" && got.result === "OK"));

    if (!ownsFlush) {
        log("report.flush_deferred", {
            hwid: maskHwid(hwid),
            reason: "another flush in progress",
        });
        try { await db.expire(bufKey, BATCH_TTL_SEC); } catch {}
        return Response.json({ ok: true, buffered: true });
    }

    log("report.flush_start", { hwid: maskHwid(hwid), window_ms: BATCH_WINDOW_MS });
    await new Promise((r) => setTimeout(r, BATCH_WINDOW_MS));

    let raw = [];
    try {
        raw = await db.lrange(bufKey, 0, -1);
        await db.del(bufKey);
        await db.del(flushKey);
    } catch (e) {
        err("report.buffer_drain_failed", e, { hwid: maskHwid(hwid) });
    }

    const items = [];
    for (const r of raw) {
        try {
            const parsed = typeof r === "string" ? JSON.parse(r) : r;
            if (parsed && typeof parsed === "object") items.push(parsed);
        } catch (e) {
            err("report.buffer_parse_failed", e);
        }
    }

    log("report.flush_complete", { hwid: maskHwid(hwid), count: items.length });
    if (items.length > 0) await sendBatchEmbed(items);
    return Response.json({ ok: true, batched: items.length });
}

export async function POST(req) {
    let url;
    try { url = new URL(req.url); }
    catch { url = new URL(req.url, "https://ur-4.vercel.app"); }
    const route = url.searchParams.get("__route");

    const body = await readBody(req);

    if (route === "report") {
        return reportBan(body);
    }

    if (!body || typeof body !== "object") {
        err("send.bad_body");
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    const v = await validate(req, body);
    if (!v.ok) {
        log("send.unauthorized", {
            why: v.why,
            hwid: maskHwid(req.headers?.get?.("x-hwid") || req.headers?.["x-hwid"] || ""),
        });
        return Response.json({ err: "unauthorized", why: v.why }, { status: 403 });
    }

    const payload = body.payload;

    if (!payload) {
        err("send.missing_payload");
        return Response.json({ err: "missing" }, { status: 400 });
    }

    if (!payload.embeds || !Array.isArray(payload.embeds) || payload.embeds.length !== 1) {
        err("send.bad_embed_shape", null, {
            session: maskToken(req.headers?.get?.("x-session") || ""),
            embedsLength: payload.embeds && payload.embeds.length,
        });
        return Response.json({ err: "bad_embed" }, { status: 400 });
    }

    const v2 = check(payload.embeds[0]);
    if (!v2.ok) {
        err("send.embed_check_failed", null, {
            session: maskToken(req.headers?.get?.("x-session") || ""),
            why: v2.why,
        });
        return Response.json({ err: "rejected", why: v2.why }, { status: 400 });
    }

    log("send.embed_validated", {
        session: maskToken(req.headers?.get?.("x-session") || ""),
    });

    const out = { username: USER, embeds: [v2.out] };
    const r = await sendToDiscord(out);
    return Response.json(r);
}
