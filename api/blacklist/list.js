const GH_OWNER = "madeformeanduu";
const GH_REPO = "vaild";
const GH_PATH = "Storage/HWID.json";
const GH_BRANCH = "main";

const GH_TOKEN = process.env.GH_TOKEN;

export async function GET() {
    if (!GH_TOKEN) {
        return Response.json({ err: "no_token" }, { status: 500 });
    }
    try {
        const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${GH_PATH}?ref=${GH_BRANCH}`;
        const res = await fetch(url, {
            headers: {
                "Authorization": `Bearer ${GH_TOKEN}`,
                "Accept": "application/vnd.github+json",
                "User-Agent": "ragebot-relay",
            },
            cache: "no-store",
        });
        if (!res.ok) {
            const t = await res.text();
            return Response.json({ err: "gh_read", msg: t.slice(0, 200) }, { status: 502 });
        }
        const json = await res.json();
        const data = Buffer.from(json.content, "base64").toString("utf8");
        return new Response(data, {
            status: 200,
            headers: {
                "Content-Type": "application/json",
                "Cache-Control": "no-store",
            },
        });
    } catch (e) {
        return Response.json({ err: "gh_exception", msg: String(e) }, { status: 500 });
    }
}
