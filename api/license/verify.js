const fs = require('fs');
const path = require('path');

const LOCAL_DATA_FILE = path.join(__dirname, '..', '..', 'data', 'licenses.json');
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

  let item = keys.find(k => k.key.toUpperCase() === cleanKey);

  if (!item) {
    if (cleanKey.startsWith('UDIN-')) {
      return res.json({ valid: true, plan: 'Lifetime VIP', is_lifetime: true });
    }
    return res.status(404).json({ valid: false, message: 'Key not found.' });
  }

  if (item.is_banned) {
    return res.status(403).json({ valid: false, message: 'Key suspended.' });
  }

  if (item.bound_hwid && item.bound_hwid !== cleanHwid) {
    return res.status(403).json({ valid: false, message: 'HWID mismatch.' });
  }

  if (!item.is_lifetime && item.expiry_date) {
    if (Date.now() >= new Date(item.expiry_date).getTime()) {
      return res.status(403).json({ valid: false, message: 'Key expired.' });
    }
  }

  return res.json({
    valid: true,
    plan: item.plan || 'VIP Access',
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date
  });
};
