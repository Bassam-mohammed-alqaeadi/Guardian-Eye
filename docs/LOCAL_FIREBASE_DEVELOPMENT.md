# تطوير Guardian Eye Pro باستخدام Firebase Emulator Suite

هذا الدليل مخصص للتطوير اليومي والاختبارات المجانية. لا يحتاج خطة Blaze، ولا يسجل دخول Firebase CLI، ولا يكتب إلى `manus-guardian`.

## المتطلبات

يلزم Flutter وNode.js 20 وFirebase CLI وJava 17. ثبّت اعتماديات Flutter وFunctions وtests مرة واحدة:

```bash
cd /home/ubuntu/guardian_eye_flutter
flutter pub get
npm --prefix firebase/functions ci
npm --prefix firebase/tests ci
```

## تشغيل Emulator يدويًا

من جذر المشروع شغّل:

```bash
firebase emulators:start --only auth,firestore,functions --project guardian-eye-emulator
```

المنافذ هي Auth `9099` وFirestore `8080` وFunctions `5001` وواجهة Emulator `4000`. المعرف `guardian-eye-emulator` اصطناعي ومختلف عمدًا عن `manus-guardian` الحقيقي.

## تشغيل Flutter مقابل Emulator

يجب تحديد البيئة والـhost صراحة. لا تستخدم هذه الأوامر في production:

```bash
# Android Emulator على نفس الحاسوب
flutter run \
  --dart-define=GUARDIAN_ENV=development \
  --dart-define=GUARDIAN_FIREBASE_EMULATOR_HOST=10.0.2.2

# هاتف Android حقيقي على الشبكة المحلية: استبدل العنوان بعنوان حاسوب التطوير
flutter run \
  --dart-define=GUARDIAN_ENV=development \
  --dart-define=GUARDIAN_FIREBASE_EMULATOR_HOST=192.168.1.20
```

في `TEST` استبدل قيمة environment بـ`test` مع host صريح. إذا لم تمرر environment معتمدًا وhost صحيحًا، يبقى bootstrap fail-closed ولا تستدعى Firebase.

## التشغيل الآلي للـEmulator

لتشغيل قواعد Firestore وAuth وFunctions في جلسة معزولة نظيفة:

```bash
./tool/run_firebase_emulator_tests.sh
```

السكربت يبني الدوال ثم يشغل Auth/Firestore/Functions Emulator في project اصطناعي ويشغل **8** اختبارات قواعد و**2** اختبارات Functions. لا يستدعي `test:real` ولا يكتب إلى Firebase الحقيقي.

## البيانات وإعادة الضبط

تبدأ `emulators:exec` من بيانات عابرة وتنظفها عند الانتهاء. عند التشغيل اليدوي، أوقف العملية بـ`Ctrl+C` لإزالة الحالة العادية غير المستوردة. لا تحفظ fixtures الأسرية الحقيقية؛ تستعمل الاختبارات أسماء/معرفات اصطناعية فقط.

## Functions وFCM في التطوير

يتحقق Functions Emulator من Incident وSOS إلى notification event، ومن provisioning للطفل وإعادة الاستخدام. يتعمد `fanoutNotification` عدم إرسال FCM في Emulator ويكتب حالة `fcmNotExercisedInEmulator` أو `noActiveToken`. هذه ليست رسالة وصلت إلى جهاز.

## فصل الاختبارات الحقيقية

`npm --prefix firebase/tests run test:real` هو اختبار شبكة حقيقي منفصل، يستعمل حسابات validation عابرة ويكتب إلى `manus-guardian`. لا تشغله في CI اليومي أو أثناء Emulator-first development. راجع `REAL_FIREBASE_VALIDATION.md` قبل تشغيله.

## استكشاف المشكلات

| العرض | السبب المرجح | الحل |
|---|---|---|
| bootstrap fail-closed | environment أو host غير محددين | مرر `GUARDIAN_ENV=development` أو `test` وhost صريحًا. |
| Flutter Android Emulator لا يصل إلى Emulator | استعمل `127.0.0.1` من داخل Android Emulator | استعمل `10.0.2.2`. |
| Functions test يفشل قبل triggers | source TypeScript غير مبني | شغل `npm --prefix firebase/functions run build`. |
| اختبار حقيقي يعمل بالخطأ | استعملت `test:real` | أوقفه، وارجع إلى `./tool/run_firebase_emulator_tests.sh`. |
| FCM لا يصل | Emulator لا يرسل FCM حقيقيًا | سجل فقط notification-event contract؛ اختبر التسليم لاحقًا على جهاز مع Functions منشورة. |

## المراجع

[1]: https://firebase.google.com/docs/emulator-suite/connect_and_prototype "Connect your app to the Local Emulator Suite"
[2]: https://firebase.google.com/docs/functions/local-emulator "Run functions locally"
