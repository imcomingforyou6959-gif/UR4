const GH_OWNER = "madeformeanduu";
const GH_REPO = "vaild";
const GH_PATH = "Storage/HWID.json";
const GH_BRANCH = "main";
const GH_TOKEN = process.env.GH_TOKEN;
const BOT_SECRET = process.env.BOT_SECRET;

const EDITABLE = ["reason", "username", "displayName", "userId", "status"];

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
    const edits = body.edits || {};
    const by = String(body.by || "unknown").slice(0, 64);

    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });
    if (typeof edits !== "object" || Object.keys(edits).length === 0) {
        return Response.json({ err: "no_edits" }, { status: 400 });
    }

    for (const k of Object.keys(edits)) {
        if (!EDITABLE.includes(k)) {
            return Response.json({ err: "bad_field", field: k, allowed: EDITABLE }, { status: 400 });
        }
    }

    let repo;
    try { repo = await fetchRepoFile(); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    const data = repo.data;
    if (!data.banned_hwids) data.banned_hwids = {};
    if (!data.violations) data.violations = {};

    let entry = data.banned_hwids[hwid];
    let source = "banned";
    if (!entry) { entry = data.violations[hwid]; source = "unbanned"; }
    if (!entry) return Response.json({ err: "not_found" }, { status: 404 });

    const now = Math.floor(Date.now() / 1000);
    const changes = [];

    for (const [field, newVal] of Object.entries(edits)) {
        const oldVal = entry[field];

        if (field === "userId") {
            const n = Number(newVal);
            if (!Number.isFinite(n) || n < 0) {
                return Response.json({ err: "bad_value", field, msg: "must be non-negative number" }, { status: 400 });
            }
            if (oldVal !== n) { changes.push({ field, old: oldVal, new: n }); entry[field] = n; }
        }
        else if (field === "status") {
            const allowed = ["banned", "unbanned"];
            if (!allowed.includes(newVal)) {
                return Response.json({ err: "bad_value", field, msg: "must be 'banned' or 'unbanned'" }, { status: 400 });
            }
            if (oldVal !== newVal) { changes.push({ field, old: oldVal, new: newVal }); entry[field] = newVal; }
        }
        else {
            const s = String(newVal).slice(0, field === "reason" ? 256 : 64);
            if (oldVal !== s) { changes.push({ field, old: oldVal, new: s }); entry[field] = s; }
        }
    }

    if (changes.length === 0) {
        return Response.json({ ok: true, changed: false, msg: "No changes (values identical)" });
    }

    if (!Array.isArray(entry.editHistory)) entry.editHistory = [];
    entry.editHistory.push({
        at: now,
        by,
        changes,
    });
    if (entry.editHistory.length > 50) entry.editHistory = entry.editHistory.slice(-50);

    if (changes.some(c => c.field === "status")) {
        const newStatus = entry.status;
        if (newStatus === "unbanned" && source === "banned") {
            entry.unbannedAt = now;
            if (!Array.isArray(entry.unbanHistory)) entry.unbanHistory = [];
            entry.unbanHistory.push({ at: now, by });
            data.violations[hwid] = entry;
            delete data.banned_hwids[hwid];
            source = "unbanned";
        } else if (newStatus === "banned" && source === "unbanned") {
            entry.rebannedAt = now;
            if (!Array.isArray(entry.rebanHistory)) entry.rebanHistory = [];
            entry.rebanHistory.push({ at: now, by, reason: entry.reason });
            data.banned_hwids[hwid] = entry;
            delete data.violations[hwid];
            source = "banned";
        }
    }

    try { await writeRepoFile(data, repo.sha, `blacklist: modify ${hwid.slice(0, 12)}… (${changes.map(c => c.field).join(",")})`); }
    catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

    return Response.json({
        ok: true,
        changed: true,
        status: source,
        changes,
        entry,
    });
      }
