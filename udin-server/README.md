# 🚀 UDIN LICENSE SERVER & DASHBOARD

Ultra-modern, cloud-ready License Server & Management Dashboard to generate, manage, bind, and expire license keys for **UDIN EXTERNAL IOS**.

---

## ⚡ Quick Start (Local PC)

1. Buka folder `udin-server` di terminal / PowerShell:
   ```bash
   cd udin-server
   npm install
   npm start
   ```
2. Buka browser: `http://localhost:3000`
3. Masukkan password admin default: **`zaeruw2026`**

---

## ☁️ Deploy Gratis ke Vercel / Render / Railway

### Opsi 1: Vercel (1-Click Free Deploy)
1. Buat akun di [Vercel](https://vercel.com).
2. Import repository `udinexternalios` di Vercel Dashboard.
3. Set **Root Directory** ke `udin-server`.
4. Set environment variable (opsional): `ADMIN_PASSWORD = password_rahasia_anda`

### Opsi 2: Render.com (Gratis & Mendukung Disk Persisten)
1. Buat akun di [Render.com](https://render.com).
2. Pilih **New Web Service**, pilih repo GitHub.
3. Root Directory: `udin-server`
4. Build Command: `npm install`
5. Start Command: `npm start`

---

## 📱 Hubungkan dengan Aplikasi iOS
Di aplikasi iOS (**UDIN EXTERNAL IOS**), server URL diatur pada `LicenseManager.swift`:
```swift
static let defaultServerURL = "https://udinexternalios.vercel.app"
```
