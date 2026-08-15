let latestSignal = null;
let latestCommand = null;
let positions = [];
let bridgeStatus = { connected: false, account_login: null, server_name: null, updated_at: null };
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
  if (!['buy', 'sell', 'close', 'modify'].includes(action)) throw new Error('Signal action must be buy, sell, close, or modify');
  const symbol = String(raw.symbol || '').trim();
  const ticket = String(raw.ticket || '').trim();
  if (['buy', 'sell'].includes(action) && !symbol) throw new Error('Signal symbol is required');
  if (['close', 'modify'].includes(action) && !ticket) throw new Error('Position ticket is required');
  const id = String(raw.id || `sig_${Date.now()}`).replace(/[^a-zA-Z0-9_.:-]/g, '').slice(0, 80);
  return {
    id,
    action,
    symbol,
    ticket,
    lot: Math.max(0.01, Number(raw.lot) || 0.01),
    sl_points: Math.max(0, Number(raw.sl_points) || 0),
    tp_points: Math.max(0, Number(raw.tp_points) || 0),
    sl: raw.sl === undefined ? undefined : Number(raw.sl),
    tp: raw.tp === undefined ? undefined : Number(raw.tp),
    mode: String(raw.mode || 'auto').slice(0, 20),
    strategy: String(raw.strategy || 'unknown').slice(0, 40),
    confidence: Math.max(0, Math.min(100, Number(raw.confidence) || 0)),
    source_symbol: String(raw.source_symbol || '').slice(0, 40),
    account_login: String(raw.account_login || '').trim().slice(0, 40),
    server_name: String(raw.server_name || '').trim().slice(0, 80),
    bridge_token: String(raw.bridge_token || '').trim().slice(0, 120),
    created_at: raw.created_at || new Date().toISOString(),
  };
}

function bridgeIdentity(raw = {}) {
  return {
    account_login: String(raw.account_login || '').trim().slice(0, 40),
    server_name: String(raw.server_name || '').trim().slice(0, 80),
    bridge_token: String(raw.bridge_token || '').trim().slice(0, 120),
  };
}

function sameBridge(a = {}, b = {}) {
  return Boolean(a.account_login && a.server_name && a.bridge_token)
    && a.account_login === b.account_login
    && a.server_name === b.server_name
    && a.bridge_token === b.bridge_token;
}

function publicBridgeStatus() {
  return {
    connected: Boolean(bridgeStatus.connected),
    account_login: bridgeStatus.account_login,
    server_name: bridgeStatus.server_name,
    updated_at: bridgeStatus.updated_at,
  };
}

function requestQuery(req) {
  if (req.query) return req.query;
  try {
    const url = new URL(req.url || '', 'http://localhost');
    return Object.fromEntries(url.searchParams.entries());
  } catch {
    return {};
  }
}

module.exports = async function handler(req, res) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method === 'GET') {
    const requestIdentity = bridgeIdentity(requestQuery(req));
    const verified = sameBridge(bridgeStatus, requestIdentity);
    const bridge = { ...publicBridgeStatus(), verified };
    const commandAllowed = latestCommand
      && !executed.has(latestCommand.id)
      && sameBridge(latestCommand, requestIdentity);
    const command = commandAllowed ? latestCommand : null;
    const matchingPositions = verified ? positions : [];
    res.status(200).json({ signal: command, command, positions: matchingPositions, bridge });
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
      if (Array.isArray(body.positions)) {
        const identity = bridgeIdentity(body);
        if (!identity.account_login || !identity.server_name || !identity.bridge_token) {
          res.status(400).json({ error: 'Bridge heartbeat requires account_login, server_name, and bridge_token' });
          return;
        }
        positions = body.positions.slice(0, 100);
        bridgeStatus = { ...identity, connected: true, updated_at: new Date().toISOString() };
        res.status(200).json({ ok: true, positions });
        return;
      }
      latestSignal = cleanSignal(body);
      if (!latestSignal.account_login || !latestSignal.server_name || !latestSignal.bridge_token) {
        res.status(400).json({ error: 'MT5 command requires account_login, server_name, and bridge_token' });
        return;
      }
      if (bridgeStatus.connected && !sameBridge(bridgeStatus, latestSignal)) {
        res.status(409).json({ error: 'Command bridge identity does not match connected EA' });
        return;
      }
      latestCommand = latestSignal;
      res.status(200).json({ ok: true, signal: latestSignal, command: latestCommand, bridge: publicBridgeStatus() });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
};
