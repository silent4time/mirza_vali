# mirza_vali

ربات فروش VPN مبتنی بر **Mirza Bot** با پشتیبانی هم‌زمان **تلگرام + بله** و اصلاحات درگاه پرداخت.

| | |
|---|---|
| نسخه فعلی | **v1.3.0** |
| مسیر نصب پیش‌فرض | `/var/www/mirza_vali` |
| پلتفرم‌ها | Telegram + Bale |

---

## نصب سریع (یک‌خطی — بدون ورود به پوشه)

روی سرور، در **هر مسیری** که هستید فقط این را بزنید:

```bash
curl -sL https://raw.githubusercontent.com/silent4time/mirza_vali/main/manage.sh | sudo bash
```

اسکریپت خودش آخرین نسخه را از گیت‌هاب می‌گیرد، منوی مدیریت را باز می‌کند.
ربات در `/var/www/mirza_vali` نصب می‌شود (قابل تغییر در منوی نصب).

نصب مستقیم بدون منو:

```bash
curl -sL https://raw.githubusercontent.com/silent4time/mirza_vali/main/manage.sh | sudo bash -s install
```

روش اختیاری (کلون دستی):

```bash
git clone https://github.com/silent4time/mirza_vali.git
cd mirza_vali
sudo bash manage.sh
```

---

## منوی مدیریت (`manage.sh`)

| کلید | عملیات |
|------|--------|
| **1** | **نصب (Install)** — نصب کامل از صفر |
| **2** | **آپدیت (Update)** — به‌روزرسانی کد بدون پاک کردن دیتابیس/کانفیگ |
| **3** | **ریست (Reset)** — ثبت مجدد وبهوک / ری‌استارت تونل / ریست step کاربران |
| **4** | **حذف کامل (Remove)** — پاک کردن فایل‌ها، دیتابیس، nginx، سرویس تونل |
| **5** | **وضعیت (Status)** — نمایش نسخه، مسیر، سرویس‌ها |
| **0** | **خروج** |

اجرای مستقیم بدون منو:

```bash
sudo bash manage.sh install
sudo bash manage.sh update
sudo bash manage.sh reset
sudo bash manage.sh remove
sudo bash manage.sh status
```

---

## قبل از آپلود روی گیت‌هاب

1. یک ریپوی خالی بسازید (مثلاً `mirza_vali`).
2. در خط ۱۲ فایل `manage.sh` آدرس ریپو را عوض کنید:

```bash
GITHUB_REPO="${GITHUB_REPO:-https://github.com/silent4time/mirza_vali.git}"
```

3. فایل‌ها را پوش کنید:

```bash
cd mirza_vali   # همین پوشه پروژه
git init
git add .
git commit -m "mirza_vali v1.1.0 — install menu + payment fixes"
git branch -M main
git remote add origin https://github.com/silent4time/mirza_vali.git
git push -u origin main
```

---

## ساختار ریپو

```
mirza_vali/
├── manage.sh              # پنل مدیریت (نصب/آپدیت/ریست/حذف/وضعیت)
├── VERSION                # شماره نسخه
├── CHANGELOG.md
├── README.md
├── README-BALE.md         # راهنمای فنی پشتیبانی بله
└── patch/                 # فایل‌های پچ‌شده روی mirzabot
    ├── botapi.php
    ├── function.php
    ├── index.php
    ├── admin.php
    ├── keyboard.php
    ├── table.php
    └── config.template.php
```

در نصب، اسکریپت سورس پایه را از `mahdiMGF2/mirzabot` می‌گیرد، سپس فایل‌های داخل `patch/` را روی آن اعمال می‌کند.

---

## اصلاحات پرداخت (از v1.0.0)

- **بله‌پی:** توکن از پنل ادمین + config خوانده می‌شود؛ دیگر پیام «تنظیم نشده» بی‌دلیل نمی‌دهد.
- **کارت‌به‌کارت در بله:** دیگر کاربر را به `t.me` هدایت نمی‌کند.
- **جداسازی پلتفرم:** پیام/لینک پرداخت بر اساس بله یا تلگرام کاربر؛ استثنای بله‌پی برای کاربر تلگرام.

جزئیات بیشتر: [CHANGELOG.md](CHANGELOG.md) و [README-BALE.md](README-BALE.md)

---

## آپدیت روی سرور

1. نسخه جدید را روی گیت‌هاب push کنید **یا** فایل `mirza_vali_vX.Y.Z.zip` را در `/home` بگذارید.
2. روی سرور:
```bash
cd /var/www/mirza_vali   # یا مسیر manage در کلون
sudo bash manage.sh update
# یا از منو گزینه 2
```
اسکریپت به‌صورت خودکار **آخرین نسخه** را از zip محلی یا GitHub اعمال می‌کند.

---

## پیش‌نیاز سرور

- Ubuntu/Debian
- دسترسی root
- پورت 80 (و 443 در صورت دامنه شخصی)
