import { Redis } from "@upstash/redis";
import { readFile } from "../github.js";
import crypto from "node:crypto";

const db = Redis.fromEnv();

export async function GET(req) {
    const url = new URL(req.url);
    const token = url.searchParams.get("s");
    const hwid = req.headers.get("x-hwid");

    if (!token || !hwid) {
        return Response.json({ err: "no_session" }, { status: 403 });
    }

    let session;
    try {
        session = await db.get(`sess:${token}`);
    } catch (e) {
        return Response.json({ err: "session_store", msg: String(e) }, { status: 503 });
    }

    if (!session || session.hwid !== hwid) {
        return Response.json({ err: "invalid_session" }, { status: 403 });
    }
    if (Math.floor(Date.now() / 1000) > session.expiresAt) {
        await db.del(`sess:${token}`).catch(() => {});
        return Response.json({ err: "session_expired" }, { status: 403 });
    }

    let plaintext;
    try {
        const p = await readFile("api/payload/Loadstring.lua");
        plaintext = typeof p.data === "string" ? p.data : String(p.data);
    } catch (e) {
        return Response.json({ err: "payload_not_found", msg: String(e) }, { status: 500 });
    }

    if (!plaintext || plaintext.length < 10) {
        return Response.json({ err: "payload_empty" }, { status: 500 });
    }

    const key = crypto.createHash("sha256").update(token + "|" + hwid).digest();
    const nonce = Buffer.from(session.nonce, "hex");
    const iv = Buffer.concat([Buffer.alloc(4, 0), nonce]);

    const cipher = crypto.createCipheriv("chacha20", key, iv);
    const encrypted = Buffer.concat([
        cipher.update(Buffer.from(plaintext, "utf8")),
        cipher.final(),
    ]);

    return new Response(encrypted, {
        status: 200,
        headers: {
            "Content-Type": "application/octet-stream",
            "Cache-Control": "no-store",
        },
    });
}
