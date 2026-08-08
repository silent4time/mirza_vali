# mirza_vali

ربات فروش و مدیریت اشتراک **VPN** برای **تلگرام + بله**

نسخه فعلی: **1.8.22**

---

## درباره پروژه

`mirza_vali` یک فورک سفارشی بر پایه ربات متن‌باز **میرزا (mirzabot)** است که برای فروش سرویس‌های VPN، مدیریت پنل‌ها، کیف پول و درگاه‌های پرداخت طراحی شده و علاوه بر تلگرام، پیام‌رسان **بله** و درگاه **بله‌پی** را پشتیبانی می‌کند.

### تشکر از سازنده اصلی

با سپاس ویژه از تیم و سازنده ربات اصلی **میرزا**:

- ریپوی اصلی: [https://github.com/mahdiMGF2/mirzabot](https://github.com/mahdiMGF2/mirzabot)

بدون زحمت ایشان این سفارشی‌سازی ممکن نبود.

---

## امکانات اصلی

| بخش | توضیح |
|-----|--------|
| تلگرام + بله | یک دیتابیس مشترک، وب‌هوک جدا |
| بله‌پی | پرداخت از بله و راهنما از تلگرام به بله |
| کارت‌به‌کارت | با حداقل/حداکثر و ارسال رسید |
| پنل‌های متعدد | Marzban، X-UI، Hiddify، و ... |
| **ایلان (Eylan)** | OpenVPN / L2TP / Cisco / WireGuard / Multi |
| Apache + SSL | نصب بدون تداخل Nginx |
| منوی مدیریت | نصب، آپدیت، حذف، ریست، SSL |

---

## پنل ایلان — پروتکل‌ها

برای هر پروتکل یک ردیف پنل با `type=eylan` و فیلد **inboundid**:

| inboundid | خروجی |
|-----------|--------|
| `openvpn` | فایل‌های `.ovpn` + صفحه کاربری |
| `wireguard` | فایل `.conf` + QR کانفیگ |
| `l2tp` | سرور / یوزر / رمز / PSK |
| `cisco` | سرور / یوزر / رمز |
| `multi` | ترکیب موارد بالا |

- آدرس نمایشی برای کاربر: `http://panel.silentping.ir:8050/...`
- دامنه API داخلی (`mirzavalibot`) به کاربر نشان داده نمی‌شود.
- PSK پیش‌فرض در صورت نبود از API: `123456`

---

## نصب یک‌خطی

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/silent4time/mirza_vali/main/install.sh)
```

سپس از منو گزینه **1) Install** را بزنید.

### آپدیت

```bash
bash /opt/mirza_vali-src/manage.sh
# گزینه 2) Update
```

یا دستی از آخرین زیپ:

```bash
cd /tmp && rm -rf mvfix && mkdir mvfix && cd mvfix
curl -fsSL -o latest.zip "https://raw.githubusercontent.com/silent4time/mirza_vali/main/mirza_vali-latest.zip"
unzip -qo latest.zip && cat VERSION
cp -f patch/*.php /var/www/mirza_vali/ 2>/dev/null || true
cp -f patch/Eylan.php patch/function.php patch/index.php patch/apply_eylan_panels.php /var/www/mirza_vali/
cp -f VERSION /var/www/mirza_vali/VERSION
cp -f patch/version /var/www/mirza_vali/version
cd /var/www/mirza_vali && php apply_eylan_panels.php
```

---

## ساختار ریپو (آپلود وب گیت‌هاب)

| فایل | نقش |
|------|-----|
| `install.sh` | نصب‌کننده یک‌خطی |
| `mirza_vali-latest.zip` | کد کامل آخرین نسخه |
| `README.md` | همین مستند |
| `generate-installer.html` | تولید دستور نصب |

---

## دونیت / حمایت مالی

اگر از این پروژه استفاده می‌کنید و مایل به حمایت هستید:

**TON / USDT (TON network):**

```text
UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA  # ← آدرس ولت خود را اینجا بگذارید
```

یا لینک مستقیم (پس از قرار دادن آدرس واقعی):

```text
https://tonkeeper.com/transfer/YOUR_WALLET_ADDRESS
```

---

## لایسنس و سلب مسئولیت

این پروژه برای استفاده قانونی و مدیریت سرویس‌های خودتان است. مسئولیت پیکربندی سرور، دامنه، SSL و رعایت قوانین محلی با شماست.

---

## تماس / ریپو

- GitHub: [https://github.com/silent4time/mirza_vali](https://github.com/silent4time/mirza_vali)
- دامنه نمونه پنل: `panel.silentping.ir`
