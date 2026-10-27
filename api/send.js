import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();

export async function POST(request) {
    let body;
    try {
        body = await request.json();
    } catch {
        return Response.json({ error: "bad_json" }, { status: 400 });
    }

    const { token, payload } = body;
    if (!token || !payload) {
        return Response.json({ error: "missing_fields" }, { status: 400 });
    }

    const tokenKey = `token:${token}`;

    const result = await redis.set(tokenKey, "used", {
        xx: true,
        get: true,
    });

    if (result !== "unused") {
        return Response.json({ error: "invalid_or_used" }, { status: 403 });
    }

    await redis.expire(tokenKey, 300);

    if (!payload.embeds || !Array.isArray(payload.embeds)) {
        return Response.json({ error: "invalid_embed" }, { status: 400 });
    }

    const discordResp = await fetch(process.env.DISCORD_WEBHOOK_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });

    return Response.json({ ok: discordResp.ok, status: discordResp.status });
}
