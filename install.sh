#!/usr/bin/env bash
# mirza_vali — one-line installer (interactive menu works)
# Usage (from ANY directory):
#   curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
#
# What this does:
#   1) Downloads latest manage.sh to /tmp
#   2) Clones/refreshes project into /opt/mirza_vali-src
#   3) Enters that folder and starts the management menu (Install = press 1)
set -euo pipefail

REPO="https://github.com/silent4time/mirza_vali.git"
BRANCH="main"
SRC_DIR="/opt/mirza_vali-src"
MANAGE_TMP="/tmp/mirza_vali-manage.sh"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root:"
  echo "  curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
command -v git >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y git curl >/dev/null 2>&1; }
command -v curl >/dev/null 2>&1 || apt-get install -y curl >/dev/null 2>&1

echo "[*] Fetching latest mirza_vali from GitHub..."
rm -rf "$SRC_DIR"
mkdir -p /opt
git clone --depth 1 --branch "$BRANCH" "$REPO" "$SRC_DIR"
chmod +x "$SRC_DIR/manage.sh"

echo "[*] Entering $SRC_DIR and starting management panel..."
echo "    Press 1 to Install"
cd "$SRC_DIR"
# Force stdin from the real terminal so menu keys work even if this
# script itself was started via "curl | bash"
if [[ -e /dev/tty ]]; then
  exec bash ./manage.sh "$@" < /dev/tty
else
  exec bash ./manage.sh "$@"
fi
