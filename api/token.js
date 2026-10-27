import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();

function generateToken() {
    const bytes = new Uint8Array(32);
    crypto.getRandomValues(bytes);
    return Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
}

export async function POST(request) {
    const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";

    const rateKey = `rate:${ip}`;
    const count = parseInt((await redis.get(rateKey)) || "0", 10);
    if (count >= 5) {
        return Response.json({ error: "rate_limited" }, { status: 429 });
    }
    await redis.set(rateKey, String(count + 1), { ex: 3600 });

    const token = generateToken();
    const expiresAt = Math.floor(Date.now() / 1000) + 60;

    await redis.set(`token:${token}`, "unused", { ex: 60, nx: true });

    return Response.json({ token, expiresAt });
}
