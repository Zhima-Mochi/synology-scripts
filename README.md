# Synology Scripts Collection 📦

A set of shell scripts designed to automate common tasks on Synology NAS systems via SSH.

## 📁 Modules

- `photos/` — Scripts for photo timestamp correction, EXIF fixes, renaming
- `system/` — System maintenance tools (auto-shutdown, cleanup)
- `network/` — Scripts for DDNS, firewall rule automation
- `utils/` — Utility tools (e.g., exiftool installer)

## ✅ Requirements

- Synology DSM 6.x / 7.x
- SSH access enabled
- bash, coreutils, optionally `exiftool`

## 🛠 How to Use

1. Enable SSH in DSM.
2. Upload scripts or `git clone` the repo.
3. Run with proper permissions:
   ```bash
   bash photos/fix_photo_timestamp.sh
   ```

## ⚠️ Disclaimer

Use at your own risk. Scripts may modify files. Always back up before running.
