export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  // Check API key
  const apiKey = req.headers['x-api-key'];
  const validKey = 'LOADER-REQUEST-X28278462876237CV-RAWR';
  
  if (!apiKey || apiKey !== validKey) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  try {
    // THE GITHUB URL IS HARDCODED HERE - HIDDEN FROM USERS!
    const targetUrl = 'https://raw.githubusercontent.com/imcomingforyou6959-git/UR4/refs/heads/main/Loadstring.lua';
    
    const response = await fetch(targetUrl);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch: ${response.status}`);
    }
    
    const script = await response.text();
    
    // Optional: Add a watermark to verify it came through proxy
    const watermarked = `-- Loaded via Vercel proxy | ${new Date().toISOString()}\n${script}`;
    
    return res.status(200).send(watermarked);
    
  } catch (error) {
    console.error('Proxy error:', error);
    return res.status(500).json({ error: 'Failed to fetch script' });
  }
}
