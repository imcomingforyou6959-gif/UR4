const GH_OWNER = "madeformeanduu";
const GH_REPO = "vaild";
const GH_BRANCH = "main";
const GH_TOKEN = process.env.GH_TOKEN;

export async function readFile(path) {
    const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${path}?ref=${GH_BRANCH}`;
    const res = await fetch(url, {
        headers: {
            "Authorization": `Bearer ${GH_TOKEN}`,
            "Accept": "application/vnd.github+json",
            "User-Agent": "relay",
        },
        cache: "no-store",
    });
    if (!res.ok) {
        if (res.status === 404) return { sha: null, data: {}, missing: true };
        throw new Error(`read ${path}: ${res.status} ${(await res.text()).slice(0, 200)}`);
    }
    const json = await res.json();
    return { sha: json.sha, data: JSON.parse(Buffer.from(json.content, "base64").toString("utf8")), missing: false };
}

export async function writeFile(path, data, sha, msg) {
    const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${path}`;
    const body = {
        message: msg,
        content: Buffer.from(JSON.stringify(data, null, 2)).toString("base64"),
        branch: GH_BRANCH,
    };
    if (sha) body.sha = sha;
    const res = await fetch(url, {
        method: "PUT",
        headers: {
            "Authorization": `Bearer ${GH_TOKEN}`,
            "Accept": "application/vnd.github+json",
            "User-Agent": "ragebot-relay",
            "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`write ${path}: ${res.status} ${(await res.text()).slice(0, 200)}`);
    return await res.json();
}
