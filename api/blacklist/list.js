import { readFile } from "../github.js";

let cache = { data: null, at: 0 };
const TTL = 3000;

export async function GET(request) {
    const url = new URL(request.url);
    const hwid = url.searchParams.get("hwid");
    const token = request.headers.get("x-session");
    const headerHwid = request.headers.get("x-hwid");

    try {
        const now = Date.now();
        if (!cache.data || now - cache.at >= TTL) {
            const r = await readFile("Storage/HWID.json");
            cache.data = r.data;
            cache.at = now;
        }
        const data = cache.data;
        const bans = (data && data.banned_hwids) || {};

        if (token && headerHwid) {
            const { requireSession } = await import("../session/verify.js");
            const denied = await requireSession(request);
            if (denied) {
            } else {
                return json(data);
            }
        }

        if (!hwid) {
            return new Response(JSON.stringify({ err: "no_session_no_hwid" }), {
                status: 400,
                headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
            });
        }
        const entry = bans[hwid] ? { reason: bans[hwid].reason || "banned" } : null;
        return json({
            banned_hwids: entry ? { [hwid]: entry } : {},
            _narrow: true,
        });
    } catch (e) {
        return Response.json({ err: "gh_exception", msg: String(e) }, { status: 500 });
    }
}

function json(obj) {
    return new Response(JSON.stringify(obj), {
        status: 200,
        headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
}
