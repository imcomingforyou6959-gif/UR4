import { Redis } from "@upstash/redis";
import { readFile } from "../github.js";

const db = Redis.fromEnv();

export async function POST(req) {
  if (req.method !== "POST") {
    return Response.json({ err: "method" }, { status: 405 });
  }

  let body;
  try { body = await req.json(); }
  catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

  const { hwid, executor, placeId, jobId, userId, userName } = body || {};
  if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
    return Response.json({ err: "missing_hwid" }, { status: 400 });
  }

  let banned = null;
  try {
    const main = await readFile("Storage/HWID.json");
    const data = main.data || {};
    if (data.banned_hwids && data.banned_hwids[hwid]) {
      banned = data.banned_hwids[hwid];
    }
  } catch (e) {
    //
  }
  if (banned) {
    return Response.json(
      { err: "banned", reason: banned.reason || "banned" },
      { status: 403 }
    );
  }

  const crypto = await import("node:crypto");
  const token = crypto.randomBytes(32).toString("hex");
  const nonce = crypto.randomBytes(12).toString("hex");
  const expiresAt = Math.floor(Date.now() / 1000) + 300;
  
  await db.set(`sess:${token}`, {
    hwid, nonce, expiresAt,
    executor: String(executor || ""),
    placeId: Number(placeId) || 0,
    jobId: String(jobId || ""),
    userId: Number(userId) || 0,
    userName: String(userName || ""),
  }, { ex: 300 });

  return Response.json({ token, nonce, expiresAt });
}
