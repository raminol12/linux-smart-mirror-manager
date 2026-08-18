# 🐧 Linux Smart Mirror Manager

ابزار Bash برای **تست، مقایسه، رتبه‌بندی و مدیریت Mirrorهای APT** در Ubuntu و Debian، با تمرکز ویژه روی سرورهای داخل ایران.

## ⚡ نصب سریع

برای نصب و آماده‌سازی پروژه فقط یک دستور اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main/install.sh | sudo bash
```

بعد از نصب:

```bash
smart-mirror
```

### 🔄 به‌روزرسانی

همین دستور را دوباره اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main/install.sh | sudo bash
```

اگر پروژه قبلاً نصب شده باشد، Installer آن را به‌روزرسانی می‌کند.

---

## 📦 نصب دستی

```bash
git clone https://github.com/raminol12/linux-smart-mirror-manager.git
cd linux-smart-mirror-manager
chmod +x smart-mirror.sh
sudo ./smart-mirror.sh
```

---

## ✨ امکانات

- 🇮🇷 انتخاب و تست تمام Mirrorهای ایرانی
- 🌍 انتخاب و تست تمام Mirrorهای خارجی
- 🔀 تست تمام Mirrorهای ایرانی و خارجی با هم
- 🎯 انتخاب دستی Mirrorها با شماره و بازه
- 📡 بررسی واقعی `dists/<codename>/Release`
- ⚡ اندازه‌گیری Latency
- 📥 اندازه‌گیری سرعت دریافت metadata
- 🏆 رتبه‌بندی Mirrorهای موفق بر اساس سرعت
- 📝 ذخیره گزارش هر تست
- 💾 Backup خودکار تنظیمات APT قبل از تغییر
- 🚀 اعمال بهترین Mirror موفق تست قبلی
- 🔄 Restore آخرین Backup
- 🐧 پشتیبانی از Ubuntu و Debian

---

## 🧭 منوی اصلی

```text
1) Select all Iranian mirrors
2) Select all foreign mirrors
3) Select all Iranian + foreign mirrors
4) Manual mirror selection
5) Show available mirrors
6) Apply best mirror from last test
7) Restore latest APT backup
0) Exit
```

تمام گزینه‌های منو عمداً انگلیسی هستند.

### گزینه 1
تمام Mirrorهای موجود در `mirrors-iran.txt` را انتخاب و تست می‌کند.

### گزینه 2
تمام Mirrorهای موجود در `mirrors-foreign.txt` را انتخاب و تست می‌کند.

### گزینه 3
تمام Mirrorهای ایرانی و خارجی را با هم تست می‌کند.

### گزینه 4
انتخاب دستی؛ مثال:

```text
1,3,5,8
```

یا:

```text
1-10
```

یا ترکیبی:

```text
1-5,8,12-15
```

### گزینه 6
بعد از تست، سریع‌ترین Mirror موفق را از آخرین گزارش پیدا می‌کند، قبل از اعمال از کاربر تأیید می‌گیرد، از تنظیمات APT Backup می‌سازد و سپس یک فایل مدیریت‌شده برای Mirror ایجاد می‌کند.

### گزینه 7
آخرین Backup ذخیره‌شده را برمی‌گرداند.

---

## 🔍 روش تست

برای هر Mirror ابتدا فایل Release مربوط به Codename سیستم بررسی می‌شود.

مثلاً برای Ubuntu 22.04:

```text
dists/jammy/Release
```

و برای Debian 12:

```text
dists/bookworm/Release
```

اگر HTTP status برابر `200` باشد، Mirror موفق محسوب می‌شود. سپس Latency و سرعت دریافت metadata اندازه‌گیری می‌شود.

در پایان، Mirrorهای موفق بر اساس سرعت مرتب می‌شوند.

---

## 🇮🇷 Mirrorهای ایران

لیست Mirrorهای ایران در:

```text
mirrors-iran.txt
```

قرار دارد.

این لیست شامل Mirrorهای Ubuntu و Debian است و منابع شناخته‌شده‌ای مانند ArvanCloud، Pardis، Sharif، IUT، LinuxMirrors.ir و Petiak را دربرمی‌گیرد.

## 🌍 Mirrorهای خارجی

لیست Mirrorهای خارجی در:

```text
mirrors-foreign.txt
```

قرار دارد.

این فایل شامل Mirrorهای عمومی و شناخته‌شده Ubuntu و Debian در نقاط مختلف جهان است.

فرمت هر خط:

```text
Name|Country|Distribution|URL
```

خطوطی که با `#` شروع شوند Comment هستند.

> وضعیت Mirrorها ممکن است تغییر کند. خود برنامه قبل از استفاده، Mirror را از روی سرور مقصد تست می‌کند.

---

## 💾 Backup و گزارش‌ها

Backupها در:

```text
/root/smart-mirror/backups/
```

و گزارش‌ها در:

```text
/root/smart-mirror/reports/
```

ذخیره می‌شوند.

آخرین گزارش نیز در:

```text
/root/smart-mirror/last-report
```

نگهداری می‌شود.

---

## 📁 ساختار پروژه

```text
linux-smart-mirror-manager/
├── smart-mirror.sh
├── install.sh
├── mirrors-iran.txt
├── mirrors-foreign.txt
├── README.md
├── README-fa.md
├── LICENSE
└── .gitignore
```

---

## 🖥️ سیستم‌عامل‌های پشتیبانی‌شده

- Ubuntu
- Debian

پیش‌نیازهای اصلی:

- Bash
- curl
- apt-get
- ابزارهای استاندارد لینوکس
- دسترسی root

---

## ⚠️ نکات مهم

سرعت Mirror به موقعیت سرور، ISP، Routing، DNS، IPv4/IPv6، Packet Loss، شلوغی شبکه و وضعیت لحظه‌ای Mirror وابسته است.

بنابراین بهترین Mirror برای یک سرور ممکن است برای سرور دیگری متفاوت باشد.

قبل از تغییر Repository روی سرور Production حتماً Backup داشته باشید.

همچنین برنامه Repositoryهای شخص ثالث را عمداً تغییر نمی‌دهد؛ اعمال Mirror از طریق فایل مدیریت‌شده `99-smart-mirror.list` انجام می‌شود.

---

## 🗺️ Roadmap

- [ ] تست DNS
- [ ] تست Packet Loss
- [ ] تست IPv4 و IPv6
- [ ] Benchmark چندمرحله‌ای
- [ ] تست موازی Mirrorها
- [ ] خروجی JSON و CSV
- [ ] تاریخچه نتایج
- [ ] امتیازدهی هوشمند
- [ ] Failover خودکار
- [ ] به‌روزرسانی خودکار لیست Mirrorها

---

## 🤝 مشارکت

برای اضافه کردن Mirror معتبر، رفع Bug یا توسعه قابلیت‌های جدید می‌توانید Pull Request ارسال کنید.

## 📄 License

این پروژه تحت مجوز MIT منتشر شده است.

## 🔗 Repository

https://github.com/raminol12/linux-smart-mirror-manager

⭐ اگر پروژه برایتان مفید بود، به Repository ستاره بدهید.
