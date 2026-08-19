# تقرير الرفع النهائي — FS-004 مراقبة الشاشة والكاميرا

**الالتزام:** `348209d` على تفرع `feature/design-system-integration`
**التاريخ:** 19 أغسطس 2026
**المستودع:** Bassam-mohammed-alqaeadi/Guardian-Eye

## 1. ما الذي أُرفع

| الملف | الوصف |
|---|---|
| `lib/data/monitoring_repository.dart` | طبقة البيانات: 5 كيانات (لقطات، جلسات، طلبات، جداول، أدلة) + CRUD كامل |
| `lib/data/monitoring_remote_service.dart` | جسر السحب البعيد عبر Firebase الحقيقي ( FirebaseAuth + حالة التهيئة ) |
| `lib/core/database/guardian_database.dart` | هجرة SQLite إلى الإصدار 18: 5 جداول + مؤشران |
| `lib/data/firestore_contracts.dart` | عقود Firestore: monitoring.shot / session / request / schedule / evidence |
| `lib/application/guardian_providers.dart` | 7 مزودات Riverpod للمراقبة |
| `lib/presentation/screens/monitoring_screens.dart` | 9 شاشات SC-001..SC-009 |
| `lib/presentation/router/app_router.dart` | 9 مسارات جديدة `/monitoring/*` |
| `lib/presentation/screens/dashboard_screen.dart` | بطاقة دخول «المراقبة» في لوحة العائلة |
| `lib/core/localization/app_localizations.dart` | ~170 مفتاحًا عربيًا/إنجليزيًا جديدًا + سد فجوة مفاتيح الويب-فلترة الإنجليزية |
| `test/fs004_monitoring_test.dart` | 11 اختبارًا: CRUD، الهجرة، الأدلة، FK، طلبات |
| `docs/00_master/FS004_DEVELOPMENT_REPORT.md` | توثيق UX + TECH + SECURITY |
| `docs/00_master/FS004_CLOSURE_REPORT.md` | تقرير الإغلاق |

إجمالي التغيير: 12 ملفًا، 3779 سطرًا مضافًا.

## 2. نتائج الفحص الشامل قبل الرفع

الفحص شمل الترابط بين جميع المراحل FS-001..FS-004 والصور والأيقونات وربط الـ Backend.

| البند | النتيجة |
|---|---|
| المسارات (58) | كلها تحيل إلى شاشات موجودة، بدون تكرار |
| المفاتيح اللغوية | 661 مفتاحًا مستخدمًا في الشاشات — كلها متوفرة في العربي والإنجليزي |
| الصور | 5 ملفات (الأيقونة + 4 صور تمهيدية) موجودة ومرتبطة فعليًا في 6 مواضع |
| الأيقونات | 138 استخدامًا لأيقونات Material في الشاشات |
| Firebase | كل طبقات البيانات تستخدم Firestore + FirebaseAuth الحقيقي، لا Mock |
| الصلاحيات | 12 فحص `can()` في شاشات المراقبة عبر FamilyRuntimeContext |
| اختبارات | 293/293 أخضر (282 أساسية + 11 FS-004) |
| تحليل ثابت | 0 أخطاء، 9 تحذيرات فقط موجودة مسبقًا في مراحل سابقة (لا علاقة لها بـ FS-004) |

## 3. أعطال وُجدت وأُصلحت أثناء الفحص

**RangeError في مولّد معرّفات الأدلة:** كان يستخدم `substring(0,6)` مما ينهار لمعرّفات عائلات أقصر من 6 أحرف؛ استُبدل بقص آمن.

**~100 مفتاح لغوي مفقود:** واجهات FS-004 كانت تستخدم مفاتيح (مثل `captureSchedules`, `evidenceReviewQueue`, `safetyActions`, `sendSos`) غير موجودة في الخريطة اللغوية أصلًا — كانت ستسبب عرض المفاتيح الخام عند التشغيل. عُدّت كلها بقيم عربية وإنجليزية حقيقية.

**فجوة اللغة الإنجليزية لمرحلة الويب-فلترة:** 60 مفتاح ويب-فلترة كانت موجودة بالعربية فقط في الملف الأساسي، فكانت تظهر كمفاتيح خام للمستخدم الإنجليزي؛ عُدّت ترجماتها الإنجليزية.

## 4. ما تبقى بعد هذا الالتزام

المرحلة التالية وفق خطة التطوير هي **FS-005** (النظام الفرعي الخامس في الخطة الرئيسية). يُنصح قبلها بالاختبار على جهاز حقيقي عبر Firebase Test Lab باستخدام APK البناء المرفوع حاليًا.
