let latestSignal = null;
const executed = new Set();

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Bridge-Token');
  res.setHeader('Cache-Control', 'no-store');
}

function readBody(req) {
  if (req.body && typeof req.body === 'object') return Promise.resolve(req.body);
  if (typeof req.body === 'string') {
    try { return Promise.resolve(JSON.parse(req.body)); }
    catch (error) { return Promise.reject(error); }
  }
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try { resolve(body ? JSON.parse(body) : {}); }
      catch (error) { reject(error); }
    });
    req.on('error', reject);
  });
}

function cleanSignal(raw) {
  const action = String(raw.action || '').toLowerCase();
  if (!['buy', 'sell'].includes(action)) throw new Error('Signal action must be buy or sell');
  const symbol = String(raw.symbol || '').trim();
  if (!symbol) throw new Error('Signal symbol is required');
  const id = String(raw.id || `sig_${Date.now()}`).replace(/[^a-zA-Z0-9_.:-]/g, '').slice(0, 80);
  return {
    id,
    action,
    symbol,
    lot: Math.max(0.01, Number(raw.lot) || 0.01),
    sl_points: Math.max(0, Number(raw.sl_points) || 0),
    tp_points: Math.max(0, Number(raw.tp_points) || 0),
    strategy: String(raw.strategy || 'unknown').slice(0, 40),
    confidence: Math.max(0, Math.min(100, Number(raw.confidence) || 0)),
    source_symbol: String(raw.source_symbol || '').slice(0, 40),
    created_at: raw.created_at || new Date().toISOString(),
  };
}

module.exports = async function handler(req, res) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method === 'GET') {
    if (!latestSignal || executed.has(latestSignal.id)) {
      res.status(200).json({ signal: null });
      return;
    }
    res.status(200).json({ signal: latestSignal });
    return;
  }

  if (req.method === 'POST') {
    try {
      const body = await readBody(req);
      if (body.executed_id) {
        executed.add(String(body.executed_id));
        res.status(200).json({ ok: true, executed_id: body.executed_id });
        return;
      }
      latestSignal = cleanSignal(body);
      res.status(200).json({ ok: true, signal: latestSignal });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
};
