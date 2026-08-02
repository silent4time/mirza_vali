#!/usr/bin/env bash
# mirza_vali — نصب یک‌خطی (از هر مسیر)
# استفاده:
#   curl -sL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
set -euo pipefail
REPO_RAW="https://raw.githubusercontent.com/silent4time/mirza_vali/main/manage.sh"
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "با sudo اجرا کنید: curl -sL $REPO_RAW | sudo bash"
  exit 1
fi
exec bash -c "$(curl -fsSL "$REPO_RAW")"
