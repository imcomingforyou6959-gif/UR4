const sessions = globalThis.__sessions || (globalThis.__sessions = new Map());

module.exports = function requireSession(req, res) {
  const token = req.headers['x-session'];
  const hwid  = req.headers['x-hwid'];
  if (!token || !hwid) {
    res.status(401).json({ error: 'no session' });
    return null;
  }
  const s = sessions.get(token);
  if (!s) {
    res.status(401).json({ error: 'unknown session' });
    return null;
  }
  if (s.hwid !== hwid) {
    res.status(401).json({ error: 'hwid mismatch' });
    return null;
  }
  if (Math.floor(Date.now() / 1000) > s.expiresAt) {
    sessions.delete(token);
    res.status(401).json({ error: 'session expired' });
    return null;
  }
  return s;
};
