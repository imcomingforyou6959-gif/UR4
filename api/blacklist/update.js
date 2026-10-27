import { Redis } from "@upstash/redis";

const db = Redis.fromEnv();

const GH_OWNER = "madeformeanduu";
const GH_REPO = "vaild";
const GH_PATH = "Storage/HWID.json";
const GH_BRANCH = "main";

const GH_TOKEN = process.env.GH_TOKEN;
const ALT_HOOK = process.env.ALT_HOOK;
const HIT_HOOK = process.env.HIT_HOOK;

const MAX_ATTEMPTS = 50;
const UPDATE_COOLDOWN = 8;

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

async function post(hook, embed) {
    if (!hook) return { ok: false, why: "no_hook" };
    for (let i = 0; i < 2; i++) {
        try {
            const ctrl = new AbortController();
            const t = setTimeout(() => ctrl.abort(), 6000);
            const res = await fetch(hook, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username: "Alt Detector", embeds: [embed] }),
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

    const cur = {
        username: clean(String(body.username || ""), 64),
        displayName: clean(String(body.displayName || ""), 64),
        userId: Number(body.userId) || 0,
        executor: clean(String(body.executor || "unknown"), 64),
        gameName: clean(String(body.gameName || gamePlaceName(body)), 128),
        placeId: Number(body.placeId) || 0,
        jobId: clean(String(body.jobId || ""), 40),
        timestamp: Number(body.timestamp) || Math.floor(Date.now() / 1000),
    };
    if (!cur.username || !cur.userId) {
        return Response.json({ err: "missing_fields" }, { status: 400 });
    }

    let repo;
    try { repo = await fetchRepoFile(); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    const data = repo.data;
    if (!data.banned_hwids) data.banned_hwids = {};

    const entry = data.banned_hwids[hwid];
    if (!entry) return Response.json({ err: "not_banned" }, { status: 404 });

    const prev = {
        username: entry.username,
        displayName: entry.displayName,
        userId: Number(entry.userId),
    };

    const infoChanged =
        prev.username !== cur.username ||
        prev.displayName !== cur.displayName ||
        prev.userId !== cur.userId;

    if (!Array.isArray(entry.attempts)) entry.attempts = [];
    entry.attempts.push({
        username: cur.username,
        displayName: cur.displayName,
        userId: cur.userId,
        executor: cur.executor,
        gameName: cur.gameName,
        placeId: cur.placeId,
        jobId: cur.jobId,
        timestamp: cur.timestamp,
        changed: infoChanged,
    });
    if (entry.attempts.length > MAX_ATTEMPTS) {
        entry.attempts = entry.attempts.slice(-MAX_ATTEMPTS);
    }
    entry.lastSeen = cur.timestamp;
    entry.hitCount = (entry.hitCount || 0) + 1;

    if (infoChanged) {
        entry.username = cur.username;
        entry.displayName = cur.displayName;
        entry.userId = cur.userId;
    }

    try { await writeRepoFile(data, repo.sha, `blacklist: hit ${hwid.slice(0, 12)}…`); }
    catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

    const embed = {
        title: infoChanged ? "Banned HWID — Alt Detected" : "Banned HWID — Retry",
        color: infoChanged ? 0xff9900 : 0xdd3333,
        fields: [
            { name: "HWID", value: "`" + hwid.slice(0, 128) + "`", inline: false },
            { name: "Stored User", value: `${prev.username} (${prev.userId})`, inline: true },
            { name: "Current User", value: `${cur.username} (${cur.userId})`, inline: true },
            { name: "Stored Display", value: prev.displayName || "?", inline: true },
            { name: "Current Display", value: cur.displayName || "?", inline: true },
            { name: "Executor", value: cur.executor || "?", inline: true },
            { name: "Game", value: cur.gameName || "?", inline: true },
            { name: "Total Hits", value: String(entry.hitCount), inline: true },
            { name: "When", value: `<t:${cur.timestamp}:R>`, inline: true },
            { name: "Reason", value: entry.reason || "*none*", inline: false },
        ],
        footer: { text: infoChanged ? "GitHub entry updated automatically" : "Same account retried" },
    };

    const hookResult = await post(infoChanged ? ALT_HOOK : (HIT_HOOK || ALT_HOOK), embed);

    return Response.json({ ok: true, changed: infoChanged, hits: entry.hitCount, hook: hookResult });
}

function gamePlaceName(body) {
    return body.gameName || "?";
}
