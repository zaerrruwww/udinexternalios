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

  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, message: 'Method Not Allowed' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { body = {}; }
  }
  body = body || {};

  const { key, hwid, device_model } = body;
  if (!key || !hwid) {
    return res.status(400).json({ success: false, message: 'Key and device HWID are required.' });
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

  // 1. Check if key is explicitly revoked/deleted
  if (revoked.includes(cleanKey)) {
    return res.status(403).json({
      success: false,
      message: 'This key has been deleted/revoked by administrator.'
    });
  }

  // 2. Find key in active database
  let item = keys.find(k => k.key.toUpperCase() === cleanKey);

  // If not found in DB
  if (!item) {
    // If it's the master key UDIN-LHIA-F0HD, allow it
    if (cleanKey === 'UDIN-LHIA-F0HD') {
      item = {
        key: cleanKey,
        plan: 'Lifetime VIP',
        duration_hours: 0,
        duration_days: 0,
        is_lifetime: true,
        created_at: new Date().toISOString(),
        activated_at: null,
        expiry_date: null,
        bound_hwid: null,
        device_model: device_model || 'iOS Device',
        customer_note: 'VIP Access Key',
        is_banned: false,
        status: 'UNBOUND'
      };
      keys.unshift(item);
    } else {
      return res.status(404).json({
        success: false,
        message: 'Invalid access key. Key does not exist or has been deleted.'
      });
    }
  }

  // 3. Check banned
  if (item.is_banned) {
    return res.status(403).json({
      success: false,
      message: 'This key has been banned/suspended by administrator.'
    });
  }

  const now = new Date();

  // 4. HWID Binding check
  if (item.bound_hwid && item.bound_hwid !== cleanHwid) {
    return res.status(403).json({
      success: false,
      message: 'Key is already bound to another device. Contact admin to reset HWID.'
    });
  }

  // 5. Check expiration
  if (!item.is_lifetime && item.expiry_date) {
    if (now.getTime() >= new Date(item.expiry_date).getTime()) {
      return res.status(403).json({
        success: false,
        message: 'This access key has expired.'
      });
    }
  }

  // Bind HWID & update
  item.bound_hwid = cleanHwid;
  item.activated_at = item.activated_at || now.toISOString();
  item.device_model = device_model || item.device_model || 'iOS Device';

  const totalHours = item.duration_hours || (item.duration_days ? item.duration_days * 24 : 0);
  if (!item.is_lifetime && totalHours > 0 && !item.expiry_date) {
    const expiryMs = now.getTime() + totalHours * 3600 * 1000;
    const expiry = new Date(expiryMs);
    item.expiry_date = expiry.toISOString();
  }

  try {
    fs.writeFileSync(TMP_DATA_FILE, JSON.stringify({ keys, revoked }, null, 2), 'utf8');
  } catch (e) {}

  return res.json({
    success: true,
    message: 'Device bound and activated successfully.',
    key: item.key,
    plan: item.plan || 'VIP Access',
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date,
    bound_hwid: item.bound_hwid
  });
};
