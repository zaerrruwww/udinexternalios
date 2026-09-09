const fs = require('fs');
const path = require('path');

const LOCAL_DATA_FILE = path.join(__dirname, '..', '..', 'data', 'licenses.json');
const TMP_DATA_FILE = path.join('/tmp', 'licenses.json');
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'zaeruw2026';

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-admin-password');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const authHeader = req.headers['authorization'];
  const passHeader = req.headers['x-admin-password'];
  const token = authHeader ? authHeader.replace('Bearer ', '').trim() : '';

  if (token !== ADMIN_PASSWORD && passHeader !== ADMIN_PASSWORD) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }

  let keys = [];
  try {
    if (fs.existsSync(LOCAL_DATA_FILE)) {
      const p = JSON.parse(fs.readFileSync(LOCAL_DATA_FILE, 'utf8'));
      if (p && Array.isArray(p.keys)) keys = p.keys;
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
    }
  } catch (e) {}

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

  if (req.method === 'POST') {
    let body = req.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch (e) { body = {}; }
    }
    body = body || {};

    const { action, key, custom_key, duration_hours, customer_note, keys: syncKeys } = body;

    if (action === 'reset_hwid' || req.url.includes('reset-hwid')) {
      const target = keys.find(k => k.key.toUpperCase() === String(key).toUpperCase().trim());
      if (target) {
        target.bound_hwid = null;
        target.device_model = null;
        try { fs.writeFileSync(TMP_DATA_FILE, JSON.stringify({ keys }, null, 2), 'utf8'); } catch (e) {}
        return res.json({ success: true, message: `HWID reset for ${target.key}` });
      }
      return res.status(404).json({ success: false, message: 'Key not found' });
    }

    if (Array.isArray(syncKeys)) {
      syncKeys.forEach(k => {
        const idx = keys.findIndex(x => x.key.toUpperCase() === k.key.toUpperCase());
        if (idx >= 0) keys[idx] = { ...keys[idx], ...k };
        else keys.push(k);
      });
      try { fs.writeFileSync(TMP_DATA_FILE, JSON.stringify({ keys }, null, 2), 'utf8'); } catch (e) {}
      return res.json({ success: true, count: keys.length });
    }

    // Create key
    const keyStr = custom_key ? custom_key.trim().toUpperCase() : ('UDIN-' + Math.random().toString(36).substring(2, 6).toUpperCase() + '-' + Math.random().toString(36).substring(2, 6).toUpperCase());
    const hours = parseFloat(duration_hours) || 0;
    const isLifetime = hours <= 0;
    const plan = isLifetime ? 'Lifetime VIP' : (hours < 24 ? hours + ' Jam VIP' : Math.round(hours / 24) + ' Hari VIP');

    const newK = {
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
      customer_note: customer_note || 'Admin Generated',
      is_banned: false,
      status: 'UNBOUND'
    };

    keys.unshift(newK);
    try { fs.writeFileSync(TMP_DATA_FILE, JSON.stringify({ keys }, null, 2), 'utf8'); } catch (e) {}
    return res.json({ success: true, message: 'Key created', key: newK });
  }

  return res.status(405).json({ success: false, message: 'Method not allowed' });
};
