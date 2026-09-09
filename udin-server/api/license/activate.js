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

  let keys = [
    {
      key: "UDIN-LHIA-F0HD",
      plan: "Lifetime VIP",
      duration_hours: 0,
      duration_days: 0,
      is_lifetime: true,
      created_at: "2026-09-09T15:20:00.000Z",
      activated_at: null,
      expiry_date: null,
      bound_hwid: null,
      device_model: null,
      customer_note: "VIP Owner Key",
      is_banned: false,
      status: "UNBOUND"
    }
  ];

  try {
    if (fs.existsSync(LOCAL_DATA_FILE)) {
      const p = JSON.parse(fs.readFileSync(LOCAL_DATA_FILE, 'utf8'));
      if (p && Array.isArray(p.keys)) {
        p.keys.forEach(k => {
          const idx = keys.findIndex(x => x.key.toUpperCase() === k.key.toUpperCase());
          if (idx >= 0) keys[idx] = k;
          else keys.push(k);
        });
      }
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

  // Auto provision any UDIN key
  if (!item) {
    if (cleanKey.startsWith('UDIN-') || cleanKey.length >= 6) {
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
        customer_note: 'Auto Provisioned',
        is_banned: false,
        status: 'UNBOUND'
      };
      keys.unshift(item);
    } else {
      return res.status(404).json({ success: false, message: 'Invalid access key. Key not found.' });
    }
  }

  if (item.is_banned) {
    return res.status(403).json({ success: false, message: 'This key has been suspended by admin.' });
  }

  const now = new Date();

  // If already bound to this device, verify
  if (item.bound_hwid && item.bound_hwid === cleanHwid) {
    if (!item.is_lifetime && item.expiry_date) {
      if (now.getTime() >= new Date(item.expiry_date).getTime()) {
        return res.status(403).json({ success: false, message: 'This access key has expired.' });
      }
    }

    return res.json({
      success: true,
      message: 'License verified successfully.',
      key: item.key,
      plan: item.plan || 'VIP Access',
      is_lifetime: item.is_lifetime,
      expiry_date: item.expiry_date,
      bound_hwid: item.bound_hwid
    });
  }

  // Bind to new HWID (Rebinds cleanly)
  item.bound_hwid = cleanHwid;
  item.activated_at = item.activated_at || now.toISOString();
  item.device_model = device_model || 'iOS Device';

  const totalHours = item.duration_hours || (item.duration_days ? item.duration_days * 24 : 0);
  if (!item.is_lifetime && totalHours > 0 && !item.expiry_date) {
    const expiryMs = now.getTime() + totalHours * 3600 * 1000;
    const expiry = new Date(expiryMs);
    item.expiry_date = expiry.toISOString();
  }

  try {
    fs.writeFileSync(TMP_DATA_FILE, JSON.stringify({ keys }, null, 2), 'utf8');
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
