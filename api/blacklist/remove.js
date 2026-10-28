import { readFile, writeFile } from "../github.js";

const BOT_SECRET = process.env.BOT_SECRET;

function summarize(e, hwid, status, attemptCount, globalLinks) {
    const accounts = e.accounts || {};
    const entryLinked = Array.isArray(e.linkedHwids) ? e.linkedHwids : [];

    const linkedSet = new Set(entryLinked);
    for (const uid of Object.keys(accounts)) {
        const globalUserHwids = (globalLinks && globalLinks[uid]) || [];
        for (const h of globalUserHwids) linkedSet.add(h);
    }
    if (!linkedSet.has(hwid)) linkedSet.add(hwid);

    return {
        hwid,
        status,
        username: e.username || "?",
        displayName: e.displayName || "?",
        userId: e.userId || 0,
        reason: e.reason || "",
        bannedAt: e.bannedAt || 0,
        unbannedAt: e.unbannedAt || 0,
        lastSeen: e.lastSeen || 0,
        hitCount: e.hitCount || 0,
        attemptCount,
        accountCount: Object.keys(accounts).length,
        linkedHwids: Array.from(linkedSet),
        linkedCount: linkedSet.size,
        accounts,
    };
}

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const action = body.action;
    const hwid = body.hwid;

    if (action === "list") {
        let main, attempts;
        try {
            [main, attempts] = await Promise.all([
                readFile("Storage/HWID.json"),
                readFile("Storage/Attempts.json"),
            ]);
        } catch (e) {
            return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 });
        }

        const bans = main.data.banned_hwids || {};
        const viol = main.data.violations || {};
        const att = attempts.data.attempts || {};
        const globalLinks = main.data.linkedHwids || {};

        const banned = Object.keys(bans).map(k => summarize(bans[k], k, "banned", (att[k] || []).length, globalLinks));
        const unbanned = Object.keys(viol).map(k => summarize(viol[k], k, "unbanned", (att[k] || []).length, globalLinks));

        banned.sort((a, b) => (b.lastSeen || b.bannedAt) - (a.lastSeen || a.bannedAt));
        unbanned.sort((a, b) => (b.unbannedAt || b.lastSeen) - (a.unbannedAt || a.lastSeen));

        return Response.json({
            ok: true,
            count: banned.length,
            totalHistory: banned.length + unbanned.length,
            entries: banned,
            unbanned,
        });
    }

    if (action === "remove") {
        if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

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
        if (!hist.data.unbans) hist.data.unbans = {};

        const entry = main.data.banned_hwids[hwid];
        if (!entry) return Response.json({ err: "not_banned" }, { status: 404 });

        const now = Math.floor(Date.now() / 1000);
        entry.status = "unbanned";
        entry.unbannedAt = now;

        main.data.violations[hwid] = entry;
        delete main.data.banned_hwids[hwid];

        if (!Array.isArray(hist.data.unbans[hwid])) hist.data.unbans[hwid] = [];
        hist.data.unbans[hwid].push({ at: now, by: String(body.by || "admin") });

        try {
            await writeFile(
                "Storage/HWID.json",
                main.data,
                main.sha,
                `blacklist: unban ${hwid.slice(0, 12)}… (history kept)`
            );
            await writeFile(
                "Storage/history.json",
                hist.data,
                hist.sha,
                `history: unban ${hwid.slice(0, 12)}…`
            );
        } catch (e) {
            return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 });
        }

        return Response.json({
            ok: true,
            removed: {
                username: entry.username,
                displayName: entry.displayName,
                userId: entry.userId,
                reason: entry.reason || "",
                accountCount: Object.keys(entry.accounts || {}).length,
                linkedCount: Array.isArray(entry.linkedHwids) ? entry.linkedHwids.length : 0,
                archived: true,
            },
        });
    }

    if (action === "get") {
        if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

        let main, attempts, hist;
        try {
            [main, attempts, hist] = await Promise.all([
                readFile("Storage/HWID.json"),
                readFile("Storage/Attempts.json"),
                readFile("Storage/history.json"),
            ]);
        } catch (e) {
            return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 });
        }

        const bans = main.data.banned_hwids || {};
        const viol = main.data.violations || {};
        const att = attempts.data.attempts || {};
        const h = hist.data || {};
        const globalLinks = main.data.linkedHwids || {};

        let raw = bans[hwid];
        let status = "banned";
        if (!raw) {
            raw = viol[hwid];
            status = "unbanned";
        }
        if (!raw) return Response.json({ err: "not_found" }, { status: 404 });

        const full = summarize(raw, hwid, status, (att[hwid] || []).length, globalLinks);
        full.attempts = (att[hwid] || []).slice(-10).reverse();
        full.edits = (h.edits?.[hwid] || []).slice(-10).reverse();
        full.unbans = (h.unbans?.[hwid] || []).slice(-10).reverse();
        full.rebans = (h.rebans?.[hwid] || []).slice(-10).reverse();

        const linkedAttempts = [];
        for (const linked of full.linkedHwids) {
            if (linked === hwid) continue;
            const list = att[linked] || [];
            for (const a of list.slice(-3)) {
                linkedAttempts.push({ ...a, hwid: linked });
            }
        }
        linkedAttempts.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
        full.linkedAttempts = linkedAttempts.slice(0, 20);

        return Response.json({ ok: true, entry: full });
    }

    return Response.json({ err: "bad_action" }, { status: 400 });
}
