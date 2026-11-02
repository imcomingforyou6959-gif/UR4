import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();

function generateToken() {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    return Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
}

const RL_MAX = 300;
const RL_WIN = 3600;

export async function POST(request) {
    const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";

    const rateKey = `rate:${ip}`;
    const count = parseInt((await redis.get(rateKey)) || "0", 10);
    if (count >= RL_MAX) {
        return Response.json({ error: "rate_limited" }, { status: 429 });
    }
    await redis.set(rateKey, String(count + 1), { ex: RL_WIN });

    const token = generateToken();
    const expiresAt = Math.floor(Date.now() / 1000) + 50;

    const r = await redis.set(`token:${token}`, "unused", { ex: 60 });
    if (r !== "OK") {
        console.error("[/token] redis set failed", { r, tokenPrefix: token.slice(0, 8) });
        return Response.json({ error: "token_store_failed" }, { status: 500 });
    }

    console.log("[/token] issued", { tokenPrefix: token.slice(0, 8), expiresAt, ip });
    return Response.json({ token, expiresAt });
}
