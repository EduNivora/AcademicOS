# Academic OS

Academic OS هو نظام إدارة أكاديمية مبني على Flutter ويهدف إلى تنظيم حياة الطالب الجامعي داخل تطبيق واحد. يركز المشروع على دمج المهام الدراسية، المقررات، الجداول، التنبيهات، والتقييم الأكاديمي في واجهة موحدة وسهلة الاستخدام، مع اعتماد على التخزين المحلي والتصميم المعماري المنظم؛ ملف قاعدة SQLite غير مشفر حالياً، وتُحفظ بعض الأسرار المختارة فقط في `flutter_secure_storage`.

يُعد هذا المشروع مثالاً عملياً لتطبيق أكاديمي حديث يوازن بين سهولة الاستخدام والهيكل المعماري المرن. ويعتمد على نموذج خفيف من Clean Architecture، حيث يتم فصل طبقات الـ Core، الـ Domain، الـ Data، و الـ Presentation. ويستند التطبيق إلى قاعدة بيانات محلية مع خدمات أمنية ومتعددة، بهدف دعم الطالب في إدارة حياته الأكاديمية اليومية بشكل أكثر فاعلية.

## لماذا هذا النظام؟

غالباً ما يحتاج الطالب الجامعي إلى إدارة العديد من الجوانب في وقت واحد، مثل:

- المهام الدراسية والتسليمات والمواعيد النهائية
- المقررات الدراسية، أسماء المحاضرين، وأوقات المحاضرات
- تقييم الأداء الأكاديمي وحساب المعدل المتوقع
- ترتيب وقت الدراسة والجداول الأسبوعية
- مواعيد الاختبارات والامتحانات
- تنبيهات تذكيرية قبل الموعد

يعالج Academic OS هذه التحديات من خلال بوابة أكاديمية موحدة تجمع هذه الوظائف داخل تطبيق محلي، مع إمكانية التوسع في المستقبل لدعم تقارير أكثر تعقيداً أو أدوات ذكاء اصطناعي متقدمة داخل النظام.

---

## Core Features

استناداً إلى الشاشات والوظائف الموجودة فعلياً في مجلد `lib/`، يحتوي التطبيق على هذه المزايا الأساسية:

### 1. إدارة المهام الدراسية
- إنشاء مهمة جديدة، تعديلها، وحذفها
- تصنيف المهام حسب النوع، الأولوية، والتكرار
- ربط كل مهمة بمادة دراسية محددة
- دعم التذكيرات عبر إشعارات محلية
- عرض المهام حسب الحالة: الكل، المكتملة، المعلقة، أو المتأخرة

### 2. إدارة المقررات الدراسية
- إضافة مقررات دراسية، تعديلها، وحذفها
- حفظ بيانات كل مادة: الاسم، الكود، المحاضر، الساعات، الفصل، والملاحظات
- إدارة تفاصيل كل مقرر، بما في ذلك المواد والمستندات المرتبطة
- عرض قائمة المقررات مع البحث والفلترة

### 3. نظام تسجيل الدخول وحماية التطبيق
- شاشة تسجيل الدخول وتسجيل المستخدم محلياً
- دعم تسجيل الدخول عبر Google
- قفل التطبيق باستخدام نظام PIN و/أو المصادقة البيومترية
- تخزين بعض بيانات المصادقة والإعدادات الحساسة داخل `flutter_secure_storage`؛ قاعدة SQLite نفسها غير مشفرة حالياً.
- إعدادات قفل التطبيق من شاشة الخصوصية والأمان
- استخدام Argon2id للتحقق من كلمات المرور وأرقام PIN الجديدة، مع ترقية بيانات التحقق القديمة بعد نجاح المصادقة؛ هذا لا يعني أن ملف SQLite مشفر.

### 4. الجداول الدراسية والتخطيط الأكاديمي
- عرض جدول أسبوعي للمحاضرات
- إدارة أيام ومواعيد المحاضرات
- دعم تنبيهات المحاضرات القريبة
- تخطيط نوعية الوقت المتاح للدراسة

### 5. الخطة الدراسية والتركيز
- شاشة Focus Timer لمتابعة جلسات الدراسة
- شاشة Study Planner لتوزيع خطة المذاكرة
- تنظيم الوقت بناءً على أولويات الطالب

### 6. اختبارات ومعدلات الطلاب
- إدارة امتحانات المقررات مع تواريخها وملاحظاتها
- شاشة Grade Simulator لتوقع النتائج أو محاكاة المعدل
- شاشة GPA Calculator و Target Grade Calculator
- شاشة Grade Distribution لعرض التوزيع أو التمثيل المرئي للدرجات

### 7. لوحة المعلومات الأكاديمية والذكاء الاصطناعي
- خدمة Academic Dashboard لإحصاء الحالة الأكاديمية العامة
- شاشة Academic AI Assistant التي تستقبل أسئلة الطالب وتقدم اقتراحات مباشرة
- دعم أسئلة عملية مثل: وقت المذاكرة، أقرب اختبار، أو توقع المعدل

### 8. الإشعارات والتنبيهات المحلية
- تنبيهات لمهام وموعد نهائي
- تنبيهات لمحاضرات قريبة
- دعم `flutter_local_notifications` و `timezone` لتحديد الوقت بدقة

### 9. الفصول الدراسية والتقارير الأكاديمية
- إنشاء الفصول الدراسية وتعديلها وتحديد الفصل النشط
- تقارير أكاديمية تُنشأ من بيانات SQLite المحلية
- حفظ التقرير النصي أو نسخه دون رفع السجلات الأكاديمية

### 10. إعدادات التطبيق
- إعدادات عامة للتطبيق
- دعم اللغة العربية/الإنجليزية
- دعم الوضع الفاتح/الداكن

---

## Architecture & Tech Stack

### Architecture

المشروع يتبع نموذجاً خفيفاً من Clean Architecture، حيث يتم تقسيم المسؤوليات إلى طبقات واضحة:

- `lib/core/` — الخدمات المشتركة: الأمن، التهيئة، التنبيهات، المنصات، الثيم، والخدمات الأكاديمية
- `lib/domain/` — الكيانات، الواجهات، وحالات الاستخدام (Use Cases)
- `lib/data/` — النماذج، مصادر البيانات المحلية، المستودعات، وقاعدة البيانات
- `lib/presentation/` — كل شاشات UI ومكونات العرض
- `lib/providers/` — إدارة الحالة باستخدام Riverpod
- `lib/features/` — وحدات خاصة ومكونات إضافية

### التقنيات والمكتبات المستخدمة فعلياً

استناداً إلى `pubspec.yaml`، هذه هي التبعيات الفعلية الموجودة في المشروع:

#### Framework and runtime
- Flutter SDK: `>=3.32.0 <4.0.0`
- Dart SDK: مرتبط مع Flutter

#### UI and app foundation
- `flutter`
- `flutter_localizations`
- `cupertino_icons`

#### State management
- `flutter_riverpod: ^2.6.1`

#### Local storage and security
- `sqflite: ^2.3.3`
- `sqflite_common_ffi: ^2.3.3`
- `sqflite_common_ffi_web: ^1.0.0`
- `shared_preferences: ^2.3.0`
- `flutter_secure_storage: ^9.0.0`
- `crypto: ^3.0.6` (legacy verifier migration and cryptographic utilities)
- `cryptography: ^2.9.0` (Argon2id password and app-lock PIN verifiers)

#### Auth and device security
- `google_sign_in: ^6.2.1`
- `local_auth: ^2.2.0`

#### Notifications and scheduling
- `flutter_local_notifications: ^18.0.0`
- `timezone: ^0.9.4`

#### File and document support
- `file_picker: ^10.2.0`
- `flutter_pdfview: ^1.2.3`
- `flutter_pdf_text: ^0.9.0`

#### Development tools
- `flutter_test`
- `flutter_lints: ^5.0.0`

> ملاحظة مهمة: بينما تذكر بعض الملفات في المشروع SQLCipher في التوثيق، فإن التبعيات الحالية الفعلية في `pubspec.yaml` توضح أنه يتم استخدام SQLite عبر `sqflite` مع دعم FFI و `flutter_secure_storage`، وهذا هو الواقع الحالي في الكود.

### قاعدة البيانات المحلية

يتم إدارة قاعدة البيانات المحلية عبر `DatabaseHelper` في `lib/data/database/database_helper.dart`، باستخدام:

- SQLite عبر `sqflite`
- إعدادات FFI للتطبيقات desktop وweb
- إنشاء الجداول الأساسية للمهام، المقررات، الامتحانات، جدول المحاضرات، والمواد الدراسية
- ترقية قاعدة البيانات عند تحديث الإصدار (`onUpgrade`)
- تخزين تفضيلات المستخدم الحساسة عبر `SecureStorageService` وبيانات المصادقة عبر `AuthSecureStorageService`؛ ملف SQLite نفسه غير مشفر حالياً

---

## Directory Structure

```text
AcademicOS/
├─ android/
├─ windows/
├─ web/
├─ test/
├─ lib/
│  ├─ core/
│  │  ├─ academic/
│  │  ├─ initializer/
│  │  ├─ notifications/
│  │  ├─ platform/
│  │  ├─ security/
│  │  ├─ services/
│  │  ├─ theme/
│  │  └─ widgets/
│  ├─ data/
│  │  ├─ database/
│  │  ├─ datasources/
│  │  ├─ models/
│  │  └─ repositories/
│  ├─ domain/
│  │  ├─ ai/
│  │  ├─ entities/
│  │  ├─ repositories/
│  │  └─ usecases/
│  ├─ features/
│  │  └─ exam/
│  ├─ presentation/
│  │  ├─ about/
│  │  ├─ ai_assistant/
│  │  ├─ auth/
│  │  ├─ course/
│  │  ├─ courses/
│  │  ├─ exam/
│  │  ├─ focus/
│  │  ├─ gpa/
│  │  ├─ grade_simulator/
│  │  ├─ home/
│  │  ├─ notifications/
│  │  ├─ onboarding/
│  │  ├─ schedule/
│  │  ├─ screens/
│  │  ├─ settings/
│  │  ├─ study_plan/
│  │  ├─ task/
│  │  └─ tasks/
│  ├─ providers/
│  ├─ main.dart
│  ├─ ROADMAP.md
│  └─ ...
├─ analysis_options.yaml
├─ pubspec.yaml
├─ README.md
├─ AGENTS.md
├─ ARCHITECTURE.md
├─ .gitignore
├─ .metadata
└─ .idea/
```

بعض الملفات الرئيسية في المشروع:

- `lib/main.dart` — نقطة تشغيل التطبيق وتركيب الاعتماديات
- `lib/presentation/home/home_screen.dart` — الشاشة الرئيسية ولوحة التحكم
- `lib/presentation/task/add_edit_task_screen.dart` — إضافة/تعديل المهام
- `lib/presentation/course/course_list_screen.dart` — قائمة المقررات
- `lib/presentation/terms/academic_terms_screen.dart` — إدارة الفصول الدراسية
- `lib/presentation/reports/academic_reports_screen.dart` — التقارير الأكاديمية المحلية
- `lib/presentation/ai_assistant/academic_ai_screen.dart` — شاشة المساعد الأكاديمي
- `lib/data/database/database_helper.dart` — إعداد قاعدة البيانات المحلية
- `lib/core/security/secure_storage_service.dart` — تخزين كلمات المرور بشكل آمن
- `lib/core/academic/academic_assistant_service.dart` — منطق المساعد الأكاديمي

---

## Getting Started

### 1. استنساخ المشروع

```bash
git clone <repository-url>
cd AcademicOS
```

### 2. تثبيت الحزم

```bash
flutter pub get
```

### 3. تشغيل التطبيق

```bash
flutter run
```

### 4. التشغيل على منصات محددة

#### Android
```bash
flutter run -d android
```

#### Web
```bash
flutter run -d chrome
```

#### Windows
```bash
flutter run -d windows
```

المنصات المهيأة حالياً داخل المستودع هي Android وWeb وWindows. مجلدات iOS وmacOS وLinux غير موجودة حالياً، فلا تُعد هذه المنصات مدعومة في إعدادات المستودع الحالية.

### 5. التحقق من الجودة

```bash
flutter analyze
flutter test
```

---

## ملاحظات المشروع والحالة الحالية

- التطبيق يعمل بواجهة عربية بشكل افتراضي، مع دعم لواجهة إنجليزية في بعض المكونات
- التصميم الحالي يركز بشكل كبير على إدارة الطالب الأكاديمي بشكل محلي
- التطبيق يعتمد على قاعدة بيانات محلية وليس خادم خارجي، ما يجعله مناسباً للاستخدام الذاتي في بيئات بلا إنترنت
- بنية المشروع تسمح بالتوسع في نقاط مثل: تقارير أكاديمية أكثر عمقاً، إدارة حضور/غياب أكثر دقة، أو نموذج ذكاء اصطناعي متقدم

---

## Summary

Academic OS هو تطبيق أكاديمي محلي مصمم لمساعدة الطالب على تنظيم حياته الدراسية بطريقة ذكية ومنظمة. يجمع بين إدارة المهام والمقررات، التذكيرات، والمعدلات، مع بنية واضحة وقاعدة بيانات محلية. ملف SQLite غير مشفر حالياً؛ لذلك لا تُعد حماية البيانات عند السكون مكتملة.


## Product scope (approved 2026-11-15)

EduNivora is a **guest-first, local-first personal academic application**. A student can open and use core features without signing in. Creating an account with Google or email/password is optional; the central service stores only minimal account identity data and notice receipts, not academic records or files.

Academic terms, courses, schedules, tasks, exams, notes, materials, attachments, settings, and reports remain on the student's device and work offline. Attachments must use durable app-owned storage.

### Public notices — Release 1
- Notices are intended for all app installations, including guests.
- Registered students may be identified by account name in delivery/read reports; guest metrics must remain anonymous aggregates only.
- A minimal protected operator interface is limited to notice publishing and notice reports. Actual delivery, receipt and read behavior remains subject to end-to-end acceptance.

### Personal backup — Release 2 (deferred)
- Google Drive backup, encrypted archives, upload, download and restore are excluded from Release 1 and must not be exposed as available functionality.
- The approved future target is a normal, visible `EduNivora` folder in each student's own Google Drive, with student-initiated encrypted backup and validated restore.
- Backup-related code retained in the repository is unaccepted work-in-progress; it is not a completed or available backup service.

Institutional portals, lecturer/student administration, official university attendance integration, institutional messaging, fees/payments, university dashboards, and academic cloud synchronization are outside the current product scope. See [docs/PRODUCT_SCOPE.md](docs/PRODUCT_SCOPE.md) for the authoritative product specification and [ARCHITECTURE.md](ARCHITECTURE.md) for technical boundaries.


## تجهيز وبناء نسخة Web

يحتاج SQLite على Web إلى ملفات WebAssembly وShared Worker التي يوفرها `sqflite_common_ffi_web`. بعد تثبيت Flutter والتبعيات، جهّز runtime ثم ابنِ نسخة Web:

```bash
flutter pub get
dart run sqflite_common_ffi_web:setup --force --verbose
flutter build web --release
```

يتحقق GitHub Actions من تجهيز runtime وبناء نسخة Web ويرفعها كـ artifact. نجاح البناء لا يثبت وحده استمرارية IndexedDB بعد إعادة التحميل، أو العمل دون اتصال، أو سلامة تعدد التبويبات؛ يلزم اختبار المتصفح لهذه السلوكيات قبل إعلان دعم Web إنتاجياً.


## Release 1 cloud metadata backend

EduNivora uses a dedicated Neon PostgreSQL project for optional account
identity and public notices only. Academic records and attachments remain in
local SQLite and are never uploaded by this backend. Neon Managed Auth is
enabled; the Hono API source, migrations and tests are in
[`backend/neon`](backend/neon/README.md). The last confirmed live Notices API
deployment is version 7. Its health and public-feed smoke checks returned HTTP
200, and the unauthenticated admin route returned HTTP 401. The latest reviewed
source changes (including the current JWT and CORS handling) have not yet been
deployed. These smoke checks do not prove real-account JWT flows, admin
publishing, production CORS, or release readiness.

The Flutter client includes the Managed Auth REST adapter and email/OTP
screens, with unit-test coverage for the request and session flows. Real-account
end-to-end verification on Android and Web remains outstanding. The public
announcements feed is available to guests through the Flutter Announcements
screen and is cached locally for offline reading; academic records and files
are never uploaded to Neon.
