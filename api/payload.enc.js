import { Redis } from "@upstash/redis";
import { readFile } from "../github.js";
import crypto from "node:crypto";

const db = Redis.fromEnv();

export async function GET(req) {
  const url = new URL(req.url);
  const token = url.searchParams.get("s");
  const hwid = req.headers.get("x-hwid");
  if (!token || !hwid) {
    return Response.json({ err: "no session" }, { status: 403 });
  }

  const session = await db.get(`sess:${token}`);
  if (!session || session.hwid !== hwid) {
    return Response.json({ err: "invalid session" }, { status: 403 });
  }
  if (Math.floor(Date.now() / 1000) > session.expiresAt) {
    await db.del(`sess:${token}`).catch(() => {});
    return Response.json({ err: "session expired" }, { status: 403 });
  }

  const payload = await readFile("api/payload/Loadstring.lua");
  const plaintext = typeof payload.data === "string"
    ? payload.data
    : JSON.stringify(payload.data);

  const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
  const nonce = Buffer.from(session.nonce, "hex");
  const iv = Buffer.concat([Buffer.alloc(4, 0), nonce]);
  const cipher = crypto.createCipheriv("chacha20", key, iv);
  const encrypted = Buffer.concat([cipher.update(Buffer.from(plaintext)), cipher.final()]);

  return new Response(encrypted, {
    status: 200,
    headers: {
      "Content-Type": "application/octet-stream",
      "Cache-Control": "no-store",
    },
  });
}
