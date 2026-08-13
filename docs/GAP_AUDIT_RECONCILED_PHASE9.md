# تدقيق الفجوات المتصالح — المرحلة التاسعة

**مصدر الحقيقة:** الشجرة الحالية والأوامر المنفذة بتاريخ 12 أغسطس 2026. لا تعتبر هذه الوثيقة Firebase Emulator بديلًا عن مشروع Firebase، ولا Android SDK بديلًا عن APK أو جهاز فعلي.

| المجال | الدليل المنفذ | التصنيف الدقيق | الفجوة التالية |
|---|---|---|---|
| تحليل Flutter | `flutter analyze` بلا ملاحظات | IMPLEMENTED + VERIFIED LOCALLY | لا فجوة تحليل حالية. |
| Flutter tests | `flutter test --reporter expanded`: 27 tests passed | IMPLEMENTED + VERIFIED LOCALLY | يحتاج integration/device tests لاحقًا. |
| SQLite/Outbox/policy/incident/SOS | اختبارات repository/domain المحلية | IMPLEMENTED + VERIFIED LOCALLY | network/process-death حقيقيان غير منفذين. |
| Firebase bootstrap | حارس fail-closed واختبار عدم التهيئة | IMPLEMENTED + VERIFIED LOCALLY | FlutterFire/project config. |
| Auth/Firestore/Functions contracts | TypeScript lint/build وEmulator | VERIFIED IN EMULATOR | Firebase project/deploy/Flutter client. |
| قواعد family isolation/device/token | 7 Firestore rules tests ناجحة | VERIFIED IN EMULATOR | نشر القواعد وحسابات حقيقية. |
| Child provisioning | distinct child UID + atomic redemption + replay rejection | VERIFIED IN EMULATOR | callable UI/runtime/project backend. |
| Incident/SOS notification events | Functions triggers Emulator | VERIFIED IN EMULATOR | deploy، token، FCM حقيقي. |
| FCM receipt/display/acknowledgement | لا token أو جهاز أو Console | BLOCKED BY ENVIRONMENT | Messaging config + physical Android. |
| Android SDK/JDK/ADB | Android SDK 36/JDK17/ADB verified في `flutter doctor -v` | IMPLEMENTED + VERIFIED LOCALLY | لا AVD/serial في ADB. |
| Android host compilation defects | أزيل stale registrant؛ AndroidX/desugaring مفعّلان | IMPLEMENTED + VERIFIED LOCALLY | final release build memory capacity. |
| Android release APK | لا artifact؛ Gradle daemon اختفى تحت 1GB/1.5GB sandbox أثناء compilation، بعد حل errors محددة | IMPLEMENTED — VALIDATION BLOCKED | عامل Android بذاكرة أعلى، artifact/hash/install. |
| Android runtime/background | `adb devices -l` فارغ؛ لا AVD | BLOCKED BY ENVIRONMENT | جهاز/AVD وscenarios منفذة. |
| Firebase project/FlutterFire | لا project alias/options/Google files ولا authorized CLI account | HUMAN ACTION REQUIRED | اتبع `FIREBASE_SETUP_REQUIRED.md`. |
| iOS/APNs | Linux بلا Xcode/macOS/iPhone | BLOCKED BY ENVIRONMENT | Mac + Apple team/device. |
| On-device AI model | لا TensorFlow Lite model/model card/test corpus | NOT IMPLEMENTED | نموذج مراجع واختبارات hardware. |

## عيوب مصححة في المرحلة التاسعة

1. أعيدت استعادة شجرة Android الكاملة من حزمة المرحلة الثامنة بعد أن كشف الاسترداد الجزئي افتقاد Manifest، والذي كان يؤدي إلى تشخيص v1 embedding مضلل. Manifest المستعاد يتضمن `flutterEmbedding=2`.
2. أزيل `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` الثابت؛ كان قديمًا ويشير إلى `dev.fluttercommunity.workmanager.WorkmanagerPlugin` غير الموجود في Workmanager الحالي. لا تستدعيه `MainActivity`، ويولد Flutter registrant المتوافق في عملية البناء.
3. أضيف AndroidX وJetifier وcore library desugaring و`desugar_jdk_libs:2.1.5`، استجابة لمتطلبات `flutter_local_notifications` التي أكدتها مهمة AAR metadata.[1]

## حواجز لا يُسمح بتجاوزها

لا تختلق `firebase_options.dart`، ولا تستخدم UID الوالد بدل UID الطفل، ولا تنشر إلى Project ID مجهول، ولا تدعي APK نجاحًا بلا `app-release.apk`، ولا تستبدل FCM backend acceptance باستلام جهاز أو عرض مستخدم. التفاصيل والأوامر في `PHASE_9_BLOCKERS.md` و`HUMAN_ACTION_REQUIRED.md`.

## المرجع

[1]: https://developer.android.com/studio/write/java8-support "Core library desugaring with Android Gradle Plugin"
