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
  
  const apiKey = req.headers['x-api-key'];
  const validKey = process.env.LOADER_API_KEY || 'MySecretKey123!';
  
  if (!apiKey || apiKey !== validKey) {
    return res.status(401).json({ error: 'Invalid or missing API key' });
  }
  
  try {
    const targetUrl = req.body.url || 'https://raw.githubusercontent.com/imcomingforyou6959-git/UR4/refs/heads/main/Loadstring.lua';
    const response = await fetch(targetUrl);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch script: ${response.status}`);
    }
    
    const script = await response.text();
    return res.status(200).send(script);
    
  } catch (error) {
    console.error('Proxy error:', error);
    return res.status(500).json({ error: 'Failed to fetch script' });
  }
}
