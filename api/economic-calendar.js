const FXMACRO_BASE = 'https://api.fxmacrodata.com/v1/calendar';
const TICKATLAS_BASE = 'https://tickatlas.com/v1/calendar';
const FOREXFACTORY_THIS_WEEK = 'https://nfs.faireconomy.media/ff_calendar_thisweek.json';

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

  const provider = String(req.query.provider || 'fxmacrodata').toLowerCase();
  const currency = String(req.query.currency || 'USD').toUpperCase().replace(/[^A-Z,]/g, '').slice(0, 40) || 'USD';
  const impact = String(req.query.impact || '').toLowerCase().replace(/[^a-z]/g, '');
  const apiKey = String(req.query.apiKey || '');

  let upstream;
  let headers = { accept: 'application/json' };

  if (provider === 'forexfactory') {
    upstream = FOREXFACTORY_THIS_WEEK;
  } else if (provider === 'tickatlas') {
    if (!apiKey) {
      res.status(400).json({ error: 'TickAtlas API key is required for forecast and previous values.' });
      return;
    }
    const params = new URLSearchParams({
      currencies: currency,
      from: String(req.query.from || ''),
      to: String(req.query.to || ''),
      offset: '0',
      limit: '100',
    });
    if (impact) params.set('impact', impact);
    upstream = `${TICKATLAS_BASE}?${params.toString()}`;
    headers['X-API-Key'] = apiKey;
  } else {
    upstream = `${FXMACRO_BASE}/${encodeURIComponent(currency.split(',')[0] || 'USD')}`;
  }

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
