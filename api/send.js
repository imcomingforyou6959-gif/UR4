import { Redis } from "@upstash/redis";

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

console.log("[/send] module loaded", {
    hasBanHook: !!BAN_HOOK,
    banHookPrefix: String(BAN_HOOK || "").slice(0, 40),
});

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
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
    console.log("[/send] readBody start", {
        hasReq: !!req,
        reqType: typeof req,
        ctor: req && req.constructor && req.constructor.name,
        hasBodyProp: req && req.body !== undefined,
        bodyType: req && req.body ? typeof req.body : "undefined",
        bodyCtor: req && req.body && req.body.constructor && req.body.constructor.name,
        hasJson: req && typeof req.json === "function",
        hasText: req && typeof req.text === "function",
        hasOn: req && typeof req.on === "function",
        hasGetReader: req && req.body && typeof req.body.getReader === "function",
    });

    if (!req) return null;

    const b = req.body;
    if (b !== undefined && b !== null) {
        if (typeof b === "object" && typeof b.getReader !== "function" && !Buffer.isBuffer(b)) {
            console.log("[/send] readBody path: plain object");
            return b;
        }
        if (typeof b === "string") {
            console.log("[/send] readBody path: string");
            try { return JSON.parse(b); } catch (e) { console.error("[/send] readBody string parse failed", String(e)); return null; }
        }
        if (Buffer.isBuffer(b)) {
            console.log("[/send] readBody path: Buffer");
            try { return JSON.parse(b.toString("utf8")); } catch (e) { console.error("[/send] readBody buffer parse failed", String(e)); return null; }
        }
        if (typeof b === "object" && typeof b.getReader === "function") {
            console.log("[/send] readBody path: stream (getReader)");
            try {
                const text = await new Response(b).text();
                console.log("[/send] readBody stream text length", text.length);
                return JSON.parse(text);
            } catch (e) { console.error("[/send] readBody stream failed", String(e)); return null; }
        }
    }

    if (typeof req.json === "function") {
        console.log("[/send] readBody path: req.json()");
        try {
            const r = await req.json();
            console.log("[/send] readBody req.json() result", { type: typeof r, keys: r && typeof r === "object" ? Object.keys(r) : null });
            return r;
        } catch (e) {
            console.error("[/send] readBody req.json() threw", String(e));
        }
    }

    if (typeof req.text === "function") {
        console.log("[/send] readBody path: req.text()");
        try {
            const t = await req.text();
            console.log("[/send] readBody req.text() length", t ? t.length : 0);
            return t ? JSON.parse(t) : null;
        } catch (e) {
            console.error("[/send] readBody req.text() threw", String(e));
        }
    }

    if (typeof req.on === "function") {
        console.log("[/send] readBody path: req.on() stream");
        try {
            const text = await new Promise((resolve, reject) => {
                const chunks = [];
                req.on("data", (c) => chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c)));
                req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
                req.on("error", reject);
            });
            console.log("[/send] readBody req.on stream length", text ? text.length : 0);
            return text ? JSON.parse(text) : null;
        } catch (e) {
            console.error("[/send] readBody req.on stream failed", String(e));
            return null;
        }
    }

    console.error("[/send] readBody exhausted all paths, returning null");
    return null;
}

async function sendToDiscord(out) {
    const url = process.env.DISCORD_WEBHOOK_URL;
    if (!url) {
        console.error("[/send] DISCORD_WEBHOOK_URL missing in this environment");
        return { ok: false, status: 0, err: "no_webhook_env" };
    }

    for (let attempt = 0; attempt < 3; attempt++) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 8000);
        try {
            console.log("[/send] dispatching to Discord", { attempt });
            const res = await fetch(url, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(out),
                signal: controller.signal,
            });
            clearTimeout(timer);

            const bodyText = await res.text().catch(() => "");
            console.log("[/send] discord responded", { status: res.status, body: bodyText.slice(0, 500) });

            if (res.status === 429) {
                let wait = 1;
                try {
                    const j = JSON.parse(bodyText);
                    if (j && typeof j.retry_after === "number") wait = j.retry_after;
                } catch {}
                await new Promise(r => setTimeout(r, Math.min(wait * 1000, 5000)));
                continue;
            }
            return { ok: res.ok, status: res.status, body: bodyText.slice(0, 500) };
        } catch (e) {
            clearTimeout(timer);
            console.error("[/send] discord fetch threw", { attempt, err: String(e) });
            if (attempt === 2) return { ok: false, status: 0, err: String(e) };
            await new Promise(r => setTimeout(r, 300 * (attempt + 1)));
        }
    }
    return { ok: false, status: 429, err: "exhausted_retries" };
}

async function sendBatchEmbed(items) {
    console.log("[/send?report] sendBatchEmbed called", { count: items && items.length });
    if (!items || items.length === 0) {
        console.warn("[/send?report] sendBatchEmbed: empty items, returning");
        return;
    }
    if (!BAN_HOOK) {
        console.error("[/send?report] BAN_HOOK env var missing");
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
        { name: "HWID",     value: clean(String(latest.hwid), 128), inline: false },
        { name: "User",     value: clean(String(latest.user || "?"), 64), inline: true },
        { name: "Display",  value: clean(String(latest.disp || "?"), 64), inline: true },
        { name: "UID",      value: String(latest.uid),               inline: true },
        { name: "Exec",     value: clean(String(latest.exec || "?"), 64), inline: true },
        { name: "Place",    value: String(latest.pid || 0),          inline: true },
        { name: "Job",      value: clean(String(latest.jid || "?"), 40), inline: true },
        { name: "When",     value: `<t:${latest.when || Math.floor(Date.now() / 1000)}:R>`, inline: false },
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

    try {
        console.log("[/send?report] dispatching batched ban embed", { count: items.length, title });
        const res = await fetch(BAN_HOOK, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(embed),
        });
        const bodyText = await res.text().catch(() => "");
        console.log("[/send?report] ban hook responded", { status: res.status, body: bodyText.slice(0, 300) });
    } catch (e) {
        console.error("[/send?report] ban hook fetch failed", String(e));
    }
}

async function reportBan(b) {
    console.log("[/send?report] reportBan called", {
        hasB: !!b,
        bType: typeof b,
        keys: b && typeof b === "object" ? Object.keys(b) : null,
    });

    if (!b || typeof b !== "object") {
        console.error("[/send?report] reportBan: body is null/non-object, returning bad_json");
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    const hwid = b.hwid, un = b.username, dn = b.displayName, uid = b.userId;
    const pid = b.placeId, jid = b.jobId, ts = b.timestamp, ex = b.executor;
    const reason = String(b.reason || "");
    const ua = b.ua;
    const claimed = b.claimedExecutor;

    console.log("[/send?report] parsed fields", {
        hwid: String(hwid || "").slice(0, 12),
        uid,
        reason,
        hasUa: !!ua,
        hasClaimed: !!claimed,
    });

    if (!hwid || !uid) {
        console.warn("[/send?report] missing hwid or uid", { hwid, uid });
        return Response.json({ err: "missing" }, { status: 400 });
    }

    if (!ALLOWED_REASONS.test(reason)) {
        console.warn("[/send?report] reason not allowed, ignoring", { reason });
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

    console.log("[/send?report] entry built", entry);

    const bufKey   = `banbuf:${hwid}`;
    const flushKey = `banbuf:${hwid}:flush`;

    try {
        await db.rpush(bufKey, JSON.stringify(entry));
        await db.expire(bufKey, BATCH_TTL_SEC);
        console.log("[/send?report] rpush ok", { bufKey });
    } catch (e) {
        console.error("[/send?report] buffer write failed", String(e));
        return Response.json({ err: "buffer_write", msg: String(e) }, { status: 500 });
    }

    let got;
    try {
        got = await db.set(flushKey, "1", { nx: true, ex: BATCH_TTL_SEC });
        console.log("[/send?report] flush lock result", { got, gotType: typeof got });
    } catch (e) {
        console.error("[/send?report] flush lock failed", String(e));
        return Response.json({ ok: true, buffered: true });
    }

    const ownsFlush = (got === "OK" || got === true || (got && typeof got === "object" && got.result === "OK"));
    console.log("[/send?report] ownsFlush", ownsFlush);

    if (!ownsFlush) {
        console.log("[/send?report] buffered (another flush in progress)", { hwid });
        try { await db.expire(bufKey, BATCH_TTL_SEC); } catch {}
        return Response.json({ ok: true, buffered: true });
    }

    console.log("[/send?report] sleeping for batch window", { ms: BATCH_WINDOW_MS });
    await new Promise((r) => setTimeout(r, BATCH_WINDOW_MS));
    console.log("[/send?report] woke from batch window");

    let raw = [];
    try {
        raw = await db.lrange(bufKey, 0, -1);
        console.log("[/send?report] lrange returned", { count: raw ? raw.length : 0 });
        await db.del(bufKey);
        await db.del(flushKey);
    } catch (e) {
        console.error("[/send?report] buffer drain failed", String(e));
    }

    const items = [];
    for (const r of raw) {
        try {
            const parsed = typeof r === "string" ? JSON.parse(r) : r;
            if (parsed && typeof parsed === "object") items.push(parsed);
        } catch (e) {
            console.error("[/send?report] parse buffer entry failed", String(e));
        }
    }

    console.log("[/send?report] flushing batch", { count: items.length, hwid });

    if (items.length > 0) {
        await sendBatchEmbed(items);
    } else {
        console.warn("[/send?report] no items to flush");
    }

    return Response.json({ ok: true, batched: items.length });
}

export async function POST(req) {
    console.log("[/send] POST handler entry", {
        hasReq: !!req,
        reqType: typeof req,
        ctor: req && req.constructor && req.constructor.name,
        hasBodyProp: req && req.body !== undefined,
        bodyType: req && req.body ? typeof req.body : "undefined",
        bodyCtor: req && req.body && req.body.constructor && req.body.constructor.name,
        hasJson: req && typeof req.json === "function",
        hasText: req && typeof req.text === "function",
        hasOn: req && typeof req.on === "function",
        hasGetReader: req && req.body && typeof req.body.getReader === "function",
        urlType: req && typeof req.url,
        urlValue: req && typeof req.url === "string" ? req.url.slice(0, 200) : "(not a string)",
        hasHeaders: req && !!req.headers,
        headersCtor: req && req.headers && req.headers.constructor && req.headers.constructor.name,
    });

    let url;
    try {
        url = new URL(req.url);
        console.log("[/send] URL parsed", { href: url.href, pathname: url.pathname });
    } catch (e) {
        console.error("[/send] URL parse failed, using fallback", String(e));
        url = new URL(req.url, "https://ur-4.vercel.app");
    }
    const route = url.searchParams.get("__route");
    console.log("[/send] route", { route });

    const body = await readBody(req);

    console.log("[/send] body resolved", {
        hasBody: !!body,
        bodyType: typeof body,
        keys: body && typeof body === "object" ? Object.keys(body) : null,
    });

    if (route === "report") {
        return reportBan(body);
    }

    if (!body || typeof body !== "object") {
        console.error("[/send] bad body for non-report route");
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    const { token, payload } = body;
    console.log("[/send] non-report body", {
        hasToken: !!token,
        tokenPrefix: token ? String(token).slice(0, 8) : null,
        hasPayload: !!payload,
    });

    if (!token || !payload) {
        console.warn("[/send] missing token or payload");
        return Response.json({ err: "missing" }, { status: 400 });
    }

    const key = `token:${token}`;

    let current;
    try {
        current = await db.get(key);
    } catch (e) {
        console.error("[/send] redis get failed", String(e));
        return Response.json({ err: "redis_error" }, { status: 500 });
    }

    console.log("[/send] token lookup", {
        tokenPrefix: String(token).slice(0, 8),
        value: current,
        type: typeof current,
    });

    if (current !== "unused") {
        console.warn("[/send] token not unused", { current });
        return Response.json({ err: "bad_token", current, got: current }, { status: 403 });
    }

    let consumed;
    try {
        consumed = await db.set(key, "used", { xx: true });
        console.log("[/send] token consume result", { consumed, consumedType: typeof consumed });
    } catch (e) {
        console.error("[/send] redis set failed", String(e));
        return Response.json({ err: "redis_error" }, { status: 500 });
    }

    if (consumed !== "OK") {
        console.warn("[/send] token consume rejected", { consumed });
        return Response.json({ err: "bad_token", consumed }, { status: 403 });
    }

    await db.expire(key, 300).catch(() => {});

    if (!payload.embeds || !Array.isArray(payload.embeds) || payload.embeds.length !== 1) {
        console.warn("[/send] bad embed shape", { embedsLength: payload.embeds && payload.embeds.length });
        return Response.json({ err: "bad_embed" }, { status: 400 });
    }

    const v = check(payload.embeds[0]);
    if (!v.ok) {
        console.warn("[/send] embed rejected by check()", { why: v.why });
        return Response.json({ err: "rejected", why: v.why }, { status: 400 });
    }

    console.log("[/send] embed validated, sending to Discord");

    const out = {
        username: USER,
        embeds: [v.out],
    };

    const r = await sendToDiscord(out);
    console.log("[/send] final response", r);
    return Response.json(r);
}
