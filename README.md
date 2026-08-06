# mirza_vali

ربات فروش و مدیریت اشتراک VPN برای **تلگرام + بله** — فورک سفارشی بر پایه میرزا با درگاه بله‌پی، Apache و نصب یک‌خطی از GitHub.

| | |
|---|---|
| **نسخه فعلی** | v1.8.1 |
| **پلتفرم** | Telegram + Bale |
| **وب‌سرور** | Apache (پورت اختصاصی + دامنه) |
| **ریپو** | [silent4time/mirza_vali](https://github.com/silent4time/mirza_vali) |

---

## قابلیت‌ها

- فروش و تمدید سرویس VPN (Marzban / Marzneshin / Hiddify / x-ui و …)
- پشتیبانی هم‌زمان **تلگرام** و **بله** با یک دیتابیس مشترک
- درگاه **بله‌پی** (کیف‌پول بله) + کارت‌به‌کارت و سایر درگاه‌های رایج میرزا
- پنل ادمین داخل ربات (تنظیمات از بله و تلگرام **همگام** هستند)
- نصب / آپدیت / حذف / تمدید SSL از منوی مدیریت
- SSL خودکار با Certbot روی دامنه اختصاصی
- بدون تداخل با ربات‌های Apache دیگر (پورت جدا `8091` + VirtualHost دامنه)

---

## پیش‌نیاز

| مورد | توضیح |
|------|--------|
| سیستم‌عامل | Ubuntu 22.04 یا 24.04 |
| دسترسی | root |
| دامنه (اختیاری ولی توصیه‌شده) | رکورد A به IP سرور — Cloudflare ترجیحاً **DNS only** |
| توکن‌ها | توکن ربات تلگرام و/یا بله |

> اگر روی سرور از قبل Apache و ربات دیگری دارید، mirza_vali با vhost و پورت جدا نصب می‌شود و پورت ۸۰ بقیه را اشغال نمی‌کند (به‌جز وقتی دامنه + SSL فعال شود).

---

## نصب

روی سرور به‌عنوان **root**:

```bash
curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
```

منوی مدیریت باز می‌شود:

```text
1) Install mirza_vali
2) Update mirza_vali
3) Remove mirza_vali
4) Reset (webhooks / tunnel / domain)
5) Renew SSL certificate
6) Help & Parameters
7) Status
0) Exit
```

گزینه **1** را بزنید و مراحل را دنبال کنید (توکن‌ها، دیتابیس، تلگرام/بله، دامنه یا تونل).

### بعد از نصب

- مسیر ربات: `/var/www/mirza_vali`
- وضعیت نصب: `/etc/mirza_vali/install.env`
- دستور سیستم (در صورت نصب کامل): `mirza_vali`

---

## آپدیت

```bash
curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
```

سپس گزینه **2) Update**

کد و پچ‌ها به‌روز می‌شوند؛ دیتابیس و تنظیمات پاک نمی‌شوند.

---

## حذف

همان دستور نصب → گزینه **3) Remove**

---

## دامنه و SSL

1. در DNS یک رکورد **A** بسازید: `your-sub.domain.tld` → IP سرور  
2. اگر Cloudflare است: Proxy روی **DNS only** (ابر خاکستری)  
3. Nameserver دامنه باید درست به Cloudflare (یا DNS شما) اشاره کند  
4. در منو: **4) Reset → Set domain + auto SSL** یا **5) Renew SSL**

دستی:

```bash
certbot --apache -d your-sub.domain.tld --non-interactive --agree-tos --register-unsafely-without-email --redirect
```

وبهوک‌ها را بعد از SSL دوباره ثبت کنید: منو → **4) Reset → 1) webhooks**

---

## بله‌پی (منطق پرداخت)

| کاربر | رفتار |
|--------|--------|
| **بله** | `sendInvoice` با `provider_token` بله‌پی — پرداخت داخل چت بله |
| **تلگرام** | ثبت سفارش + لینک/دکمه باز کردن ربات در بله (`https://ble.ir/...`) |

تنظیمات لازم در پنل ادمین ربات (بخش مالی → بله‌پی):

- توکن پرداخت (`merchant_balepay`)
- وضعیت روشن (`onbalepay`)
- حداقل / حداکثر مبلغ

جزئیات کامل منطق در مستندات پروژه با عنوان **«منطق پرداخت بله‌پی در ربات»** نگهداری می‌شود.

---

## کارت‌به‌کارت

- حداقل یک کارت در پنل ادمین ثبت شود  
- پس از انتخاب مبلغ و روش «کارت به کارت»، شماره کارت و فاکتور نمایش داده می‌شود  
- از v1.8.1 اگر مبلغ خارج از بازه باشد، دوباره مبلغ گرفته می‌شود (گیر نمی‌کند)

---

## دستورات CLI

```bash
# از طریق manage.sh یا بعد از لینک شدن:
mirza_vali install
mirza_vali update
mirza_vali remove
mirza_vali reset
mirza_vali renew
mirza_vali status
mirza_vali help
```

---

## عیب‌یابی سریع

```bash
# دیتابیس و config
php -r 'require "/var/www/mirza_vali/config.php"; echo "DB_OK\n";'

# جداول (اگر setting نبود)
cd /var/www/mirza_vali && php table.php

# وضعیت HTTP
curl -sS -o /dev/null -w "%{http_code}\n" https://YOUR_DOMAIN/index.php

# لاگ ربات
tail -30 /var/www/mirza_vali/error_log

# php-mysql برای همه نسخه‌ها
apt-get install -y php-mysql php8.2-mysql php8.4-mysql
systemctl restart apache2
```

| مشکل | اقدام |
|------|--------|
| 500 بعد از نصب | `php table.php` + نصب `php-gd` / `php-mysql` |
| DNS / SSL | `dig -4 +short DOMAIN @1.1.1.1` سپس certbot |
| وبهوک | Reset → webhooks |
| QR ساخته نمی‌شود | `php-gd` و `vendor/endroid` و مجوز نوشتن پوشه |
| QR در بله نمی‌آید | ارسال عکس روی API بله را جدا بررسی کنید |

---

## ساختار مهم روی سرور

```text
/var/www/mirza_vali/          # کد ربات
/etc/mirza_vali/install.env   # وضعیت نصب
/opt/mirza_vali-src/          # manage.sh و منبع پچ
/etc/apache2/sites-enabled/   # vhost دامنه و پورت 8091
```

---

## فایل‌های ریپو (آپلود GitHub)

| فایل | نقش |
|------|-----|
| `install.sh` | بوت‌استرپ یک‌خطی |
| `mirza_vali-latest.zip` | پکیج کامل (manage + patch) |
| `README.md` | همین راهنما |
| `generate-installer.html` | صفحه راهنمای وب (اختیاری) |

---

## تفاوت با میرزای رسمی

| | mirzabot رسمی | mirza_vali |
|--|---------------|------------|
| پیام‌رسان | عمدتاً تلگرام | تلگرام **+ بله** |
| بله‌پی | — | دارد |
| منوی نصب | Install / Update / Remove / Migrate Pro / SSL | مشابه + Reset دامنه/وبهوک (بدون Migrate Pro) |
| مسیر پیش‌فرض | مسیر رسمی میرزا | `/var/www/mirza_vali` |
| تداخل Apache | سرور تمیز توصیه‌شده | پورت و vhost جدا برای هم‌زیستی |

---

## مجوز و منبع

بر پایه ساختار ربات میرزا؛ سفارشی‌سازی‌شده برای استقرار دوپلتفرمه و درگاه بله.

**نصب سریع:**

```bash
curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh | sudo bash
```
