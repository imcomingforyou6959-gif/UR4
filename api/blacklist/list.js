import { readFile } from "../github.js";
import { requireSession } from "../_session_verify.js";

let cache = { data: null, at: 0 };
const TTL = 3000;

export async function GET(request) {
    const { session, denied } = await requireSession(request);
    if (denied) return denied;

    try {
        const now = Date.now();
        if (cache.data && now - cache.at < TTL) {
            return Response.json(cache.data);
        }
        const r = await readFile("Storage/HWID.json");
        cache.data = r.data;
        cache.at = now;
        return Response.json(r.data);
    } catch (e) {
        return Response.json({ err: "gh_exception", msg: String(e) }, { status: 500 });
    }
}
