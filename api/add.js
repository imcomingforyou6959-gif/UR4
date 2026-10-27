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

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = String(body.hwid || "").trim();
    const reason = String(body.reason || "bye bye :3").slice(0, 256);
    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

    let repo;
    try { repo = await fetchRepoFile(); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    const data = repo.data;
    if (!data.banned_hwids) data.banned_hwids = {};

    if (data.banned_hwids[hwid]) {
        return Response.json({ err: "already_banned" }, { status: 409 });
    }

    data.banned_hwids[hwid] = {
        username: String(body.username || "?").slice(0, 64),
        displayName: String(body.displayName || "?").slice(0, 64),
        userId: Number(body.userId) || 0,
        bannedAt: Math.floor(Date.now() / 1000),
        reason,
        attempts: [],
    };

    try { await writeRepoFile(data, repo.sha, `blacklist: add ${hwid.slice(0, 12)}…`); }
    catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

    return Response.json({ ok: true, entry: data.banned_hwids[hwid] });
}
