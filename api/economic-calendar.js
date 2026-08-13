const FXMACRO_BASE = 'https://api.fxmacrodata.com/v1/calendar';

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

module.exports = async function handler(req, res) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const currency = String(req.query.currency || 'USD').toUpperCase().replace(/[^A-Z]/g, '').slice(0, 6) || 'USD';
  const upstream = `${FXMACRO_BASE}/${encodeURIComponent(currency)}`;

  try {
    const upstreamRes = await fetch(upstream, {
      headers: { accept: 'application/json' },
    });
    const text = await upstreamRes.text();
    res.status(upstreamRes.status);
    res.setHeader('Content-Type', upstreamRes.headers.get('content-type') || 'application/json; charset=utf-8');
    res.send(text);
  } catch (error) {
    res.status(502).json({ error: `Calendar proxy failed: ${error.message}` });
  }
};
