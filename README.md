# mirza_vali

ربات فروش و مدیریت اشتراک **VPN** برای **تلگرام + بله**

**نسخه فعلی: 1.8.35**

---

## مسیرهای ثابت سرور

| مورد | مسیر |
|------|------|
| نصب ربات | **`/home/mirza_vali`** |
| سورس منوی مدیریت | `/opt/mirza_vali-src` |
| تنظیمات نصب | `/etc/mirza_vali/install.env` |
| دامنه ربات | `mirzavali.silentping.ir` |
| پنل ایلان (نمایش به کاربر) | `http://panel.silentping.ir:8050` |
| ریپو گیت‌هاب | [silent4time/mirza_vali](https://github.com/silent4time/mirza_vali) |

> پیش‌فرض نصب **`/home/mirza_vali`** است (نه `/var/www/...`).  
> پس از نصب/آپدیت، پوشه قدیمی `/var/www/mirza_vali` در صورت وجود پاک می‌شود.

---

## درباره پروژه

`mirza_vali` فورک سفارشی بر پایه ربات متن‌باز **میرزا (mirzabot)** است؛ برای فروش VPN، مدیریت پنل، کیف پول و درگاه‌های پرداخت. علاوه بر تلگرام، **بله** و **بله‌پی** پشتیبانی می‌شود.

### تشکر از سازنده اصلی

با سپاس از سازنده ربات اصلی **میرزا**:

- ریپو: [https://github.com/mahdiMGF2/mirzabot](https://github.com/mahdiMGF2/mirzabot)

---

## امکانات

| بخش | توضیح |
|-----|--------|
| تلگرام + بله | دیتابیس مشترک، وب‌هوک جدا |
| بله‌پی | پرداخت در بله؛ از تلگرام لینک ربات بله |
| کارت‌به‌کارت | حداقل/حداکثر، رسید، تأیید ادمین |
| پنل‌ها | Marzban، X-UI، Hiddify، … |
| **ایلان (Eylan)** | OpenVPN / L2TP / Cisco / WireGuard / Multi |
| Apache + SSL | بدون تداخل با Nginx |
| منوی مدیریت | نصب، آپدیت، حذف، ریست، SSL، وضعیت |

---

## پنل ایلان

برای هر پروتکل یک ردیف با `type=eylan` و **inboundid**:

| inboundid | خروجی ربات |
|-----------|------------|
| `openvpn` | فایل‌های `.ovpn` + صفحه کاربری |
| `wireguard` | فایل `.conf` + QR (هر instance موجود در API) |
| `l2tp` | سرور / یوزر / رمز / PSK |
| `cisco` | سرور / یوزر / رمز |
| `multi` | ترکیب موارد بالا |

- لینک کاربر: همیشه `http://panel.silentping.ir:8050/...` (پورت **8050**)
- دامنه API داخلی (`mirzavalibot`) به کاربر نشان داده **نمی‌شود**
- PSK پیش‌فرض اگر از API نیاید: `123456`

**WireGuard چند instance:** ربات از `wg1_files` و در صورت وجود از مسیرهای download هر instance کانفیگ می‌گیرد. اگر پنل برای `wg2` فقط در UI فایل بدهد و APIی `download_wg2` برابر ۴۰۴ باشد، فقط کانفیگ‌هایی که API برمی‌گرداند ارسال می‌شوند.

---

## نصب یک‌خطی

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh)
```

از منو: **1) Install** — مسیر پیش‌فرض: `/home/mirza_vali`

---

## آپدیت از منو

```bash
cd /opt/mirza_vali-src && bash manage.sh
# گزینه 2) Update
```

---

## آپدیت دستی از زیپ (روی سرور)

زیپ را مثلاً در `/root/` بگذارید، سپس:

```bash
cd /tmp && rm -rf mvfix && mkdir mvfix && cd mvfix
unzip -qo /root/mirza_vali_v1.8.35.zip
ls -la
unzip -qo mirza_vali-latest.zip
ls -la patch/Eylan.php VERSION manage.sh

# کپی پچ روی مسیر نصب
cp -f patch/Eylan.php patch/function.php patch/index.php \
      patch/apply_eylan_panels.php patch/eylan_diag.php patch/eylan_wg_diag.php \
      /home/mirza_vali/ 2>/dev/null || true
cp -f patch/*.php /home/mirza_vali/ 2>/dev/null || true
cp -f VERSION /home/mirza_vali/VERSION
cp -f manage.sh /opt/mirza_vali-src/manage.sh
chmod +x /opt/mirza_vali-src/manage.sh

cd /home/mirza_vali
php apply_eylan_panels.php 2>/dev/null || true
php -l Eylan.php && cat VERSION
```

> همیشه بعد از `unzip` با `ls` مطمئن شوید فایل‌ها هستند؛ بعد `cp` بزنید.

---

## ساختار فایل‌های گیت‌هاب (آپلود وب)

| فایل در ریشه ریپو | نقش |
|-------------------|-----|
| `install.sh` | نصب‌کننده یک‌خطی |
| `mirza_vali-latest.zip` | کل پروژه آخرین نسخه (manage + patch + VERSION + README) |
| `README.md` | همین مستند — **با هر نسخه باید هم‌خوان باشد** |
| `generate-installer.html` | صفحه تولید دستور نصب |

داخل `mirza_vali-latest.zip`:

- `manage.sh` — منوی مدیریت (مسیر پیش‌فرض `/home/mirza_vali`)
- `VERSION` — شماره نسخه
- `patch/` — کد PHP ربات (Eylan.php، function.php، index.php، …)
- `README.md`، `install.sh`

---

## پشتیبانی / دونیت

**TON / USDT (TON):**

```text
UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
```

(آدرس ولت خود را جایگزین کنید.)

---

## لایسنس

استفاده قانونی و مدیریت سرویس خودتان. مسئولیت سرور، دامنه، SSL و قوانین محلی با شماست.

ریپو: [https://github.com/silent4time/mirza_vali](https://github.com/silent4time/mirza_vali)
