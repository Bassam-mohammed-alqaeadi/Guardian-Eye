# خطة المرحلة العاشرة — تكامل Firebase الحقيقي

**المدخل المراجع:** ملف `google-services.json` سلّمه مالك المشروع في 12 أغسطس 2026. الفحص الأولي يطابق package `com.guardianeye.app` وAndroid app ID المشروع مع `android/app/build.gradle.kts`. يحتوي الملف Android client configuration وWeb API key مقيدة من Firebase client config؛ لا يحتوي private key أو service-account JSON أو OAuth client secret. يبقى الملف خارج سجلات التسليم العامة ويضاف إلى `android/app/` فقط.

| المجال | القرار | معيار القبول | بوابة الأمان |
|---|---|---|---|
| Android config | نسخ ملف المستخدم إلى `android/app/google-services.json` ثم تطبيق Google Services plugin فقط. | `flutter analyze` وGradle configuration لا يكشفان mismatch. | لا تغيير `applicationId` ولا تسجيل قيمة API key في docs/logs. |
| FlutterFire | استعمال `flutterfire configure --project=manus-guardian --platforms=android` فقط إذا CLI يقبل Project ID المراجع ويولد options. | وجود `lib/firebase_options.dart` مولد رسميًا والمراجعة تطابق project/app ID دون كشف key. | لا invent config يدويًا؛ توقف إن ظهر project mismatch. |
| Auth | إضافة anonymous method فقط إلى wrapper/UI دون تصنيف المستخدم المجهول كوالد مسجل. | unit tests للـunconfigured/signed-out/anonymous contracts، وتسجيل دليل real backend لاحقًا. | لا test credentials في source أو التقرير. |
| Firestore/Functions | فحص `firebase.json` وcodebase ثم طلب تأكيد صريح قبل deploy أو تشغيل real write. | Project ID من CLI يطابق ملف Android وتظهر only Guardian resources. | لا `--force` ولا rules weakening ولا production seed data. |
| Real Auth/Firestore | استخدام حسابات اختبار مخصصة، identifiers/hashes منقحة، read-back منفصل لكل خطوة. | evidence يحتوي expected/actual/time/status بلا PII. | لا اختبار دور Parent A/B قبل تأكيد rules deploy. |
| APK/device/FCM | إعادة محاولة APK بعد Firebase integration، ثم الجهاز وFCM في مراحل منفصلة. | artifact/hash/install أو blocker محدد. | backend acceptance لا يعني delivered/seen/acknowledged. |

## ترتيب التنفيذ

1. نسخ ملف Android فقط بعد تحقق hash/package ثم إضافة plugin الرسمي في root/app Gradle.
2. فحص FlutterFire CLI وCLI project state؛ توليد options فقط من `manus-guardian` أو التوقف عند الرفض/mismatch.
3. تطبيق bootstrap باستخدام `DefaultFirebaseOptions.currentPlatform` بدل تهيئة يدوية افتراضية حين يصبح الملف المولد متاحًا.
4. تنفيذ Auth contract/UI للـanonymous بوضوح وكتابة tests محلية.
5. تشغيل `flutter analyze` و`flutter test` ثم فحص Gradle/APK حسب الذاكرة المتاحة.
6. لا deploy ولا real write قبل عرض Firebase CLI project identity والموارد المراد نشرها للمراجعة.
7. عند توفّر الإذن/الهوية المراجعة، شغّل tests real backend بأسماء حسابات اختبار غير مخزنة وتوثيق منقح.

## حدود المرحلة

تكوين Android لا يثبت Firebase runtime، ونجاح Auth لا يثبت Firestore authorization، ونجاح Function لا يثبت FCM على الجهاز. كل طبقة تحتفظ بدليلها المنفصل في `docs/REAL_FIREBASE_VALIDATION.md`.
