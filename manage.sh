#!/usr/bin/env bash
# ============================================================================
#  mirza_vali — پنل مدیریت نصب
#  نسخه: با فایل VERSION هم‌خوان است
#
#  اجرا:
#    sudo bash manage.sh
#
#  One-line install (from any directory, interactive menu works):
#    curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
#  Or:
#    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh)"
# ============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
#  تنظیمات — این آدرس را بعد از ساخت ریپوی گیت‌هاب خودتان عوض کنید
# ---------------------------------------------------------------------------
GITHUB_REPO="${GITHUB_REPO:-https://github.com/silent4time/mirza_vali.git}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
PROJECT_NAME="mirza_vali"
DEFAULT_INSTALL_DIR="/var/www/${PROJECT_NAME}"
STATE_DIR="/etc/${PROJECT_NAME}"
STATE_FILE="${STATE_DIR}/install.env"
SERVICE_NAME="${PROJECT_NAME}-tunnel"
NGINX_SITE="${PROJECT_NAME}"
# مسیر پیش‌فرض قرار دادن zip روی سرور (شما zip را اینجا می‌گذارید)
ZIP_DROP_DIR="${ZIP_DROP_DIR:-/home}"

# رنگ‌ها
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---------------------------------------------------------------------------
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${CYAN}[i]${NC} $*"; }

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "This script must be run as root:"
    echo "  sudo bash $0"
    exit 1
  fi
}

version_of() {
  local dir="${1:-.}"
  if [[ -f "${dir}/VERSION" ]]; then
    cat "${dir}/VERSION" | tr -d '[:space:]'
  else
    echo "unknown"
  fi
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

save_state() {
  mkdir -p "$STATE_DIR"
  cat > "$STATE_FILE" <<EOF
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
DB_NAME="${DB_NAME:-mirza_vali}"
DB_USER="${DB_USER:-mirzavali}"
DB_PASS="${DB_PASS:-}"
ENABLE_TELEGRAM="${ENABLE_TELEGRAM:-true}"
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_USERNAME="${TELEGRAM_USERNAME:-}"
ADMIN_ID="${ADMIN_ID:-}"
ENABLE_BALE="${ENABLE_BALE:-true}"
BALE_TOKEN="${BALE_TOKEN:-}"
BALE_ADMIN_ID="${BALE_ADMIN_ID:-}"
BALE_REPORT_GROUP_ID="${BALE_REPORT_GROUP_ID:-}"
BALE_PROVIDER_TOKEN="${BALE_PROVIDER_TOKEN:-}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"
DOMAIN="${DOMAIN:-}"
DOMAIN_MODE="${DOMAIN_MODE:-2}"
GITHUB_REPO="${GITHUB_REPO}"
INSTALLED_VERSION="$(version_of "${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}" 2>/dev/null || echo unknown)"
INSTALLED_AT="$(date -Is)"
EOF
  chmod 600 "$STATE_FILE"
  ok "Install state saved: $STATE_FILE"
}

pause() {
  echo ""
  read -rp "Press Enter to return to menu... " _
}

ask() {
  local prompt="$1" default="${2:-}" var
  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " var
    echo "${var:-$default}"
  else
    read -rp "$prompt: " var
    echo "$var"
  fi
}

ask_yn() {
  local prompt="$1" default="${2:-y}" var
  read -rp "$prompt [y/n] (default: $default): " var
  var="${var:-$default}"
  [[ "$var" =~ ^[YyیY] ]] && echo "true" || echo "false"
}

# مسیر خود اسکریپت / ریپوی محلی (اگر از داخل کلون اجرا شود)
# اگر با curl | bash اجرا شود، BASH_SOURCE ممکن است /dev/fd/... باشد → از گیت‌هاب کلون می‌کنیم
_bootstrap_source() {
  local candidate=""
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"
  fi
  if [[ -n "$candidate" && -d "${candidate}/patch" && -f "${candidate}/patch/botapi.php" ]]; then
    SCRIPT_DIR="$candidate"
    HAS_LOCAL_PATCH="true"
    cd "$SCRIPT_DIR" || true
    return 0
  fi

  # No local patch tree: clone latest from GitHub into a fixed folder
  HAS_LOCAL_PATCH="false"
  local cache="/opt/${PROJECT_NAME}-src"
  info "Downloading latest version from GitHub..."
  command -v git >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y git >/dev/null 2>&1; }
  rm -rf "$cache"
  mkdir -p /opt
  if git clone --depth 1 --branch "$GITHUB_BRANCH" "$GITHUB_REPO" "$cache" 2>/dev/null; then
    SCRIPT_DIR="$cache"
    if [[ -d "${cache}/patch" ]]; then
      HAS_LOCAL_PATCH="true"
    fi
    ok "Source ready: $cache"
    cd "$SCRIPT_DIR" || true
  else
    err "GitHub clone failed: $GITHUB_REPO"
    err "Make sure the repo is public or you have access."
    exit 1
  fi
}

# If this process was started via "curl | bash", stdin is the script pipe
# and the menu cannot read key presses. Re-exec from a real file on a TTY.
_reexec_if_piped() {
  # Already marked as re-exec'd
  if [[ "${MIRZA_REEXEC:-}" == "1" ]]; then
    return 0
  fi
  # stdin is a terminal? OK
  if [[ -t 0 ]]; then
    return 0
  fi
  # Prefer the cloned/local manage.sh on disk
  local target="${SCRIPT_DIR}/manage.sh"
  if [[ ! -f "$target" ]]; then
    target="/opt/${PROJECT_NAME}-src/manage.sh"
  fi
  if [[ ! -f "$target" ]]; then
    # Last resort: save ourselves to /tmp
    target="/tmp/${PROJECT_NAME}-manage.sh"
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
      cp -f "${BASH_SOURCE[0]}" "$target"
    else
      curl -fsSL "https://raw.githubusercontent.com/silent4time/mirza_vali/main/manage.sh" -o "$target" || true
    fi
  fi
  if [[ -f "$target" ]]; then
    chmod +x "$target"
    info "Switching to interactive mode (menu input enabled)..."
    cd "$(dirname "$target")" 2>/dev/null || true
    export MIRZA_REEXEC=1
    exec sudo -E env MIRZA_REEXEC=1 bash "$target" "$@"
  fi
}

SCRIPT_DIR=""
HAS_LOCAL_PATCH="false"

# ===========================================================================
#  منوی اصلی
# ===========================================================================
show_banner() {
  clear
  local ver
  ver="$(version_of "$SCRIPT_DIR")"
  echo -e "${BOLD}${CYAN}"
  cat << EOF
+==========================================================+
|                                                          |
|              mirza_vali  -  Management Panel             |
|                   Telegram  +  Bale                      |
|                                                          |
+==========================================================+
EOF
  echo -e "${NC}"
  echo -e "  Version : ${BOLD}v${ver}${NC}"
  if [[ -f "$STATE_FILE" ]]; then
    load_state
    echo -e "  Status  : ${GREEN}Installed${NC}  ->  ${INSTALL_DIR:-?}  (v${INSTALLED_VERSION:-?})"
  else
    echo -e "  Status  : ${YELLOW}Not installed${NC}"
  fi
  echo ""
}

show_menu() {
  echo -e "${BOLD}  Main Menu:${NC}"
  echo "  -------------------------------------"
  echo "   1)  Install"
  echo "   2)  Update"
  echo "   3)  Reset (webhooks / tunnel / user steps)"
  echo "   4)  Remove (full uninstall)"
  echo "   5)  Status"
  echo "   0)  Exit"
  echo "  -------------------------------------"
  echo ""
}

# ===========================================================================
#  ۱) نصب
# ===========================================================================
do_install() {
  echo ""
  echo -e "${BOLD}=== Install mirza_vali ===${NC}"
  echo ""

  if [[ -f "$STATE_FILE" ]]; then
    warn "An existing installation was found."
    local cont
    cont="$(ask_yn 'Continue and overwrite/install again?' 'n')"
    [[ "$cont" != "true" ]] && return 0
  fi

  INSTALL_DIR="$(ask 'Install path' "$DEFAULT_INSTALL_DIR")"
  if [[ "$(basename "$INSTALL_DIR")" != "$PROJECT_NAME" ]]; then
    INSTALL_DIR="${INSTALL_DIR%/}/$PROJECT_NAME"
    info "Install path set to: $INSTALL_DIR"
  fi

  DB_NAME="$(ask 'Database name' 'mirza_vali')"
  DB_USER="$(ask 'Database user' 'mirzavali')"
  if [[ -z "${DB_PASS:-}" ]]; then
    DB_PASS="$(openssl rand -hex 12)"
    ok "Database password generated: $DB_PASS  (save it!)"
  else
    DB_PASS="$(ask 'Database password' "$DB_PASS")"
  fi

  ENABLE_TELEGRAM="$(ask_yn 'Enable Telegram bot?' 'y')"
  if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
    TELEGRAM_TOKEN="$(ask 'Telegram bot token (BotFather)')"
    TELEGRAM_USERNAME="$(ask 'Telegram bot username (without @)')"
    ADMIN_ID="$(ask 'Admin numeric ID (Telegram)')"
  else
    TELEGRAM_TOKEN="disabled"
    TELEGRAM_USERNAME="disabled"
    ADMIN_ID="$(ask 'Admin numeric ID (panel access)')"
  fi

  ENABLE_BALE="$(ask_yn 'Enable Bale bot?' 'y')"
  if [[ "$ENABLE_BALE" == "true" ]]; then
    BALE_TOKEN="$(ask 'Bale bot token (my.bale.ai)')"
    BALE_ADMIN_ID="$(ask 'Bale admin numeric ID (optional)' '')"
    BALE_REPORT_GROUP_ID="$(ask 'Bale report group ID (optional)' '')"
    BALE_PROVIDER_TOKEN="$(ask 'Bale Pay provider token (optional)' '')"
  else
    BALE_TOKEN="disabled"
    BALE_ADMIN_ID=""
    BALE_REPORT_GROUP_ID=""
    BALE_PROVIDER_TOKEN=""
  fi

  WEBHOOK_SECRET="$(openssl rand -hex 16)"

  echo ""
  echo "Internet access:"
  echo "  1) My own domain + SSL"
  echo "  2) Temporary Cloudflare tunnel (testing)"
  DOMAIN_MODE="$(ask 'Choose (1 or 2)' '2')"
  DOMAIN=""
  if [[ "$DOMAIN_MODE" == "1" ]]; then
    DOMAIN="$(ask 'Domain (without https://)')"
  fi

  echo ""
  info "Starting installation..."

  # --- پکیج‌ها ---
  info "Installing packages (nginx, mariadb, php)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || warn "apt-get update had an error, continuing..."
  apt-get install -y nginx mariadb-server php php-fpm php-mysql php-curl \
    php-mbstring php-gd php-xml php-zip unzip git curl openssl >/dev/null
  if ! command -v composer >/dev/null 2>&1; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >/dev/null 2>&1 || true
  fi
  ok "Packages installed."

  PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
  if [[ -z "$PHP_VERSION" ]]; then
    PHP_VERSION="$(ls /etc/php/ 2>/dev/null | sort -V | tail -1)"
  fi
  PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
  systemctl enable --now mariadb >/dev/null 2>&1 || true
  systemctl enable --now "php${PHP_VERSION}-fpm" >/dev/null 2>&1 || true

  # --- دیتابیس ---
  info "Creating database..."
  mysql -uroot -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -uroot -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null || true
  mysql -uroot -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
  ok "Database ready."

  # --- سورس پایه میرزا ---
  if [[ -d "$INSTALL_DIR" ]]; then
    warn "Existing folder found — creating backup..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}-backup-$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$(dirname "$INSTALL_DIR")"
  info "Downloading base mirzabot source from GitHub..."
  git clone --quiet https://github.com/mahdiMGF2/mirzabot.git "$INSTALL_DIR"
  PATCH_BASE_COMMIT="fcd9afeb0e80b67db21cc21611dc91a07c0feee0"
  (cd "$INSTALL_DIR" && git checkout --quiet "$PATCH_BASE_COMMIT") || warn "Could not checkout pinned commit"
  ok "Base source ready."

  if [[ -f "$INSTALL_DIR/composer.json" && ! -d "$INSTALL_DIR/vendor" ]]; then
    info "Installing Composer dependencies..."
    (cd "$INSTALL_DIR" && composer install --no-dev --no-interaction --optimize-autoloader) || warn "composer install failed"
  fi

  # --- اعمال پچ ---
  info "Applying mirza_vali patch..."
  apply_patch_files "$INSTALL_DIR"
  write_config "$INSTALL_DIR"
  echo "$(version_of "$SCRIPT_DIR")" > "$INSTALL_DIR/VERSION"
  echo "$PROJECT_NAME" > "$INSTALL_DIR/PROJECT_NAME"
  ok "Patch applied."

  # --- جداول ---
  info "Building database tables..."
  (cd "$INSTALL_DIR" && php table.php) || true
  if [[ -n "${BALE_PROVIDER_TOKEN:-}" && "$BALE_PROVIDER_TOKEN" != "0" ]]; then
    mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e \
      "UPDATE PaySetting SET ValuePay='${BALE_PROVIDER_TOKEN}' WHERE NamePay='merchant_balepay';" 2>/dev/null || true
    mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e \
      "UPDATE PaySetting SET ValuePay='onbalepay' WHERE NamePay='balepaystatus';" 2>/dev/null || true
    ok "Bale Pay token saved and enabled in database."
  fi
  chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || chown -R nginx:nginx "$INSTALL_DIR" 2>/dev/null || true

  # --- Nginx ---
  info "Configuring Nginx..."
  cat > "/etc/nginx/sites-available/${NGINX_SITE}" <<EOF
server {
    listen 80;
    server_name _;
    root ${INSTALL_DIR};
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_SOCK};
    }

    location ~ /\.ht { deny all; }
}
EOF
  ln -sf "/etc/nginx/sites-available/${NGINX_SITE}" "/etc/nginx/sites-enabled/${NGINX_SITE}"
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
  ok "Nginx ready."

  # --- دامنه / تونل ---
  setup_connectivity

  # --- وبهوک ---
  register_webhooks

  save_state
  echo ""
  ok "Install complete — $PROJECT_NAME v$(version_of "$INSTALL_DIR")"
  echo "  Path:   $INSTALL_DIR"
  echo "  URL:    https://${DOMAIN:-YOUR_DOMAIN}"
  echo "  DB:     $DB_NAME / $DB_USER / $DB_PASS"
  echo ""
}

# کپی فایل‌های پچ از ریپوی محلی یا دانلود از گیت‌هاب
apply_patch_files() {
  local target="$1"
  local src_patch=""

  if [[ "$HAS_LOCAL_PATCH" == "true" ]]; then
    src_patch="${SCRIPT_DIR}/patch"
  fi

  # اگر پچ محلی نبود، zip داخل /home را امتحان کن
  if [[ -z "$src_patch" || ! -d "$src_patch" ]]; then
    local latest_zip=""
    if [[ -d "${ZIP_DROP_DIR:-/home}" ]]; then
      latest_zip="$(ls -1t ${ZIP_DROP_DIR:-/home}/mirza_vali*.zip 2>/dev/null | head -1 || true)"
    fi
    if [[ -n "$latest_zip" && -f "$latest_zip" ]]; then
      info "Using local zip for patch: $latest_zip"
      local ztmp
      ztmp="$(mktemp -d)"
      command -v unzip >/dev/null 2>&1 || apt-get install -y unzip >/dev/null 2>&1 || true
      unzip -qo "$latest_zip" -d "$ztmp"
      if [[ -d "$ztmp/patch" ]]; then
        src_patch="$ztmp/patch"
      else
        src_patch="$(find "$ztmp" -type d -name patch 2>/dev/null | head -1 || true)"
      fi
      # نگه داشتن ztmp تا پایان کپی — با trap پاک نمی‌کنیم چون ساده است
      export _MIRZA_ZIP_TMP="$ztmp"
    fi
  fi

  if [[ -z "$src_patch" || ! -d "$src_patch" ]]; then
    info "Downloading patch files from GitHub..."
    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 --branch "$GITHUB_BRANCH" "$GITHUB_REPO" "$tmp/repo" 2>/dev/null; then
      src_patch="$tmp/repo/patch"
      export _MIRZA_ZIP_TMP="$tmp"
    else
      err "Could not clone from GitHub: $GITHUB_REPO"
      err "Place a zip in /home or fix the repo URL."
      exit 1
    fi
  fi

  for f in botapi.php function.php index.php admin.php keyboard.php table.php; do
    if [[ -f "${src_patch}/${f}" ]]; then
      cp -f "${src_patch}/${f}" "${target}/${f}"
    else
      warn "Patch file missing: $f"
    fi
  done
}


write_config() {
  local target="$1"
  local tpl="${SCRIPT_DIR}/patch/config.template.php"
  if [[ ! -f "$tpl" ]]; then
    # از گیت‌هاب یا از خود target بعد از پچ
    if [[ -f "${target}/../patch/config.template.php" ]]; then
      tpl="${target}/../patch/config.template.php"
    elif [[ -f "${SCRIPT_DIR}/patch/config.template.php" ]]; then
      tpl="${SCRIPT_DIR}/patch/config.template.php"
    else
      # اگر فقط در temp کلون شده
      tpl="$(find /tmp -name 'config.template.php' 2>/dev/null | head -1 || true)"
    fi
  fi
  # آخرین تلاش: از داخل ریپوی موقت که apply ممکن است ساخته باشد
  if [[ ! -f "$tpl" ]]; then
    cat > "${target}/config.php" <<CFGEOF
<?php
\$request_exec_timeout = null;
\$dbhost = '127.0.0.1';
\$dbname = '${DB_NAME}';
\$usernamedb = '${DB_USER}';
\$passworddb = '${DB_PASS}';
\$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES => false,
    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
];
\$dsn = "mysql:host=\$dbhost;dbname=\$dbname;charset=utf8mb4";
try {
    \$pdo = new PDO(\$dsn, \$usernamedb, \$passworddb, \$options);
} catch (\\PDOException \$e) {
    error_log("Database connection failed: " . \$e->getMessage());
    die("error: database connection failed");
}
\$APIKEY = '${TELEGRAM_TOKEN}';
\$adminnumber = '${ADMIN_ID}';
\$domainhosts = '${DOMAIN:-PENDING}';
\$usernamebot = '${TELEGRAM_USERNAME}';
\$ENABLE_TELEGRAM = ${ENABLE_TELEGRAM};
\$ENABLE_BALE     = ${ENABLE_BALE};
\$TELEGRAM_APIKEY = \$APIKEY;
\$BALE_APIKEY = '${BALE_TOKEN}';
\$BALE_ADMIN_ID = '${BALE_ADMIN_ID}';
\$BALE_REPORT_GROUP_ID = '${BALE_REPORT_GROUP_ID}';
\$BALE_PROVIDER_TOKEN = '${BALE_PROVIDER_TOKEN}';
\$TELEGRAM_API_BASE = 'https://api.telegram.org/bot';
\$BALE_API_BASE     = 'https://tapi.bale.ai/bot';
\$WEBHOOK_SECRET_TOKEN = '${WEBHOOK_SECRET}';
if (!defined('BALE_ID_OFFSET')) {
    define('BALE_ID_OFFSET', 9000000000000);
}
CFGEOF
    return
  fi

  sed \
    -e "s|{{DB_HOST}}|127.0.0.1|g" \
    -e "s|{{DB_NAME}}|${DB_NAME}|g" \
    -e "s|{{DB_USER}}|${DB_USER}|g" \
    -e "s|{{DB_PASS}}|${DB_PASS}|g" \
    -e "s|{{TELEGRAM_TOKEN}}|${TELEGRAM_TOKEN}|g" \
    -e "s|{{ADMIN_ID}}|${ADMIN_ID}|g" \
    -e "s|{{TELEGRAM_USERNAME}}|${TELEGRAM_USERNAME}|g" \
    -e "s|{{ENABLE_TELEGRAM}}|${ENABLE_TELEGRAM}|g" \
    -e "s|{{ENABLE_BALE}}|${ENABLE_BALE}|g" \
    -e "s|{{BALE_TOKEN}}|${BALE_TOKEN}|g" \
    -e "s|{{BALE_ADMIN_ID}}|${BALE_ADMIN_ID:-}|g" \
    -e "s|{{BALE_REPORT_GROUP_ID}}|${BALE_REPORT_GROUP_ID:-}|g" \
    -e "s|{{BALE_PROVIDER_TOKEN}}|${BALE_PROVIDER_TOKEN:-}|g" \
    -e "s|{{WEBHOOK_SECRET}}|${WEBHOOK_SECRET}|g" \
    -e "s|{{DOMAIN}}|${DOMAIN:-PENDING}|g" \
    "$tpl" > "${target}/config.php"
}

setup_connectivity() {
  if [[ "$DOMAIN_MODE" == "2" ]]; then
    info "Setting up Cloudflare tunnel..."
    if ! command -v cloudflared >/dev/null 2>&1; then
      curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
        -o /usr/local/bin/cloudflared
      chmod +x /usr/local/bin/cloudflared
    fi
    mkdir -p "$STATE_DIR"
    cat > "${STATE_DIR}/tunnel.env" <<ENVEOF
INSTALL_DIR="${INSTALL_DIR}"
ENABLE_TELEGRAM="${ENABLE_TELEGRAM}"
TELEGRAM_TOKEN="${TELEGRAM_TOKEN}"
ENABLE_BALE="${ENABLE_BALE}"
BALE_TOKEN="${BALE_TOKEN}"
WEBHOOK_SECRET="${WEBHOOK_SECRET}"
ENVEOF
    chmod 600 "${STATE_DIR}/tunnel.env"

    cat > "/usr/local/bin/${PROJECT_NAME}-tunnel-refresh.sh" <<'REFRESHEOF'
#!/usr/bin/env bash
set -uo pipefail
source /etc/mirza_vali/tunnel.env
LOGFILE="/var/log/mirza_vali-cloudflared.log"
: > "$LOGFILE"
cloudflared tunnel --url http://localhost:80 >> "$LOGFILE" 2>&1 &
CF_PID=$!
DOMAIN=""
for i in $(seq 1 30); do
  DOMAIN="$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOGFILE" | head -1 | sed 's|https://||')"
  [[ -n "$DOMAIN" ]] && break
  sleep 1
done
if [[ -n "$DOMAIN" ]]; then
  echo "$(date -Is) New tunnel URL: https://$DOMAIN" >> "$LOGFILE"
  sed -i "s|\$domainhosts = '.*';|\$domainhosts = '${DOMAIN}';|" "${INSTALL_DIR}/config.php" || true
  sleep 8
  register_webhook() {
    local url="$1" label="$2"
    local attempt result
    for attempt in 1 2 3 4 5; do
      result="$(curl -s -F "url=${url}" "$3" || echo '{"ok":false}')"
      echo "$(date -Is) ${label} webhook attempt ${attempt}: ${result}" >> "$LOGFILE"
      if [[ "$result" == *'"ok":true'* ]]; then return 0; fi
      sleep 5
    done
    return 1
  }
  if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
    register_webhook "https://${DOMAIN}/index.php?secret=${WEBHOOK_SECRET}" "Telegram" \
      "https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook"
  fi
  if [[ "$ENABLE_BALE" == "true" ]]; then
    register_webhook "https://${DOMAIN}/index.php?platform=bale&secret=${WEBHOOK_SECRET}" "Bale" \
      "https://tapi.bale.ai/bot${BALE_TOKEN}/setWebhook"
  fi
fi
wait "$CF_PID"
REFRESHEOF
    chmod +x "/usr/local/bin/${PROJECT_NAME}-tunnel-refresh.sh"

    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICEEOF
[Unit]
Description=${PROJECT_NAME} Cloudflare tunnel
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/${PROJECT_NAME}-tunnel-refresh.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF
    systemctl daemon-reload
    systemctl enable --now "${SERVICE_NAME}.service"

    info "Waiting for tunnel (up to 25s)..."
    DOMAIN=""
    for i in $(seq 1 25); do
      DOMAIN="$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/${PROJECT_NAME}-cloudflared.log 2>/dev/null | head -1 | sed 's|https://||')"
      [[ -n "$DOMAIN" ]] && break
      sleep 1
    done
    if [[ -z "$DOMAIN" ]]; then
      warn "Tunnel URL not found. Check: systemctl status ${SERVICE_NAME}"
    else
      ok "Tunnel active: https://$DOMAIN"
      sed -i "s|domainhosts = 'PENDING'|domainhosts = '${DOMAIN}'|; s|{{DOMAIN}}|${DOMAIN}|g" "${INSTALL_DIR}/config.php" || true
    fi
  else
    info "Your domain: $DOMAIN — point DNS to this server and get SSL:"
    echo "  certbot --nginx -d $DOMAIN"
  fi
}

register_webhooks() {
  if [[ "$DOMAIN_MODE" == "2" ]]; then
    info "Webhooks will be registered by the tunnel service."
    return 0
  fi
  if [[ -z "${DOMAIN:-}" ]]; then
    warn "Domain is empty — webhooks not registered."
    return 0
  fi
  if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
    local r
    r="$(curl -s -F "url=https://${DOMAIN}/index.php?secret=${WEBHOOK_SECRET}" \
      "https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook" || true)"
    info "Telegram webhook: $r"
  fi
  if [[ "$ENABLE_BALE" == "true" ]]; then
    local r
    r="$(curl -s -F "url=https://${DOMAIN}/index.php?platform=bale&secret=${WEBHOOK_SECRET}" \
      "https://tapi.bale.ai/bot${BALE_TOKEN}/setWebhook" || true)"
    info "Bale webhook: $r"
  fi
}

# ===========================================================================
#  ۲) آپدیت
# ===========================================================================
do_update() {
  echo ""
  echo -e "${BOLD}=== Update mirza_vali (latest) ===${NC}"
  echo ""
  load_state

  if [[ -z "${INSTALL_DIR:-}" || ! -d "${INSTALL_DIR:-}" ]]; then
    err "No active install found. Run Install first."
    return 1
  fi

  local current newv
  current="$(version_of "$INSTALL_DIR")"
  info "Current version on server: v${current}"

  # بک‌آپ فایل‌های حیاتی
  local bak="${INSTALL_DIR}-backup-$(date +%Y%m%d%H%M%S)"
  info "Creating backup..."
  mkdir -p "$bak"
  for f in config.php botapi.php function.php index.php admin.php keyboard.php table.php VERSION; do
    [[ -f "${INSTALL_DIR}/${f}" ]] && cp -a "${INSTALL_DIR}/${f}" "${bak}/" || true
  done
  ok "Backup: $bak"

  local tmp src_patch=""
  tmp="$(mktemp -d)"

  # اولویت ۱: آخرین zip داخل ZIP_DROP_DIR (مثلاً /home/mirza_vali_v1.2.0.zip)
  local latest_zip=""
  if [[ -d "${ZIP_DROP_DIR}" ]]; then
    latest_zip="$(ls -1t "${ZIP_DROP_DIR}"/mirza_vali*.zip 2>/dev/null | head -1 || true)"
  fi

  if [[ -n "$latest_zip" && -f "$latest_zip" ]]; then
    info "Found local zip: $latest_zip"
    info "Extracting and using as update source..."
    mkdir -p "$tmp/zipout"
    if command -v unzip >/dev/null 2>&1; then
      unzip -qo "$latest_zip" -d "$tmp/zipout"
    else
      apt-get install -y unzip >/dev/null 2>&1 || true
      unzip -qo "$latest_zip" -d "$tmp/zipout"
    fi
    # پیدا کردن پوشه‌ای که patch/ یا manage.sh دارد
    if [[ -d "$tmp/zipout/patch" ]]; then
      src_patch="$tmp/zipout/patch"
      [[ -f "$tmp/zipout/VERSION" ]] && cp -f "$tmp/zipout/VERSION" "$tmp/VERSION" || true
    else
      local found
      found="$(find "$tmp/zipout" -type d -name patch 2>/dev/null | head -1 || true)"
      if [[ -n "$found" ]]; then
        src_patch="$found"
        [[ -f "$(dirname "$found")/VERSION" ]] && cp -f "$(dirname "$found")/VERSION" "$tmp/VERSION" || true
      fi
    fi
  fi

  # اولویت ۲: کلون آخرین نسخه از گیت‌هاب
  if [[ -z "$src_patch" ]]; then
    info "Fetching latest from GitHub: $GITHUB_REPO (branch $GITHUB_BRANCH)..."
    if git clone --depth 1 --branch "$GITHUB_BRANCH" "$GITHUB_REPO" "$tmp/repo" 2>/dev/null; then
      src_patch="$tmp/repo/patch"
      [[ -f "$tmp/repo/VERSION" ]] && cp -f "$tmp/repo/VERSION" "$tmp/VERSION" || true
      ok "Latest version fetched from GitHub."
    else
      err "No local zip found and GitHub clone failed."
      err "Put a zip in ${ZIP_DROP_DIR}/ or push to GitHub."
      rm -rf "$tmp"
      return 1
    fi
  fi

  if [[ -z "$src_patch" || ! -d "$src_patch" ]]; then
    err "patch/ folder not found in update source."
    rm -rf "$tmp"
    return 1
  fi

  info "Applying patch files..."
  for f in botapi.php function.php index.php admin.php keyboard.php table.php; do
    if [[ -f "${src_patch}/${f}" ]]; then
      cp -f "${src_patch}/${f}" "${INSTALL_DIR}/${f}"
      ok "  $f"
    else
      warn "  missing: $f"
    fi
  done

  if [[ -f "$tmp/VERSION" ]]; then
    cp -f "$tmp/VERSION" "${INSTALL_DIR}/VERSION"
  elif [[ -f "$(dirname "$src_patch")/VERSION" ]]; then
    cp -f "$(dirname "$src_patch")/VERSION" "${INSTALL_DIR}/VERSION"
  fi

  chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || true

  info "Syncing database tables (no data loss)..."
  (cd "$INSTALL_DIR" && php table.php) 2>/dev/null || true

  newv="$(version_of "$INSTALL_DIR")"
  save_state
  rm -rf "$tmp"
  ok "Update done: v${current} -> v${newv}"
  info "If needed, re-register webhooks from the Reset menu."
}


# ===========================================================================
#  ۳) ریست
# ===========================================================================
do_reset() {
  echo ""
  echo -e "${BOLD}=== Reset mirza_vali ===${NC}"
  echo ""
  load_state

  if [[ -z "${INSTALL_DIR:-}" || ! -d "${INSTALL_DIR:-}" ]]; then
    err "No active install found."
    return 1
  fi

  echo "What should be reset?"
  echo "  1) Re-register webhooks only"
  echo "  2) Restart tunnel service + webhooks"
  echo "  3) Clear user steps (stuck menus) — step field only"
  echo "  0) Cancel"
  local choice
  read -rp "Choice: " choice

  case "$choice" in
    1)
      DOMAIN_MODE="${DOMAIN_MODE:-1}"
      register_webhooks
      ok "Webhooks re-registered."
      ;;
    2)
      if systemctl list-unit-files | grep -q "${SERVICE_NAME}"; then
        systemctl restart "${SERVICE_NAME}" || true
        ok "Tunnel service restarted."
        sleep 5
        DOMAIN="$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/${PROJECT_NAME}-cloudflared.log 2>/dev/null | head -1 | sed 's|https://||' || true)"
        if [[ -n "$DOMAIN" ]]; then
          sed -i "s|\$domainhosts = '.*';|\$domainhosts = '${DOMAIN}';|" "${INSTALL_DIR}/config.php" || true
          ok "New tunnel URL: https://$DOMAIN"
        fi
      else
        warn "Tunnel service not installed (you may be using your own domain)."
        register_webhooks
      fi
      ;;
    3)
      if [[ -n "${DB_NAME:-}" && -n "${DB_USER:-}" && -n "${DB_PASS:-}" ]]; then
        mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e "UPDATE user SET step='home' WHERE step NOT IN ('home','none','');" 2>/dev/null \
          && ok "User steps reset." \
          || err "Database connection error."
      else
        err "Database credentials not found in state file."
      fi
      ;;
    *) info "Cancelled." ;;
  esac
}

# ===========================================================================
#  ۴) حذف کامل
# ===========================================================================
do_remove() {
  echo ""
  echo -e "${BOLD}${RED}=== Full remove mirza_vali ===${NC}"
  echo ""
  load_state

  warn "This cannot be undone. It will remove:"
  echo "  - Install folder: ${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
  echo "  - Database: ${DB_NAME:-mirza_vali}"
  echo "  - Tunnel service and nginx site"
  echo "  - State files in $STATE_DIR"
  echo ""
  local conf
  conf="$(ask_yn 'Are you sure? Delete everything?' 'n')"
  [[ "$conf" != "true" ]] && { info "Cancelled."; return 0; }

  # وبهوک را حذف کن
  if [[ "${ENABLE_TELEGRAM:-}" == "true" && -n "${TELEGRAM_TOKEN:-}" && "$TELEGRAM_TOKEN" != "disabled" ]]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/deleteWebhook" >/dev/null || true
  fi
  if [[ "${ENABLE_BALE:-}" == "true" && -n "${BALE_TOKEN:-}" && "$BALE_TOKEN" != "disabled" ]]; then
    curl -s "https://tapi.bale.ai/bot${BALE_TOKEN}/deleteWebhook" >/dev/null || true
  fi

  systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
  systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  systemctl daemon-reload 2>/dev/null || true
  rm -f "/usr/local/bin/${PROJECT_NAME}-tunnel-refresh.sh"
  rm -f "/var/log/${PROJECT_NAME}-cloudflared.log"

  rm -f "/etc/nginx/sites-enabled/${NGINX_SITE}"
  rm -f "/etc/nginx/sites-available/${NGINX_SITE}"
  nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true

  if [[ -n "${INSTALL_DIR:-}" && -d "${INSTALL_DIR}" ]]; then
    rm -rf "${INSTALL_DIR}"
    ok "Install folder removed."
  fi

  if [[ -n "${DB_NAME:-}" ]]; then
    mysql -uroot -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" 2>/dev/null || true
    if [[ -n "${DB_USER:-}" && "$DB_USER" != "root" ]]; then
      mysql -uroot -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
    fi
    ok "Database removed."
  fi

  rm -rf "$STATE_DIR"
  ok "Full removal complete."
}

# ===========================================================================
#  ۵) وضعیت
# ===========================================================================
do_status() {
  echo ""
  echo -e "${BOLD}=== System status ===${NC}"
  echo ""
  load_state

  echo "  Project:         $PROJECT_NAME"
  echo "  Script version:  v$(version_of "$SCRIPT_DIR")"
  if [[ -f "$STATE_FILE" ]]; then
    echo "  Installed ver:   v${INSTALLED_VERSION:-?}"
    echo "  Path:            ${INSTALL_DIR:-?}"
    echo "  Domain:          ${DOMAIN:-?}"
    echo "  Telegram:        ${ENABLE_TELEGRAM:-?}"
    echo "  Bale:            ${ENABLE_BALE:-?}"
    echo "  Database:        ${DB_NAME:-?} / ${DB_USER:-?}"
    echo "  Installed at:    ${INSTALLED_AT:-?}"
  else
    echo "  Install:         Not installed"
  fi
  echo ""
  echo "  Services:"
  if systemctl is-active --quiet nginx 2>/dev/null; then
    ok "nginx is active"
  else
    warn "nginx inactive or not installed"
  fi
  if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
    ok "mariadb/mysql is active"
  else
    warn "database inactive"
  fi
  if systemctl list-unit-files 2>/dev/null | grep -q "${SERVICE_NAME}"; then
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
      ok "Cloudflare tunnel is active"
    else
      warn "Cloudflare tunnel installed but inactive"
    fi
  else
    info "Cloudflare tunnel not installed (likely custom domain)"
  fi
  echo ""
}

# ===========================================================================
#  Main loop
# ===========================================================================
main() {
  need_root
  _bootstrap_source
  _reexec_if_piped "$@"

  # Direct arguments (non-interactive flags still work after re-exec)
  case "${1:-}" in
    install) do_install; exit 0 ;;
    update)  do_update;  exit 0 ;;
    reset)   do_reset;   exit 0 ;;
    remove|uninstall) do_remove; exit 0 ;;
    status)  do_status;  exit 0 ;;
  esac

  while true; do
    show_banner
    show_menu
    local choice
    read -rp "  Select option: " choice
    case "$choice" in
      1) do_install; pause ;;
      2) do_update;  pause ;;
      3) do_reset;   pause ;;
      4) do_remove;  pause ;;
      5) do_status;  pause ;;
      0|q|Q)
        echo ""
        info "Exiting. Goodbye."
        exit 0
        ;;
      *)
        warn "Invalid option."
        sleep 1
        ;;
    esac
  done
}

main "$@"
