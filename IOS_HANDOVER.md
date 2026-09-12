# 📱 دليل تسليم وبناء تطبيق inRide لنظام iOS (Mac & Xcode Handover Guide)

هذا الدليل مخصص للمبرمج الذي سيقوم بفتح المشروع على جهاز **Mac**، وبناء أرشيف **iOS Archive** ورفع التطبيق إلى **Apple App Store Connect**.

---

## 📌 معلومات التطبيق الأساسية (App Metadata)

| البند | القيمة |
| :--- | :--- |
| **اسم التطبيق (App Name)** | `inRide` |
| **معرف الحزمة (iOS Bundle ID)** | `com.inride.app` |
| **إصدار التطبيق (Version)** | `1.0.0` |
| **رقم البناء (Build Number)** | `1` (أو `1.0.0+1`) |
| **بيئة العمل (Framework)** | Flutter (Dart SDK `^3.9.2` / Flutter `3.29.x+`) |
| **مدير الحزم (iOS Dependency Manager)** | CocoaPods |
| **الحد الأدنى لنظام iOS (Deployment Target)** | iOS 13.0+ |

---

## 🚀 خطوات تجهيز المشروع على جهاز Mac (Step-by-Step)

### الخطوة 1: التحقق من البيئة والمتطلبات (Prerequisites)
تأكد من توفر الأدوات التالية على جهاز Mac:
1. **macOS** حديث متوافق مع أحدث إصدارات Xcode.
2. **Xcode** (الإصدار 15.0 أو أحدث) مع تثبيت أدوات سطر الأوامر (Command Line Tools):
   ```bash
   xcode-select --install
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
3. **Flutter SDK**: تثبيت Flutter (نسخة 3.29.x أو متوافقة مع Dart 3.9+):
   ```bash
   flutter --version
   flutter doctor -v
   ```
4. **CocoaPods**:
   ```bash
   sudo gem install cocoapods
   # أو عبر Homebrew:
   # brew install cocoapods
   pod --version
   ```

---

### الخطوة 2: تثبيت حزم المشروع (Dependencies)
افتح مجلد المشروع في التيرمنال ونفّذ:
```bash
# 1. جلب حزم Flutter
flutter pub get

# 2. الانتقال إلى مجلد iOS وتثبيت الـ Pods
cd ios
pod install --repo-update
cd ..
```

---

### الخطوة 3: فتح المشروع في Xcode بالطريقة الصحيحة ⚠️
> **هام جدًا:** افتح دائمًا ملف مساحة العمل `.xcworkspace` وليس `.xcodeproj`.

من التيرمنال:
```bash
open ios/Runner.xcworkspace
```
أو من خلال برنامج Xcode: **File -> Open** واختر: `ios/Runner.xcworkspace`.

---

### الخطوة 4: ضبط التوقيع الرقمي وحساب المطور (Signing & Capabilities)
1. في الشريط الجانبي لـ Xcode (Project Navigator)، اضغط على **Runner** في الأعلى.
2. اختر الهدف **Runner** من قائمة **Targets**.
3. انتقل إلى تبويب **Signing & Capabilities**.
4. حدد خيار **"Automatically manage signing"**.
5. في خانة **Team**: اختر حساب مطور Apple الخاص بك (**Apple Developer Team**).
6. تأكد من أن **Bundle Identifier** يظهر كالتالي:
   ```text
   com.inride.app
   ```
7. تأكد من عدم وجود أي علامات خطأ حمراء في التوقيع (Signing Certificate & Provisioning Profile).

---

### الخطوة 5: التحقق من الصلاحيات والقدرات (Capabilities & Background Modes)
تأكد من تفعيل الصلاحيات التالية في تبويب **Signing & Capabilities**:
- **Push Notifications** (مطلوبة لتنبيهات OneSignal).
- **Background Modes**:
  - `Location updates` (لتتبع موقع الكابتن والرحلة).
  - `Remote notifications` (لاستقبال إشعارات الرحلات).

---

### الخطوة 6: إعداد لوحة تحكم OneSignal (Push Notifications Setup)
التطبيق مهيأ لاستقبال الإشعارات الفورية عبر **OneSignal App ID**:
`388d1944-0b83-4942-8f80-b12584def7d7`

قبل وصول الإشعارات على أجهزة iOS الحقيقية:
1. اذهب إلى [Apple Developer Portal](https://developer.apple.com) -> **Certificates, Identifiers & Profiles** -> **Keys**.
2. أنشئ مفتاح **Apple Push Notifications service (APNs)** وحمّل ملف `.p8`.
3. اذهب إلى لوحة تحكم [OneSignal](https://onesignal.com) للتطبيق -> **Settings** -> **Apple iOS (APNs)** -> ارفع مفتاح `.p8` مع **Key ID** و **Team ID** و **Bundle ID** (`com.inride.app`).

---

### الخطوة 7: إعداد التطبيق على App Store Connect
1. سجّل الدخول إلى [App Store Connect](https://appstoreconnect.apple.com).
2. انتقل إلى **My Apps** -> اضغط على أيقونة **(+)** -> **New App**.
3. اختر:
   - **Platforms**: `iOS`
   - **Name**: `inRide`
   - **Primary Language**: `Arabic` أو `English`
   - **Bundle ID**: اختر `com.inride.app`
   - **SKU**: `inride-app-ios`
   - **User Access**: `Full Access`

---

### الخطوة 8: بناء التطبيق وعمل الأرشيف (Build & Archive)

#### الطريقة الأولى (موصى بها عبر Flutter CLI):
```bash
# تنظيف وبناء ملف IPA للإنتاج
flutter clean
flutter pub get
flutter build ipa --release
```
بعد اكتمال الأمر بنجاح، ستجد ملف الـ `.ipa` في المسار:
`build/ios/archive/Runner.xcarchive` أو `build/ios/ipa/inride_app.ipa`.

يمكنك رفع الملف مباشرة باستخدام أداة **Apple Transporter** أو **Xcode Organizer**.

#### الطريقة الثانية (عبر واجهة Xcode):
1. في Xcode، اختر الجهاز المستهدف من الأعلى: **Any iOS Device (arm64)** (وليس المحاكي Simulator).
2. من القائمة العلوية اختر: **Product -> Archive**.
3. بعد اكتمال الأرشفة، ستفتح نافذة **Organizer**.
4. اضغط على **Distribute App** -> اختر **App Store Connect** -> **Upload** -> اتبع الخطوات التلقائية للتوقيع والرفع.

---

### الخطوة 9: الاختبار والنشر (TestFlight & App Store Review)
1. بعد بضع دقائق من الرفع، سيظهر الإصدار في تبويب **TestFlight** داخل App Store Connect.
2. أجب على استبيان التشفير (**Export Compliance Information**): اختر **No** (Non-exempt encryption).
3. أضف المختبرين عبر TestFlight لتجربة النسخة.
4. املأ بيانات متجر التطبيقات (الوصف، لقطات الشاشة Screenshots، سياسة الخصوصية، معلومات الاتصال) ثم أرسل التطبيق للمراجعة (**Submit for Review**).

---

## 🛠️ استكشاف الأخطاء وحلولها السريعة (Troubleshooting)

- **خطأ: `CocoaPods's specs repository is too out-of-date`**
  - الحل: `pod repo update` ثم `pod install`.
- **خطأ: `No signing certificate "iOS Distribution"`**
  - الحل: تأكد من تسجيل الدخول بحساب Apple Developer في Xcode (**Xcode -> Settings -> Accounts**)، واضغط على **Download Manual Profiles** أو فعّل **Automatically manage signing**.
- **خطأ: `Bundle identifier already exists`**
  - الحل: تأكد من أن الـ App ID `com.inride.app` مسجل في حساب Apple Developer التابع لنفس الـ Team المختار في Xcode.
