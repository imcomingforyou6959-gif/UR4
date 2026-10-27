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
    });
    if (!res.ok) {
        const t = await res.text();
        throw new Error(`fetch failed: ${res.status} ${t.slice(0, 200)}`);
    }
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
    if (!res.ok) {
        const t = await res.text();
        throw new Error(`write failed: ${res.status} ${t.slice(0, 200)}`);
    }
    return await res.json();
}

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) {
        return Response.json({ err: "unauthorized" }, { status: 401 });
    }

    if (!GH_TOKEN) {
        return Response.json({ err: "gh_read", msg: "GH_TOKEN not set in Vercel env" }, { status: 502 });
    }

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
    const entries = Object.keys(bans).map(k => {
        const b = bans[k];
        const attempts = Array.isArray(b.attempts) ? b.attempts : [];
        const accounts = b.accounts || {};
        return {
            hwid: k,
            username: b.username || "?",
            displayName: b.displayName || "?",
            userId: b.userId || 0,
            reason: b.reason || "",
            bannedAt: b.bannedAt || 0,
            lastSeen: b.lastSeen || 0,
            hitCount: b.hitCount || 0,
            attemptCount: attempts.length,
            accountCount: Object.keys(accounts).length,
            accounts: accounts,
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
    });
    entries.sort((a, b) => (b.lastSeen || b.bannedAt) - (a.lastSeen || a.bannedAt));
    return Response.json({ ok: true, count: entries.length, entries });
    }

    if (action === "remove") {
        if (!hwid || typeof hwid !== "string") {
            return Response.json({ err: "missing_hwid" }, { status: 400 });
        }

        let repo;
        try { repo = await fetchRepoFile(); }
        catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

        const data = repo.data;
        if (!data.banned_hwids || !data.banned_hwids[hwid]) {
            return Response.json({ err: "not_banned" }, { status: 404 });
        }

        const removed = data.banned_hwids[hwid];
        delete data.banned_hwids[hwid];

        try { await writeRepoFile(data, repo.sha, `blacklist: remove ${hwid.slice(0, 12)}…`); }
        catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

        return Response.json({
            ok: true,
            removed: {
                username: removed.username,
                displayName: removed.displayName,
                userId: removed.userId,
                reason: removed.reason || "",
                attempts: Array.isArray(removed.attempts) ? removed.attempts.length : 0,
            },
        });
    }

    return Response.json({ err: "bad_action" }, { status: 400 });
}
