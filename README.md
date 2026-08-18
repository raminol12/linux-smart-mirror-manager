# 🐧 Linux Smart Mirror Manager

ابزار هوشمند برای **تست، بررسی، مقایسه، Benchmark و مدیریت Mirrorهای لینوکس** با استفاده از Bash.

این پروژه برای سرورهایی طراحی شده است که دسترسی اینترنت آن‌ها، مخصوصاً دسترسی بین‌الملل، ناپایدار یا محدود است و انتخاب یک Repository مناسب می‌تواند سرعت نصب و به‌روزرسانی Packageها را به شکل قابل توجهی بهتر کند.

---

## ✨ امکانات

* 🇮🇷 تست Mirrorهای ایرانی
* 🌍 تست Mirrorهای خارجی
* 🎯 انتخاب دستی Mirrorهای مورد نظر
* 🔀 تست هم‌زمان Mirrorهای ایران و خارج
* 📡 بررسی اتصال به Repository
* ⚡ اندازه‌گیری Latency
* 📥 بررسی سرعت دریافت اطلاعات Repository
* 🏆 شناسایی سریع‌ترین Mirror
* 📊 نمایش نتایج به صورت جدول
* 🔬 Benchmark چندمرحله‌ای
* 💾 تهیه Backup قبل از تغییر Repository
* 🔄 امکان Restore کردن تنظیمات قبلی
* 🚀 اعمال Mirror انتخاب‌شده روی APT
* 🔍 اجرای خودکار `apt update`
* 🛡️ امکان Rollback در صورت شکست `apt update`
* 📝 ذخیره گزارش تست
* 📁 نگهداری لیست Mirrorها در فایل‌های جداگانه
* 🐧 پشتیبانی از Ubuntu و Debian

---

## 🎯 هدف پروژه

در بسیاری از سرورهای داخل ایران، استفاده از Repositoryهای خارجی ممکن است با مشکلاتی مانند:

* سرعت پایین
* Packet Loss
* افزایش Latency
* محدودیت مسیرهای بین‌الملل
* قطعی موقت
* Timeout
* مشکلات DNS
* شلوغی Mirror

همراه باشد.

از طرف دیگر، ممکن است یک Mirror ایرانی در یک زمان خاص بسیار سریع باشد و در زمان دیگری Mirror دیگری عملکرد بهتری داشته باشد.

این پروژه به جای انتخاب یک Mirror ثابت، امکان **تست Mirrorها در همان لحظه از روی سرور مقصد** را فراهم می‌کند.

---

# 🖥️ سیستم‌عامل‌های پشتیبانی‌شده

در نسخه فعلی:

* Ubuntu
* Debian

پشتیبانی از توزیع‌های دیگر در Roadmap پروژه قرار دارد.

---

# 📋 پیش‌نیازها

برای اجرای پروژه به موارد زیر نیاز است:

* Bash
* curl
* awk
* sed
* grep
* sort
* date
* ابزارهای استاندارد لینوکس

اجرای اسکریپت به دسترسی `root` نیاز دارد؛ زیرا در صورت درخواست کاربر، Repositoryهای APT را تغییر می‌دهد.

---

# 📥 نصب

ابتدا Repository را Clone کنید:

```bash
git clone https://github.com/YOUR-USERNAME/linux-smart-mirror-manager.git
```

و وارد پوشه پروژه شوید:

```bash
cd linux-smart-mirror-manager
```

دسترسی اجرای اسکریپت را فعال کنید:

```bash
chmod +x smart-mirror.sh
```

سپس اسکریپت را اجرا کنید:

```bash
sudo ./smart-mirror.sh
```

یا:

```bash
sudo bash smart-mirror.sh
```

---

# 🧭 منوی اصلی

بعد از اجرای برنامه، منوی اصلی نمایش داده می‌شود:

```text
==============================================================
                 Linux Smart Mirror Manager
==============================================================

OS       : ubuntu 22.04
Codename : jammy
Mirrors  : 20

==============================================================

1) Test Iranian mirrors
2) Test foreign mirrors
3) Test Iranian + foreign mirrors
4) Manual mirror selection
5) Show available mirrors
6) Restore backup
0) Exit
```

---

# 🇮🇷 تست Mirrorهای ایران

با انتخاب:

```text
1) Test Iranian mirrors
```

تمام Mirrorهای ایرانی موجود در فایل `mirrors-iran.txt` که با سیستم‌عامل فعلی سازگار باشند، برای تست انتخاب می‌شوند.

قبل از شروع تست، برنامه از کاربر تأیید می‌گیرد.

---

# 🌍 تست Mirrorهای خارجی

با انتخاب:

```text
2) Test foreign mirrors
```

Mirrorهای خارجی موجود در فایل:

```text
mirrors-foreign.txt
```

برای تست انتخاب می‌شوند.

---

# 🇮🇷 + 🌍 تست همه Mirrorها

با انتخاب:

```text
3) Test Iranian + foreign mirrors
```

تمام Mirrorهای سازگار موجود در دو فایل تست خواهند شد.

این گزینه زمانی مفید است که بخواهید عملکرد Mirrorهای داخلی و خارجی را مستقیماً از روی سرور مقایسه کنید.

---

# 🎯 انتخاب دستی Mirror

یکی از امکانات مهم پروژه، انتخاب دستی Mirrorها است.

با انتخاب:

```text
4) Manual mirror selection
```

لیست Mirrorها نمایش داده می‌شود.

می‌توانید چند Mirror را به صورت هم‌زمان انتخاب کنید.

### انتخاب چند مورد

مثلاً:

```text
1,3,5,8,13
```

### انتخاب یک بازه

```text
1-8
```

### ترکیب بازه و شماره

```text
1-5,10,13-16
```

به این ترتیب فقط Mirrorهایی که مشخص کرده‌اید تست خواهند شد.

---

# 🔍 نحوه تست Mirror

برنامه فقط به Ping کردن Mirror اکتفا نمی‌کند.

برای هر Mirror ابتدا Repository واقعی بررسی می‌شود.

برای مثال در Ubuntu:

```text
dists/jammy/Release
```

و در Debian:

```text
dists/bookworm/Release
```

بررسی می‌شود.

اگر Repository در دسترس باشد، مراحل بعدی تست انجام می‌شوند.

---

# 📡 بررسی Repository

نمونه خروجی:

```text
Testing: ArvanCloud
URL: https://mirror.arvancloud.ir/ubuntu/

Repository     : OK
Latency        : 34 ms
Download Speed : 18.42 MB/s
```

اگر Repository در دسترس نباشد:

```text
Repository     : FAIL
```

Mirror در نتایج به عنوان Mirror ناموفق ثبت می‌شود.

---

# ⚡ بررسی Latency

برنامه زمان برقراری اتصال به Mirror را اندازه‌گیری می‌کند.

مثلاً:

```text
Latency : 34 ms
```

Latency پایین‌تر معمولاً به معنی مسیر ارتباطی سریع‌تر است، اما به تنهایی معیار مناسبی برای انتخاب بهترین Repository نیست.

---

# 📥 بررسی سرعت

یکی از معیارهای مهم پروژه سرعت دریافت اطلاعات Repository است.

مثلاً:

```text
Download Speed : 18.42 MB/s
```

ممکن است یک Mirror Latency بالاتری داشته باشد اما سرعت دانلود بسیار بیشتری ارائه کند.

به همین دلیل انتخاب Mirror صرفاً بر اساس Ping انجام نمی‌شود.

---

# 🏆 انتخاب سریع‌ترین Mirror

بعد از پایان تست، نتایج نمایش داده می‌شوند:

```text
====================================================================
                         TEST RESULTS
====================================================================

#   MIRROR                    REGION  LATENCY   SPEED         STATUS
------------------------------------------------------------------------
1   ArvanCloud                IRAN    34ms      18.42 MB/s    OK
2   IranServer                IRAN    41ms      14.87 MB/s    OK
3   Kernel.ir                 IRAN    37ms      11.23 MB/s    OK
4   Hetzner                   FOREIGN 92ms       6.43 MB/s    OK
```

برنامه سریع‌ترین Mirror قابل استفاده را مشخص می‌کند.

مثلاً:

```text
==============================================================
                       BEST MIRROR
==============================================================

Name    : ArvanCloud
Country : IR
Region  : IRAN
Latency : 34 ms
Speed   : 18.42 MB/s
URL     : https://mirror.arvancloud.ir/ubuntu/
```

---

# 🔬 Benchmark

برای بررسی دقیق‌تر، امکان Benchmark چندمرحله‌ای وجود دارد.

در این حالت یک Mirror چند بار تست می‌شود.

مثال:

```text
Benchmark: ArvanCloud
--------------------------------------------

Run 1 : 18.20 MB/s
Run 2 : 19.10 MB/s
Run 3 : 17.80 MB/s

Average : 18.36 MB/s
Minimum : 17.80 MB/s
Maximum : 19.10 MB/s
```

این قابلیت کمک می‌کند نتیجه‌ای که به دلیل یک نوسان لحظه‌ای شبکه ایجاد شده، ملاک انتخاب قرار نگیرد.

---

# 🚀 اعمال Mirror

برنامه بدون تأیید کاربر Repository را تغییر نمی‌دهد.

پس از تست، منوی زیر نمایش داده می‌شود:

```text
1) Apply fastest mirror
2) Apply fastest Iranian mirror
3) Apply fastest foreign mirror
4) Select mirror manually
5) Run benchmark
6) Save report
7) Run tests again
0) Back to main menu
```

برای مثال با انتخاب:

```text
1) Apply fastest mirror
```

سریع‌ترین Mirror شناسایی‌شده روی سیستم اعمال می‌شود.

---

# 💾 Backup

قبل از هرگونه تغییر در Repository، برنامه از تنظیمات فعلی Backup می‌گیرد.

Backupها در مسیر زیر ذخیره می‌شوند:

```text
/root/smart-mirror/backups/
```

برای مثال:

```text
/root/smart-mirror/backups/20260818-084500/
```

این موضوع باعث می‌شود در صورت بروز مشکل بتوان Repository قبلی را برگرداند.

---

# 🔄 Restore

در منوی اصلی گزینه زیر وجود دارد:

```text
6) Restore backup
```

با انتخاب آن Backupهای قبلی نمایش داده می‌شوند.

مثلاً:

```text
Available backups:

20260818-084500
20260817-221500
20260816-103200
```

کاربر می‌تواند Backup مورد نظر را انتخاب و تنظیمات قبلی را Restore کند.

---

# 🛡️ Rollback

بعد از اعمال Mirror، برنامه:

```bash
apt-get update
```

را اجرا می‌کند.

اگر `apt update` موفق باشد:

```text
MIRROR APPLIED SUCCESSFULLY
```

نمایش داده می‌شود.

اگر شکست بخورد، برنامه از کاربر می‌پرسد که آیا تنظیمات قبلی Restore شود یا خیر.

این قابلیت برای جلوگیری از خراب شدن Repository در سرورهای Production در نظر گرفته شده است.

---

# 📝 ذخیره گزارش

نتایج تست را می‌توان ذخیره کرد.

گزارش‌ها در مسیر زیر قرار می‌گیرند:

```text
/root/smart-mirror/reports/
```

نمونه:

```text
mirror-report-20260818-084500.txt
```

گزارش شامل اطلاعاتی مانند:

* سیستم‌عامل
* نسخه سیستم‌عامل
* تاریخ تست
* نام Mirror
* کشور
* منطقه
* Latency
* سرعت
* وضعیت Repository

است.

---

# 📁 ساختار پروژه

```text
linux-smart-mirror-manager/
│
├── smart-mirror.sh
├── mirrors-iran.txt
├── mirrors-foreign.txt
├── README.md
├── LICENSE
└── .gitignore
```

---

# 🇮🇷 فایل Mirrorهای ایران

Mirrorهای ایرانی در فایل زیر قرار دارند:

```text
mirrors-iran.txt
```

فرمت اطلاعات:

```text
Name|Country|Distribution|URL
```

مثال:

```text
ArvanCloud|IR|Ubuntu|https://mirror.arvancloud.ir/ubuntu/
```

برای اضافه کردن Mirror جدید نیازی به تغییر فایل اصلی اسکریپت نیست.

فقط یک خط جدید به فایل اضافه کنید.

---

# 🌍 فایل Mirrorهای خارجی

Mirrorهای خارجی در:

```text
mirrors-foreign.txt
```

قرار دارند.

فرمت:

```text
Name|Country|Distribution|URL
```

مثال:

```text
Hetzner|DE|Ubuntu|https://mirror.hetzner.com/ubuntu/
```

---

# ➕ اضافه کردن Mirror جدید

برای اضافه کردن Mirror جدید:

```bash
nano mirrors-iran.txt
```

یا:

```bash
nano mirrors-foreign.txt
```

سپس یک خط با ساختار زیر اضافه کنید:

```text
Mirror Name|Country|Distribution|URL
```

مثلاً:

```text
Example Mirror|IR|Ubuntu|https://example.com/ubuntu/
```

---

# ⚠️ نکات مهم

## Mirrorها ثابت نیستند

ممکن است یک Mirror امروز سرعت بسیار خوبی داشته باشد و چند ساعت یا چند روز بعد کند یا موقتاً از دسترس خارج شود.

به همین دلیل این پروژه Mirrorها را در زمان اجرای تست بررسی می‌کند.

---

## نتیجه تست به محل سرور بستگی دارد

نتیجه‌ای که روی یک سرور در ایران به دست می‌آید الزاماً روی سرور دیگری یکسان نیست.

مواردی مانند:

* موقعیت جغرافیایی
* ISP
* Routing
* DNS
* IPv4
* IPv6
* Packet Loss
* شلوغی شبکه
* وضعیت خود Mirror

روی نتیجه تأثیر دارند.

---

## تغییر Repository با مسئولیت کاربر

قبل از استفاده از Mirrorهای شخص ثالث، از معتبر بودن Repository و URL آن اطمینان حاصل کنید.

این پروژه صرفاً ابزار تست و مدیریت Repository است و مالکیت یا صحت عملکرد Mirrorهای شخص ثالث را تضمین نمی‌کند.

---

# 🗺️ نقشه راه

قابلیت‌های برنامه در آینده می‌توانند شامل موارد زیر باشند:

* [ ] پشتیبانی از Arch Linux
* [ ] پشتیبانی از Fedora
* [ ] پشتیبانی از Rocky Linux
* [ ] پشتیبانی از AlmaLinux
* [ ] شناسایی خودکار Mirrorها
* [ ] به‌روزرسانی خودکار لیست Mirrorها
* [ ] تست DNS
* [ ] مقایسه IPv4 و IPv6
* [ ] تست Packet Loss
* [ ] تست واقعی با Packageهای حجیم‌تر
* [ ] تست موازی Mirrorها
* [ ] خروجی JSON
* [ ] خروجی CSV
* [ ] رابط کاربری حرفه‌ای ترمینال
* [ ] ذخیره تاریخچه Benchmark
* [ ] امتیازدهی هوشمند به Mirrorها
* [ ] انتخاب خودکار Mirror بر اساس سابقه عملکرد
* [ ] سیستم Failover برای Mirrorها
* [ ] اجرای خودکار تست در بازه‌های زمانی مشخص

---

# 🤝 مشارکت در پروژه

اگر Mirror معتبر ایرانی یا خارجی جدیدی می‌شناسید، می‌توانید آن را به فایل مربوطه اضافه کرده و Pull Request ارسال کنید.

همچنین می‌توانید در موارد زیر مشارکت کنید:

* اضافه کردن Distribution جدید
* اضافه کردن Mirrorهای معتبر
* بهبود الگوریتم Benchmark
* بهبود تست سرعت
* بهبود مدیریت خطا
* رفع Bug
* بهبود رابط کاربری
* پیشنهاد قابلیت‌های جدید

---

# 📄 License

این پروژه تحت مجوز MIT منتشر شده است.

برای اطلاعات کامل به فایل زیر مراجعه کنید:

```text
MIT License

Copyright (c) 2026 Ramin Alidoost

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```

---

# ⭐ حمایت از پروژه

اگر این پروژه برای شما مفید بود:

* ⭐ به Repository ستاره بدهید.
* 🐛 مشکلات را در Issues گزارش کنید.
* 🔧 در توسعه پروژه مشارکت کنید.
* 📢 پروژه را با سایر مدیران سرور و Linux Administratorها به اشتراک بگذارید.

---

## 👨‍💻 Linux Smart Mirror Manager

ابزاری ساده و کاربردی برای پیدا کردن Mirror مناسب، مخصوصاً برای سرورهایی که با محدودیت یا ناپایداری دسترسی به Repositoryهای خارجی مواجه هستند.
