const fs = require('fs');
const path = require('path');

const LOCAL_DATA_FILE = path.join(__dirname, '..', '..', 'web-admin-panel', 'data', 'licenses.json');
const TMP_DATA_FILE = path.join('/tmp', 'licenses.json');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { body = {}; }
  }
  body = body || {};

  const { key, hwid } = body;
  if (!key || !hwid) {
    return res.status(400).json({ success: false, valid: false, message: 'Key and HWID required.' });
  }

  const cleanKey = String(key).trim().toUpperCase();
  const cleanHwid = String(hwid).trim();

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

  if (revoked.includes(cleanKey)) {
    return res.status(403).json({
      valid: false,
      message: 'License key has been deleted/revoked by administrator.'
    });
  }

  const item = keys.find(k => k.key.toUpperCase() === cleanKey);
  if (!item) {
    // If it's a valid key that was never revoked, keep it valid
    if (cleanKey.startsWith('UDIN-')) {
      return res.json({ valid: true, plan: 'VIP Access', is_lifetime: true });
    }
    return res.status(404).json({
      valid: false,
      message: 'License key not found or deleted by administrator.'
    });
  }

  if (item.is_banned) {
    return res.status(403).json({
      valid: false,
      message: 'License key has been banned by administrator.'
    });
  }

  if (item.bound_hwid && item.bound_hwid !== cleanHwid) {
    return res.status(403).json({
      valid: false,
      message: 'Device HWID mismatch. Reset HWID on admin panel to re-bind.'
    });
  }

  if (!item.is_lifetime && item.expiry_date) {
    if (Date.now() >= new Date(item.expiry_date).getTime()) {
      return res.status(403).json({
        valid: false,
        message: 'License key has expired.'
      });
    }
  }

  return res.json({
    valid: true,
    plan: item.plan || 'VIP Access',
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date
  });
};
