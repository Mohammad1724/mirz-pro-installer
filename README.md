# Mirza Pro Installer

یک اسکریپت نصب قدرتمند و آسان برای پنل ربات تلگرام Mirza Pro

![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2FDebian-orange.svg)

---

## ✨ امکانات

| امکان | توضیحات |
|-------|---------|
| 📦 **نصب یک کلیکی** | نصب کامل با یک دستور |
| 🗑️ **حذف کامل** | پاکسازی کامل همه فایل‌ها و دیتابیس |
| 🔄 **آپدیت** | آپدیت از GitHub با حفظ تنظیمات |
| 💾 **بکاپ‌گیری** | بکاپ کامل از فایل‌ها و دیتابیس |
| 📂 **بازیابی** | ریستور از هر نقطه بکاپ |
| 📋 **مشاهده لاگ** | لاگ‌های Apache، PHP و سیستم |
| 📡 **مانیتور زنده** | رصد لحظه‌ای لاگ‌ها |
| 📊 **وضعیت سرویس‌ها** | بررسی سرویس‌ها و منابع سرور |
| 🔃 **ریستارت سرویس** | ریستارت Apache، MariaDB، PHP |
| ⚙️ **تنظیمات ربات** | تغییر توکن، ادمین، دامنه |
| 🔗 **مدیریت Webhook** | بررسی، ریست یا حذف وبهوک |

---

## 📋 پیش‌نیازها

- Ubuntu 20.04 / 22.04 / 24.04 یا Debian 11 / 12
- دسترسی root
- دامنه متصل به سرور
- حداقل 1GB رم
- حداقل 10GB فضای دیسک

---

## 🚀 نصب

### نصب سریع (پیشنهادی)

```bash
bash <(curl -s https://raw.githubusercontent.com/Mohammad1724/mirz-pro-installer/main/install.sh)
```

نصب دستی

# دانلود اسکریپت
```
curl -O https://raw.githubusercontent.com/Mohammad1724/mirz-pro-installer/main/install.sh
```

# دادن دسترسی اجرا
```
chmod +x install.sh
```
# اجرا
```
./install.sh

```


📁 مسیر فایل‌ها
فایل/پوشه	مسیر
محل نصب	/var/www/mirzapro
کانفیگ	/var/www/mirzapro/config.php
بکاپ‌ها	/root/mirza_backups
لاگ منیجر	/var/log/mirza_manager.log
رمز دیتابیس	/root/mirza_pass.txt
کانفیگ Apache	/etc/apache2/sites-available/mirzapro.conf


بررسی وضعیت سرویس‌ها
```Bash

systemctl status apache2
systemctl status mariadb

```
مشاهده لاگ خطا
```Bash

tail -f /var/log/apache2/mirza_error.log

```
تست اتصال دیتابیس
```Bash

mysql -u mirza_user -p mirzapro

```
