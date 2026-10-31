import { Redis } from "@upstash/redis";
import { readFile, writeFile } from "../github.js";

const db = Redis.fromEnv();
const VIOLATION_KEY = process.env.VIOLATION_KEY;
const ALT_HOOK = process.env.ALT_HOOK;
const COOLDOWN = 8;

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
}

async function postHook(embed) {
    if (!ALT_HOOK) return { ok: false, why: "no_hook" };
    try {
        const ctrl = new AbortController();
        const t = setTimeout(() => ctrl.abort(), 6000);
        const res = await fetch(ALT_HOOK, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username: "rawr.xyz anti-spy", embeds: [embed] }),
            signal: ctrl.signal,
        });
        clearTimeout(t);
        return { ok: res.ok, status: res.status };
    } catch (e) {
        return { ok: false, why: String(e) };
    }
}

export async function POST(req) {
    const key = req.headers.get("x-violation-key");
    if (!VIOLATION_KEY || key !== VIOLATION_KEY) {
        return Response.json({ err: "unauthorized" }, { status: 401 });
    }

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = String(body.hwid || "").trim();
    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

    const coolKey = `viol:${hwid}`;
    if (await db.get(coolKey)) {
        return Response.json({ ok: true, already: true, cooldown: true });
    }
    await db.set(coolKey, "1", { ex: COOLDOWN });

    const reason = clean(String(body.reason || "HTTP spy detected"), 256);
    const spyInfo = clean(String(body.spyInfo || ""), 256);
    const username = clean(String(body.username || "?"), 64);
    const displayName = clean(String(body.displayName || "?"), 64);
    const userId = Number(body.userId) || 0;
    const executor = clean(String(body.executor || "unknown"), 64);
    const gameName = clean(String(body.gameName || "?"), 128);
    const now = Math.floor(Date.now() / 1000);

    let main;
    try { main = await readFile("Storage/HWID.json"); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    if (!main.data.banned_hwids) main.data.banned_hwids = {};
    if (!main.data.violations) main.data.violations = {};

    let already = false;
    if (main.data.banned_hwids[hwid]) {
        already = true;
        const e = main.data.banned_hwids[hwid];
        e.lastSeen = now;
        e.hitCount = (e.hitCount || 0) + 1;
    } else {
        const old = main.data.violations[hwid];
        if (old) {
            delete main.data.violations[hwid];
            old.status = "banned";
            old.reason = reason;
            old.rebannedAt = now;
            old.lastSeen = now;
            old.hitCount = (old.hitCount || 0) + 1;
            if (!Array.isArray(old.linkedHwids)) old.linkedHwids = [hwid];
            main.data.banned_hwids[hwid] = old;
        } else {
            main.data.banned_hwids[hwid] = {
                username,
                displayName,
                userId,
                bannedAt: now,
                reason,
                status: "banned",
                hitCount: 1,
                lastSeen: now,
                linkedHwids: [hwid],
                accounts: userId ? {
                    [String(userId)]: {
                        username, displayName, userId,
                        firstSeen: now, lastSeen: now, hits: 1,
                        executors: [executor], games: [gameName],
                    },
                } : {},
            };
        }
    }

    try {
        await writeFile(
            "Storage/HWID.json",
            main.data,
            main.sha,
            `blacklist: violation ${hwid.slice(0, 12)}… (${already ? "retry" : "new"})`
        );
    } catch (e) {
        return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 });
    }

    const embed = {
        title: already ? "Violation Retry" : "Violation Ban",
        color: 0xff0044,
        fields: [
            { name: "HWID", value: "`" + hwid.slice(0, 128) + "`", inline: false },
            { name: "Reason", value: reason, inline: false },
            { name: "Spy Info", value: spyInfo || "n/a", inline: false },
            { name: "Username", value: username, inline: true },
            { name: "Display", value: displayName, inline: true },
            { name: "User ID", value: String(userId), inline: true },
            { name: "Executor", value: executor, inline: true },
            { name: "Game", value: gameName, inline: true },
            { name: "Status", value: already ? "Already banned" : "Banned now", inline: true },
            { name: "When", value: `<t:${now}:R>`, inline: false },
        ],
        footer: { text: "Anti-spy violation" },
    };

    const hook = await postHook(embed);

    return Response.json({
        ok: true,
        already,
        banned: hwid,
        hook,
    });
}
