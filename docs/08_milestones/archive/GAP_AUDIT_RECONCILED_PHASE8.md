# تدقيق الفجوات المتصالح — المرحلة الثامنة

**تاريخ الحالة:** 12 أغسطس 2026. **مصدر الحالة:** شجرة المصدر بعد Bootstrap المحروس، إعادة ربط الواجهة بـ`OutboxSyncExecutor`، Functions provisioning، واختبارات Auth/Firestore/Functions Emulator. هذه الوثيقة تحل محل أي وصف سابق يتعارض مع الأدلة الأحدث، ولا تدّعي مشروع Firebase أو جهازًا فعليًا غير موجودين.

| المطلب | الموقع/الدليل | محلي | Emulator | خلفية حقيقية | جهاز فعلي | التصنيف الحالي |
|---|---|---|---|---|---|---|
| تشغيل Flutter دون Firebase | `GuardianFirebaseBootstrap` وشاشة الحساب | **متحقق** | غير مطلوب | غير مطلوب | غير مطلوب | IMPLEMENTED + VERIFIED LOCALLY |
| مسار Auth UI وخدمة الدخول/الخروج | `FirebaseSessionScreen` و`FirebaseAuthService` | واجهة عدم التهيئة متحققة | Auth callable اختبر UID في Functions | لا إعداد مشروع/مستخدم حقيقي | لا جهاز | IMPLEMENTED — REAL ENVIRONMENT VALIDATION BLOCKED |
| أسرة وprimary parent ذريان | `FirestoreOutboxRemoteWriter` + rules | عقد/Outbox متحقق | **متحقق** في batch rule test | غير منشور | لا جهاز | VERIFIED IN EMULATOR؛ الخلفية الحقيقية محجوبة |
| طفل وOutbox SQLite | `FamilyRepository` واختبارات المستودع | **متحقق** | لا Flutter client | غير متاح | لا جهاز | VERIFIED LOCALLY |
| Outbox unified runtime path | Provider/Safety screen → `OutboxSyncExecutor` | **متحقق** وfail-closed tested | لا تطبيق Flutter | غير متاح | لا جهاز | IMPLEMENTED + VERIFIED LOCALLY |
| Firestore business writes/read-back من Flutter | `FirestoreOutboxRemoteWriter` + contracts | mocks/عقود فقط | rules فقط، لا عميل Flutter | لا Firebase config | لا جهاز | IMPLEMENTED — REAL ENVIRONMENT VALIDATION BLOCKED |
| retry/permanent failure | `OutboxRetryPolicy` وexecutor tests | **متحقق** | لا latency/شبكة تطبيق | غير متاح | process-death غير متاح | VERIFIED LOCALLY فقط |
| عزل العائلة/التصعيد/الجهاز المسحوب | `firestore.rules` و7 tests | لا | **متحقق** | غير منشور | لا جهاز | VERIFIED IN EMULATOR |
| تسجيل FCM token للوالد | `DeviceTokenRepository` وrules | local contract متحقق | parent token rule متحقق | لا Messaging/token حقيقي | لا جهاز | IMPLEMENTED — REAL ENVIRONMENT VALIDATION BLOCKED |
| جهاز الطفل وهوية منفصلة | callable provisioning + rules | TypeScript متحقق | **متحقق**: Auth UID منفصل، binding ذري، replay مرفوض | غير منشور | لا جهاز طفل | VERIFIED IN EMULATOR؛ الإنتاج محجوب |
| Incident → notification event | Functions trigger test | local incident Outbox متحقق | **متحقق**؛ event و`noActiveToken` | غير منشور | لا جهاز | VERIFIED IN EMULATOR |
| SOS → notification event | Functions trigger test | local SOS Outbox متحقق | **متحقق**؛ event و`noActiveToken` | غير منشور | لا جهاز | VERIFIED IN EMULATOR |
| FCM backend acceptance | `fanoutNotification` | semantics implemented | متعمد `fcmNotExercisedInEmulator` | لا token/FCM config | لا جهاز | IMPLEMENTED — REAL ENVIRONMENT VALIDATION BLOCKED |
| FCM received/displayed/acknowledged | لا دليل ميداني | لا | لا | لا | لا | BLOCKED BY ENVIRONMENT |
| Android APK/الاستعادة/Doze | host Android files فقط | لا SDK/ADB في البيئة | لا | لا | لا | BLOCKED BY ENVIRONMENT |
| iOS/APNs | iOS host/privacy strings فقط | Linux لا يدعم Xcode | لا | لا | لا iPhone | BLOCKED BY ENVIRONMENT |
| AI inference محلي | abstraction/risk pipeline فقط | pipeline متحقق | لا حاجة | لا model artifact | لا قياس جهاز | NOT IMPLEMENTED FOR INFERENCE |

> الحالة الخضراء الوحيدة هنا تعني **المستوى المبين في العمود**. لا يسمح نجاح Emulator بوسم Firebase الحقيقي أو FCM أو Android/iOS بالإنتاجية.

## الثغرات المتبقية ذات الأولوية

1. يتطلب التحقق الحقيقي مشروع Firebase وملفات FlutterFire وAuth/Firestore منشورين، ثم vertical slice من تطبيق Flutter لا من عميل اختبار Node.
2. يتطلب child-device provisioning عميل Flutter callable لا يزال غير موصولًا بشاشة pairing؛ العقد الخادمي والقواعد موجودان، لكن تجربة المسح/الاسترداد على جهاز لم تُنفذ.
3. يتطلب FCM/APNs token حقيقيًا ودوال منشورة وجهازًا فعليًا، مع إثبات منفصل للقبول والاستلام والعرض والتأكيد.
4. تتطلب صلاحيات Android وbackground recovery وDoze، ثم iOS وAPNs، بيئات الأجهزة المنصوص عليها في `HUMAN_ACTION_REQUIRED.md`.

## التوصية التالية المقيدة بالأدلة

بعد أن ينفذ المالك خطوات Firebase، يكون العمل التالي هو **Flutter-to-Emulator vertical slice** ثم نفس السيناريو على مشروع اختبار حقيقي محدود. لا تبدأ مزايا مراقبة جديدة ولا إطلاق متجر قبل غلق هذه الفجوات وتوثيق جهاز فعلي.
