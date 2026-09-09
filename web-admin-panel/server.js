const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'zaeruw2026';

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const DATA_DIR = process.env.VERCEL ? '/tmp' : path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'licenses.json');
const SEED_FILE = path.join(__dirname, 'data', 'licenses.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  } catch (e) {}
}

function saveDatabase(data) {
  try {
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (err) {
    console.error('Error saving database file to', DATA_FILE, err);
  }
}

let db = { keys: [] };

function getDatabase() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      const content = fs.readFileSync(DATA_FILE, 'utf8');
      const parsed = JSON.parse(content);
      if (parsed && Array.isArray(parsed.keys)) {
        db = parsed;
        return db;
      }
    }
  } catch (err) {
    console.error('Error reading DATA_FILE:', err);
  }

  try {
    if (fs.existsSync(SEED_FILE)) {
      const content = fs.readFileSync(SEED_FILE, 'utf8');
      const parsed = JSON.parse(content);
      if (parsed && Array.isArray(parsed.keys)) {
        db = parsed;
        saveDatabase(db);
        return db;
      }
    }
  } catch (err) {
    console.error('Error reading SEED_FILE:', err);
  }

  db = { keys: [] };
  saveDatabase(db);
  return db;
}

db = getDatabase();

// Helper: Check key status
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

// -------------------------------------------------------------
// CLIENT API ENDPOINTS (CALLED FROM IOS APP)
// -------------------------------------------------------------

// POST /api/license/activate
app.post('/api/license/activate', (req, res) => {
  const currentDb = getDatabase();
  const { key, hwid, device_model, os_version } = req.body || {};
  if (!key || !hwid) {
    return res.status(400).json({ success: false, message: 'Key and device HWID are required.' });
  }

  const cleanKey = String(key).trim();
  const cleanHwid = String(hwid).trim();

  const item = currentDb.keys.find(k => k.key.toLowerCase() === cleanKey.toLowerCase());
  if (!item) {
    return res.status(404).json({ success: false, message: 'Invalid access key. Key has been deleted or not found.' });
  }

  if (item.is_banned) {
    return res.status(403).json({ success: false, message: 'This key has been suspended by admin.' });
  }

  const now = new Date();

  // If already activated, check HWID binding
  if (item.bound_hwid) {
    if (item.bound_hwid !== cleanHwid) {
      return res.status(403).json({
        success: false,
        message: 'Key is already bound to another device. Contact admin to reset HWID.'
      });
    }

    // Check expiration if not lifetime
    if (!item.is_lifetime && item.expiry_date) {
      if (now.getTime() >= new Date(item.expiry_date).getTime()) {
        return res.status(403).json({ success: false, message: 'This access key has expired.' });
      }
    }

    return res.json({
      success: true,
      message: 'License verified successfully.',
      key: item.key,
      plan: item.plan,
      is_lifetime: item.is_lifetime,
      expiry_date: item.expiry_date,
      bound_hwid: item.bound_hwid
    });
  }

  // First time activation: bind device and calculate expiry accurately down to the exact second
  item.bound_hwid = cleanHwid;
  item.activated_at = now.toISOString();
  item.device_model = device_model || 'Unknown iOS Device';

  const totalHours = item.duration_hours || (item.duration_days ? item.duration_days * 24 : 0);
  if (!item.is_lifetime && totalHours > 0) {
    const expiryMs = now.getTime() + totalHours * 3600 * 1000;
    const expiry = new Date(expiryMs);
    item.expiry_date = expiry.toISOString();
  }

  saveDatabase(currentDb);

  return res.json({
    success: true,
    message: 'Device bound and activated successfully.',
    key: item.key,
    plan: item.plan,
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date,
    bound_hwid: item.bound_hwid
  });
});

// POST /api/license/verify
app.post('/api/license/verify', (req, res) => {
  const currentDb = getDatabase();
  const { key, hwid } = req.body || {};
  if (!key || !hwid) {
    return res.status(400).json({ success: false, valid: false, message: 'Key and HWID required.' });
  }

  const cleanKey = String(key).trim();
  const cleanHwid = String(hwid).trim();

  const item = currentDb.keys.find(k => k.key.toLowerCase() === cleanKey.toLowerCase());
  if (!item) {
    return res.status(404).json({ success: false, valid: false, message: 'License key has been deleted or does not exist.' });
  }

  if (item.is_banned) {
    return res.status(403).json({ success: false, valid: false, message: 'License key has been suspended by admin.' });
  }

  if (item.bound_hwid && item.bound_hwid !== cleanHwid) {
    return res.status(403).json({ success: false, valid: false, message: 'Key is bound to another device HWID.' });
  }

  if (!item.is_lifetime && item.expiry_date && Date.now() >= new Date(item.expiry_date).getTime()) {
    return res.status(403).json({ success: false, valid: false, message: 'License key has expired.' });
  }

  return res.json({
    success: true,
    valid: true,
    key: item.key,
    plan: item.plan,
    is_lifetime: item.is_lifetime,
    expiry_date: item.expiry_date
  });
});

// Accurate server time endpoint
app.get('/api/time', (req, res) => {
  const now = new Date();
  res.json({
    server_time_iso: now.toISOString(),
    server_timestamp: now.getTime(),
    server_time_wib: now.toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' }) + ' WIB'
  });
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    service: 'UDIN License Server',
    version: '2.4.0',
    developer: 'zaeruw',
    total_keys: db.keys.length,
    server_time: new Date().toISOString()
  });
});

// -------------------------------------------------------------
// ADMIN WEB PANEL ENDPOINTS
// -------------------------------------------------------------

function authMiddleware(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || authHeader !== `Bearer ${ADMIN_PASSWORD}`) {
    return res.status(401).json({ success: false, message: 'Unauthorized. Invalid Admin Password.' });
  }
  next();
}

// Admin Login
app.post('/api/admin/login', (req, res) => {
  const { password } = req.body;
  if (password === ADMIN_PASSWORD) {
    return res.json({ success: true, token: ADMIN_PASSWORD, message: 'Login successful' });
  }
  return res.status(401).json({ success: false, message: 'Incorrect Admin Password' });
});

// Get Stats & Key List
app.get('/api/admin/keys', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const enrichedKeys = currentDb.keys.map(k => ({
    ...k,
    status: evaluateKeyStatus(k)
  }));

  const stats = {
    total: enrichedKeys.length,
    active: enrichedKeys.filter(k => k.status === 'ACTIVE').length,
    unbound: enrichedKeys.filter(k => k.status === 'UNBOUND').length,
    expired: enrichedKeys.filter(k => k.status === 'EXPIRED').length,
    banned: enrichedKeys.filter(k => k.status === 'BANNED').length
  };

  res.json({
    success: true,
    server_time: new Date().toISOString(),
    stats,
    keys: enrichedKeys.reverse()
  });
});

// Create New Key
app.post('/api/admin/keys/create', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const { custom_key, duration_hours, duration_days, customer_note } = req.body || {};
  
  let keyString = custom_key ? custom_key.trim() : `UDIN-${crypto.randomBytes(3).toString('hex').toUpperCase()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
  
  if (currentDb.keys.some(k => k.key.toLowerCase() === keyString.toLowerCase())) {
    return res.status(400).json({ success: false, message: 'Key already exists. Choose another name.' });
  }

  let hours = 0;
  if (duration_hours !== undefined && duration_hours !== null && duration_hours !== '') {
    hours = parseFloat(duration_hours);
  } else if (duration_days !== undefined && duration_days !== null && duration_days !== '') {
    hours = parseFloat(duration_days) * 24;
  }

  const isLifetime = isNaN(hours) || hours <= 0;
  const planName = getPlanName(isLifetime ? 0 : hours);

  const newKey = {
    key: keyString,
    plan: planName,
    duration_hours: isLifetime ? 0 : hours,
    duration_days: isLifetime ? 0 : (hours >= 24 ? Math.round(hours / 24) : +(hours / 24).toFixed(2)),
    is_lifetime: isLifetime,
    created_at: new Date().toISOString(),
    activated_at: null,
    expiry_date: null,
    bound_hwid: null,
    device_model: null,
    customer_note: customer_note || 'Direct Purchase',
    is_banned: false
  };

  currentDb.keys.push(newKey);
  saveDatabase(currentDb);

  res.json({ success: true, message: 'Key created successfully', key: newKey });
});

// Bulk Key Generator
app.post('/api/admin/keys/bulk', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const { count, duration_hours, duration_days, prefix, customer_note } = req.body || {};
  const num = Math.min(Math.max(parseInt(count, 10) || 5, 1), 50);

  let hours = 0;
  if (duration_hours !== undefined && duration_hours !== null && duration_hours !== '') {
    hours = parseFloat(duration_hours);
  } else if (duration_days !== undefined && duration_days !== null && duration_days !== '') {
    hours = parseFloat(duration_days) * 24;
  }

  const isLifetime = isNaN(hours) || hours <= 0;
  const planName = getPlanName(isLifetime ? 0 : hours);
  const keyPrefix = (prefix || 'UDIN').trim().toUpperCase();

  const generated = [];
  for (let i = 0; i < num; i++) {
    const randomPart = `${crypto.randomBytes(3).toString('hex').toUpperCase()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
    const keyString = `${keyPrefix}-${randomPart}`;
    const newKey = {
      key: keyString,
      plan: planName,
      duration_hours: isLifetime ? 0 : hours,
      duration_days: isLifetime ? 0 : (hours >= 24 ? Math.round(hours / 24) : +(hours / 24).toFixed(2)),
      is_lifetime: isLifetime,
      created_at: new Date().toISOString(),
      activated_at: null,
      expiry_date: null,
      bound_hwid: null,
      device_model: null,
      customer_note: customer_note || `Bulk Batch (${num} keys)`,
      is_banned: false
    };
    currentDb.keys.push(newKey);
    generated.push(newKey);
  }

  saveDatabase(currentDb);
  res.json({ success: true, message: `Successfully generated ${generated.length} keys!`, keys: generated });
});

// Cleanup Expired Keys
app.post('/api/admin/keys/cleanup-expired', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const initialCount = currentDb.keys.length;
  currentDb.keys = currentDb.keys.filter(k => evaluateKeyStatus(k) !== 'EXPIRED');
  const removed = initialCount - currentDb.keys.length;
  saveDatabase(currentDb);
  res.json({ success: true, message: `Cleaned up ${removed} expired keys.` });
});

// Reset HWID
app.post('/api/admin/keys/reset-hwid', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const key = req.body?.key || req.query?.key;
  if (!key) return res.status(400).json({ success: false, message: 'Key required.' });
  const item = currentDb.keys.find(k => k.key.toLowerCase() === String(key).trim().toLowerCase());
  if (!item) return res.status(404).json({ success: false, message: 'Key not found' });

  item.bound_hwid = null;
  item.device_model = null;
  saveDatabase(currentDb);

  res.json({ success: true, message: `HWID reset for ${item.key}. User can now bind a new device.` });
});

// Toggle Ban/Unban
app.post('/api/admin/keys/toggle-ban', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const key = req.body?.key || req.query?.key;
  if (!key) return res.status(400).json({ success: false, message: 'Key required.' });
  const item = currentDb.keys.find(k => k.key.toLowerCase() === String(key).trim().toLowerCase());
  if (!item) return res.status(404).json({ success: false, message: 'Key not found' });

  item.is_banned = !item.is_banned;
  saveDatabase(currentDb);

  res.json({ success: true, message: `Key ${item.key} is now ${item.is_banned ? 'BANNED' : 'UNBANNED'}.` });
});

// Extend Duration (Supports extra_hours or extra_days)
app.post('/api/admin/keys/extend', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const key = req.body?.key || req.query?.key;
  const { extra_hours, extra_days } = req.body || {};
  if (!key) return res.status(400).json({ success: false, message: 'Key required.' });
  const item = currentDb.keys.find(k => k.key.toLowerCase() === String(key).trim().toLowerCase());
  if (!item) return res.status(404).json({ success: false, message: 'Key not found' });

  if (item.is_lifetime) {
    return res.json({ success: true, message: 'Key is already Lifetime.' });
  }

  let addMs = 0;
  if (extra_hours !== undefined && extra_hours !== null && extra_hours !== '') {
    addMs = parseFloat(extra_hours) * 3600 * 1000;
  } else if (extra_days !== undefined && extra_days !== null && extra_days !== '') {
    addMs = parseFloat(extra_days) * 24 * 3600 * 1000;
  } else {
    addMs = 24 * 3600 * 1000; // default 1 day
  }

  const currentExpiry = item.expiry_date ? new Date(item.expiry_date).getTime() : Date.now();
  const baseTime = currentExpiry > Date.now() ? currentExpiry : Date.now();
  const newExpiry = new Date(baseTime + addMs);

  item.expiry_date = newExpiry.toISOString();
  saveDatabase(currentDb);

  const newDateStr = newExpiry.toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' }) + ' WIB';
  res.json({ success: true, message: `Extended ${item.key} successfully. Expiration: ${newDateStr}` });
});

// Delete Key Handler (100% Robust for All HTTP Clients & Proxies)
function deleteKeyHandler(req, res) {
  const currentDb = getDatabase();
  const keyToDelete = req.body?.key || req.query?.key || req.params?.key;
  if (!keyToDelete) {
    return res.status(400).json({ success: false, message: 'Key identifier is required.' });
  }

  const cleanKey = String(keyToDelete).trim().toLowerCase();
  const initialLength = currentDb.keys.length;
  currentDb.keys = currentDb.keys.filter(k => k.key.toLowerCase() !== cleanKey);

  if (currentDb.keys.length === initialLength) {
    return res.status(404).json({ success: false, message: `Key "${keyToDelete}" not found.` });
  }

  saveDatabase(currentDb);

  return res.json({ success: true, message: `Key "${keyToDelete}" successfully deleted!` });
}

app.post('/api/admin/keys/delete', authMiddleware, deleteKeyHandler);
app.delete('/api/admin/keys', authMiddleware, deleteKeyHandler);
app.delete('/api/admin/keys/:key', authMiddleware, deleteKeyHandler);

// Export Database JSON Backup
app.get('/api/admin/keys/export', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', 'attachment; filename="udin_licenses_backup.json"');
  res.send(JSON.stringify(currentDb, null, 2));
});

// Import Database JSON
app.post('/api/admin/keys/import', authMiddleware, (req, res) => {
  const currentDb = getDatabase();
  const { keys } = req.body || {};
  if (!Array.isArray(keys)) {
    return res.status(400).json({ success: false, message: 'Invalid format. Expected keys array.' });
  }
  currentDb.keys = keys;
  saveDatabase(currentDb);
  res.json({ success: true, message: `Successfully imported ${keys.length} licenses!` });
});

function getIndexHtml() {
  const possiblePaths = [
    path.join(__dirname, 'public', 'index.html'),
    path.join(__dirname, 'index.html'),
    path.join(process.cwd(), 'web-admin-panel', 'public', 'index.html'),
    path.join(process.cwd(), 'public', 'index.html')
  ];
  for (const p of possiblePaths) {
    try {
      if (fs.existsSync(p)) {
        return fs.readFileSync(p, 'utf8');
      }
    } catch (e) {}
  }
  return null;
}

// Wildcard fallback to serve index.html for any frontend route
app.get('*', (req, res) => {
  const html = getIndexHtml();
  if (html) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(html);
  }
  res.status(404).send('UDIN Admin Panel UI not found.');
});

if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`===========================================`);
    console.log(`🚀 UDIN LICENSE ADMIN SERVER READY`);
    console.log(`🌐 Dashboard: http://localhost:${PORT}`);
    console.log(`🔑 Admin Password: ${ADMIN_PASSWORD}`);
    console.log(`===========================================`);
  });
}

module.exports = app;
