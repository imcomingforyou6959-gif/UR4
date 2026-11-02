import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();
const FAIL_HOOK = process.env.FAIL_HOOK || process.env.DISCORD_WEBHOOK_URL;

const FAIL_COL = 0xffaa00;

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
}

export async function POST(req) {
    let b;
    try { b = await req.json(); } catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const stage = clean(String(b.stage || "unknown"), 64);
    const detail = clean(String(b.detail || ""), 500);

    console.error("[/fail]", { stage, detail, userId: b.userId });

    if (!FAIL_HOOK) {
        return Response.json({ ok: false, err: "no_hook" }, { status: 500 });
    }

    const embed = {
        username: "silent failure watcher",
        embeds: [{
            title: "Payload did not fire /send",
            color: FAIL_COL,
            fields: [
                { name: "Stage",    value: stage,                       inline: false },
                { name: "Detail",   value: detail || "(none)",          inline: false },
                { name: "User",     value: clean(String(b.userName || "?"), 64), inline: true },
                { name: "UID",      value: String(b.userId || 0),       inline: true },
                { name: "Executor", value: clean(String(b.executor || "?"), 64), inline: true },
                { name: "HWID",     value: clean(String(b.hwid || "?"), 128),    inline: false },
                { name: "Place",    value: String(b.placeId || 0),      inline: true },
                { name: "Job",      value: clean(String(b.jobId || "?"), 40),    inline: true },
                { name: "When",     value: `<t:${b.timestamp || Math.floor(Date.now()/1000)}:R>`, inline: false },
            ],
            footer: { text: "error log" },
        }],
    };

    try {
        const res = await fetch(FAIL_HOOK, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(embed),
        });
        const body = await res.text().catch(() => "");
        console.error("[/fail] hook responded", { status: res.status, body: body.slice(0, 300) });
        return Response.json({ ok: res.ok, status: res.status });
    } catch (e) {
        console.error("[/fail] hook fetch threw", String(e));
        return Response.json({ ok: false, err: String(e) }, { status: 500 });
    }
}
