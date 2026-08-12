# حواجز المرحلة التاسعة — البيئة الحقيقية وAndroid

**تاريخ التسجيل:** 12 أغسطس 2026. يصف هذا الملف حقائق البيئة المنفذة فقط، ولا يحول نجاح Emulator إلى تحقق Firebase أو Android فعلي.

| الحاجز | سبب وجوده | الإجراء البشري الدقيق | الأمر الدقيق | النتيجة المتوقعة | طريقة التحقق | ما يمكن متابعته مستقلاً |
|---|---|---|---|---|---|---|
| Firebase Project ID | لا توجد `.firebaserc` أو حساب Firebase مصرح به أو ملفات FlutterFire. | يختار المالك مشروع اختبار ويصرح باستعمال Project ID محدد. | `firebase login` ثم `firebase use --add <FIREBASE_PROJECT_ID>`. | alias محلي للمشروع المراجع. | `firebase use` يعرض Project ID قبل أي deploy. | تبقى الاختبارات المحلية وEmulator متاحة وbootstrap fail-closed. |
| FlutterFire/Android config | لا يوجد `firebase_options.dart` أو `google-services.json` أو iOS plist. | يسجل المالك `com.guardianeye.app` وينزل ملفات المشروع الصحيح. | `flutterfire configure --project=<FIREBASE_PROJECT_ID> --platforms=android,ios`. | config generated من FlutterFire. | `flutter analyze` وتهيئة Firebase على test device/Emulator. | واجهة Firebase تبقى صادقة بشأن عدم التهيئة. |
| نشر rules/functions | لا توجد وجهة Firebase معتمدة ولا Console verification. | يراجع المالك Project ID والقواعد والفهارس والدوال قبل النشر. | `firebase deploy --only firestore:rules,firestore:indexes,functions:guardian --project <FIREBASE_PROJECT_ID>`. | الموارد Guardian فقط منشورة. | Console + Cloud Logging + allow/deny accounts. | Auth/Firestore/Functions Emulator tests. |
| FCM/APNs حقيقي | لا يوجد Firebase Messaging project أو token مادي أو APNs configuration. | فعّل Messaging، وAPNs على macOS، ثم سجّل token من جهاز فعلي. | لا يكفي أمر واحد؛ نفذ checklist في `HUMAN_ACTION_REQUIRED.md`. | token → event → accepted → received → displayed evidence مفصول. | logs منقحة وجهاز حقيقي وnotification tap. | event/fanout contracts وEmulator skip guard. |
| APK release | release build لا يُنتج artifact في sandbox المحدود رغم اكتمال Android toolchain وإصلاح registry/desugaring. | استخدم عامل Android ذاكرة كافية؛ لا توزع build debug-signed. | الأمر المسجل في `IMPLEMENTATION_BLOCKERS.md`. | `app-release.apk` arm64 أو universal. | size/hash/aapt، ثم install. | تحليل Flutter وEmulator والأمن والتوثيق. |
| جهاز/AVD Android | لا serial في `adb devices -l` ولا AVD. | صِل هاتفًا مع USB debugging أو جهز AVD. | `adb devices -l` ثم `adb install -r <APK>`. | device + install success. | launch، family flow، offline/network recovery، background evidence. | Android host compile fixes وADB readiness. |
| iOS/macOS | هذا host Linux بلا Xcode أو APNs signing. | نفذ على macOS مع Xcode وApple Developer Team وiPhone. | `flutter build ios --debug --no-codesign` ثم Xcode/device signing. | iOS build/install. | permission/APNs/secure storage evidence. | Flutter cross-platform code وiOS templates. |

> لا تعالج حواجز البيئة بتخفيف قواعد Firestore أو استعمال UID والد لطفل أو إضافة credential إلى التطبيق. تتوقف الادعاءات عند مستوى الدليل المتاح.
