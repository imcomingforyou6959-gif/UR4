export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key, X-Target-URL');
  
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  
  const apiKey = req.headers['x-api-key'];
  const validKey = 'LOADER-REQUEST-X28278462876237CV-RAWR';
  
  if (!apiKey || apiKey !== validKey) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  try {
    const targetUrl = req.headers['x-target-url'];
    
    if (!targetUrl) {
      return res.status(400).json({ error: 'No target URL provided' });
    }
    
    console.log(`[Proxy] Fetching: ${targetUrl}`);
    const response = await fetch(targetUrl);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const script = await response.text();
    return res.status(200).send(script);
    
  } catch (error) {
    console.error('Proxy error:', error);
    return res.status(500).json({ 
      error: 'Failed to fetch script',
      details: error.message 
    });
  }
}
