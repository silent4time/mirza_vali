#!/usr/bin/env bash
# ============================================================================
#  mirza_vali — پنل مدیریت نصب
#  نسخه: با فایل VERSION هم‌خوان است
#
#  اجرا:
#    sudo bash manage.sh
#
#  یا یک‌خطی از گیت‌هاب (بعد از آپلود ریپو):
#    curl -sL https://raw.githubusercontent.com/USER/mirza_vali/main/manage.sh | sudo bash
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
    err "این اسکریپت باید با دسترسی root اجرا شود:"
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
  ok "وضعیت نصب ذخیره شد: $STATE_FILE"
}

pause() {
  echo ""
  read -rp "Enter بزنید تا به منو برگردید... " _
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
  read -rp "$prompt [y/n] (پیش‌فرض: $default): " var
  var="${var:-$default}"
  [[ "$var" =~ ^[YyیY] ]] && echo "true" || echo "false"
}

# مسیر خود اسکریپت / ریپوی محلی (اگر از داخل کلون اجرا شود)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAS_LOCAL_PATCH="false"
if [[ -d "${SCRIPT_DIR}/patch" && -f "${SCRIPT_DIR}/patch/botapi.php" ]]; then
  HAS_LOCAL_PATCH="true"
fi

# ===========================================================================
#  منوی اصلی
# ===========================================================================
show_banner() {
  clear
  local ver
  ver="$(version_of "$SCRIPT_DIR")"
  echo -e "${BOLD}${CYAN}"
  echo "+----------------------------------------------------------+"
  echo "|                                                          |"
  echo "|              mirza_vali  -  Management Panel             |"
  echo "|                  Telegram  +  Bale                       |"
  echo "|                                                          |"
  echo "+----------------------------------------------------------+"
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
  echo -e "${BOLD}  منوی مدیریت:${NC}"
  echo "  ─────────────────────────────────────"
  echo "   1)  نصب (Install)"
  echo "   2)  آپدیت (Update)"
  echo "   3)  ریست (Reset) — وبهوک / سرویس / تنظیمات پایه"
  echo "   4)  حذف کامل (Remove)"
  echo "   5)  وضعیت سیستم (Status)"
  echo "   0)  خروج"
  echo "  ─────────────────────────────────────"
  echo ""
}

# ===========================================================================
#  ۱) نصب
# ===========================================================================
do_install() {
  echo ""
  echo -e "${BOLD}═══ نصب mirza_vali ═══${NC}"
  echo ""

  if [[ -f "$STATE_FILE" ]]; then
    warn "به نظر می‌رسد قبلاً نصب شده است."
    local cont
    cont="$(ask_yn 'ادامه و نصب روی مسیر جدید/بازنویسی؟' 'n')"
    [[ "$cont" != "true" ]] && return 0
  fi

  INSTALL_DIR="$(ask 'مسیر نصب' "$DEFAULT_INSTALL_DIR")"
  if [[ "$(basename "$INSTALL_DIR")" != "$PROJECT_NAME" ]]; then
    INSTALL_DIR="${INSTALL_DIR%/}/$PROJECT_NAME"
    info "مسیر تنظیم شد به: $INSTALL_DIR"
  fi

  DB_NAME="$(ask 'نام دیتابیس' 'mirza_vali')"
  DB_USER="$(ask 'یوزر دیتابیس' 'mirzavali')"
  if [[ -z "${DB_PASS:-}" ]]; then
    DB_PASS="$(openssl rand -hex 12)"
    ok "رمز دیتابیس تولید شد: $DB_PASS  (یادداشت کنید)"
  else
    DB_PASS="$(ask 'رمز دیتابیس' "$DB_PASS")"
  fi

  ENABLE_TELEGRAM="$(ask_yn 'فعال‌سازی ربات تلگرام؟' 'y')"
  if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
    TELEGRAM_TOKEN="$(ask 'توکن تلگرام (BotFather)')"
    TELEGRAM_USERNAME="$(ask 'یوزرنیم ربات تلگرام (بدون @)')"
    ADMIN_ID="$(ask 'آیدی عددی ادمین تلگرام')"
  else
    TELEGRAM_TOKEN="disabled"
    TELEGRAM_USERNAME="disabled"
    ADMIN_ID="$(ask 'آیدی عددی ادمین (برای دسترسی پنل)')"
  fi

  ENABLE_BALE="$(ask_yn 'فعال‌سازی ربات بله؟' 'y')"
  if [[ "$ENABLE_BALE" == "true" ]]; then
    BALE_TOKEN="$(ask 'توکن بله (my.bale.ai)')"
    BALE_ADMIN_ID="$(ask 'آیدی عددی ادمین بله (اختیاری)' '')"
    BALE_REPORT_GROUP_ID="$(ask 'آیدی گروه گزارش بله (اختیاری)' '')"
    BALE_PROVIDER_TOKEN="$(ask 'توکن پرداخت بله‌پی (اختیاری)' '')"
  else
    BALE_TOKEN="disabled"
    BALE_ADMIN_ID=""
    BALE_REPORT_GROUP_ID=""
    BALE_PROVIDER_TOKEN=""
  fi

  WEBHOOK_SECRET="$(openssl rand -hex 16)"

  echo ""
  echo "دسترسی اینترنت:"
  echo "  1) دامنه + SSL خودم"
  echo "  2) تونل موقت Cloudflare (تست)"
  DOMAIN_MODE="$(ask 'کدام؟ (1 یا 2)' '2')"
  DOMAIN=""
  if [[ "$DOMAIN_MODE" == "1" ]]; then
    DOMAIN="$(ask 'دامنه (بدون https://)')"
  fi

  echo ""
  info "شروع نصب..."

  # --- پکیج‌ها ---
  info "نصب پیش‌نیازها (nginx, mariadb, php)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || warn "apt-get update خطا داشت، ادامه..."
  apt-get install -y nginx mariadb-server php php-fpm php-mysql php-curl \
    php-mbstring php-gd php-xml php-zip unzip git curl openssl >/dev/null
  if ! command -v composer >/dev/null 2>&1; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >/dev/null 2>&1 || true
  fi
  ok "پکیج‌ها نصب شدند."

  PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
  if [[ -z "$PHP_VERSION" ]]; then
    PHP_VERSION="$(ls /etc/php/ 2>/dev/null | sort -V | tail -1)"
  fi
  PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
  systemctl enable --now mariadb >/dev/null 2>&1 || true
  systemctl enable --now "php${PHP_VERSION}-fpm" >/dev/null 2>&1 || true

  # --- دیتابیس ---
  info "ساخت دیتابیس..."
  mysql -uroot -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -uroot -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null || true
  mysql -uroot -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  mysql -uroot -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
  ok "دیتابیس آماده است."

  # --- سورس پایه میرزا ---
  if [[ -d "$INSTALL_DIR" ]]; then
    warn "پوشه قبلی وجود دارد — بک‌آپ گرفته می‌شود..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}-backup-$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$(dirname "$INSTALL_DIR")"
  info "دانلود سورس پایه mirzabot از GitHub..."
  git clone --quiet https://github.com/mahdiMGF2/mirzabot.git "$INSTALL_DIR"
  PATCH_BASE_COMMIT="fcd9afeb0e80b67db21cc21611dc91a07c0feee0"
  (cd "$INSTALL_DIR" && git checkout --quiet "$PATCH_BASE_COMMIT") || warn "checkout به کامیت پین‌شده ممکن نشد"
  ok "سورس پایه آماده شد."

  if [[ -f "$INSTALL_DIR/composer.json" && ! -d "$INSTALL_DIR/vendor" ]]; then
    info "نصب وابستگی‌های Composer..."
    (cd "$INSTALL_DIR" && composer install --no-dev --no-interaction --optimize-autoloader) || warn "composer با خطا مواجه شد"
  fi

  # --- اعمال پچ ---
  info "اعمال پچ mirza_vali..."
  apply_patch_files "$INSTALL_DIR"
  write_config "$INSTALL_DIR"
  echo "$(version_of "$SCRIPT_DIR")" > "$INSTALL_DIR/VERSION"
  echo "$PROJECT_NAME" > "$INSTALL_DIR/PROJECT_NAME"
  ok "پچ اعمال شد."

  # --- جداول ---
  info "ساخت جداول دیتابیس..."
  (cd "$INSTALL_DIR" && php table.php) || true
  if [[ -n "${BALE_PROVIDER_TOKEN:-}" && "$BALE_PROVIDER_TOKEN" != "0" ]]; then
    mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e \
      "UPDATE PaySetting SET ValuePay='${BALE_PROVIDER_TOKEN}' WHERE NamePay='merchant_balepay';" 2>/dev/null || true
    mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e \
      "UPDATE PaySetting SET ValuePay='onbalepay' WHERE NamePay='balepaystatus';" 2>/dev/null || true
    ok "توکن بله‌پی در دیتابیس ثبت و روشن شد."
  fi
  chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || chown -R nginx:nginx "$INSTALL_DIR" 2>/dev/null || true

  # --- Nginx ---
  info "پیکربندی Nginx..."
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
  ok "Nginx آماده است."

  # --- دامنه / تونل ---
  setup_connectivity

  # --- وبهوک ---
  register_webhooks

  save_state
  echo ""
  ok "نصب کامل شد — $PROJECT_NAME v$(version_of "$INSTALL_DIR")"
  echo "  مسیر:  $INSTALL_DIR"
  echo "  دامنه: https://${DOMAIN:-YOUR_DOMAIN}"
  echo "  دیتابیس: $DB_NAME / $DB_USER / $DB_PASS"
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
      info "استفاده از zip محلی برای پچ: $latest_zip"
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
    info "دانلود فایل‌های پچ از گیت‌هاب..."
    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 --branch "$GITHUB_BRANCH" "$GITHUB_REPO" "$tmp/repo" 2>/dev/null; then
      src_patch="$tmp/repo/patch"
      export _MIRZA_ZIP_TMP="$tmp"
    else
      err "نتوانست از گیت‌هاب کلون کند: $GITHUB_REPO"
      err "zip را در /home بگذارید یا آدرس ریپو را درست کنید."
      exit 1
    fi
  fi

  for f in botapi.php function.php index.php admin.php keyboard.php table.php; do
    if [[ -f "${src_patch}/${f}" ]]; then
      cp -f "${src_patch}/${f}" "${target}/${f}"
    else
      warn "فایل پچ یافت نشد: $f"
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
    info "راه‌اندازی تونل Cloudflare..."
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

    info "منتظر تونل (حداکثر ۲۵ ثانیه)..."
    DOMAIN=""
    for i in $(seq 1 25); do
      DOMAIN="$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/${PROJECT_NAME}-cloudflared.log 2>/dev/null | head -1 | sed 's|https://||')"
      [[ -n "$DOMAIN" ]] && break
      sleep 1
    done
    if [[ -z "$DOMAIN" ]]; then
      warn "آدرس تونل پیدا نشد. وضعیت: systemctl status ${SERVICE_NAME}"
    else
      ok "تونل فعال: https://$DOMAIN"
      sed -i "s|domainhosts = 'PENDING'|domainhosts = '${DOMAIN}'|; s|{{DOMAIN}}|${DOMAIN}|g" "${INSTALL_DIR}/config.php" || true
    fi
  else
    info "دامنه شما: $DOMAIN — DNS را به IP سرور وصل کنید و SSL بگیرید:"
    echo "  certbot --nginx -d $DOMAIN"
  fi
}

register_webhooks() {
  if [[ "$DOMAIN_MODE" == "2" ]]; then
    info "وبهوک توسط سرویس تونل ثبت می‌شود."
    return 0
  fi
  if [[ -z "${DOMAIN:-}" ]]; then
    warn "دامنه خالی است — وبهوک ثبت نشد."
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
  echo -e "${BOLD}═══ آپدیت mirza_vali (آخرین نسخه) ═══${NC}"
  echo ""
  load_state

  if [[ -z "${INSTALL_DIR:-}" || ! -d "${INSTALL_DIR:-}" ]]; then
    err "نصب فعالی پیدا نشد. اول گزینه نصب را بزنید."
    return 1
  fi

  local current newv
  current="$(version_of "$INSTALL_DIR")"
  info "نسخه فعلی روی سرور: v${current}"

  # بک‌آپ فایل‌های حیاتی
  local bak="${INSTALL_DIR}-backup-$(date +%Y%m%d%H%M%S)"
  info "بک‌آپ..."
  mkdir -p "$bak"
  for f in config.php botapi.php function.php index.php admin.php keyboard.php table.php VERSION; do
    [[ -f "${INSTALL_DIR}/${f}" ]] && cp -a "${INSTALL_DIR}/${f}" "${bak}/" || true
  done
  ok "بک‌آپ: $bak"

  local tmp src_patch=""
  tmp="$(mktemp -d)"

  # اولویت ۱: آخرین zip داخل ZIP_DROP_DIR (مثلاً /home/mirza_vali_v1.2.0.zip)
  local latest_zip=""
  if [[ -d "${ZIP_DROP_DIR}" ]]; then
    latest_zip="$(ls -1t "${ZIP_DROP_DIR}"/mirza_vali*.zip 2>/dev/null | head -1 || true)"
  fi

  if [[ -n "$latest_zip" && -f "$latest_zip" ]]; then
    info "یافت شد zip محلی: $latest_zip"
    info "استخراج و اعمال به‌عنوان منبع آپدیت..."
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
    info "دریافت آخرین نسخه از GitHub: $GITHUB_REPO (شاخه $GITHUB_BRANCH)..."
    if git clone --depth 1 --branch "$GITHUB_BRANCH" "$GITHUB_REPO" "$tmp/repo" 2>/dev/null; then
      src_patch="$tmp/repo/patch"
      [[ -f "$tmp/repo/VERSION" ]] && cp -f "$tmp/repo/VERSION" "$tmp/VERSION" || true
      ok "آخرین نسخه از گیت‌هاب دریافت شد."
    else
      err "نه zip محلی پیدا شد و نه کلون از گیت‌هاب موفق بود."
      err "zip را در ${ZIP_DROP_DIR}/ بگذارید (مثلاً mirza_vali_v1.2.0.zip) یا ریپو را روی گیت‌هاب پوش کنید."
      rm -rf "$tmp"
      return 1
    fi
  fi

  if [[ -z "$src_patch" || ! -d "$src_patch" ]]; then
    err "پوشه patch در منبع آپدیت یافت نشد."
    rm -rf "$tmp"
    return 1
  fi

  info "اعمال فایل‌های پچ..."
  for f in botapi.php function.php index.php admin.php keyboard.php table.php; do
    if [[ -f "${src_patch}/${f}" ]]; then
      cp -f "${src_patch}/${f}" "${INSTALL_DIR}/${f}"
      ok "  $f"
    else
      warn "  موجود نیست: $f"
    fi
  done

  if [[ -f "$tmp/VERSION" ]]; then
    cp -f "$tmp/VERSION" "${INSTALL_DIR}/VERSION"
  elif [[ -f "$(dirname "$src_patch")/VERSION" ]]; then
    cp -f "$(dirname "$src_patch")/VERSION" "${INSTALL_DIR}/VERSION"
  fi

  chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || true

  info "همگام‌سازی جداول (بدون حذف داده)..."
  (cd "$INSTALL_DIR" && php table.php) 2>/dev/null || true

  newv="$(version_of "$INSTALL_DIR")"
  save_state
  rm -rf "$tmp"
  ok "آپدیت انجام شد: v${current} → v${newv}"
  info "در صورت نیاز از منوی ریست، وبهوک‌ها را دوباره ثبت کنید."
}


# ===========================================================================
#  ۳) ریست
# ===========================================================================
do_reset() {
  echo ""
  echo -e "${BOLD}═══ ریست mirza_vali ═══${NC}"
  echo ""
  load_state

  if [[ -z "${INSTALL_DIR:-}" || ! -d "${INSTALL_DIR:-}" ]]; then
    err "نصب فعالی پیدا نشد."
    return 1
  fi

  echo "چه چیزی ریست شود؟"
  echo "  1) فقط ثبت مجدد وبهوک‌ها"
  echo "  2) ری‌استارت سرویس تونل + ثبت وبهوک"
  echo "  3) پاک کردن step کاربران (گیرکردن منو) — فقط فیلد step"
  echo "  0) انصراف"
  local choice
  read -rp "انتخاب: " choice

  case "$choice" in
    1)
      DOMAIN_MODE="${DOMAIN_MODE:-1}"
      register_webhooks
      ok "وبهوک‌ها دوباره ثبت شدند."
      ;;
    2)
      if systemctl list-unit-files | grep -q "${SERVICE_NAME}"; then
        systemctl restart "${SERVICE_NAME}" || true
        ok "سرویس تونل ری‌استارت شد."
        sleep 5
        DOMAIN="$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' /var/log/${PROJECT_NAME}-cloudflared.log 2>/dev/null | head -1 | sed 's|https://||' || true)"
        if [[ -n "$DOMAIN" ]]; then
          sed -i "s|\$domainhosts = '.*';|\$domainhosts = '${DOMAIN}';|" "${INSTALL_DIR}/config.php" || true
          ok "دامنه تونل جدید: https://$DOMAIN"
        fi
      else
        warn "سرویس تونل نصب نیست (احتمالاً از دامنه شخصی استفاده می‌کنید)."
        register_webhooks
      fi
      ;;
    3)
      if [[ -n "${DB_NAME:-}" && -n "${DB_USER:-}" && -n "${DB_PASS:-}" ]]; then
        mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -e "UPDATE user SET step='home' WHERE step NOT IN ('home','none','');" 2>/dev/null \
          && ok "step کاربران ریست شد." \
          || err "خطا در اتصال به دیتابیس."
      else
        err "اطلاعات دیتابیس در state موجود نیست."
      fi
      ;;
    *) info "انصراف." ;;
  esac
}

# ===========================================================================
#  ۴) حذف کامل
# ===========================================================================
do_remove() {
  echo ""
  echo -e "${BOLD}${RED}═══ حذف کامل mirza_vali ═══${NC}"
  echo ""
  load_state

  warn "این کار غیرقابل بازگشت است و شامل موارد زیر می‌شود:"
  echo "  • پوشه نصب: ${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
  echo "  • دیتابیس:  ${DB_NAME:-mirza_vali}"
  echo "  • سرویس تونل و nginx site"
  echo "  • فایل وضعیت در $STATE_DIR"
  echo ""
  local conf
  conf="$(ask_yn 'مطمئن هستید؟ همه چیز پاک شود؟' 'n')"
  [[ "$conf" != "true" ]] && { info "لغو شد."; return 0; }

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
    ok "پوشه نصب حذف شد."
  fi

  if [[ -n "${DB_NAME:-}" ]]; then
    mysql -uroot -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" 2>/dev/null || true
    if [[ -n "${DB_USER:-}" && "$DB_USER" != "root" ]]; then
      mysql -uroot -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null || true
    fi
    ok "دیتابیس حذف شد."
  fi

  rm -rf "$STATE_DIR"
  ok "حذف کامل انجام شد."
}

# ===========================================================================
#  ۵) وضعیت
# ===========================================================================
do_status() {
  echo ""
  echo -e "${BOLD}═══ وضعیت سیستم ═══${NC}"
  echo ""
  load_state

  echo "  پروژه:          $PROJECT_NAME"
  echo "  نسخه اسکریپت:   v$(version_of "$SCRIPT_DIR")"
  if [[ -f "$STATE_FILE" ]]; then
    echo "  نسخه نصب‌شده:   v${INSTALLED_VERSION:-?}"
    echo "  مسیر:           ${INSTALL_DIR:-?}"
    echo "  دامنه:          ${DOMAIN:-?}"
    echo "  تلگرام:         ${ENABLE_TELEGRAM:-?}"
    echo "  بله:            ${ENABLE_BALE:-?}"
    echo "  دیتابیس:        ${DB_NAME:-?} / ${DB_USER:-?}"
    echo "  تاریخ نصب:      ${INSTALLED_AT:-?}"
  else
    echo "  نصب:            انجام نشده"
  fi
  echo ""
  echo "  سرویس‌ها:"
  if systemctl is-active --quiet nginx 2>/dev/null; then
    ok "nginx فعال"
  else
    warn "nginx غیرفعال یا نصب نیست"
  fi
  if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
    ok "mariadb/mysql فعال"
  else
    warn "دیتابیس غیرفعال"
  fi
  if systemctl list-unit-files 2>/dev/null | grep -q "${SERVICE_NAME}"; then
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
      ok "تونل Cloudflare فعال"
    else
      warn "تونل Cloudflare نصب است ولی فعال نیست"
    fi
  else
    info "تونل Cloudflare نصب نیست (احتمالاً دامنه شخصی)"
  fi
  echo ""
}

# ===========================================================================
#  حلقه منو
# ===========================================================================
main() {
  need_root

  # اگر آرگومان مستقیم داده شده باشد
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
    read -rp "  گزینه را انتخاب کنید: " choice
    case "$choice" in
      1) do_install; pause ;;
      2) do_update;  pause ;;
      3) do_reset;   pause ;;
      4) do_remove;  pause ;;
      5) do_status;  pause ;;
      0|q|Q|خروج)
        echo ""
        info "خروج از مدیریت. موفق باشید."
        exit 0
        ;;
      *)
        warn "گزینه نامعتبر."
        sleep 1
        ;;
    esac
  done
}

main "$@"
