import { readFile } from "../github.js";

export async function GET() {
    try {
        const r = await readFile("Storage/HWID.json");
        return new Response(JSON.stringify(r.data), {
            status: 200,
            headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
        });
    } catch (e) {
        return Response.json({ err: "gh_exception", msg: String(e) }, { status: 500 });
    }
}
