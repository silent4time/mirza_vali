#!/usr/bin/env bash
# mirza_vali — one-line installer (zip-based)
# Usage (from ANY directory):
#   curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
#
# On GitHub, upload ONE file in the repo root:
#   mirza_vali-latest.zip
# (full project zip: manage.sh + patch/ + VERSION + ...)
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/silent4time/mirza_vali/main"
REPO_ZIP_RAW="${REPO_RAW}/mirza_vali-latest.zip"
REPO_ZIP_GITHUB="https://github.com/silent4time/mirza_vali/raw/main/mirza_vali-latest.zip"
SRC_DIR="/opt/mirza_vali-src"
WORK="/tmp/mirza_vali_install_$$"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root:"
  echo "  curl -fsSL ${REPO_RAW}/install.sh | sudo bash"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
command -v curl >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y curl >/dev/null 2>&1; }
command -v unzip >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y unzip >/dev/null 2>&1; }

echo "[*] Downloading mirza_vali-latest.zip from GitHub..."
mkdir -p "$WORK"
ZIP_FILE="$WORK/mirza_vali-latest.zip"

# Try github.com/raw first, then raw.githubusercontent.com
if ! curl -fsSL --connect-timeout 15 --max-time 180 --retry 2 -o "$ZIP_FILE" "$REPO_ZIP_GITHUB"; then
  echo "[*] Retry with raw.githubusercontent.com ..."
  if ! curl -fsSL --connect-timeout 15 --max-time 180 --retry 2 -o "$ZIP_FILE" "$REPO_ZIP_RAW"; then
    echo "[x] ERROR: Could not download mirza_vali-latest.zip"
    echo "    Upload this file to the root of your GitHub repo:"
    echo "    https://github.com/silent4time/mirza_vali"
    echo "    File name must be exactly: mirza_vali-latest.zip"
    rm -rf "$WORK"
    exit 1
  fi
fi

# Basic check: zip magic / size
if [[ ! -s "$ZIP_FILE" ]]; then
  echo "[x] Downloaded file is empty."
  rm -rf "$WORK"
  exit 1
fi
if ! unzip -t "$ZIP_FILE" >/dev/null 2>&1; then
  echo "[x] Downloaded file is not a valid zip (maybe HTML error page)."
  echo "    Make sure mirza_vali-latest.zip is uploaded to the repo root."
  rm -rf "$WORK"
  exit 1
fi

echo "[*] Extracting..."
mkdir -p "$WORK/out"
unzip -qo "$ZIP_FILE" -d "$WORK/out"

# Find folder that contains manage.sh + patch/
FOUND=""
if [[ -f "$WORK/out/manage.sh" && -d "$WORK/out/patch" ]]; then
  FOUND="$WORK/out"
else
  FOUND="$(find "$WORK/out" -type f -name manage.sh 2>/dev/null | head -1 || true)"
  if [[ -n "$FOUND" ]]; then
    FOUND="$(dirname "$FOUND")"
  fi
fi

if [[ -z "$FOUND" || ! -f "$FOUND/manage.sh" ]]; then
  echo "[x] manage.sh not found inside the zip."
  rm -rf "$WORK"
  exit 1
fi
if [[ ! -d "$FOUND/patch" || ! -f "$FOUND/patch/botapi.php" ]]; then
  echo "[x] patch/ folder missing inside the zip."
  echo "    Zip must contain: manage.sh and patch/botapi.php ..."
  rm -rf "$WORK"
  exit 1
fi

echo "[*] Installing source to $SRC_DIR ..."
rm -rf "$SRC_DIR"
mkdir -p /opt
mkdir -p "$SRC_DIR"
# copy tree (handles both flat and nested zip layouts)
cp -a "$FOUND"/. "$SRC_DIR/"
chmod +x "$SRC_DIR/manage.sh" "$SRC_DIR/install.sh" 2>/dev/null || true
rm -rf "$WORK"

echo "[*] Source OK — patch/ found"
echo "[*] Entering $SRC_DIR and starting management panel..."
echo "    Press 1 to Install"
cd "$SRC_DIR"
if [[ -e /dev/tty ]]; then
  exec bash ./manage.sh "$@" < /dev/tty
else
  exec bash ./manage.sh "$@"
fi
