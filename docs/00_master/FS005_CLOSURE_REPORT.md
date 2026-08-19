# FS-005 — Custom Modes (الأنماط المخصصة) | تقرير الإغلاق

**التاريخ:** 19 أغسطس 2026
**الحالة:** مكتمل ومختبر — بانتظار تأكيد المستخدم قبل الرفع إلى GitHub
**الفرع:** `feature/design-system-integration` (لم يُمزج أبدًا مع `master`)

## 1. الملخص التنفيذي

أُغلق نظام الأنماط المخصصة (FS-005) بكامل طبقاته: المجال، البيانات، التوجيه البعيد، مزودي Riverpod، الشاشات العشر، الترجمة (عربي/إنجليزي)، وبطاقة الدخول في لوحة التحكم. يوفّر النظام للوالدين إنشاء أنماط جاهزة (واجبات، نوم، سفر) وأنماطًا مخصصة، وجدولتها (يوميًا/أسبوعيًا/مرة واحدة)، وتعيينها لأطفال محددين، وتفعيلها وإيقافها مع سجل تفعيلات صادق لا يُخفي الفشل أبدًا. عند تعارض أنماط متزامنة على طفل واحد، يُحل التعارض حتميًا بترتيب (الأولوية تنازليًا، ثم تاريخ الإنشاء تصاعديًا) ويُسجَّل الفائز والخاسر صراحةً في السجل.

| المؤشر | القيمة |
|---|---|
| الشاشات المبنية | 10 (MD-001 إلى MD-010) |
| إصدار قاعدة البيانات | v19 (جدولا `mode_configs` + `mode_activations` + مؤشران) |
| مفاتيح الترجمة | 102 (51 عربيًا + 51 إنجليزيًا) |
| الاختبارات الجديدة | 15 (fs005_modes_test.dart) |
| الانحدار الكامل | **308/308 خضراء** |
| تحليل Flutter | **0 أخطاء** (9 تحذيرات موجودة مسبقًا فقط) |

## 2. الملفات الجديدة والمعدّلة

| الملف | الحالة | الوصف |
|---|---|---|
| `lib/domain/mode_config.dart` | جديد | `ModeConfig` + `ModeTemplate.builtIns` (3 قوالب) + `ModeActivation` + `ModeConflictResolver` + `ModeConflictResolution` |
| `lib/data/mode_config_repository.dart` | جديد | CRUD كامل + `activateMode`/`deactivateMode` مع سجل التفعيلات الصادق وحل التعارضات عند التفعيل |
| `lib/data/modes_remote_service.dart` | جديد | جسر القارئ البعيد (نمط mirror لـ FS-004 مع `FlutterModesRemoteReader.unavailable()` وحارس `_ready`) |
| `lib/presentation/screens/modes_screens.dart` | جديد | الشاشات العشر MD-001..MD-010 بنظام التصميم الموحّد (navy #0F2A5B / teal #00B8A9، Cairo، M3) |
| `test/fs005_modes_test.dart` | جديد | 15 اختبارًا: جولة كاملة للبيانات، حل التعارضات، الترحيل v19، القيود الخارجية، التسامح مع الحقول المفقودة |
| `lib/core/database/guardian_database.dart` | معدّل | إصدار 19: جدولا الأنماط في مسارَي `_createSchema` و `_upgradeSchema` مع تصحيح قيد FK المركّب (family_id, mode_id) |
| `lib/data/firestore_contracts.dart` | معدّل | حالتا `mode.config` و `mode.activation` + مسارا `FirestorePaths.modeConfig/modeActivation` |
| `lib/application/guardian_providers.dart` | معدّل | 6 مزودات: `modeConfigRepositoryProvider`، `modeConfigsProvider`، `modeChildConfigsProvider`، `modeActivationsProvider`، `modesRemoteReaderProvider`، `modesPullProvider` |
| `lib/presentation/router/app_router.dart` | معدّل | 9 مسارات جديدة |
| `lib/presentation/screens/dashboard_screen.dart` | معدّل | بطاقة دخول «الأنماط المخصصة» بعد مجموعة المراقبة |
| `lib/core/localization/app_localizations.dart` | معدّل | 102 مفتاح `modes_*` (إدراج عند رؤوس الخرائط وفق التقنية الموثّقة) |

## 3. الشاشات العشر (MD-001 إلى MD-010)

| الرمز | الشاشة | المسار | الوظيفة | التحقق |
|---|---|---|---|---|
| MD-001 | لوحة الأنماط | `/modes/:familyId` | قائمة الأنماط، القوالب الجاهزة، تفعيل/إيقاف سريع | `ctx.can(managePolicies)` |
| MD-002 | تفاصيل النمط | `/modes/:familyId/:modeId` | معلومات النمط، تفعيل/إيقاف، تعديل/حذف | `ctx.can(managePolicies)` |
| MD-003 | إنشاء نمط | `/modes/:familyId/new` | من قالب أو مخصص: اسم، نوع، إجراء | `ctx.can(managePolicies)` |
| MD-004 | تعديل نمط | `/modes/:familyId/:modeId/edit` | تعديل الخصائص والأولوية | `ctx.can(managePolicies)` |
| MD-005 | الجدولة | `/modes/:familyId/:modeId/schedule` | يومي/أسبوعي/مرة واحدة، نافذة زمنية، أيام الأسبوع | `ctx.can(managePolicies)` |
| MD-006 | تعيين الأطفال | `/modes/:familyId/:modeId/children` | اختيار/إلغاء الأطفال المعنيّين | `ctx.can(managePolicies)` |
| MD-007 | سجل التفعيلات | `/modes/:familyId/:modeId/history` | سجل صادق (requested/active/applied/failed/expired) | `ctx.can(managePolicies)` |
| MD-008 | نمط الطفل | `/child/:familyId/:childId/mode` | عرض الطفل لنمطه النشط الخاص | `ctx.can(viewOwnPolicy)` |
| MD-009 | حل التعارضات | `/modes/:familyId/conflict` | ترتيب الحسم الحتمي وعرض الفائز/الخاسر | `ctx.can(managePolicies)` |
| MD-010 | القوالب | `/modes/:familyId/templates` | تصفح القوالب الثلاثة قبل الإنشاء | `ctx.can(managePolicies)` |

تلتزم جميع الشاشات بمبادئ الحالة الصادقة: تظهر حالات التحميل والفراغ والخطأ وانتهاء الصلاحية وعدم التوفر الفعلي (بانر الانقطاع `GuardianOfflineBanner`)، ولا يُعرض نجاح مزعوم قبل تأكيد الخادم (كل كتابة تبقى `sync_state = queued`).

## 4. قرارات معمارية موثّقة

**سجل التفعيلات صادق دائمًا.** يُسجَّل كل تفعيل/إيقاف كصف منفصل بحالة صريحة (active عند النجاح الكامل، requested عند وجود نمط أقوى متعارض، expired عند الإيقاف، failed عند إخفاق الدفع)، ولا تُعاد كتابة السجلات عند ظهور تعارضات لاحقة — التاريخ لا يُحرَّف.

**حذف النمط يُنظّف سجله معًا.** بعد رصد فشل FK عند حذف نمط له تفعيلات، عُدّل `deleteMode` لحذف تفعيلات النمط أولًا، فالسجلات اليتيمة التي تشير إلى سياسة محذوفة تلوّث السجل الصادق.

**القيد الخارجي المركّب.** جدول `mode_configs` بمفتاح مركّب `(family_id, mode_id)`، لذلك يشير `mode_activations` إليه بقيد `FOREIGN KEY(family_id, mode_id)` صريح في مسارَي إنشاء المخطط وترقيته v19، وقد تحقّق الاختبار من رفض SQLite لنمط ينتمي لعائلة غير موجودة.

**عدم وجود outbox للأنماط.** اتّبع النظام نفس نمط FS-004 (monitoring): كتابة محلية أولًا مع `sync_state = queued` دون إدراج صريح في طابور outbox — متوافق مع بقية الشيفرة. لا يتطلب ذلك أي تغيير على قواعد Firebase أو المخطط البعيد أو خدمة Render.

## 5. خلفية Firebase و Firestore (بلا تغييرات)

أُضيفت حالتا عقدين فقط إلى طبقة التعاقد الموجودة: `mode.config` و `mode.activation` مع مساريهما في `FirestorePaths`. لا توجد قواعد أمان جديدة ولا تغييرات على مخطط Firestore القائم ولا على خدمة Render (المُتحقَّق من حيّتها سابقًا: guardian-eye-djg8.onrender.com).

## 6. نتائج الاختبار والتحقق

اختُبرت طبقة البيانات على قاعدة SQLite حقيقية معزولة (قاعدة مؤقتة لكل اختبار مع sqflite_common_ffi): جولة كاملة للبيانات، ترشيح الأطفال المعنيّين، التفعيل/الإيقاف مع سجله، حذف النمط، حل التعارضات بثلاث سيناريوهات (أولوية أعلى تفوز، تكافؤ الأولوية بالأقدمية، أزواج فائز/خاسر)، الترحيل v19 بإنشاء الجدولين والمؤشرين، قيود FK، وتسامح `fromMap` مع الحقول الاختيارية. **15/15 خضراء.**

الانحدار الكامل بعد إضافة FS-005: **308/308 خضراء، 0 فاشلة**. تحليل Flutter: **0 أخطاء**؛ 9 تحذيرات موجودة مسبقًا فقط في ملفات المراحل السابقة دون أي تغييرات من هذه المرحلة. استُبعد `headless_validation_test.dart` (تعليق مسبق معروف، موثق) و `test_database.dart` (اختبار بيئة قديم) كما هو معتاد.

## 7. المتبقي

| البند | الحالة |
|---|---|
| رفع الفرع إلى GitHub | بانتظار تأكيد صريح من المستخدم ("yes, commit") |
| FS-006 — توسيع SOS (8 شاشات) | المرحلة التالية وفق الخطة الرئيسية بعد الاعتماد |
