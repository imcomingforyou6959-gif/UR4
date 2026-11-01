const sessions = globalThis.__sessions || (globalThis.__sessions = new Map());

export function requireSession(req) {
    const token = req.headers.get("x-session");
    const hwid = req.headers.get("x-hwid");
    if (!token || !hwid) return null;
    const s = sessions.get(token);
    if (!s) return null;
    if (s.hwid !== hwid) return null;
    if (Math.floor(Date.now() / 1000) > s.expiresAt) {
        sessions.delete(token);
        return null;
    }
    return s;
}
