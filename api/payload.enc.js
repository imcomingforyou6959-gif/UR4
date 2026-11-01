const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sessions = globalThis.__sessions || (globalThis.__sessions = new Map());

module.exports = function handler(req, res) {
  const token = req.query.s;
  const hwid  = req.headers['x-hwid'];
  if (!token || !hwid) return res.status(403).json({ error: 'no session' });

  const s = sessions.get(token);
  if (!s || s.hwid !== hwid) return res.status(403).json({ error: 'invalid session' });
  if (Math.floor(Date.now() / 1000) > s.expiresAt) {
    sessions.delete(token);
    return res.status(403).json({ error: 'session expired' });
  }

  let plaintext;
  try {
    const payloadPath = path.join(process.cwd(), 'api', 'payload', 'Loadstring.lua');
    plaintext = fs.readFileSync(payloadPath);
  } catch (e) {
    return res.status(500).json({ error: 'payload not found', detail: String(e) });
  }

  const key = crypto.createHash('sha256').update(token + '|' + hwid).digest();

  const nonce = Buffer.from(s.nonce, 'hex');
  const iv = Buffer.concat([Buffer.alloc(4, 0), nonce]);

  const cipher = crypto.createCipheriv('chacha20', key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);

  res.set('Content-Type', 'application/octet-stream');
  res.set('Cache-Control', 'no-store');
  return res.status(200).send(encrypted);
};
