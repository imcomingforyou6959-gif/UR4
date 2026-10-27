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

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });
    if (!GH_TOKEN) return Response.json({ err: "gh_read", msg: "GH_TOKEN missing" }, { status: 502 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = String(body.hwid || "").trim();
    const reason = String(body.reason || "Banned by admin").slice(0, 256);
    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });

    let repo;
    try { repo = await fetchRepoFile(); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    const data = repo.data;
    if (!data.banned_hwids) data.banned_hwids = {};
    if (!data.violations) data.violations = {};

    const history = data.violations[hwid] || null;

    if (data.banned_hwids[hwid]) {
        return Response.json({ err: "already_banned" }, { status: 409 });
    }

    const now = Math.floor(Date.now() / 1000);
    const uid = Number(body.userId) || 0;
    const username = String(body.username || "?").slice(0, 64);
    const displayName = String(body.displayName || "?").slice(0, 64);

    if (history) {
        delete data.violations[hwid];
        history.status = "banned";
        history.reason = reason;
        history.rebannedAt = now;
        if (!history.rebanHistory) history.rebanHistory = [];
        history.rebanHistory.push({ reason, at: now });
        data.banned_hwids[hwid] = history;
    } else {
        data.banned_hwids[hwid] = {
            username,
            displayName,
            userId: uid,
            bannedAt: now,
            reason,
            status: "banned",
            hitCount: 0,
            lastSeen: now,
            accounts: uid ? {
                [String(uid)]: {
                    username,
                    displayName,
                    userId: uid,
                    firstSeen: now,
                    lastSeen: now,
                    executors: [],
                    games: [],
                    hits: 0,
                },
            } : {},
            attempts: [],
            rebanHistory: [],
        };
    }

    try { await writeRepoFile(data, repo.sha, `blacklist: ban ${hwid.slice(0, 12)}…`); }
    catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

    return Response.json({ ok: true, entry: data.banned_hwids[hwid], hadHistory: !!history });
}
