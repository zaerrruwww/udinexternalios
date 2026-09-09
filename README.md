# 🚀 UDIN EXTERNAL IOS

Project iOS External & Web License Management System untuk **UDIN EXTERNAL IOS**.

---

## 📁 Struktur Repositori

- `ThreeOneOSFive/`
  - `views/`: Komponen antarmuka SwiftUI, Cyber Stealth Design System, dan panel kontrol patch.
  - `helpers/`: Modul internal (LicenseManager, DevicePatchService, Exploit helper, CleanerCatalog, dll).
  - `Assets.xcassets/`: Asset ikon, logo UDIN, dan konfigurasi grafis.
  - `Patches/`: Modul patch binary bawaan.
  - `exploit/` & `kexploit/`: Komponen bypass kernel & sandbox escape.
- `UdinExternalIOS.xcodeproj/`: Konfigurasi proyek Xcode.
- `udin-server/`: License Server & Management Dashboard REST API backend berbasis Express.js & Tailwind CSS.
- `.github/workflows/`: GitHub Actions CI/CD workflow untuk otomatisasi build IPA unsigned & eSign-ready.
- `build_unsigned.sh`: Script kompilasi IPA unsigned di macOS/CI.
- `build_esign_ready_ipa.sh`: Verifikator bundle IPA untuk kemudahan signing via eSign / Scarlet / TrollStore.

---

## 🔑 Sistem Lisensi (License Server)

Aplikasi iOS terhubung langsung dengan backend **License Server**:
- Default Server URL: `https://udinexternalios.vercel.app` (dapat dikonfigurasi melalui Settings atau `LicenseManager.swift`).
- Format lisensi default: `UDIN-XXXX-XXXX`
- Dukungan Hardware ID (HWID) binding per perangkat, masa berlaku (Hourly/Daily/Lifetime), dan sistem remote revoke/ban.

---

## 🛠️ Cara Build IPA

### 1. Menggunakan GitHub Actions (Otomatis)
1. Push repository ke GitHub.
2. Buka tab **Actions** → pilih **Build UDIN EXTERNAL IOS IPA** → klik **Run workflow**.
3. Unduh file `UDIN-EXTERNAL-IOS-unsigned-ipa` yang dihasilkan pada bagian Artifacts.

### 2. Build Lokal di macOS (Xcode)
```bash
chmod +x ./build_unsigned.sh ./build_esign_ready_ipa.sh
./build_unsigned.sh
./build_esign_ready_ipa.sh build/UDIN-EXTERNAL-IOS-unsigned.ipa
```

---

## 🌐 Menjalankan License Server

```bash
cd udin-server
npm install
npm start
```
Buka browser pada `http://localhost:3000` dan login dengan password admin default: `zaeruw2026`.

