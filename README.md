# 🐧 Linux Smart Mirror Manager

ابزار هوشمند Bash برای **تست، مقایسه و مدیریت Mirrorهای APT** در Ubuntu و Debian، با تمرکز ویژه روی سرورهای داخل ایران.

## ⚡ نصب سریع

برای نصب و آماده‌سازی پروژه فقط **یک دستور** اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main/install.sh | sudo bash
```

بعد از نصب، برنامه را اجرا کنید:

```bash
smart-mirror
```

### 🔄 به‌روزرسانی

برای دریافت آخرین نسخه نیز همین دستور را دوباره اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main/install.sh | sudo bash
```

اگر پروژه قبلاً نصب شده باشد، Installer آن را به‌روزرسانی می‌کند.

---

## 📦 نصب دستی

در صورت تمایل به نصب دستی:

```bash
git clone https://github.com/raminol12/linux-smart-mirror-manager.git
cd linux-smart-mirror-manager
chmod +x smart-mirror.sh
sudo ./smart-mirror.sh
```

---

## ✨ امکانات

- 🇮🇷 تست Mirrorهای ایرانی
- 🌍 تست Mirrorهای خارجی
- 🎯 انتخاب دستی Mirrorها قبل از شروع تست
- 🔀 تست Mirrorهای ایران و خارج
- 📡 بررسی واقعی Repository و فایل Release
- ⚡ اندازه‌گیری زمان پاسخ
- 📥 بررسی سرعت دریافت Repository metadata
- 🏆 مقایسه نتایج Mirrorها
- 💾 Backup قبل از تغییر Repository
- 🔄 Restore تنظیمات قبلی
- 📝 ذخیره گزارش تست
- 🐧 پشتیبانی از Ubuntu و Debian

---

## 🧭 منوی اصلی

```text
1) Test Iranian mirrors
2) Test foreign mirrors
3) Test Iranian + foreign mirrors
4) Manual mirror selection
5) Show available mirrors
6) Restore backup
0) Exit
```

تمام متن گزینه‌های منو عمداً انگلیسی است.

---

## 🎯 انتخاب دستی Mirrorها

با انتخاب گزینه زیر:

```text
4) Manual mirror selection
```

می‌توانید مشخص کنید کدام Mirrorها تست شوند.

چند مورد:

```text
1,3,5,8,13
```

یک بازه:

```text
1-8
```

ترکیبی:

```text
1-5,10,13-16
```

---

## 🔍 روش تست

برای هر Mirror، ابتدا دسترسی واقعی به Repository بررسی می‌شود. سپس زمان پاسخ و سرعت دریافت metadata اندازه‌گیری می‌شود.

برای Ubuntu، فایل Release مربوط به Codename سیستم مانند زیر بررسی می‌شود:

```text
dists/jammy/Release
```

برای Debian نیز Codename سیستم استفاده می‌شود.

---

## 💾 Backup و گزارش‌ها

Backup تنظیمات APT در مسیر زیر ذخیره می‌شود:

```text
/root/smart-mirror/backups/
```

گزارش‌های تست در مسیر زیر قرار می‌گیرند:

```text
/root/smart-mirror/reports/
```

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

## 🇮🇷 Mirrorهای ایران

لیست Mirrorهای ایران در فایل زیر قرار دارد:

```text
mirrors-iran.txt
```

## 🌍 Mirrorهای خارجی

لیست Mirrorهای خارجی در فایل زیر قرار دارد:

```text
mirrors-foreign.txt
```

فرمت هر خط:

```text
Name|Country|Distribution|URL
```

خطوطی که با `#` شروع شوند Comment هستند.

> وضعیت Mirrorها ممکن است تغییر کند. قبل از استفاده در Production، معتبر بودن URL و وضعیت Mirror را بررسی کنید.

---

## 🖥️ سیستم‌عامل‌های پشتیبانی‌شده

- Ubuntu
- Debian

---

## ⚠️ نکات مهم

نتیجه تست به موقعیت سرور، ISP، Routing، DNS، IPv4/IPv6، Packet Loss، شلوغی شبکه و وضعیت لحظه‌ای Mirror وابسته است. بنابراین سریع‌ترین Mirror روی یک سرور الزاماً روی سرور دیگری سریع‌ترین گزینه نیست.

قبل از تغییر Repository روی سرور Production از تنظیمات خود Backup داشته باشید.

---

## 🗺️ Roadmap

- [ ] پشتیبانی از Arch Linux
- [ ] پشتیبانی از Fedora
- [ ] پشتیبانی از Rocky Linux
- [ ] تست DNS
- [ ] تست Packet Loss
- [ ] تست IPv4 و IPv6
- [ ] Benchmark پیشرفته
- [ ] خروجی JSON و CSV
- [ ] تاریخچه نتایج
- [ ] امتیازدهی هوشمند Mirrorها
- [ ] Failover خودکار

---

## 🤝 مشارکت

برای اضافه کردن Mirror معتبر، رفع Bug یا توسعه قابلیت‌های جدید می‌توانید Pull Request ارسال کنید.

## 📄 License

این پروژه تحت مجوز MIT منتشر شده است.

## 🔗 Repository

https://github.com/raminol12/linux-smart-mirror-manager

⭐ اگر پروژه برایتان مفید بود، به Repository ستاره بدهید.
