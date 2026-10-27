import { readFile, writeFile } from "../github.js";

const BOT_SECRET = process.env.BOT_SECRET;
const EDITABLE = ["reason", "username", "displayName", "userId", "status"];

export async function POST(req) {
    const secret = req.headers.get("x-bot-secret");
    if (!BOT_SECRET || secret !== BOT_SECRET) return Response.json({ err: "unauthorized" }, { status: 401 });

    let body;
    try { body = await req.json(); }
    catch { return Response.json({ err: "bad_json" }, { status: 400 }); }

    const hwid = String(body.hwid || "").trim();
    const edits = body.edits || {};
    const by = String(body.by || "unknown").slice(0, 64);

    if (!hwid) return Response.json({ err: "missing_hwid" }, { status: 400 });
    if (typeof edits !== "object" || Object.keys(edits).length === 0) return Response.json({ err: "no_edits" }, { status: 400 });
    for (const k of Object.keys(edits)) {
        if (!EDITABLE.includes(k)) return Response.json({ err: "bad_field", field: k, allowed: EDITABLE }, { status: 400 });
    }

    let main, hist;
    try {
        [main, hist] = await Promise.all([
            readFile("Storage/HWID.json"),
            readFile("Storage/history.json"),
        ]);
    } catch (e) { return Response.json({ err: "gh_read", msg: String(e) }, { status: 502 }); }

    if (!main.data.banned_hwids) main.data.banned_hwids = {};
    if (!main.data.violations) main.data.violations = {};
    if (!hist.data.edits) hist.data.edits = {};

    let entry = main.data.banned_hwids[hwid];
    let source = "banned";
    if (!entry) { entry = main.data.violations[hwid]; source = "unbanned"; }
    if (!entry) return Response.json({ err: "not_found" }, { status: 404 });

    const now = Math.floor(Date.now() / 1000);
    const changes = [];

    for (const [field, newVal] of Object.entries(edits)) {
        const oldVal = entry[field];
        if (field === "userId") {
            const n = Number(newVal);
            if (!Number.isFinite(n) || n < 0) return Response.json({ err: "bad_value", field }, { status: 400 });
            if (oldVal !== n) { changes.push({ field, old: oldVal, new: n }); entry[field] = n; }
        }
        else if (field === "status") {
            if (!["banned", "unbanned"].includes(newVal)) return Response.json({ err: "bad_value", field }, { status: 400 });
            if (oldVal !== newVal) { changes.push({ field, old: oldVal, new: newVal }); entry[field] = newVal; }
        }
        else {
            const s = String(newVal).slice(0, field === "reason" ? 256 : 64);
            if (oldVal !== s) { changes.push({ field, old: oldVal, new: s }); entry[field] = s; }
        }
    }

    if (changes.length === 0) return Response.json({ ok: true, changed: false });

    if (!Array.isArray(hist.data.edits[hwid])) hist.data.edits[hwid] = [];
    hist.data.edits[hwid].push({ at: now, by, changes });
    if (hist.data.edits[hwid].length > 100) hist.data.edits[hwid] = hist.data.edits[hwid].slice(-100);

    if (changes.some(c => c.field === "status")) {
        if (entry.status === "unbanned" && source === "banned") {
            entry.unbannedAt = now;
            main.data.violations[hwid] = entry;
            delete main.data.banned_hwids[hwid];
            source = "unbanned";
        } else if (entry.status === "banned" && source === "unbanned") {
            entry.rebannedAt = now;
            main.data.banned_hwids[hwid] = entry;
            delete main.data.violations[hwid];
            source = "banned";
        }
    }

    try {
        await Promise.all([
            writeFile("Storage/HWID.json", main.data, main.sha, `blacklist: modify ${hwid.slice(0, 12)}…`),
            writeFile("Storage/history.json", hist.data, hist.sha, `history: edit ${hwid.slice(0, 12)}…`),
        ]);
    } catch (e) { return Response.json({ err: "gh_write", msg: String(e) }, { status: 502 }); }

    return Response.json({ ok: true, changed: true, status: source, changes, entry });
}
