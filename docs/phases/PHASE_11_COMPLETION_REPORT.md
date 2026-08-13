# تقرير المرحلة 11 — Firebase Auth وFirestore الحقيقيان

**الحالة:** **PARTIALLY COMPLETE WITH REAL BACKEND EVIDENCE**. أكملت هذه المرحلة التفويض الرسمي لـFirebase CLI وربط FlutterFire ونشر Firestore rules/indexes واختبارات Auth/Firestore حقيقية. Cloud Functions وFCM وAPK/الجهاز تبقى مفصولة ومقيدة بحواجز موثقة.

## 1. هوية ونطاق المشروع

سجّل Firebase CLI الدخول بحساب المشروع، وتحقق `firebase projects:list` من ظهور `manus-guardian`. استعملت جميع أوامر Firebase `--project manus-guardian`. لم يُنشأ مشروع جديد ولم يتغير `com.guardianeye.app`، ولم يُستبدل ملف Android بملف مشروع آخر.

## 2. FlutterFire وAndroid

نجح `flutterfire configure --project=manus-guardian --platforms=android --android-package-name=com.guardianeye.app --out=lib/firebase_options.dart --yes`. رُبط bootstrap بـ`DefaultFirebaseOptions.currentPlatform`، مع بقاء guard `GUARDIAN_FIREBASE_CONFIGURED` fail-closed. ملف options وملف Google Services محليان ومستبعدان من Git والحزم؛ لا توجد Admin credentials في Flutter.

## 3. تصحيح أمني قبل الإنتاج

اكتشفت المراجعة أن قاعدة member السابقة كانت تسمح للـprimary parent بتعديل role أو `memberUid` لطفل. لم أختبر هذا المسار على الإنتاج قبل الإصلاح. عُدلت القاعدة لتجميد الحقلين بعد الإنشاء، ثم نجحت 8 اختبارات Firestore Emulator، وأعيد نشر Firestore rules. أثبت backend الحقيقي HTTP 403 لمحاولة role escalation.

## 4. النشر

نجح نشر `firestore:rules` و`firestore:indexes` فقط إلى `manus-guardian`. لم يُنشر Storage. بدأت محاولة codebase `guardian` فقط بعد build TypeScript ناجح، لكن Firebase CLI أوقف Cloud Functions قبل النشر لأن `artifactregistry.googleapis.com` يتطلب خطة Blaze. لا توجد Guardian Functions منشورة وفق `firebase functions:list --json`.

## 5. الأدلة الحقيقية

| الاختبار | النتيجة الفعلية |
|---|---|
| Email registration | HTTP 200 |
| Email login | HTTP 200 |
| Token refresh/session continuation | HTTP 200 |
| Anonymous authentication | HTTP 200 |
| Atomic family + primary parent create | HTTP 200 |
| Parent family read-back | HTTP 200 |
| Cross-family read denied | HTTP 403 |
| Unauthenticated read denied | HTTP 403 |
| Role escalation denied | HTTP 403 |
| Revoked-device token write denied | HTTP 403 |
| Unauthorized device incident write denied | HTTP 403 |

الاختبار في `firebase/tests/real_backend_validation.mjs` ينشئ حسابات وبيانات اختبار عابرة ومقنعة وينفذ cleanup دون تسجيل email/password/token أو IDs خام.

## 6. الجودة والحواجز

`flutter analyze` بلا ملاحظات، و`flutter test` نجح بـ27 اختبارًا، وTypeScript Functions build نجح. Release APK لا يزال بلا artifact لأن Gradle daemon اختفى تحت حد sandbox حتى بعد إصلاح plugin Crashlytics الناقص بالنسخة الرسمية 3.0.7. `adb devices -l` لا يعرض جهازًا.

### الإجراء التالي

يتطلب نشر Cloud Functions Guardian وتمكين FCM backend ترقية Firebase project إلى Blaze؛ لا تنفذ هذه الترقية تلقائيًا لأنها تغيير فوترة. بعد ذلك يصبح الأمر المحصور: `firebase deploy --only functions:guardian --project manus-guardian`. يستلزم إثبات Flutter runtime وFCM جهاز Android وAPK صالحًا.

## المراجع

[1]: https://firebase.google.com/docs/flutter/setup "Add Firebase to your Flutter app"
[2]: https://firebase.google.com/docs/firestore/manage-data/transactions "Transactions and batched writes"
[3]: https://firebase.google.com/docs/firestore/security/rules-conditions "Writing conditions for Cloud Firestore Security Rules"
[4]: https://firebase.google.com/docs/crashlytics/android/get-started "Get started with Crashlytics for Android"
