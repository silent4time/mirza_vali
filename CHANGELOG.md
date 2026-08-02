# mirza_vali — Changelog

## v1.3.3 (2026-08-02)

### Fix incomplete GitHub repo / double-clone crash
- install.sh verifies patch/ exists after clone and shows a clear error if missing
- manage.sh no longer deletes /opt/mirza_vali-src while running from it
- If already inside the source tree, skips a second git clone


## v1.3.2 (2026-08-02)

### Interactive one-line install
- Use `install.sh` as the entry point (not raw `manage.sh` via pipe)
- Clones into `/opt/mirza_vali-src`, cds there, opens menu with real TTY
- Pressing 1 starts Install; menu input works after curl|bash
- `manage.sh` auto re-execs from disk if started with a piped stdin


## v1.3.1 (2026-08-02)

### English-only terminal UI
- All menu text, prompts, and status messages are in English (fixes broken RTL display in many terminals)
- Cleaner management panel banner box


## v1.3.0 (2026-08-02)

### نصب یک‌خطی بدون ورود به پوشه
- از هر مسیر روی سرور:
  `curl -sL https://raw.githubusercontent.com/silent4time/mirza_vali/main/manage.sh | sudo bash`
- در صورت نبود پوشه patch محلی، خودکار از GitHub کلون می‌شود به `/opt/mirza_vali-src`
- فایل `install.sh` به‌عنوان میانبر همان کار را انجام می‌دهد

# mirza_vali — Changelog

## v1.3.3 (2026-08-02)

### Fix incomplete GitHub repo / double-clone crash
- install.sh verifies patch/ exists after clone and shows a clear error if missing
- manage.sh no longer deletes /opt/mirza_vali-src while running from it
- If already inside the source tree, skips a second git clone


## v1.3.2 (2026-08-02)

### Interactive one-line install
- Use `install.sh` as the entry point (not raw `manage.sh` via pipe)
- Clones into `/opt/mirza_vali-src`, cds there, opens menu with real TTY
- Pressing 1 starts Install; menu input works after curl|bash
- `manage.sh` auto re-execs from disk if started with a piped stdin


## v1.3.1 (2026-08-02)

### English-only terminal UI
- All menu text, prompts, and status messages are in English (fixes broken RTL display in many terminals)
- Cleaner management panel banner box


## v1.2.0 (2026-08-02)

### آپدیت خودکار آخرین نسخه
- گزینه **آپدیت** به این ترتیب منبع را انتخاب می‌کند:
  1. آخرین فایل `mirza_vali*.zip` داخل `/home` (مسیری که zip را می‌گذارید)
  2. در غیر این صورت، کلون آخرین commit از `github.com/silent4time/mirza_vali`
- نصب هم در صورت نبودن پوشه `patch` محلی، از همان zip یا گیت‌هاب پچ را می‌گیرد.
- متغیر `ZIP_DROP_DIR` (پیش‌فرض `/home`) قابل تنظیم است.

### یادآوری
- بعد از هر انتشار جدید: zip را در `/home` بگذارید **یا** روی گیت‌هاب push کنید، سپس از منو گزینه آپدیت را بزنید.

---

## v1.1.0 (2026-08-02)

### منوی مدیریت
- `manage.sh`: نصب / آپدیت / ریست / حذف / وضعیت / خروج
- ریپو: `https://github.com/silent4time/mirza_vali.git`

---

## v1.0.0 (2026-08-02)

### نام پروژه و رفع باگ پرداخت
- مسیر نصب: `/var/www/mirza_vali`
- بله‌پی، کارت‌به‌کارت بله، جداسازی پلتفرم پرداخت
