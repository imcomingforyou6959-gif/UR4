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

    return {
        ok: true,
        out: {
            title: TITLE,
            color: COLOR,
            footer: { text: FOOT },
            thumbnail: { url: clean(emb.thumbnail.url, THUMB_MAX) },
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
    for (let attempt = 0; attempt < 3; attempt++) {
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

            if (res.status === 429) {
                let wait = 1;
                try {
                    const j = await res.json();
                    if (j && typeof j.retry_after === "number") wait = j.retry_after;
                } catch {}
                // Cap wait so we never exceed Vercel's timeout
                await new Promise(r => setTimeout(r, Math.min(wait * 1000, 5000)));
                continue;
            }
            return { ok: res.ok, status: res.status };
        } catch (e) {
            clearTimeout(timer);
            if (attempt === 2) return { ok: false, status: 0, err: String(e) };
            await new Promise(r => setTimeout(r, 300 * (attempt + 1)));
        }
    }
    return { ok: false, status: 429, err: "exhausted_retries" };
}

export async function POST(req) {
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

    const got = await db.set(key, "used", { xx: true, get: true });

    if (got !== "unused") {
        return Response.json({ err: "bad_token" }, { status: 403 });
    }

    await db.expire(key, 300);

    if (!payload.embeds || !Array.isArray(payload.embeds) || payload.embeds.length !== 1) {
        return Response.json({ err: "bad_embed" }, { status: 400 });
    }

    const v = check(payload.embeds[0]);
    if (!v.ok) {
        return Response.json({ err: "rejected", why: v.why }, { status: 400 });
    }

    const out = {
        username: USER,
        embeds: [v.out],
    };

    const r = await sendToDiscord(out);
    return Response.json(r);
}
