const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const LOCAL_DATA_FILE = path.join(__dirname, '..', '..', 'web-admin-panel', 'data', 'licenses.json');
const TMP_DATA_FILE = path.join('/tmp', 'licenses.json');
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'zaeruw2026';

function loadDb() {
  let keys = [];
  let revoked = [];

  try {
    if (fs.existsSync(LOCAL_DATA_FILE)) {
      const p = JSON.parse(fs.readFileSync(LOCAL_DATA_FILE, 'utf8'));
      if (p && Array.isArray(p.keys)) keys = p.keys;
      if (p && Array.isArray(p.revoked)) revoked = p.revoked;
    }
  } catch (e) {}

  try {
    if (fs.existsSync(TMP_DATA_FILE)) {
      const p = JSON.parse(fs.readFileSync(TMP_DATA_FILE, 'utf8'));
      if (p && Array.isArray(p.keys)) {
        p.keys.forEach(k => {
          const idx = keys.findIndex(x => x.key.toUpperCase() === k.key.toUpperCase());
          if (idx >= 0) keys[idx] = k;
          else keys.push(k);
        });
      }
      if (p && Array.isArray(p.revoked)) {
        p.revoked.forEach(r => {
          if (!revoked.includes(r.toUpperCase())) revoked.push(r.toUpperCase());
        });
      }
    }
  } catch (e) {}

  keys = keys.filter(k => !revoked.includes(k.key.toUpperCase()));
  return { keys, revoked };
}

function saveDb(data) {
  try { fs.writeFileSync(TMP_DATA_FILE, JSON.stringify(data, null, 2), 'utf8'); } catch (e) {}
  try { fs.writeFileSync(LOCAL_DATA_FILE, JSON.stringify(data, null, 2), 'utf8'); } catch (e) {}
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-admin-password');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const authHeader = req.headers['authorization'];
  const passHeader = req.headers['x-admin-password'];
  const token = authHeader ? authHeader.replace('Bearer ', '').trim() : '';

  const isValidAuth = (t) => {
    const clean = String(t || '').trim().toLowerCase();
    return clean === 'zaeruw2026' || clean === 'udin2026' || clean === 'admin';
  };

  if (!isValidAuth(token) && !isValidAuth(passHeader)) {
    return res.status(401).json({ success: false, message: 'Unauthorized. Invalid admin password.' });
  }

  const { keys, revoked } = loadDb();

  if (req.method === 'GET') {
    const keysWithStatus = keys.map(item => {
      let status = 'ACTIVE';
      if (item.is_banned) status = 'BANNED';
      else if (!item.activated_at) status = 'UNBOUND';
      else if (!item.is_lifetime && item.expiry_date && new Date(item.expiry_date) <= new Date()) status = 'EXPIRED';
      return { ...item, status };
    });

    const total = keysWithStatus.length;
    const active = keysWithStatus.filter(k => k.status === 'ACTIVE').length;
    const unbound = keysWithStatus.filter(k => k.status === 'UNBOUND').length;
    const expired = keysWithStatus.filter(k => k.status === 'EXPIRED').length;
    const banned = keysWithStatus.filter(k => k.status === 'BANNED').length;

    return res.json({
      success: true,
      keys: keysWithStatus,
      stats: { total, active, unbound, expired, banned }
    });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { body = {}; }
  }
  body = body || {};

  const { action, key, custom_key, duration_hours, customer_note, keys: syncKeys } = body;
  const targetKey = (key || custom_key || '').toUpperCase().trim();

  // DELETE
  if (action === 'delete' || req.method === 'DELETE' || req.url.includes('delete')) {
    const idx = keys.findIndex(k => k.key.toUpperCase() === targetKey);
    if (idx !== -1) keys.splice(idx, 1);
    if (!revoked.includes(targetKey)) revoked.push(targetKey);
    saveDb({ keys, revoked });
    return res.json({ success: true, message: `Key ${targetKey} permanently deleted.` });
  }

  // RESET HWID
  if (action === 'reset-hwid' || req.url.includes('reset-hwid')) {
    const target = keys.find(k => k.key.toUpperCase() === targetKey);
    if (target) {
      target.bound_hwid = null;
      target.device_model = null;
      saveDb({ keys, revoked });
      return res.json({ success: true, message: `HWID reset for ${target.key}` });
    }
    return res.status(404).json({ success: false, message: 'Key not found.' });
  }

  // TOGGLE BAN
  if (action === 'toggle-ban' || req.url.includes('toggle-ban')) {
    const target = keys.find(k => k.key.toUpperCase() === targetKey);
    if (target) {
      target.is_banned = !target.is_banned;
      saveDb({ keys, revoked });
      return res.json({ success: true, message: `Key ${target.key} status updated.` });
    }
    return res.status(404).json({ success: false, message: 'Key not found.' });
  }

  // BULK CREATE
  if (action === 'bulk' || req.url.includes('bulk') || body.count) {
    const count = Math.min(Math.max(parseInt(body.count, 10) || 5, 1), 50);
    const prefix = (body.prefix || 'UDIN').trim().toUpperCase();
    const generated = [];

    const hours = parseFloat(duration_hours) || 0;
    const isLifetime = hours <= 0;
    const plan = isLifetime ? 'Lifetime VIP' : (hours < 24 ? hours + ' Jam VIP' : Math.round(hours / 24) + ' Hari VIP');

    for (let i = 0; i < count; i++) {
      const randStr = crypto.randomBytes(2).toString('hex').toUpperCase() + '-' + crypto.randomBytes(2).toString('hex').toUpperCase();
      const kStr = `${prefix}-${randStr}`;
      const rIdx = revoked.indexOf(kStr);
      if (rIdx !== -1) revoked.splice(rIdx, 1);

      const item = {
        key: kStr,
        plan,
        duration_hours: isLifetime ? 0 : hours,
        duration_days: isLifetime ? 0 : Math.round(hours / 24),
        is_lifetime: isLifetime,
        created_at: new Date().toISOString(),
        activated_at: null,
        expiry_date: null,
        bound_hwid: null,
        device_model: null,
        customer_note: customer_note || `Bulk Batch (${count} keys)`,
        is_banned: false,
        status: 'UNBOUND'
      };
      keys.unshift(item);
      generated.push(item);
    }

    saveDb({ keys, revoked });
    return res.json({ success: true, message: `Successfully generated ${generated.length} keys!`, keys: generated });
  }

  // SYNC FROM ADMIN LOCALSTORAGE
  if (action === 'sync' || Array.isArray(syncKeys)) {
    if (Array.isArray(syncKeys)) {
      syncKeys.forEach(k => {
        const idx = keys.findIndex(x => x.key.toUpperCase() === k.key.toUpperCase());
        if (idx >= 0) keys[idx] = k;
        else keys.push(k);
      });
    }
    saveDb({ keys, revoked });
    return res.json({ success: true, message: 'Database synced successfully.', total: keys.length });
  }

  // CREATE KEY
  const keyStr = custom_key ? custom_key.trim().toUpperCase() : ('UDIN-' + crypto.randomBytes(2).toString('hex').toUpperCase() + '-' + crypto.randomBytes(2).toString('hex').toUpperCase());
  const revIdx = revoked.indexOf(keyStr);
  if (revIdx !== -1) revoked.splice(revIdx, 1);

  const hours = parseFloat(duration_hours) || 0;
  const isLifetime = hours <= 0;
  const plan = isLifetime ? 'Lifetime VIP' : (hours < 24 ? hours + ' Jam VIP' : Math.round(hours / 24) + ' Hari VIP');

  const newKey = {
    key: keyStr,
    plan,
    duration_hours: isLifetime ? 0 : hours,
    duration_days: isLifetime ? 0 : Math.round(hours / 24),
    is_lifetime: isLifetime,
    created_at: new Date().toISOString(),
    activated_at: null,
    expiry_date: null,
    bound_hwid: null,
    device_model: null,
    customer_note: customer_note || 'Created from Web Admin',
    is_banned: false,
    status: 'UNBOUND'
  };

  keys.unshift(newKey);
  saveDb({ keys, revoked });
  return res.json({ success: true, message: 'Key created successfully.', key: newKey });
};
