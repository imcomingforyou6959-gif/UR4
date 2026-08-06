export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key, X-Script-Type');
  
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  
  const apiKey = req.headers['x-api-key'];
  const validKey = 'LOADER-REQUEST-X28278462876237CV-RAWR';
  
  if (!apiKey || apiKey !== validKey) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  try {
    const scriptType = req.headers['x-script-type'] || 'main';
    
    const scriptMap = {
      'main': 'https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Loadstring.lua',
      'adonis': 'https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Adonis.lua',
      'library': 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua',
      'theme': 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua',
      'save': 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua',
      'rapidfire': 'https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Supporting/RapidFire.lua',
      'commands': 'https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Supporting/Commands.lua',
      'jumpc': 'https://raw.githubusercontent.com/imcomingforyou6959-gif/UR4/refs/heads/main/Supporting/Jumpc.lua'
    };
    
    const targetUrl = scriptMap[scriptType];
    
    if (!targetUrl) {
      return res.status(400).json({ error: 'Unknown script type: ' + scriptType });
    }
    
    console.log(`[Proxy] Fetching: ${scriptType} -> ${targetUrl}`);
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
