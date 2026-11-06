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

const ALT_HOOK = process.env.ALT_HOOK || process.env.ALT_HOOK || process.env.DISCORD_WEBHOOK_URL;
const BAN_COL = 0xff4444;

const ALLOWED_REASONS = /^(ua_mismatch|hard_block_ua:.+|AUTH_NETWORK|SEND_FAILED|SEND_HTTP_\d+|JSON_ENCODE|TOKEN_FAILED|UNKNOWN)$/;

const BATCH_WINDOW_MS = 2000;
const BATCH_TTL_SEC = 60;

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
    if (!items || items.length === 0) return;
    if (!ALT_HOOK) {
        console.error("[/send?report] ALT_HOOK env var missing");
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
        const res = await fetch(ALT_HOOK, {
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

async function reportBan(req) {
    let b;
    try { b = await req.json(); } catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = b.hwid, un = b.username, dn = b.displayName, uid = b.userId;
    const pid = b.placeId, jid = b.jobId, ts = b.timestamp, ex = b.executor;
    const reason = String(b.reason || "");
    const ua = b.ua;
    const claimed = b.claimedExecutor;

    if (!hwid || !uid) return Response.json({ err: "missing" }, { status: 400 });

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

    const bufKey   = `banbuf:${hwid}`;
    const flushKey = `banbuf:${hwid}:flush`;

    try {
        await db.rpush(bufKey, JSON.stringify(entry));
        await db.expire(bufKey, BATCH_TTL_SEC);
    } catch (e) {
        console.error("[/send?report] buffer write failed", String(e));
        return Response.json({ err: "buffer_write", msg: String(e) }, { status: 500 });
    }

    let got;
    try {
        got = await db.set(flushKey, "1", { nx: true, ex: BATCH_TTL_SEC });
    } catch (e) {
        console.error("[/send?report] flush lock failed", String(e));
        return Response.json({ ok: true, buffered: true });
    }

    const ownsFlush = (got === "OK" || got === true);

    if (!ownsFlush) {
        console.log("[/send?report] buffered (another flush in progress)", { hwid });
        try { await db.expire(bufKey, BATCH_TTL_SEC); } catch {}
        return Response.json({ ok: true, buffered: true });
    }

    await new Promise((r) => setTimeout(r, BATCH_WINDOW_MS));

    let raw = [];
    try {
        raw = await db.lrange(bufKey, 0, -1);
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
        } catch {}
    }

    console.log("[/send?report] flushing batch", { count: items.length, hwid });

    if (items.length > 0) {
        await sendBatchEmbed(items);
    }

    return Response.json({ ok: true, batched: items.length });
}

export async function POST(req) {
    const url = new URL(req.url);
    const route = url.searchParams.get("__route");

    if (route === "report") return reportBan(req);

    let body;
    try {
        body = await req.json();
    } catch {
        return Response.json({ err: "bad_json" }, { status: 400 });
    }

    const { token, payload } = body;
    if (!token || !payload) {
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
        return Response.json({ err: "bad_token", current, got: current }, { status: 403 });
    }

    let consumed;
    try {
        consumed = await db.set(key, "used", { xx: true });
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
        return Response.json({ err: "bad_embed" }, { status: 400 });
    }

    const v = check(payload.embeds[0]);
    if (!v.ok) {
        console.warn("[/send] embed rejected by check()", { why: v.why });
        return Response.json({ err: "rejected", why: v.why }, { status: 400 });
    }

    const out = {
        username: USER,
        embeds: [v.out],
    };

    const r = await sendToDiscord(out);
    return Response.json(r);
}
