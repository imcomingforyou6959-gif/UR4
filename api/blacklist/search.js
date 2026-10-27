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
    if (!res.ok) throw new Error(`fetch ${res.status}`);
    const json = await res.json();
    return JSON.parse(Buffer.from(json.content, "base64").toString("utf8"));
}

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });
    if (!GH_TOKEN) return Response.json({ err: "no_token" }, { status: 500 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const query = String(body.query || "").trim();
    if (!query) return Response.json({ err: "missing_query" }, { status: 400 });

    let data;
    try { data = await fetchRepoFile(); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    const bans = data.banned_hwids || {};
    const viol = data.violations || {};
    const all = {};
    for (const [k, v] of Object.entries(bans)) all[k] = { entry: v, status: "banned" };
    for (const [k, v] of Object.entries(viol)) all[k] = { entry: v, status: "unbanned" };

    const q = query.toLowerCase();
    const qNum = Number(query);
    const hwidMatches = [];
    const accountMatches = [];

    for (const [hwid, { entry, status }] of Object.entries(all)) {
        if (hwid.toLowerCase().includes(q)) {
            hwidMatches.push({
                hwid,
                status,
                username: entry.username || "?",
                displayName: entry.displayName || "?",
                userId: entry.userId || 0,
                reason: entry.reason || "",
                accountCount: Object.keys(entry.accounts || {}).length,
                hitCount: entry.hitCount || 0,
            });
        }
        const accounts = entry.accounts || {};
        for (const [uid, acc] of Object.entries(accounts)) {
            const matches =
                String(uid) === String(query) ||
                (qNum && Number(uid) === qNum) ||
                (acc.username || "").toLowerCase().includes(q) ||
                (acc.displayName || "").toLowerCase().includes(q);
            if (matches && !hwidMatches.find(m => m.hwid === hwid)) {
                accountMatches.push({
                    hwid,
                    status,
                    account: acc,
                    reason: entry.reason,
                    hitCount: entry.hitCount || 0,
                });
            }
        }
    }

    const linkedByHwid = {};
    for (const m of accountMatches) {
        if (!linkedByHwid[m.hwid]) linkedByHwid[m.hwid] = { hwid: m.hwid, status: m.status, accounts: [], reason: m.reason, hitCount: m.hitCount };
        linkedByHwid[m.hwid].accounts.push(m.account);
    }

    return Response.json({
        ok: true,
        query,
        hwidCount: hwidMatches.length,
        accountLinkCount: Object.keys(linkedByHwid).length,
        hwids: hwidMatches.slice(0, 10),
        linked: Object.values(linkedByHwid).slice(0, 10),
    });
}
