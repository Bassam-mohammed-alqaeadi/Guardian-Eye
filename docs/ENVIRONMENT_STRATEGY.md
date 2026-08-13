# استراتيجية بيئات Guardian Eye Pro

Guardian Eye Pro يحافظ على **مصدر Firebase إنتاجي واحد** هو `manus-guardian`، لكنه يستعمل Firebase Emulator Suite للتطوير والاختبارات اليومية. لا توجد بيئة هجينة ولا اختيار افتراضي صامت.

| البيئة | Firebase target | شرط البدء | الاستخدام المسموح | الدليل المسموح |
|---|---|---|---|---|
| `DEVELOPMENT` | Auth/Firestore/Functions Emulator | `GUARDIAN_ENV=development` + host Emulator صريح | تطوير Flutter اليدوي، fixtures، استكشاف تدفقات غير حساسة | VERIFIED IN EMULATOR |
| `TEST` | Auth/Firestore/Functions Emulator | `GUARDIAN_ENV=test` + host Emulator صريح | اختبارات تكامل متكررة وآلية | VERIFIED IN EMULATOR |
| `REAL_BACKEND_VALIDATION` | `manus-guardian` الحقيقي | `GUARDIAN_ENV=real_backend_validation` + `GUARDIAN_REAL_BACKEND_VALIDATION=true` | smoke tests دورية بحسابات اختبار عابرة فقط | VERIFIED ON REAL BACKEND |
| `PRODUCTION` | `manus-guardian` الحقيقي | `GUARDIAN_ENV=production` + `GUARDIAN_PRODUCTION_APPROVED=true` | APK/جهاز/إطلاق مخول فقط | VERIFIED ON PHYSICAL DEVICE عند توفر الدليل |
| غير محددة أو متناقضة | لا شيء | لا يوجد | SQLite المحلي فقط؛ لا تستدعى Firebase | BLOCKED / fail-closed |

## ضوابط منع الخلط

`GuardianFirebaseEnvironmentConfig` لا يقبل `development` أو `test` ما لم يمرر host Emulator صريحًا، ولا يقبل real backend أو production ما لم يمرر approval define مختلف. لذلك لا يستطيع أمر تطوير عادي أن يكتب إلى `manus-guardian`، ولا يستطيع أمر production أن يشير إلى Emulator بصورة صامتة.

> **قاعدة الدليل:** نجاح Emulator لا يثبت الإنتاج، ونجاح Firebase API الحقيقي لا يثبت Android runtime أو FCM receipt أو acknowledgement.

## مصادر Firebase التي يجب حفظها

يظل `android/app/google-services.json` و`lib/firebase_options.dart` محليين وخارج Git والحزمة. يولدهما FlutterFire من `manus-guardian` فقط ولا يجوز استبدالهما ببيانات مصطنعة. يبقى `.firebaserc` و`firebase.json` مسارات تعريف غير سرية تخدم Emulator والنشر المقيد.

## مرجع الأدلة

التاريخ التفصيلي لـAuth وFirestore الحقيقيين محفوظ في `REAL_FIREBASE_VALIDATION.md` و`docs/phases/PHASE_11_COMPLETION_REPORT.md`. النتائج المحلية وEmulator لا تستبدل ذلك السجل.

## المراجع

[1]: https://firebase.google.com/docs/emulator-suite "Firebase Local Emulator Suite"
[2]: https://firebase.google.com/docs/flutter/setup "Add Firebase to your Flutter app"
