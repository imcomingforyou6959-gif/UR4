import { Redis } from "@upstash/redis";
import { readFile, writeFile } from "../github.js";

const db = Redis.fromEnv();
const ALT_HOOK = process.env.ALT_HOOK;
const HIT_HOOK = process.env.HIT_HOOK;
const MAX_ATTEMPTS = 100;
const UPDATE_COOLDOWN = 8;
const COLOR = 0x8b5cf6;

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
}

function pushUnique(arr, val, max) {
    if (!Array.isArray(arr)) arr = [];
    if (!arr.includes(val)) arr.push(val);
    if (arr.length > max) arr = arr.slice(-max);
    return arr;
}

async function post(hook, embed) {
    if (!hook) return { ok: false, why: "no_hook" };
    for (let i = 0; i < 2; i++) {
        try {
            const ctrl = new AbortController();
            const t = setTimeout(() => ctrl.abort(), 6000);
            const res = await fetch(hook, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username: "Secuirty found rawr.xyz", embeds: [embed] }),
                signal: ctrl.signal,
            });
            clearTimeout(t);
            if (res.status === 429) {
                let wait = 1;
                try { const j = await res.json(); if (typeof j.retry_after === "number") wait = j.retry_after; } catch {}
                await new Promise(r => setTimeout(r, Math.min(wait * 1000, 4000)));
                continue;
            }
            return { ok: res.ok, status: res.status };
        } catch {
            if (i === 1) return { ok: false, why: "fetch_failed" };
            await new Promise(r => setTimeout(r, 500));
        }
    }
    return { ok: false, why: "exhausted" };
}

export async function POST(req) {
    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = body.hwid;
    if (!hwid || typeof hwid !== "string") {
        return Response.json({ err: "missing_hwid" }, { status: 400 });
    }

    const coolKey = `upd:${hwid}`;
    if (await db.get(coolKey)) {
        return Response.json({ err: "cooldown" }, { status: 429 });
    }
    await db.set(coolKey, "1", { ex: UPDATE_COOLDOWN });

    const now = Math.floor(Date.now() / 1000);
    const cur = {
        username: clean(String(body.username || ""), 64),
        displayName: clean(String(body.displayName || ""), 64),
        userId: Number(body.userId) || 0,
        executor: clean(String(body.executor || "unknown"), 64),
        gameName: clean(String(body.gameName || "?"), 128),
        placeId: Number(body.placeId) || 0,
        jobId: clean(String(body.jobId || ""), 40),
        timestamp: Number(body.timestamp) || now,
    };
    if (!cur.username || !cur.userId) {
        return Response.json({ err: "missing_fields" }, { status: 400 });
    }

    let main, attempts;
    try {
        [main, attempts] = await Promise.all([
            readFile("Storage/HWID.json"),
            readFile("Storage/Attempts.json"),
        ]);
    } catch (e) {
        return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 });
    }

    if (!main.data.banned_hwids) main.data.banned_hwids = {};
    if (!main.data.violations) main.data.violations = {};
    if (!main.data.linkedHwids) main.data.linkedHwids = {};
    if (!attempts.data.attempts) attempts.data.attempts = {};

    let entry = main.data.banned_hwids[hwid];
    let target = "banned";
    let effectiveHwid = hwid;

    if (!entry) {
        entry = main.data.violations[hwid];
        target = "unbanned";
    }

    if (!entry) {
        const uidStr = String(cur.userId);
        const userHwids = main.data.linkedHwids[uidStr] || [];
        for (const h of userHwids) {
            if (main.data.banned_hwids[h]) {
                entry = main.data.banned_hwids[h];
                target = "banned";
                effectiveHwid = h;
                break;
            }
            if (main.data.violations[h]) {
                entry = main.data.violations[h];
                target = "unbanned";
                effectiveHwid = h;
                break;
            }
        }
    }

    if (!entry) return Response.json({ err: "not_banned" }, { status: 404 });
    if (!entry.accounts) entry.accounts = {};
    if (!Array.isArray(entry.linkedHwids)) entry.linkedHwids = [];

    const uidStr = String(cur.userId);

    if (!Array.isArray(main.data.linkedHwids[uidStr])) {
        main.data.linkedHwids[uidStr] = [];
    }
    if (!main.data.linkedHwids[uidStr].includes(hwid)) {
        main.data.linkedHwids[uidStr].push(hwid);
        if (main.data.linkedHwids[uidStr].length > 30) {
            main.data.linkedHwids[uidStr] = main.data.linkedHwids[uidStr].slice(-30);
        }
    }

    const accountBannedAnywhere =
        main.data.banned_hwids[hwid] != null
        || Object.keys(main.data.banned_hwids).some(h => {
            const e = main.data.banned_hwids[h];
            if (!e || !e.accounts) return false;
            return !!e.accounts[uidStr];
        })
        || Object.keys(main.data.violations || {}).some(h => {
            const e = main.data.violations[h];
            if (!e || !e.accounts) return false;
            return !!e.accounts[uidStr];
        });

    if (accountBannedAnywhere) {
        for (const linked of main.data.linkedHwids[uidStr]) {
            if (!entry.linkedHwids.includes(linked)) {
                entry.linkedHwids.push(linked);
            }
        }
        if (entry.linkedHwids.length > 30) {
            entry.linkedHwids = entry.linkedHwids.slice(-30);
        }
    }

    const prev = {
        username: entry.username,
        displayName: entry.displayName,
        userId: Number(entry.userId),
    };
    const infoChanged =
        prev.username !== cur.username ||
        prev.displayName !== cur.displayName ||
        prev.userId !== cur.userId;

    const uidKey = String(cur.userId);
    const existing = entry.accounts[uidKey];
    const isNewAccount = !existing;
    const isNewHwid = effectiveHwid !== hwid || !entry.linkedHwids.includes(hwid);

    if (existing) {
        existing.username = cur.username;
        existing.displayName = cur.displayName;
        existing.lastSeen = cur.timestamp;
        existing.hits = (existing.hits || 0) + 1;
        existing.executors = pushUnique(existing.executors || [], cur.executor, 10);
        existing.games = pushUnique(existing.games || [], cur.gameName, 10);
    } else {
        entry.accounts[uidKey] = {
            username: cur.username,
            displayName: cur.displayName,
            userId: cur.userId,
            firstSeen: cur.timestamp,
            lastSeen: cur.timestamp,
            hits: 1,
            executors: [cur.executor],
            games: [cur.gameName],
        };
    }

    if (!Array.isArray(attempts.data.attempts[effectiveHwid])) attempts.data.attempts[effectiveHwid] = [];
    attempts.data.attempts[effectiveHwid].push({
        username: cur.username,
        displayName: cur.displayName,
        userId: cur.userId,
        executor: cur.executor,
        gameName: cur.gameName,
        placeId: cur.placeId,
        jobId: cur.jobId,
        timestamp: cur.timestamp,
        changed: infoChanged,
        newAccount: isNewAccount,
        hwid: hwid,
        linkedVia: effectiveHwid !== hwid ? effectiveHwid : null,
        target,
    });
    if (attempts.data.attempts[effectiveHwid].length > MAX_ATTEMPTS) {
        attempts.data.attempts[effectiveHwid] = attempts.data.attempts[effectiveHwid].slice(-MAX_ATTEMPTS);
    }

    entry.lastSeen = cur.timestamp;
    entry.hitCount = (entry.hitCount || 0) + 1;

    if (infoChanged) {
        entry.username = cur.username;
        entry.displayName = cur.displayName;
        entry.userId = cur.userId;
    }

    try {
        await writeFile(
            "Storage/HWID.json",
            main.data,
            main.sha,
            `blacklist: hit ${hwid.slice(0, 12)}… via ${effectiveHwid.slice(0, 12)}…`
        );
        await writeFile(
            "Storage/Attempts.json",
            attempts.data,
            attempts.sha,
            `attempts: log ${effectiveHwid.slice(0, 12)}…`
        );
    } catch (e) {
        return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 });
    }

    const totalAccounts = Object.keys(entry.accounts).length;
    const isAlt = isNewAccount && totalAccounts > 1;

    let title = "Retry";
    if (isAlt) title = "New Alt";
    else if (infoChanged) title = "Info Changed";
    else if (isNewHwid) title = "New HWID";
    if (target === "unbanned") title = "Unbanned HWID Run";

    const embed = {
        title,
        color: COLOR,
        fields: [
            { name: "HWID", value: "`" + hwid.slice(0, 128) + "`", inline: false },
            { name: "Username", value: cur.username, inline: true },
            { name: "Display Name", value: cur.displayName, inline: true },
            { name: "User ID", value: String(cur.userId), inline: true },
            { name: "Stored User", value: prev.username, inline: true },
            { name: "Stored Display", value: prev.displayName || "?", inline: true },
            { name: "Stored ID", value: String(prev.userId || 0), inline: true },
            { name: "Executor", value: cur.executor || "?", inline: true },
            { name: "Game", value: cur.gameName || "?", inline: true },
            { name: "Accounts Tied", value: String(totalAccounts), inline: true },
            { name: "Total Hits", value: String(entry.hitCount), inline: true },
            { name: "Linked HWIDs", value: String(entry.linkedHwids.length), inline: true },
            { name: "Status", value: target === "banned" ? "🔴 Banned" : "🟢 Unbanned", inline: true },
            { name: "When", value: `<t:${cur.timestamp}:R>`, inline: false },
        ],
        footer: {
            text: isAlt
                ? "New account tied to HWID"
                : isNewHwid
                    ? "New HWID linked to banned account"
                    : infoChanged
                        ? "GitHub entry updated"
                        : "Same account retried",
        },
    };

    const hookResult = await post(infoChanged || isNewHwid ? ALT_HOOK : (HIT_HOOK || ALT_HOOK), embed);

    return Response.json({
        ok: true,
        changed: infoChanged,
        isAlt,
        isNewHwid,
        totalAccounts,
        linkedHwids: entry.linkedHwids.length,
        hits: entry.hitCount,
        status: target,
        effectiveHwid,
        hook: hookResult,
    });
}
