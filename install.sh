#!/usr/bin/env bash
# mirza_vali — one-line installer (interactive menu)
# Usage (from ANY directory):
#   curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
set -euo pipefail

REPO="https://github.com/silent4time/mirza_vali.git"
BRANCH="main"
SRC_DIR="/opt/mirza_vali-src"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root:"
  echo "  curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
command -v git >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y git curl >/dev/null 2>&1; }
command -v curl >/dev/null 2>&1 || apt-get install -y curl >/dev/null 2>&1

echo "[*] Fetching latest mirza_vali from GitHub..."
# Clone to a temp dir first, then replace — avoids deleting a live directory
TMP_CLONE="$(mktemp -d)/mirza_vali"
git clone --depth 1 --branch "$BRANCH" "$REPO" "$TMP_CLONE"

if [[ ! -d "$TMP_CLONE/patch" ]] || [[ ! -f "$TMP_CLONE/patch/botapi.php" ]]; then
  echo "[x] ERROR: GitHub repo is incomplete — folder 'patch/' is missing."
  echo "    Open https://github.com/silent4time/mirza_vali"
  echo "    Upload the full 'patch' folder (botapi.php, index.php, function.php, admin.php, keyboard.php, table.php, config.template.php)"
  echo "    Then run this command again."
  rm -rf "$(dirname "$TMP_CLONE")"
  exit 1
fi

rm -rf "$SRC_DIR"
mkdir -p /opt
mv "$TMP_CLONE" "$SRC_DIR"
chmod +x "$SRC_DIR/manage.sh" "$SRC_DIR/install.sh" 2>/dev/null || true

echo "[*] Source OK — patch/ found"
echo "[*] Entering $SRC_DIR and starting management panel..."
echo "    Press 1 to Install"
cd "$SRC_DIR"
if [[ -e /dev/tty ]]; then
  exec bash ./manage.sh "$@" < /dev/tty
else
  exec bash ./manage.sh "$@"
fi
