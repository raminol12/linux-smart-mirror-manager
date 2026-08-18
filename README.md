# 🐧 Linux Smart Mirror Manager

ابزار Bash برای **تست، مقایسه، رتبه‌بندی و مدیریت Mirrorهای APT** در Ubuntu و Debian، با تمرکز ویژه روی سرورهای داخل ایران.

## ⚡ نصب سریع

برای نصب یا به‌روزرسانی فقط یک دستور اجرا کنید:

```bash
curl -4 -fsSL https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main/install.sh | sudo bash
```

بعد از پایان نصب:

```bash
smart-mirror
```

> Installer تعاملی نیست و هنگام نصب وارد منوی برنامه نمی‌شود. فایل‌های اصلی را مستقیم از GitHub دریافت می‌کند.

---

## 🎛️ منوی اصلی

```text
==============================================================
              Linux Smart Mirror Manager
==============================================================
OS       : ubuntu
Codename : jammy
Mirrors  : 30  |  Selected: 0
==============================================================

  1) Select mirrors manually
  2) Test all Iranian mirrors
  3) Test all foreign mirrors
  4) Test all Iranian + foreign mirrors
  5) Test currently selected mirrors
  6) Show available mirrors
  7) Apply best mirror from last test
  8) Restore latest APT backup
  0) Exit
```

منو با رنگ‌بندی ANSI در ترمینال نمایش داده می‌شود.

### 1) Select mirrors manually

ابتدا تمام Mirrorها نمایش داده می‌شوند و می‌توانید هر Mirror را با شماره انتخاب کنید.

مثال:

```text
1,3,5-8
```

یعنی Mirrorهای 1، 3 و بازه 5 تا 8 انتخاب می‌شوند.

این انتخاب می‌تواند ترکیبی از Mirrorهای ایرانی و خارجی باشد.

### 2) Test all Iranian mirrors

تمام Mirrorهای موجود در `mirrors-iran.txt` را فقط تست می‌کند.

### 3) Test all foreign mirrors

تمام Mirrorهای موجود در `mirrors-foreign.txt` را فقط تست می‌کند.

### 4) Test all Iranian + foreign mirrors

هر دو لیست را با هم تست می‌کند.

### 5) Test currently selected mirrors

فقط Mirrorهایی را که با گزینه 1 انتخاب کرده‌اید تست می‌کند.

### 6) Show available mirrors

فهرست کامل Mirrorهای موجود را نمایش می‌دهد.

### 7) Apply best mirror from last test

سریع‌ترین Mirror موفق آخرین تست را انتخاب می‌کند، قبل از اعمال از شما تأیید می‌گیرد و قبل از تغییر APT Backup ایجاد می‌کند.

### 8) Restore latest APT backup

آخرین Backup تنظیمات APT را برمی‌گرداند.

---

## 🔍 نمایش مرحله‌به‌مرحله تست

هنگام تست، وضعیت هر Mirror به‌صورت زنده در ترمینال نمایش داده می‌شود:

```text
Mirror 3/16  [##########----------------------------]  25%
  Name   : Ubuntu Germany
  Region : DE
  URL    : https://...
  ----------------------------------------------------
  [OK] Operating-system compatibility
  [OK] Connectivity / HTTP
  [OK] Release file: jammy/Release
  [OK] Download speed
  [OK] Result: OK | Latency: 91ms | Speed: 18.42 MB/s
```

رنگ‌ها:

- 🟢 سبز = موفق
- 🔴 قرمز = خطا
- 🟡 زرد = در حال تست
- 🔵 آبی/فیروزه‌ای = اطلاعات و عنوان‌ها
- 🟣 بنفش = اطلاعات انتخاب فعلی

### مراحل تست هر Mirror

1. بررسی سازگاری Distribution
2. بررسی اتصال و HTTP
3. بررسی `dists/<codename>/Release`
4. اندازه‌گیری سرعت دریافت Metadata
5. ثبت Latency
6. ثبت نتیجه نهایی

در پایان، خلاصه و سریع‌ترین Mirrorهای موفق نمایش داده می‌شوند.

---

## 📊 گزارش تست

گزارش هر تست در مسیر زیر ذخیره می‌شود:

```text
/root/smart-mirror/reports/
```

آخرین گزارش:

```text
/root/smart-mirror/last-report
```

---

## 🇮🇷 Mirrorهای ایران

لیست Mirrorهای ایران در فایل زیر قرار دارد:

```text
mirrors-iran.txt
```

فرمت:

```text
Name|Country|Distribution|URL
```

## 🌍 Mirrorهای خارجی

لیست Mirrorهای خارجی در:

```text
mirrors-foreign.txt
```

قرار دارد.

---

## 💾 Backup

قبل از اعمال Mirror جدید، تنظیمات APT در مسیر زیر Backup می‌شوند:

```text
/root/smart-mirror/backups/
```

برنامه Repositoryهای شخص ثالث را عمداً مدیریت نمی‌کند.

---

## 📦 نصب دستی

```bash
git clone https://github.com/raminol12/linux-smart-mirror-manager.git
cd linux-smart-mirror-manager
chmod +x smart-mirror.sh
sudo ./smart-mirror.sh
```

---

## 🖥️ سیستم‌عامل‌های پشتیبانی‌شده

- Ubuntu
- Debian

پیش‌نیازها:

- Bash
- curl
- awk
- apt-get
- ابزارهای استاندارد لینوکس
- دسترسی root

---

## ⚠️ نکات مهم

بهترین Mirror برای هر سرور می‌تواند متفاوت باشد؛ Latency، Routing، ISP، Packet Loss، DNS و وضعیت لحظه‌ای Mirror روی نتیجه تأثیر دارند.

قبل از تغییر Repository روی سرور Production حتماً Backup ایجاد کنید.

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

## 📄 License

MIT

## 🔗 Repository

https://github.com/raminol12/linux-smart-mirror-manager
