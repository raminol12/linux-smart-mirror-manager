# Linux Smart Mirror Manager

راهنمای فارسی پروژه.

## نصب تک‌خطی

```bash
curl -fsSL https://raw.githubusercontent.com/raminol12/linux-smart-mirror-manager/main/install.sh | sudo bash
```

پس از نصب:

```bash
smart-mirror
```

برای به‌روزرسانی نیز همین دستور را دوباره اجرا کنید.

## امکانات

- تست Mirrorهای ایرانی
- تست Mirrorهای خارجی
- انتخاب دستی Mirrorها
- تست Repository واقعی
- اندازه‌گیری زمان پاسخ و سرعت دریافت
- Benchmark
- Backup و Restore
- مدیریت Repositoryهای APT
- پشتیبانی از Ubuntu و Debian

## انتخاب دستی

```text
1,3,5,8
1-8
1-5,10,13-16
```

## ساختار پروژه

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

## فایل Mirrorها

فرمت هر خط:

```text
Name|Country|Distribution|URL
```

Mirrorهای ایران در `mirrors-iran.txt` و Mirrorهای خارجی در `mirrors-foreign.txt` قرار می‌گیرند.

## نکته

نتیجه تست به موقعیت سرور، ISP، Routing، DNS، IPv4/IPv6، Packet Loss و وضعیت لحظه‌ای Mirror وابسته است.

قبل از استفاده از Mirrorهای شخص ثالث در Production، URL آنها را بررسی کنید.

## Repository

https://github.com/raminol12/linux-smart-mirror-manager
