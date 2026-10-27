import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();

const GH_OWNER = "madeformeanduu";
const GH_REPO = "vaild";
const GH_PATH = "Storage/HWID.json";
const GH_BRANCH = "main";

const GH_TOKEN = process.env.GH_TOKEN;

const MAX_ATTEMPTS = 20;
const UPDATE_COOLDOWN = 30;

function clean(s, max) {
    if (typeof s !== "string") return "";
    return s.slice(0, max).replace(/[\u0000-\u001F\u007F]/g, "?");
}

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

async function writeRepoFile(data, sha) {
    const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${GH_PATH}`;
    const body = {
        message: "blacklist: update entry from loader",
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

    const cur = {
        username: clean(String(body.username || ""), 64),
        displayName: clean(String(body.displayName || ""), 64),
        userId: Number(body.userId) || 0,
        executor: clean(String(body.executor || "unknown"), 64),
        timestamp: Number(body.timestamp) || Math.floor(Date.now() / 1000),
    };
    if (!cur.username || !cur.userId) {
        return Response.json({ err: "missing_fields" }, { status: 400 });
    }

    let repo;
    try {
        repo = await fetchRepoFile();
    } catch (e) {
        return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 });
    }

    const data = repo.data;
    if (!data.banned_hwids) data.banned_hwids = {};

    const entry = data.banned_hwids[hwid];
    if (!entry) {
        return Response.json({ err: "not_banned" }, { status: 404 });
    }

    const diff =
        entry.username !== cur.username ||
        entry.displayName !== cur.displayName ||
        Number(entry.userId) !== cur.userId;

    if (!diff) {
        return Response.json({ ok: true, changed: false });
    }

    if (!Array.isArray(entry.attempts)) entry.attempts = [];
    entry.attempts.push({
        username: entry.username,
        displayName: entry.displayName,
        userId: entry.userId,
        timestamp: cur.timestamp,
        executor: cur.executor,
        hwid,
    });
    if (entry.attempts.length > MAX_ATTEMPTS) {
        entry.attempts = entry.attempts.slice(-MAX_ATTEMPTS);
    }

    entry.username = cur.username;
    entry.displayName = cur.displayName;
    entry.userId = cur.userId;

    try {
        await writeRepoFile(data, repo.sha);
    } catch (e) {
        return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 });
    }

    return Response.json({ ok: true, changed: true });
}
