import { Redis } from "@upstash/redis";
import { readFile } from "../github.js";
import crypto from "node:crypto";

const db = Redis.fromEnv();
const SESSION_TTL = 300;

export async function POST(req) {
    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const { hwid, executor, placeId, jobId, userId, userName } = body || {};
    if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
        return Response.json({ err: "missing_hwid" }, { status: 400 });
    }

    try {
        const main = await readFile("Storage/HWID.json");
        const bans = (main.data && main.data.banned_hwids) || {};
        if (bans[hwid]) {
            return Response.json(
                { err: "banned", reason: bans[hwid].reason || "banned" },
                { status: 403 }
            );
        }
    } catch {
        //
    }

    const token = crypto.randomBytes(32).toString("hex");
    const nonce = crypto.randomBytes(12).toString("hex");
    const expiresAt = Math.floor(Date.now() / 1000) + SESSION_TTL;

    try {
        await db.set(
            `sess:${token}`,
            {
                hwid,
                nonce,
                expiresAt,
                executor: String(executor || ""),
                placeId: Number(placeId) || 0,
                jobId: String(jobId || ""),
                userId: Number(userId) || 0,
                userName: String(userName || ""),
            },
            { ex: SESSION_TTL }
        );
    } catch (e) {
        return Response.json({ err: "session_store", msg: String(e) }, { status: 503 });
    }

    return Response.json({ token, nonce, expiresAt });
}
