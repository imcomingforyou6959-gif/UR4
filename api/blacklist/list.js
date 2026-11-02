import { readFile } from "../github.js";

let cache = { data: null, at: 0 };
const TTL = 3000;

export async function GET(request) {
    try {
        const url = new URL(request.url);
        const hwid = url.searchParams.get("hwid");

        if (!hwid || typeof hwid !== "string" || hwid.length < 8) {
            return Response.json({ err: "missing_hwid" }, { status: 400 });
        }

        const now = Date.now();
        if (!cache.data || now - cache.at >= TTL) {
            const r = await readFile("Storage/HWID.json");
            cache.data = r.data;
            cache.at = now;
        }

        const bans = (cache.data && cache.data.banned_hwids) || {};
        const entry = bans[hwid];

        if (!entry) {
            return Response.json({ banned_hwids: {} });
        }

        return Response.json({
            banned_hwids: {
                [hwid]: {
                    reason: entry.reason || "banned",
                },
            },
        });
    } catch (e) {
        return Response.json({ err: "gh_exception", msg: String(e) }, { status: 500 });
    }
}
