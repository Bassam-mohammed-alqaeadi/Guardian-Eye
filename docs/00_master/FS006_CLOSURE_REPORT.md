# FS-006 — توسيع الطوارئ SOS: تقرير الإغلاق

**التاريخ:** 19 أغسطس 2026 | **الفرع:** `feature/design-system-integration` | **الحالة:** مكتمل ومُتحقَّق — بانتظار تأكيد الرفع إلى GitHub

---

## 1. الملخص التنفيذي

أُغلقت مرحلة **FS-006 — توسيع الطوارئ SOS** بأكملها: ثماني شاشات (SO-001 إلى SO-008) تغطي دورة الطوارئ كاملة من جاهزية المستجيبين، عبر تفعيل التنبيه العاجل، وتتبع حالة كل متلقٍّ لحظةً بلحظة، إلى الإعتراف الصادق بالتنبيه، وتاريخ الإعترافات، وإدارة قائمة المستجيبين، ثم تمرين الجاهزية المُوجَّه خطوة بخطوة. رُفع إصدار قاعدة البيانات المحلية إلى **v20** بإضافة جدول `sos_recipients` (الروستر) وعمود `recipient_id` إلى `notification_events`، وامتُدت طبقة التعاقد مع Firestore بحالتي عقدين جديدين (`sos.recipient` و `notification.acknowledged`) دون أي تغيير على قواعد أمان Firebase أو المخطط البعيد أو خدمة Render.

يظل المبدأ الحاكم لكل ما بُني هنا هو **الحالة الصادقة**: لا يُدَّعى أن العائلة «جاهزة» إلا إذا كان رoster المستجيبين يحوي مستجيبين فعليًا، ولا يُدَّعى أن التنبيه «مُعترَف به» إلا إذا انتقلت صفوف الإعتراف إلى حالة `acknowledged` عبر بوابة الآلة الصارمية التي ترفض الحالات النهائية، ولا يُكتب نجاح مزعوم قبل تأكيد قاعدة البيانات — كل كتابة تبدأ `pendingBackend` وتبقى مكشوفة في الواجهة حتى استكمال الانتقال.

| المؤشر | القيمة |
|---|---|
| الشاشات المبنية | 8 (SO-001 إلى SO-008) |
| إصدار قاعدة البيانات | v20 (`sos_recipients` + عمود `recipient_id` على `notification_events`) |
| مفاتيح الترجمة | 99 مفتاح `sos_*` في خريطتي العربية والإنجليزية (متطابقة تمامًا) |
| الاختبارات الجديدة | 13 (fs006_sos_test.dart) |
| الانحدار الكامل | **321/321 خضراء** |
| تحليل Flutter | **0 أخطاء** (التحذيرات الموجودة مسبقًا فقط) |

## 2. الملفات الجديدة والمعدّلة

| الملف | الحالة | الوصف |
|---|---|---|
| `lib/domain/sos_config.dart` | جديد | `SosRecipient` + `SosRecipientRole` (responder / notifyOnly مع امتداد التخزين) + `SosDrillStep` و `SosDrillStateKind` و `SosDrillState` و `SosDrillRecord` + الدالة النقية `evaluateDrill` التي تحسم نتيجة التمرين |
| `lib/data/safety_repositories.dart` | معدّل | إضافة `SosRepository`: `activateSosForFamily` (حدث SOS + صف إعتراف لكل متلقٍّ) و `standDownSos` و `acknowledgeNotification` (آلة حالات صارمية) و `recipientsForFamily` / `saveRecipient` / `deleteRecipient` / `upsertRecipients` و `notificationsForSos` و `sosIdForNotification` و `activeSosForFamily` و `sosHistoryForFamily` |
| `lib/core/database/guardian_database.dart` | معدّل | الإصدار v20: جدول `sos_recipients` بمفتاح مركّب (PK family_id, recipient_id) + `ALTER TABLE notification_events ADD COLUMN recipient_id` في مسارَي `_createSchema` و `_upgradeSchema` (oldVersion < 20) مع قيد `FOREIGN KEY` إلى جدول العائلات |
| `lib/data/sos_remote_service.dart` | جديد | جسر القارئ البعيد `FlutterSosRemoteReader` بنفس نمط FS-004/FS-005: بنّاء `unavailable()` وحارس `_isUnavailable` ودالة `pullPending` التي تنسحب بصمت عند انقطاع Firebase دون أن تدّعي نجاحًا |
| `lib/presentation/screens/sos_screens.dart` | جديد | الشاشات الثماني SO-001..SO-008 (≈1960 سطرًا) بنظام التصميم الموحّد (navy #0F2A5B / teal #00B8A9، تدرّج SOS المخصص `statusSOS`/`statusSOSDeep`، Cairo، M3 ببطاقات مدوّرة) |
| `test/fs006_sos_test.dart` | جديد | 13 اختبارًا في 5 مجموعات: ترحيل v20 (2)، قائمة الجاهزية (3)، تفعيل SOS (3)، الإعتراف الصادق (3)، حسم التمرين (2) |
| `lib/data/firestore_contracts.dart` | معدّل | حالتا `sos.recipient` و `notification.acknowledged` + مسارا `FirestorePaths.family` و `sosRecipient` |
| `lib/application/guardian_providers.dart` | معدّل | 7 مزودات: `sosRepositoryProvider`، `sosRecipientsProvider`، `activeSosProvider`، `sosNotificationsProvider`، `sosHistoryProvider`، `futureSosIdProvider`، `sosRemoteReaderProvider`، `sosPullProvider` |
| `lib/presentation/router/app_router.dart` | معدّل | 8 مسارات SOS جديدة مسجلة في الراوتر |
| `lib/presentation/screens/dashboard_screen.dart` | معدّل | مجموعة تنقل «الطوارئ SOS» في لوحة القيادة بعد مجموعة الأنماط: لوحة الطوارئ، المتلقّون، تمرين الجاهزية |
| `lib/core/localization/app_localizations.dart` | معدّل | 99 مفتاح `sos_*` (إدراج عند رؤوس الخرائط بتقنية التثبيت بسطرٍ موثّقة، بنفس التغطية عربيًا وإنجليزيًا) |

## 3. الشاشات الثماني (SO-001 إلى SO-008)

| الرمز | الشاشة | المسار | الوظيفة | التحقق |
|---|---|---|---|---|
| SO-001 | لوحة الطوارئ | `/sos/:familyId` | جاهزية الاستجابة بعدد المستجيبين الفعليين، نتيجة آخر تمرين، مقتطفات سجل التنبيهات | `ctx.can(viewSafetyTimeline)` |
| SO-002 | تفعيل SOS | `/sos/:familyId/activate` | تفعيل عاجل بملء الشاشة، تكرار التفعيل يعيد نفس الحدث بدلًا من إنشاء ازدواجية | `ctx.can(viewSafetyTimeline)` |
| SO-003 | التنبيه النشط | `/sos/:familyId/active` | الحالة الحية لكل صف متلقٍّ (مرسل/مُسلَّم/مُعترَف به) + الوصول السريع لموقع الطوارئ | `ctx.can(viewSafetyTimeline)` |
| SO-004 | موقع الطوارئ | `/sos/:familyId/location` | خريطة موقع الطفل اللحظي أثناء التنبيه (مكوّن الخريطة الموحّد GuardianMapWidget) | `ctx.can(viewSafetyTimeline)` |
| SO-005 | تفاصيل التنبيه | `/sos/:familyId/alert/:alertId` | عرض التنبيه المستلم مع زر الإعتراف؛ انتقالات صادقة ترفض الحالات النهائية | `ctx.can(viewSafetyTimeline)` |
| SO-006 | تاريخ الإعترافات | `/sos/:familyId/ack` | خط زمني صادق: من أعترف ومتى، ومن بقي صفه مفتوحًا؛ الفراغ يُعرض ولا يُختلق | `ctx.can(viewSafetyTimeline)` |
| SO-007 | إدارة المتلقّين | `/sos/:familyId/recipients` | رoster الجاهزية: إضافة/حذف مع الأدوار (مستجيب / إشعار فقط) والترتيب | `ctx.can(viewSafetyTimeline)` |
| SO-008 | تمرين الجاهزية | `/sos/:familyId/drill` | اختبار مُوجَّه بأربع خطوات (تنبيه أُرسل → استُقبل → أُعترِف به → الموقع تُحقِّق منه) وحسم صريح passed/failed/inProgress/notStarted | `ctx.can(viewSafetyTimeline)` |

تلتزم جميع الشاشات بالحالة الصادقة: حالات التحميل والفراغ والخطأ تظهر عبر `GuardianStateView`، وبانر الانقطاع `GuardianOfflineBanner` ظاهر دائمًا في أسفل الشاشات، ولا يُعرض «مُعترَف به» قبل انتقال الصف فعليًا في قاعدة البيانات.

## 4. قرارات معمارية موثّقة

**تفرد حدث SOS النشط.** كان اختبار «تفعيل مزدوج» يكشف أنه عند وجود SOS نشط يُنشأ حدث جديد بدلًا من حماية الوحدة. عُدّل `activateSosForFamily` ليستعلم أولًا عن حدث نشط (`status NOT IN (cancelled, acknowledged)`) داخل المعاملة ذاتها ويعيد معرّف الحدث الموجود — فلا ازدواجية، ولا نجاح مزعوم من حدثين متزامنين.

**الإعتراف بوابة صورية صادقة.** لا تنتقل أي صف إعلام إلى `acknowledged` إلا من الحالات المسموحة (`pendingBackend`/`queued`/`notified`)، وكل انتقال يُدخل صفًا في طابور outbox بنوع `notification.acknowledged` ليصل إلى Firestore عبر جسر outbox القائم. كما يُقدَّم حدث الأب إلى `acknowledged` فقط حين تعترف **كل صفوف المستجيبين** — سلسلة المستجيبين هي البوابة الصادقة لإغلاق التنبيه، ولا يُمسح أي سجل عند الإغلاق بل يبقى في `sos_history` بحالة `cancelled`.

**مفتاح مزوّد الإشعارات هو sosId وليس معرّف الصف.** اكتُشف أثناء بناء SO-005 أن `sosNotificationsProvider` يُفتَّح بمعرّف حدث SOS (لأن الاستعلام يستعلم بـ `sos_id`)، بينما الشاشة تصل بمعرّف صف الإشعار. أُضيفت دالة `sosIdForNotification` في المستودع ومزوّد `futureSosIdProvider` لتحديد حدث الأب أولًا، وبذلك تظل التحديثات وإعادة المحاولة داخل النطاق الصحيح الذي يعمل فيه `ActiveSosScreen` بالفعل.

**اختبار الترحيل v19→v20 على مخطط يدوي حقيقي.** كُتب اختبار ترقية يبدأ بقاعدة v19 مبنية يدويًا (بجداول `families` و `sos_events` و `notification_events` وبيانات تجريبية)، ثم يفتحها `GuardianDatabase` فتُطبَّق ترقية v20 الفعلية، ويُتحقَّق من وجود جدول `sos_recipients` وعمود `recipient_id` وبقاء الصفوف القديمة. هذا يثبت أن الترقية التزايدية لا تُعيد إنشاء الجداول ولا تفقد البيانات.

**حارس الصلاحيات الموحد.** جميع شاشات SO-* تمر عبر `_guardedScaffold` الذي يستدعي `contextValue.can(FamilyPermission.viewSafetyTimeline)` — لا إعادة تنفيذ لفحص الأدوار محليًا، وبنفس نمط FS-001/FS-004 تمامًا.

## 5. خلفية Firebase و Firestore (بلا تغييرات)

أُضيفت حالتا عقدين فقط إلى طبقة التعاقد الموجودة: `sos.recipient` (لمزامنة قائمة المستجيبين مع `families/{id}/sos/recipients/{recipientId}`) و `notification.acknowledged` (لمزامنة صفوف الإعتراف). لا توجد قواعد أمان جديدة ولا تغييرات على مخطط Firestore القائم ولا على خدمة Render (المُتحقَّق من حيّتها: guardian-eye-djg8.onrender.com). القارئ البعيد `FlutterSosRemoteReader` يتدرّج بصمت إلى `unavailable()` عند انقطاع Firebase فيبقى المسار المحلي المُوفَّق-أولًا هو مصدر الحقيقة الوحيد.

## 6. نتائج الاختبار والتحقق

اختُبرت طبقة البيانات على قاعدة SQLite حقيقية معزولة (قاعدة مؤقتة لكل اختبار مع sqflite_common_ffi): الترحيل v20 بمساري إنشاء المخطط والترقية، جولة كاملة لقائمة المستجيبين بترتيبها، تفعيل SOS يُنشئ حدثًا واحدًا وصفًّا لكل متلقٍّ، حماية وحدة الحدث النشط بعد الإغلاق، الآلة الصارمية للإعتراف بثلاث سيناريوهات (مسار مسموح حتى acknowledgement، رفض حالة نهائية، إغلاق صادق بحالة cancelled)، وحسم التمرين (لا بدء بدون حدث اختبار، النجاح يتطلب تأكيد كل الخطوات). **13/13 خضراء.**

الانحدار الكامل بعد إضافة FS-006: **321/321 خضراء، 0 فاشلة**. تحليل Flutter: **0 أخطاء**؛ التحذيرات معلوماتية موجودة مسبقًا دون أي تغيير من هذه المرحلة. استُبعد `headless_validation_test.dart` (تعليق مسبق معروف، موثق) و `test_database.dart` (اختبار بيئة قديم) كما هو معتاد.

## 7. المتبقي

| البند | الحالة |
|---|---|
| رفع الفرع إلى GitHub | بانتظار تأكيد صريح من المستخدم ("yes, commit") |
| FS-007 — المرحلة التالية وفق الخطة الرئيسية | التالي بعد الاعتماد |
