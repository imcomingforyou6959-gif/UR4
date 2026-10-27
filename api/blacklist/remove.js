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
    const content = Buffer.from(json.content, "base64").toString("utf8");
    return { sha: json.sha, data: JSON.parse(content) };
}

async function writeRepoFile(data, sha, msg) {
    const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${GH_PATH}`;
    const body = {
        message: msg,
        content: Buffer.from(JSON.stringify(data, null, 2)).toString("base64"),
        sha,
        branch: GH_BRANCH,
    };
    const res = await fetch(url, {
        method: "PUT",
        headers: {
            "Authorization": `Bearer ${GH_TOKEN}`,
            "Accept": "application/vnd.github+json",
            "User-Agent": "ragebot-relay",
            "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
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
        const entries = Object.keys(bans).map(k => ({
            hwid: k,
            username: bans[k].username || "?",
            displayName: bans[k].displayName || "?",
            userId: bans[k].userId || 0,
            reason: bans[k].reason || "",
            bannedAt: bans[k].bannedAt || 0,
            attempts: Array.isArray(bans[k].attempts) ? bans[k].attempts.length : 0,
        }));
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
