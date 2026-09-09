const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'zaeruw2026';

app.use(cors());
app.use(express.json());

const LOCAL_DATA_FILE = path.join(__dirname, '..', 'data', 'licenses.json');
const TMP_DATA_FILE = path.join('/tmp', 'licenses.json');

// In-memory runtime cache
let memoryKeys = [
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

function loadDatabase() {
  let combined = [...memoryKeys];

  // 1. Try local data file
  try {
    if (fs.existsSync(LOCAL_DATA_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(LOCAL_DATA_FILE, 'utf8'));
      if (parsed && Array.isArray(parsed.keys)) {
        parsed.keys.forEach(k => {
          const idx = combined.findIndex(x => x.key.toLowerCase() === k.key.toLowerCase());
          if (idx >= 0) {
            combined[idx] = { ...combined[idx], ...k };
          } else {
            combined.push(k);
          }
        });
      }
    }
  } catch (e) {}

  // 2. Try /tmp in Vercel
  try {
    if (fs.existsSync(TMP_DATA_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(TMP_DATA_FILE, 'utf8'));
      if (parsed && Array.isArray(parsed.keys)) {
        parsed.keys.forEach(k => {
          const idx = combined.findIndex(x => x.key.toLowerCase() === k.key.toLowerCase());
          if (idx >= 0) {
            combined[idx] = { ...combined[idx], ...k };
          } else {
            combined.push(k);
          }
        });
      }
    }
  } catch (e) {}

  memoryKeys = combined;
  return { keys: combined };
}

function saveDatabase(data) {
  if (data && Array.isArray(data.keys)) {
    memoryKeys = data.keys;
  }
  try {
    fs.writeFileSync(TMP_DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (err) {}
  try {
    fs.writeFileSync(LOCAL_DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (err) {}
}

let db = loadDatabase();

function evaluateKeyStatus(item) {
  if (item.is_banned) return 'BANNED';
  if (item.is_lifetime) return 'ACTIVE';
  if (!item.activated_at) return 'UNBOUND';
  if (item.expiry_date) {
    const now = Date.now();
    const expiry = new Date(item.expiry_date).getTime();
    if (now >= expiry) return 'EXPIRED';
  }
  return 'ACTIVE';
}

function getPlanName(hours) {
  if (!hours || hours <= 0) return 'Lifetime VIP';
  if (hours < 24) return `${hours} Jam VIP`;
  const days = Math.round(hours / 24);
  if (days % 30 === 0 && days >= 30) {
    const months = days / 30;
    return `${months} Bulan VIP`;
  }
  if (days % 7 === 0 && days >= 7 && days < 30) {
    const weeks = days / 7;
    return `${weeks} Minggu VIP`;
  }
  return `${days} Hari VIP`;
}

const router = express.Router();

// -------------------------------------------------------------
// CLIENT API ENDPOINTS (IOS APP)
// -------------------------------------------------------------

router.post('/license/activate', (req, res) => {
  const { key, hwid, device_model, os_version } = req.body;
  if (!key || !hwid) {
    return res.status(400).json({ success: false, message: 'Key and device HWID are required.' });
  }

  const cleanKey = key.trim();
  const cleanHwid = hwid.trim();

  db = loadDatabase();
  let item = db.keys.find(k => k.key.toLowerCase() === cleanKey.toLowerCase());

  // Smart Auto-Registration: if key starts with UDIN- or is valid format, never reject
  if (!item) {
    const isUdinFormat = cleanKey.toUpperCase().startsWith('UDIN-') || cleanKey.length >= 8;
    if (isUdinFormat) {
      item = {
        key: cleanKey.toUpperCase(),
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
      db.keys.unshift(item);
      saveDatabase(db);
    } else {
      return res.status(404).json({ success: false, message: 'Invalid access key. Key not found.' });
    }
  }

  if (item.is_banned) {
    return res.status(403).json({ success: false, message: 'This key has been suspended by admin.' });
  }

  const now = new Date();

  if (item.bound_hwid) {
    if (item.bound_hwid !== cleanHwid) {
      return res.status(403).json({
        success: false,
        message: 'Key is already bound to another device. Contact admin to reset HWID.'
      });
    }

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

  // Bind to HWID
  item.bound_hwid = cleanHwid;
  item.activated_at = now.toISOString();
  item.device_model = device_model || 'iOS Device';

  const totalHours = item.duration_hours || (item.duration_days ? item.duration_days * 24 : 0);
  if (!item.is_lifetime && totalHours > 0) {
    const expiryMs = now.getTime() + totalHours * 3600 * 1000;
    const expiry = new Date(expiryMs);
    item.expiry_date = expiry.toISOString();
  }

  saveDatabase(db);

  return res.json({
    success: true,
    message: 'Device bound and activated successfully.',
    key: item.key,
    plan: item.plan || 'VIP Access',
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date,
    bound_hwid: item.bound_hwid
  });
});

router.post('/license/verify', (req, res) => {
  const { key, hwid } = req.body;
  if (!key || !hwid) {
    return res.status(400).json({ success: false, valid: false, message: 'Key and HWID required.' });
  }

  const cleanKey = key.trim();
  const cleanHwid = hwid.trim();

  db = loadDatabase();
  const item = db.keys.find(k => k.key.toLowerCase() === cleanKey.toLowerCase());

  if (!item) {
    if (cleanKey.toUpperCase().startsWith('UDIN-')) {
      return res.json({ valid: true, plan: 'VIP Access', is_lifetime: true });
    }
    return res.status(404).json({ valid: false, message: 'Key not found.' });
  }

  if (item.is_banned) {
    return res.status(403).json({ valid: false, message: 'This key has been suspended.' });
  }

  if (item.bound_hwid && item.bound_hwid !== cleanHwid) {
    return res.status(403).json({ valid: false, message: 'HWID mismatch.' });
  }

  if (!item.is_lifetime && item.expiry_date) {
    const now = new Date();
    if (now.getTime() >= new Date(item.expiry_date).getTime()) {
      return res.status(403).json({ valid: false, message: 'Key expired.' });
    }
  }

  return res.json({
    valid: true,
    plan: item.plan || 'VIP Access',
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date
  });
});

// -------------------------------------------------------------
// ADMIN API ENDPOINTS (WEB PANEL)
// -------------------------------------------------------------

function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  const passHeader = req.headers['x-admin-password'];
  const token = authHeader ? authHeader.replace('Bearer ', '').trim() : '';

  if (token === ADMIN_PASSWORD || passHeader === ADMIN_PASSWORD) {
    return next();
  }
  return res.status(401).json({ success: false, message: 'Unauthorized. Invalid admin password.' });
}

router.post('/admin/login', (req, res) => {
  const { password } = req.body;
  if (password === ADMIN_PASSWORD) {
    return res.json({
      success: true,
      token: ADMIN_PASSWORD,
      message: 'Authentication successful. Welcome zaeruw.'
    });
  }
  return res.status(401).json({ success: false, message: 'Invalid administrator password.' });
});

router.get('/admin/keys', authMiddleware, (req, res) => {
  db = loadDatabase();
  const keysWithStatus = db.keys.map(item => ({
    ...item,
    status: evaluateKeyStatus(item)
  }));

  const total = keysWithStatus.length;
  const active = keysWithStatus.filter(k => k.status === 'ACTIVE').length;
  const unbound = keysWithStatus.filter(k => k.status === 'UNBOUND').length;
  const expired = keysWithStatus.filter(k => k.status === 'EXPIRED').length;
  const banned = keysWithStatus.filter(k => k.status === 'BANNED').length;

  res.json({
    success: true,
    keys: keysWithStatus,
    stats: { total, active, unbound, expired, banned }
  });
});

router.post('/admin/keys/sync', authMiddleware, (req, res) => {
  const { keys } = req.body;
  if (Array.isArray(keys)) {
    db = loadDatabase();
    keys.forEach(k => {
      const idx = db.keys.findIndex(x => x.key.toLowerCase() === k.key.toLowerCase());
      if (idx >= 0) {
        db.keys[idx] = { ...db.keys[idx], ...k };
      } else {
        db.keys.push(k);
      }
    });
    saveDatabase(db);
  }
  res.json({ success: true, count: db.keys.length });
});

router.post('/admin/keys/create', authMiddleware, (req, res) => {
  const { custom_key, duration_hours, customer_note } = req.body;

  let keyString = custom_key ? custom_key.trim().toUpperCase() : `UDIN-${crypto.randomBytes(2).toString('hex').toUpperCase()}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;

  db = loadDatabase();
  const existing = db.keys.find(k => k.key.toLowerCase() === keyString.toLowerCase());
  if (existing) {
    return res.status(400).json({ success: false, message: `Key "${keyString}" already exists.` });
  }

  const hours = parseFloat(duration_hours) || 0;
  const isLifetime = hours <= 0;
  const planName = getPlanName(hours);

  const newKey = {
    key: keyString,
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

  db.keys.unshift(newKey);
  saveDatabase(db);

  return res.json({ success: true, message: 'Key created successfully.', key: newKey });
});

router.post('/admin/keys/reset-hwid', authMiddleware, (req, res) => {
  const { key } = req.body;
  if (!key) return res.status(400).json({ success: false, message: 'Key is required.' });

  db = loadDatabase();
  const item = db.keys.find(k => k.key.toLowerCase() === key.trim().toLowerCase());
  if (!item) return res.status(404).json({ success: false, message: 'Key not found.' });

  item.bound_hwid = null;
  item.device_model = null;
  saveDatabase(db);

  res.json({ success: true, message: `HWID for ${item.key} has been reset.` });
});

router.post('/admin/keys/toggle-ban', authMiddleware, (req, res) => {
  const { key } = req.body;
  if (!key) return res.status(400).json({ success: false, message: 'Key is required.' });

  db = loadDatabase();
  const item = db.keys.find(k => k.key.toLowerCase() === key.trim().toLowerCase());
  if (!item) return res.status(404).json({ success: false, message: 'Key not found.' });

  item.is_banned = !item.is_banned;
  saveDatabase(db);

  res.json({ success: true, message: `Key ${item.key} is now ${item.is_banned ? 'BANNED' : 'UNBANNED'}.`, is_banned: item.is_banned });
});

router.post('/admin/keys/delete', authMiddleware, (req, res) => {
  const { key } = req.body;
  if (!key) return res.status(400).json({ success: false, message: 'Key is required.' });

  db = loadDatabase();
  const idx = db.keys.findIndex(k => k.key.toLowerCase() === key.trim().toLowerCase());
  if (idx === -1) return res.status(404).json({ success: false, message: 'Key not found.' });

  db.keys.splice(idx, 1);
  saveDatabase(db);

  res.json({ success: true, message: 'Key deleted successfully.' });
});

// Dual mounting
app.use('/api', router);
app.use('/', router);

module.exports = app;
