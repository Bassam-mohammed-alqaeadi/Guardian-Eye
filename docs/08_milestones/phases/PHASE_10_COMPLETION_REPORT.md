# تقرير حالة المرحلة العاشرة — Android Firebase Client Integration

**التاريخ:** 12 أغسطس 2026. **الحالة:** **PARTIALLY IMPLEMENTED — REAL BACKEND VALIDATION BLOCKED**. اكتمل التكامل المحلي الآمن المتاح من ملف Android المقدم؛ بقي التحقق الحقيقي والنشر محجوبين فقط بسبب غياب Firebase CLI authorization، لا بسبب package mismatch أو حاجة إلى إعادة كتابة التطبيق.

## A. هوية المشروع وملف Android

فُحص الملف المقدم قبل النسخ. Project ID هو `manus-guardian`، Android package هو `com.guardianeye.app`، وAndroid client app ID موجود في ملف config ويتطابق prefix الخاص به مع Project Number. طابق package، `namespace`، و`applicationId` القيم نفسها، لذا لم يحدث أي تغيير صامت لمعرف التطبيق. لا يسجل هذا التقرير Web API key أو Android app ID كاملًا.

لم تظهر حقول `private_key` أو `private_key_id` أو `service_account` أو `client_secret`. لذلك الملف Android client config وليس Firebase Admin credential. نسخ إلى `android/app/google-services.json` بصلاحية `0600` واستبعد من Git؛ لا يوجد Admin SDK داخل Flutter.

## B. Android Gradle

أضيف `com.google.gms.google-services` version `4.4.4` في root plugin block وطُبق على module `app`. نجح:

```bash
flutter build apk --debug --config-only --no-pub
```

هذه نتيجة **VERIFIED LOCALLY** لتهيئة Gradle فقط. محاولة `flutter build apk --release --target-platform android-arm64` لم تنتج artifact؛ اختفى Gradle daemon تحت حد sandbox بعد 51.3 ثانية. لا APK path أو size أو version أو hash يمكن الإبلاغ عنه.

## C. FlutterFire

ثبتت Firebase CLI `15.26.0` وFlutterFire CLI `1.4.1`. لم يولد `lib/firebase_options.dart`: `firebase login:list` لا يعرض حسابًا، وFlutterFire لم يستطع `firebase projects:list`. رفضت صراحةً اقتراح FlutterFire بإنشاء Firebase project جديد؛ Project ID الصحيح معروف ولا يجوز استبداله. لم تُنشأ قيم يدويًا.

## D. Firebase Core وAuth

الـbootstrap القائم يستعمل `Firebase.initializeApp()` فقط عند `GUARDIAN_FIREBASE_CONFIGURED=true`، ويظل fail-closed عند غياب العلم/config. مع Google Services Android يمكن لـdefault options أن تُستخدم على Android عندما يصبح runtime متاحًا، لكن لا يوجد جهاز أو APK لإثبات initialization.

أضيف `signInAnonymously()` إلى `FirebaseAuthService` وزر جلسة مؤقتة إلى واجهة الحساب. تصف الواجهة الجلسة المجهولة بصراحة بأنها لا تمنح role والد أو family membership؛ التفويض يستمر عبر layer domain/Firestore rules. لم تجر anonymous/email/login/logout/restoration على backend حقيقي لأن CLI/session/device غير متاحة.

## E. Firestore, Functions, FCM

تبقى نتائج Firebase Emulator الأخيرة مستقلة: 2 Auth/Functions tests و7 Firestore Rules tests ناجحة. لا يوجد real Firestore write/read-back، ولا rules deployment، ولا functions deployment/logs، ولا FCM token/fanout/received/displayed/acknowledgement. لم تُخفف القواعد ولم تستخدم Parent UID كـchild UID.

## F. تحقق الجودة

| الأمر | النتيجة |
|---|---|
| `flutter analyze` | PASS — No issues found. |
| `flutter test --reporter expanded` | PASS — 27 tests passed. |
| Google Services config-only | PASS — Gradle configuration completed. |
| `flutter build apk --release --target-platform android-arm64` | BLOCKED — Gradle daemon disappeared; APK absent. |

## G. الحواجز والإجراء التالي

**الخطوة البشرية الوحيدة المطلوبة للتقدم الحقيقي:** تسجيل Firebase CLI في نفس بيئة التنفيذ بحساب عضو يملك access إلى `manus-guardian`، من دون إرسال password أو token في المحادثة. بعده سيتحقق النظام من `firebase projects:list`، ويولد FlutterFire options، ثم يعرض نطاق deploy لمراجعة منفصلة قبل أي نشر.

الوثائق الداعمة هي: `FIREBASE_REAL_ENVIRONMENT_SETUP.md`، `REAL_FIREBASE_VALIDATION.md`، `GAP_AUDIT_RECONCILED_PHASE10.md`، و`HUMAN_ACTION_REQUIRED.md`.

## المراجع

[1]: https://firebase.google.com/docs/android/setup "Add Firebase to your Android project"
[2]: https://firebase.google.com/docs/flutter/setup "Add Firebase to your Flutter app"
[3]: https://firebase.google.com/docs/auth/flutter/anonymous-auth "Anonymous authentication for Flutter"
