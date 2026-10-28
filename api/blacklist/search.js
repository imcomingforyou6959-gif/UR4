import { readFile } from "../github.js";

const BOT_SECRET = process.env.BOT_SECRET;

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const query = String(body.query || "").trim();
    if (!query) return Response.json({ err: "missing_query" }, { status: 400 });

    let main;
    try { main = await readFile("Storage/HWID.json"); }
    catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    const bans = main.data.banned_hwids || {};
    const viol = main.data.violations || {};
    const globalLinks = main.data.linkedHwids || {};
    const all = {};
    for (const [k, v] of Object.entries(bans)) all[k] = { entry: v, status: "banned" };
    for (const [k, v] of Object.entries(viol)) all[k] = { entry: v, status: "unbanned" };

    const q = query.toLowerCase();
    const qNum = Number(query);
    const hwidMatches = [];
    const accountMatches = [];
    const matchedUserIds = new Set();

    for (const [hwid, { entry, status }] of Object.entries(all)) {
        const entryLinked = Array.isArray(entry.linkedHwids) ? entry.linkedHwids : [];

        if (hwid.toLowerCase().includes(q)) {
            hwidMatches.push({
                hwid, status,
                username: entry.username || "?",
                displayName: entry.displayName || "?",
                userId: entry.userId || 0,
                accountCount: Object.keys(entry.accounts || {}).length,
                hitCount: entry.hitCount || 0,
                linkedHwids: entryLinked,
            });
        }

        const accounts = entry.accounts || {};
        for (const [uid, acc] of Object.entries(accounts)) {
            const matches =
                String(uid) === String(query) ||
                (qNum && Number(uid) === qNum) ||
                (acc.username || "").toLowerCase().includes(q) ||
                (acc.displayName || "").toLowerCase().includes(q);
            if (matches) {
                matchedUserIds.add(String(uid));
                if (!hwidMatches.find(m => m.hwid === hwid)) {
                    accountMatches.push({ hwid, status, account: acc, linkedHwids: entryLinked });
                }
            }
        }
    }

    for (const uid of matchedUserIds) {
        const globalUserHwids = globalLinks[uid] || [];
        for (const h of globalUserHwids) {
            if (all[h] && !accountMatches.find(m => m.hwid === h) && !hwidMatches.find(m => m.hwid === h)) {
                const found = all[h];
                const entryLinked = Array.isArray(found.entry.linkedHwids) ? found.entry.linkedHwids : [];
                const accObj = (found.entry.accounts || {})[uid];
                if (accObj) {
                    accountMatches.push({ hwid: h, status: found.status, account: accObj, linkedHwids: entryLinked });
                }
            }
        }
    }

    const linkedByHwid = {};
    for (const m of accountMatches) {
        if (!linkedByHwid[m.hwid]) {
            linkedByHwid[m.hwid] = {
                hwid: m.hwid,
                status: m.status,
                accounts: [],
                linkedHwids: m.linkedHwids || [],
            };
        }
        linkedByHwid[m.hwid].accounts.push(m.account);
        for (const h of m.linkedHwids || []) {
            if (!linkedByHwid[m.hwid].linkedHwids.includes(h)) {
                linkedByHwid[m.hwid].linkedHwids.push(h);
            }
        }
    }

    const unionLinked = new Set();
    for (const uid of matchedUserIds) {
        for (const h of globalLinks[uid] || []) unionLinked.add(h);
    }

    return Response.json({
        ok: true,
        query,
        hwidCount: hwidMatches.length,
        accountLinkCount: Object.keys(linkedByHwid).length,
        matchedUserIds: Array.from(matchedUserIds),
        unionLinkedHwids: Array.from(unionLinked),
        hwids: hwidMatches.slice(0, 10),
        linked: Object.values(linkedByHwid).slice(0, 10),
    });
}
