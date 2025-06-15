# Synology Scripts Collection 📦

A set of shell scripts designed to automate common tasks on Synology NAS systems via SSH.

## 📁 Modules

- `media/` — Scripts for media (photos and videos) timestamp correction, metadata fixes, and organization
- `system/` — System maintenance tools (auto-shutdown, cleanup)
- `network/` — Scripts for DDNS, firewall rule automation
- `utils/` — Utility tools (e.g., exiftool installer)

## ✅ Requirements

- Synology DSM 6.x / 7.x
- SSH access enabled
- bash, coreutils, optionally `exiftool` (for media processing)
- optionally `ffmpeg` (for video processing and tests)

## 🛠 How to Use

1. Enable SSH in DSM.
2. Upload scripts or `git clone` the repo.
3. Run with proper permissions:
   ```bash
   bash media/fix_media_timestamp.sh /path/to/media
   bash media/move_media_by_date.sh /path/to/media /destination/folder
   ```

## ⚠️ Disclaimer

Use at your own risk. Scripts may modify files. Always back up before running.
