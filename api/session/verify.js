import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();

export async function requireSession(req) {
  const token = req.headers.get("x-session");
  const hwid = req.headers.get("x-hwid");
  if (!token || !hwid) {
    return new Response(JSON.stringify({ err: "no session" }), { status: 401 });
  }

  let session;
  try {
    session = await db.get(`sess:${token}`);
  } catch {
    return new Response(JSON.stringify({ err: "session store error" }), { status: 503 });
  }

  if (!session || session.hwid !== hwid) {
    return new Response(JSON.stringify({ err: "invalid session" }), { status: 401 });
  }
  if (Math.floor(Date.now() / 1000) > session.expiresAt) {
    await db.del(`sess:${token}`).catch(() => {});
    return new Response(JSON.stringify({ err: "session expired" }), { status: 401 });
  }
  return null;
}
