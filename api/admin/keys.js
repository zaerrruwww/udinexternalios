const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const LOCAL_DATA_FILE = path.join(__dirname, '..', '..', 'data', 'licenses.json');
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

  // Filter out any key that was revoked
  keys = keys.filter(k => !revoked.includes(k.key.toUpperCase()));

  return { keys, revoked };
}

function saveDb(data) {
  try { fs.writeFileSync(TMP_DATA_FILE, JSON.stringify(data, null, 2), 'utf8'); } catch (e) {}
  try { fs.writeFileSync(LOCAL_DATA_FILE, JSON.stringify(data, null, 2), 'utf8'); } catch (e) {}
}

function evaluateStatus(item) {
  if (item.is_banned) return 'BANNED';
  if (item.is_lifetime) return 'ACTIVE';
  if (!item.activated_at) return 'UNBOUND';
  if (item.expiry_date && new Date(item.expiry_date) <= new Date()) return 'EXPIRED';
  return 'ACTIVE';
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-admin-password');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const authHeader = req.headers['authorization'];
  const passHeader = req.headers['x-admin-password'];
  const token = authHeader ? authHeader.replace('Bearer ', '').trim() : '';

  if (token !== ADMIN_PASSWORD && passHeader !== ADMIN_PASSWORD) {
    return res.status(401).json({ success: false, message: 'Unauthorized. Invalid admin credentials.' });
  }

  const { keys, revoked } = loadDb();
  const url = req.url || '';

  // GET: List all keys
  if (req.method === 'GET') {
    const keysWithStatus = keys.map(item => ({
      ...item,
      status: evaluateStatus(item)
    }));

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

  // POST: Actions
  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { body = {}; }
  }
  body = body || {};

  const { action, key, custom_key, duration_hours, extra_hours, customer_note, keys: syncKeys } = body;
  const targetKey = (key || custom_key || '').toUpperCase().trim();

  // 1. DELETE KEY (REAL-TIME REVOCATION)
  if (req.method === 'DELETE' || action === 'delete' || url.includes('/delete')) {
    if (!targetKey) return res.status(400).json({ success: false, message: 'Key is required to delete.' });

    const idx = keys.findIndex(k => k.key.toUpperCase() === targetKey);
    if (idx !== -1) {
      keys.splice(idx, 1);
    }
    if (!revoked.includes(targetKey)) {
      revoked.push(targetKey);
    }

    saveDb({ keys, revoked });
    return res.json({ success: true, message: `Key ${targetKey} permanently revoked and deleted from server.` });
  }

  // 2. TOGGLE BAN
  if (action === 'toggle-ban' || url.includes('toggle-ban')) {
    if (!targetKey) return res.status(400).json({ success: false, message: 'Key is required.' });
    const target = keys.find(k => k.key.toUpperCase() === targetKey);
    if (!target) return res.status(404).json({ success: false, message: 'Key not found.' });

    target.is_banned = !target.is_banned;
    saveDb({ keys, revoked });
    return res.json({ success: true, message: `Key ${target.key} is now ${target.is_banned ? 'BANNED' : 'ACTIVE'}.`, is_banned: target.is_banned });
  }

  // 3. RESET HWID
  if (action === 'reset-hwid' || url.includes('reset-hwid')) {
    if (!targetKey) return res.status(400).json({ success: false, message: 'Key is required.' });
    const target = keys.find(k => k.key.toUpperCase() === targetKey);
    if (!target) return res.status(404).json({ success: false, message: 'Key not found.' });

    target.bound_hwid = null;
    target.device_model = null;
    saveDb({ keys, revoked });
    return res.json({ success: true, message: `HWID reset for ${target.key}. Device can now re-bind.` });
  }

  // 4. EXTEND DURATION
  if (action === 'extend' || url.includes('extend')) {
    if (!targetKey) return res.status(400).json({ success: false, message: 'Key is required.' });
    const target = keys.find(k => k.key.toUpperCase() === targetKey);
    if (!target) return res.status(404).json({ success: false, message: 'Key not found.' });

    const addMs = (parseFloat(extra_hours) || 24) * 3600 * 1000;
    const currentExpiry = target.expiry_date ? new Date(target.expiry_date).getTime() : Date.now();
    const base = currentExpiry > Date.now() ? currentExpiry : Date.now();
    target.expiry_date = new Date(base + addMs).toISOString();

    saveDb({ keys, revoked });
    return res.json({ success: true, message: `Key ${target.key} extended by ${extra_hours} hours.`, expiry_date: target.expiry_date });
  }

  // 5. BULK SYNC
  if (Array.isArray(syncKeys)) {
    syncKeys.forEach(k => {
      const idx = keys.findIndex(x => x.key.toUpperCase() === k.key.toUpperCase());
      if (idx >= 0) keys[idx] = { ...keys[idx], ...k };
      else if (!revoked.includes(k.key.toUpperCase())) keys.push(k);
    });
    saveDb({ keys, revoked });
    return res.json({ success: true, count: keys.length });
  }

  // 6. CREATE KEY
  const keyStr = custom_key ? custom_key.trim().toUpperCase() : ('UDIN-' + crypto.randomBytes(2).toString('hex').toUpperCase() + '-' + crypto.randomBytes(2).toString('hex').toUpperCase());
  
  // If previously revoked, un-revoke it
  const revIdx = revoked.indexOf(keyStr);
  if (revIdx !== -1) revoked.splice(revIdx, 1);

  const hours = parseFloat(duration_hours) || 0;
  const isLifetime = hours <= 0;
  let planName = 'Lifetime VIP';
  if (!isLifetime) {
    if (hours < 24) planName = `${hours} Jam VIP`;
    else planName = `${Math.round(hours / 24)} Hari VIP`;
  }

  const newKey = {
    key: keyStr,
    plan: planName,
    duration_hours: isLifetime ? 0 : hours,
    duration_days: isLifetime ? 0 : Math.round(hours / 24),
    is_lifetime: isLifetime,
    created_at: new Date().toISOString(),
    activated_at: null,
    expiry_date: null,
    bound_hwid: null,
    device_model: null,
    customer_note: customer_note ? customer_note.trim() : 'Created from Admin Panel',
    is_banned: false,
    status: 'UNBOUND'
  };

  keys.unshift(newKey);
  saveDb({ keys, revoked });

  return res.json({ success: true, message: 'Key created successfully.', key: newKey });
};
