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

    const reason = String(body.reason || "Banned for a Violation").slice(0, 256);
    const username = String(body.username || "?").slice(0, 64);
    const displayName = String(body.displayName || "?").slice(0, 64);
    const userId = Number(body.userId) || 0;
    const now = Math.floor(Date.now() / 1000);

    let main, hist;
    try {
        [main, hist] = await Promise.all([
            readFile("Storage/HWID.json"),
            readFile("Storage/history.json"),
        ]);
    } catch (e) {
        return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 });
    }

    if (!main.data.banned_hwids) main.data.banned_hwids = {};
    if (!main.data.violations) main.data.violations = {};
    if (!main.data.linkedHwids) main.data.linkedHwids = {};
    if (!hist.data.rebans) hist.data.rebans = {};

    if (main.data.banned_hwids[hwid]) {
        return Response.json({ err: "already_banned" }, { status: 409 });
    }

    const existingHistory = main.data.violations[hwid] || null;

    const uidStr = userId ? String(userId) : null;
    const linkedHwids = [];

    if (uidStr) {
        if (!Array.isArray(main.data.linkedHwids[uidStr])) {
            main.data.linkedHwids[uidStr] = [];
        }
        if (!main.data.linkedHwids[uidStr].includes(hwid)) {
            main.data.linkedHwids[uidStr].push(hwid);
            if (main.data.linkedHwids[uidStr].length > 30) {
                main.data.linkedHwids[uidStr] = main.data.linkedHwids[uidStr].slice(-30);
            }
        }

        for (const h of main.data.linkedHwids[uidStr]) {
            if (!linkedHwids.includes(h)) linkedHwids.push(h);
        }

        for (const [h, e] of Object.entries(main.data.banned_hwids)) {
            if (e && e.accounts && e.accounts[uidStr] && !linkedHwids.includes(h)) {
                linkedHwids.push(h);
            }
        }
        for (const [h, e] of Object.entries(main.data.violations || {})) {
            if (e && e.accounts && e.accounts[uidStr] && !linkedHwids.includes(h)) {
                linkedHwids.push(h);
            }
        }
    }

    if (existingHistory) {
        delete main.data.violations[hwid];
        existingHistory.status = "banned";
        existingHistory.reason = reason;
        existingHistory.rebannedAt = now;

        if (!Array.isArray(existingHistory.linkedHwids)) existingHistory.linkedHwids = [];
        for (const h of linkedHwids) {
            if (!existingHistory.linkedHwids.includes(h)) {
                existingHistory.linkedHwids.push(h);
            }
        }
        if (existingHistory.linkedHwids.length > 30) {
            existingHistory.linkedHwids = existingHistory.linkedHwids.slice(-30);
        }

        main.data.banned_hwids[hwid] = existingHistory;

        if (!Array.isArray(hist.data.rebans[hwid])) hist.data.rebans[hwid] = [];
        hist.data.rebans[hwid].push({
            at: now,
            reason,
            by: String(body.by || "admin"),
        });
    } else {
        main.data.banned_hwids[hwid] = {
            username,
            displayName,
            userId,
            bannedAt: now,
            reason,
            status: "banned",
            hitCount: 0,
            lastSeen: now,
            linkedHwids: linkedHwids.slice(0, 30),
            accounts: userId ? {
                [String(userId)]: {
                    username,
                    displayName,
                    userId,
                    firstSeen: now,
                    lastSeen: now,
                    hits: 0,
                    executors: [],
                    games: [],
                },
            } : {},
        };
    }

    if (uidStr && linkedHwids.length > 0) {
        for (const [otherHwid, otherEntry] of Object.entries(main.data.banned_hwids)) {
            if (otherHwid === hwid) continue;
            if (!otherEntry || !otherEntry.accounts) continue;
            if (!otherEntry.accounts[uidStr]) continue;
            if (!Array.isArray(otherEntry.linkedHwids)) otherEntry.linkedHwids = [];
            for (const h of linkedHwids) {
                if (!otherEntry.linkedHwids.includes(h)) {
                    otherEntry.linkedHwids.push(h);
                }
            }
            if (otherEntry.linkedHwids.length > 30) {
                otherEntry.linkedHwids = otherEntry.linkedHwids.slice(-30);
            }
        }
        for (const [otherHwid, otherEntry] of Object.entries(main.data.violations || {})) {
            if (otherHwid === hwid) continue;
            if (!otherEntry || !otherEntry.accounts) continue;
            if (!otherEntry.accounts[uidStr]) continue;
            if (!Array.isArray(otherEntry.linkedHwids)) otherEntry.linkedHwids = [];
            for (const h of linkedHwids) {
                if (!otherEntry.linkedHwids.includes(h)) {
                    otherEntry.linkedHwids.push(h);
                }
            }
            if (otherEntry.linkedHwids.length > 30) {
                otherEntry.linkedHwids = otherEntry.linkedHwids.slice(-30);
            }
        }
    }

    try {
        await writeFile(
            "Storage/HWID.json",
            main.data,
            main.sha,
            `blacklist: ban ${hwid.slice(0, 12)}… (${linkedHwids.length} linked)`
        );

        if (existingHistory) {
            await writeFile(
                "Storage/history.json",
                hist.data,
                hist.sha,
                `history: reban ${hwid.slice(0, 12)}…`
            );
        }
    } catch (e) {
        return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 });
    }

    return Response.json({
        ok: true,
        entry: main.data.banned_hwids[hwid],
        hadHistory: !!existingHistory,
        linkedHwids: linkedHwids.length,
    });
}
