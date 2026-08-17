# تقرير المرحلة 12 — Firebase Emulator-first Development

**الحالة:** **IMPLEMENTED + VERIFIED LOCALLY / VERIFIED IN EMULATOR**، مع حفظ أدلة Firebase الحقيقي السابقة كما هي. لا توجد دلالة جديدة على FCM delivery أو APK أو physical-device runtime.

## 1. القرار المعماري

أصبحت Firebase Emulator Suite البيئة الأساسية للتطوير والاختبارات اليومية، بينما `manus-guardian` يبقى مرجع real-backend والتحقق الدوري فقط. لا يتطلب هذا القرار Blaze، ولا يغير مشروع Firebase، ولا يعيد كتابة SQLite أو Riverpod أو OutboxSyncExecutor.

## 2. التحكم الآمن بالبيئة

أضيف `GuardianFirebaseEnvironmentConfig` بأربع بيئات صريحة: DEVELOPMENT وTEST وREAL_BACKEND_VALIDATION وPRODUCTION. Development/Test لا تعمل بلا Emulator host صريح. Real validation وproduction لا تعمل بلا approval define منفصل. الغموض أو القيم غير المعروفة يؤدي إلى fail-closed؛ لا تستدعى Firebase.

## 3. سير التطوير والاختبار

أضيف `tool/run_firebase_emulator_tests.sh`. يبني الدوال ويشغل Auth وFirestore وFunctions Emulator داخل project اصطناعي `guardian-eye-emulator`، ثم يشغل 8 اختبارات rules و2 اختبارات Functions. لا يشغل real-backend validation ولا يستعمل `manus-guardian`.

| الطبقة | النتيجة |
|---|---|
| Flutter analyze | PASS — no issues found |
| Flutter tests | PASS — 29 tests after environment tests were added |
| Firestore Emulator | PASS — 8 authorization tests |
| Functions Emulator | PASS — 2 notification/provisioning tests |
| Real Firebase Auth/Firestore | محفوظ كـVERIFIED ON REAL BACKEND في السجل المنفصل |

## 4. الوثائق

`ENVIRONMENT_STRATEGY.md` يحدد حدود DEVELOPMENT/TEST/REAL_BACKEND_VALIDATION/PRODUCTION. `LOCAL_FIREBASE_DEVELOPMENT.md` يوثق prerequisites وstartup وFlutter defines وreset/fixtures/functions/auth/firestore/troubleshooting. يحتفظ `REAL_FIREBASE_VALIDATION.md` بسجل الشبكة الحقيقية دون خلط.

## 5. الحواجز التالية

Cloud Functions production وFCM backend تتطلبان Blaze ولا تُترقى تلقائيًا. APK لا يزال بلا artifact بسبب sandbox memory، ولا يوجد جهاز Android متصل. هذه البنود لا تمنع التطوير Emulator-first، لكنها تمنع الادعاء بـFunctions deployed أو FCM delivered أو physical runtime.

## المراجع

[1]: https://firebase.google.com/docs/emulator-suite "Firebase Local Emulator Suite"
[2]: https://firebase.google.com/docs/functions/local-emulator "Run functions locally"
[3]: https://firebase.google.com/docs/firestore/security/rules-conditions "Writing conditions for Cloud Firestore Security Rules"
