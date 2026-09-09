# 🚀 UDIN LICENSE WEB ADMIN PANEL

Ultra-modern, cloud-ready Web Admin Dashboard & REST API server to generate, manage, bind, and expire license keys for **UDIN EXTERNAL IOS**.

---

## ⚡ Quick Start (Local PC)

1. Buka folder `web-admin-panel` di terminal / PowerShell:
   ```bash
   cd web-admin-panel
   npm install
   npm start
   ```
2. Buka browser: `http://localhost:3000`
3. Masukkan password admin default: **`zaeruw2026`**

---

## ☁️ Deploy Gratis ke Vercel / Render / Railway

### Opsi 1: Vercel (1-Click Free Deploy)
1. Buat akun di [Vercel](https://vercel.com).
2. Upload folder `web-admin-panel` ke GitHub atau deploy via Vercel CLI:
   ```bash
   npm i -g vercel
   vercel
   ```
3. Set environment variable: `ADMIN_PASSWORD = password_rahasia_anda`

### Opsi 2: Render.com (Gratis & Mendukung Disk Persisten)
1. Buat akun di [Render.com](https://render.com).
2. Pilih **New Web Service**, pilih repo GitHub.
3. Build Command: `npm install`
4. Start Command: `npm start`

---

## 📱 Hubungkan dengan Aplikasi iOS
Di aplikasi iOS (**UDIN EXTERNAL IOS**), server URL diatur pada `LicenseManager.swift`:
```swift
static let defaultServerURL = "https://your-panel.vercel.app"
```
