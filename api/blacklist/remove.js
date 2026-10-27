import { Redis } from "@upstash/redis";
const db = Redis.fromEnv();

const GH_OWNER = "madeformeanduu";
const GH_REPO = "vaild";
const GH_PATH = "Storage/HWID.json";
const GH_BRANCH = "main";
const GH_TOKEN = process.env.GH_TOKEN;
const BOT_SECRET = process.env.BOT_SECRET;

async function fetchRepoFile() {
    const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH}`;
    const res = await fetch(url, {
        headers: {
            "Authorization": `Bearer ${GH_TOKEN}`,
            "Accept": "application/vnd.github+json",
            "User-Agent": "ragebot-relay",
        },
        cache: "no-store",
    });
    if (!res.ok) throw new Error(`fetch ${res.status} ${(await res.text()).slice(0, 200)}`);
    const json = await res.json();
    return { sha: json.sha, data: JSON.parse(Buffer.from(json.content, "base64").toString("utf8")) };
}

async function writeRepoFile(data, sha, msg) {
    const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${GH_PATH}`;
    const res = await fetch(url, {
        method: "PUT",
        headers: {
            "Authorization": `Bearer ${GH_TOKEN}`,
            "Accept": "application/vnd.github+json",
            "User-Agent": "ragebot-relay",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            message: msg,
            content: Buffer.from(JSON.stringify(data, null, 2)).toString("base64"),
            sha,
            branch: GH_BRANCH,
        }),
    });
    if (!res.ok) throw new Error(`write ${res.status} ${(await res.text()).slice(0, 200)}`);
    return await res.json();
}

function summarize(e, hwid, status) {
    const attempts = Array.isArray(e.attempts) ? e.attempts : [];
    const accounts = e.accounts || {};
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
        attemptCount: attempts.length,
        accountCount: Object.keys(accounts).length,
        accounts,
        attempts: attempts.slice(-5).map(a => ({
            username: a.username || "?",
            displayName: a.displayName || "?",
            userId: a.userId || 0,
            executor: a.executor || "?",
            gameName: a.gameName || "?",
            timestamp: a.timestamp || 0,
            changed: !!a.changed,
            newAccount: !!a.newAccount,
        })),
    };
}

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });
    if (!GH_TOKEN) return Response.json({ err: "gh_read", msg: "GH_TOKEN missing" }, { status: 502 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const action = body.action;
    const hwid = body.hwid;

    if (action === "list") {
        let repo;
        try { repo = await fetchRepoFile(); }
        catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

        const bans = repo.data.banned_hwids || {};
        const viol = repo.data.violations || {};

        const banned = Object.keys(bans).map(k => summarize(bans[k], k, "banned"));
        const unbanned = Object.keys(viol).map(k => summarize(viol[k], k, "unbanned"));

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
        if (!hwid || typeof hwid !== "string") return Response.json({ err: "missing_hwid" }, { status: 400 });

        let repo;
        try { repo = await fetchRepoFile(); }
        catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

        const data = repo.data;
        if (!data.banned_hwids) data.banned_hwids = {};
        if (!data.violations) data.violations = {};

        const entry = data.banned_hwids[hwid];
        if (!entry) return Response.json({ err: "not_banned" }, { status: 404 });

        entry.status = "unbanned";
        entry.unbannedAt = Math.floor(Date.now() / 1000);
        if (!entry.unbanHistory) entry.unbanHistory = [];
        entry.unbanHistory.push({ at: entry.unbannedAt });

        data.violations[hwid] = entry;
        delete data.banned_hwids[hwid];

        try { await writeRepoFile(data, repo.sha, `blacklist: unban ${hwid.slice(0, 12)}… (history kept)`); }
        catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

        return Response.json({
            ok: true,
            removed: {
                username: entry.username,
                displayName: entry.displayName,
                userId: entry.userId,
                reason: entry.reason || "",
                attempts: Array.isArray(entry.attempts) ? entry.attempts.length : 0,
                accountCount: Object.keys(entry.accounts || {}).length,
                archived: true,
            },
        });
    }

    if (action === "get") {
        if (!hwid || typeof hwid !== "string") return Response.json({ err: "missing_hwid" }, { status: 400 });

        let repo;
        try { repo = await fetchRepoFile(); }
        catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

        const bans = repo.data.banned_hwids || {};
        const viol = repo.data.violations || {};

        if (bans[hwid]) return Response.json({ ok: true, entry: summarize(bans[hwid], hwid, "banned") });
        if (viol[hwid]) return Response.json({ ok: true, entry: summarize(viol[hwid], hwid, "unbanned") });
        return Response.json({ err: "not_found" }, { status: 404 });
    }

    return Response.json({ err: "bad_action" }, { status: 400 });
}
