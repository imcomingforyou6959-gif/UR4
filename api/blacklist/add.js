import { Redis } from "@upstash/redis";
import { readFile, writeFile } from "../github.js";

const db = Redis.fromEnv();
const BOT_SECRET = process.env.BOT_SECRET;

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = String(body.hwid || "").trim();
    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

    const reason = String(body.reason || "Banned by admin").slice(0, 256);
    const username = String(body.username || "?").slice(0, 64);
    const displayName = String(body.displayName || "?").slice(0, 64);
    const userId = Number(body.userId) || 0;
    const now = Math.floor(Date.now() / 1000);

    let main, attempts, hist;
    try {
        [main, attempts, hist] = await Promise.all([
            readFile("Storage/HWID.json"),
            readFile("Storage/Attempts.json"),
            readFile("Storage/history.json"),
        ]);
    } catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    if (!main.data.banned_hwids) main.data.banned_hwids = {};
    if (!main.data.violations) main.data.violations = {};

    if (main.data.banned_hwids[hwid]) return Response.json({ err: "already_banned" }, { status: 409 });

    const existingHistory = main.data.violations[hwid] || null;

    if (existingHistory) {
        delete main.data.violations[hwid];
        existingHistory.status = "banned";
        existingHistory.reason = reason;
        existingHistory.rebannedAt = now;
        main.data.banned_hwids[hwid] = existingHistory;
        if (!hist.data.rebans) hist.data.rebans = {};
        if (!Array.isArray(hist.data.rebans[hwid])) hist.data.rebans[hwid] = [];
        hist.data.rebans[hwid].push({ at: now, reason, by: String(body.by || "admin") });
    } else {
        main.data.banned_hwids[hwid] = {
            username, displayName, userId,
            bannedAt: now,
            reason,
            status: "banned",
            hitCount: 0,
            lastSeen: now,
            accounts: userId ? {
                [String(userId)]: {
                    username, displayName, userId,
                    firstSeen: now, lastSeen: now,
                    hits: 0, executors: [], games: [],
                },
            } : {},
        };
    }

    try {
        await writeFile("Storage/HWID.json", main.data, main.sha, `blacklist: ban ${hwid.slice(0, 12)}…`);
        if (existingHistory) {
            await writeFile("Storage/history.json", hist.data, hist.sha, `history: reban ${hwid.slice(0, 12)}…`);
        }
    } catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

    return Response.json({
        ok: true,
        entry: main.data.banned_hwids[hwid],
        hadHistory: !!existingHistory,
    });
}
