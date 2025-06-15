#!/bin/sh

# Target install directory (adjust if needed)
INSTALL_DIR="/volume1/@tools/exiftool"
EXIFTOOL_URL="https://exiftool.org/Image-ExifTool-13.30.tar.gz"
TMP_DIR="/tmp/exiftool_install"

# Create temp working dir
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1

echo "[*] Downloading ExifTool..."
wget "$EXIFTOOL_URL" -O Image-ExifTool.tar.gz || {
  echo "[!] Download failed"
  exit 1
}

echo "[*] Extracting..."
tar -xzf Image-ExifTool.tar.gz || {
  echo "[!] Extraction failed"
  exit 1
}

cd Image-ExifTool-* || exit 1

echo "[*] Preparing install directory..."
mkdir -p "$INSTALL_DIR"
cp -a exiftool "$INSTALL_DIR/"
cp -a lib "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/exiftool"

echo "[*] Adding to PATH (current session)..."
export PATH="$PATH:$INSTALL_DIR"

# Add to profile if not already there
PROFILE="$HOME/.profile"
if ! grep -q "$INSTALL_DIR" "$PROFILE"; then
  echo "export PATH=\$PATH:$INSTALL_DIR" >> "$PROFILE"
  echo "[*] PATH added to $PROFILE"
fi

echo "[✔] Install complete."
echo "[i] Run 'exiftool -ver' to verify."
echo "[i] You may need to relogin or run 'source $PROFILE' for PATH to take effect."

# Cleanup
rm -rf "$TMP_DIR"
