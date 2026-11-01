const crypto = require('crypto');

const sessions = globalThis.__sessions || (globalThis.__sessions = new Map());

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'method' });

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch {
    return res.status(400).json({ error: 'bad json' });
  }
  const { hwid, executor, placeId, jobId, userId, userName } = body || {};
  if (!hwid || typeof hwid !== 'string' || hwid.length < 8) {
    return res.status(400).json({ error: 'missing hwid' });
  }

  try {
    const base = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : `http://localhost:${process.env.PORT || 3000}`;
    const r = await fetch(`${base}/api/blacklist/search?hwid=${encodeURIComponent(hwid)}`);
    if (r.ok) {
      const data = await r.json();
      if (data && data.banned) {
        return res.status(403).json({ error: 'banned', reason: data.reason || 'banned' });
      }
    }
  } catch {

  const token = crypto.randomBytes(32).toString('hex');
  const nonce = crypto.randomBytes(12).toString('hex');
  const expiresAt = Math.floor(Date.now() / 1000) + 300;

  sessions.set(token, { hwid, nonce, expiresAt, executor, placeId, jobId, userId, userName });
  setTimeout(() => sessions.delete(token), 300 * 1000).unref?.();

  return res.status(200).json({ token, nonce, expiresAt });
};
