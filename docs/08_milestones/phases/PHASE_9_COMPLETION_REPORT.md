# تقرير إكمال المرحلة التاسعة — Bootstrap البيئة وAndroid

**التاريخ:** 12 أغسطس 2026. **حالة المرحلة:** **ENGINEERING COMPLETE / REAL ENVIRONMENT VALIDATION BLOCKED**. نُفذ تدقيق البيئة، وثُبت Android toolchain وJDK 17، وأصلحت عوائق Android source/Gradle محددة، وأعيدت اختبارات Flutter وFirebase Emulator. لا توجد أدلة Firebase حقيقية أو APK أو جهاز Android أو FCM مادي، ولذلك لا يحق وصف المرحلة بأنها «REAL ENVIRONMENT VALIDATED» أو «production-ready».

## A. الملخص التنفيذي

ركزت المرحلة على إزالة فجوات البيئة لا إضافة ميزات. أصبحت أدوات Android المحلية متاحة: Android SDK 36 وBuild Tools 36.0.0 وplatform-tools وNDK 28.2.13676358 وCMake 3.22.1 وJDK 17. أصلحت الشجرة المستعادة registrant قديمًا غير متوافقًا مع Workmanager، وأضفت AndroidX وcore-library desugaring المطلوبة من `flutter_local_notifications`. تحسن بناء release حتى compilation، لكنه لا يزال يفشل في sandbox بسبب اختفاء Gradle daemon تحت حد الذاكرة بعد أن تجاوز الأخطاء المصدرية؛ لا يوجد `app-release.apk`.

| مستوى الدليل | النتيجة |
|---|---|
| محلي | `flutter analyze` بلا ملاحظات و**27 اختبار Flutter ناجح**. |
| Emulator | **2 Functions/Auth tests** و**7 Firestore Rules tests** ناجحة. |
| Firebase حقيقي | لا مشروع/حساب/config/deploy؛ **لا دليل**. |
| Android APK | لم ينتج artifact؛ **لا دليل**. |
| جهاز/FCM | `adb devices -l` فارغ؛ **لا دليل**. |

## B. البيئة

| العنصر | النتيجة الفعلية |
|---|---|
| OS | Ubuntu 24.04.4 LTS Linux. |
| Flutter | 3.44.9، Dart 3.12.2. |
| Java | OpenJDK 17.0.19 مع `javac 17.0.19`. |
| Android SDK | `/home/ubuntu/android-sdk`، platform android-36 وBuild Tools 36.0.0. |
| ADB | 1.0.41 / platform-tools 37.0.1؛ لا devices متصلة. |
| Android Emulator | غير مثبت؛ لا AVD. |
| Firebase CLI/FlutterFire CLI | CLI تم استخدامها عبر `npx firebase-tools@15.26.0` للـEmulator؛ لا حساب Firebase مصرح. FlutterFire لا تستطيع config بلا Project ID. |
| Node/npm | Node 22.13.0، npm 10.9.2 في تدقيق البيئة. |

لم تجر ترقية Flutter أو اعتماديات Dart. خُفّض توازي Gradle إلى عامل واحد، واستُخدم JDK 17 بعد أن أثبتت المحاولة الأولى أن Java 21 المتاحة لم تكن تتضمن compiler.

## C. مشروع Firebase

لا يوجد Project ID أو `.firebaserc` أو `firebase_options.dart` أو `google-services.json` أو `GoogleService-Info.plist`. أظهر `firebase login:list` أنه لا توجد حسابات مفوضة. لم يُنفذ `firebase login` أو `firebase use` أو أي deploy، لذلك لا توجد وجهة تخاطر بها هذه المرحلة. يظل bootstrap في وضع fail-closed حتى ملفات FlutterFire الحقيقية. يقدم `docs/FIREBASE_SETUP_REQUIRED.md` الخطوات الدقيقة.[1]

## D. المصادقة

تظل `FirebaseAuthService` و`FirebaseAuthContext` وواجهة الحالة غير المهيأة موجودة ومختبرة محليًا. في Emulator أنشأت اختبارات provisioning UID والد وUID طفل مختلفًا وتحققت من binding ورفض replay. لم يسجل التطبيق دخولًا إلى Firebase حقيقي ولم يستعد session ولم ينفذ logout على جهاز، وبالتالي:

| دليل | الحالة |
|---|---|
| Contract وfail-closed UI | IMPLEMENTED + VERIFIED LOCALLY |
| UID identity في callable | VERIFIED IN EMULATOR |
| Account register/login/session/logout حقيقي | HUMAN ACTION REQUIRED |

## E. Firestore

عقود family/member/device والحوافز Outbox موجودة، وEmulator يثبت family isolation وatomic family creation. لم ينفذ تطبيق Flutter write/read-back من شبكة Firebase حقيقية، إذ لا توجد خيارات FlutterFire ولا Project ID. لا يسمح التقرير باستبدال اختبار Node Emulator بدليل Firestore إنتاجي.[2]

## F. الأمن

تغطي اختبارات Firestore Emulator: Family A مقابل Family B، إنشاء الأسرة/عضو الوالد الذري، منع role escalation، منع الوالد من binding UID الطفل من العميل، token boundary للوالد، رفض جهاز مسحوب، ومنع client notification-event write. ظل إدخال UID الطفل عبر callable provisioning فقط. لا توجد قواعد منشورة أو IAM audit أو App Check مفروض على backend حقيقي؛ هذه فجوة نشر لا عيب مبرر لتخفيف القواعد.

## G. Device Provisioning

تتحقق الدوال في Emulator من: parent authorization، six-digit session، SHA-256 storage، مدة عشر دقائق، one-time redemption، UID طفل منفصل، device/member binding ذري، ورفض replay. لم يتصل Flutter pairing screen بعد بـcallable على جهاز أو Firebase حقيقي، ولم يتحقق expiry/five-attempt lockout على backend حقيقي.

## H. المزامنة

يبقى المسار: `UI → Riverpod → OutboxSyncExecutor → Auth → Firestore writer`، مع SQLite مصدر الحقيقة وretry/blocked/idempotency في الاختبارات المحلية. لا توجد تجربة online/offline/recovery على Android أو Firestore read-back من التطبيق؛ لا تدعي المرحلة ذلك. حُددت خطوات الأداء والتكلفة والqueue growth في وثيقة observability المرحلة الثامنة.

## I. Cloud Functions

| المسار | النتيجة |
|---|---|
| TypeScript lint/build | PASS محليًا ضمن `firebase/functions`. |
| Auth/Firestore/Functions Emulator | PASS: **2 tests**؛ incident/SOS events وprovisioning/replay. |
| Firestore Rules Emulator | PASS: **7 tests**. |
| نشر الدوال | لم ينفذ؛ لا Project ID. |

تشغيل Emulator بقي معزولًا ولا يستخدم FCM خارجيًا؛ عند وجود token اختباري تحفظ الدالة `fcmNotExercisedInEmulator` بدل محاولة delivery.

## J. FCM

| الحالة | الدليل المتاح | النتيجة |
|---|---|---|
| Requested | incident/SOS Outbox محلي | VERIFIED LOCALLY |
| Notification Event Created | Functions Emulator | VERIFIED IN EMULATOR |
| FCM Processing | server contract/claim موجود | IMPLEMENTED — VALIDATION BLOCKED |
| FCM Accepted | لا Firebase Messaging/token حقيقي | BLOCKED BY ENVIRONMENT |
| Device Received | لا جهاز | BLOCKED BY ENVIRONMENT |
| Displayed | لا جهاز | BLOCKED BY ENVIRONMENT |
| Acknowledged | لا handler/device evidence | BLOCKED BY ENVIRONMENT |

قبول backend لا يعني الاستلام أو العرض أو تفاعل المستخدم، وفق حدود FCM المعروفة.[3]

## K. Android

**Toolchain:** تم التحقق من SDK وJDK وADB عبر `flutter doctor -v`. **Device model/API/ABI:** غير متاح؛ لا serial في ADB. **APK:** غير منتج، ولا hash أو size أو installation result.

كشفت المحاولات عوائق حقيقية وصححت المصدر قبل بلوغ قيد sandbox:

1. الاسترداد الجزئي فقد Android host files وسبب تشخيص v1 embedding؛ أعيدت الشجرة من حزمة المرحلة الثامنة، وManifest يحتوي `flutterEmbedding=2`.
2. أزيل `GeneratedPluginRegistrant.java` ثابت قديم يشير إلى Workmanager class غير موجود؛ `MainActivity` لا يستدعيه وFlutter يولد registrant المتوافق.
3. فُعل AndroidX وJetifier وcore library desugaring، وأضيف `desugar_jdk_libs:2.1.5` بعد أن طلبتها AAR metadata لـflutter_local_notifications.[4]
4. بعد تجاوز هذه الأخطاء، اختفى Gradle daemon أثناء release compilation تحت 1GB/1.5GB heap في sandbox. لم ينتج artifact، وهذا **ليس نجاح APK**.

يستخدم build type `release` debug signing حاليًا في `android/app/build.gradle.kts`؛ حتى بعد نجاح artifact، لا يجوز توزيعه تجاريًا بلا keystore وإدارة signing بشرية.

## L. الخلفية والمرونة

لا نفذت process death أو force-stop أو reboot أو Doze أو network chaos على جهاز/AVD، وبالتالي لا توجد نتيجة لهذه السيناريوهات. المنفذ المحلي يفصل retryable/permanent failures في اختبارات Flutter فقط. لا أضيف background loop؛ يستلزم تشغيل WorkManager/permissions/Doze دليل جهاز وسياسة متجر.

## M. الاختبارات والأوامر

| الأمر | النتيجة |
|---|---|
| `flutter doctor -v` | Android toolchain detected؛ SDK 36/JDK17/licenses accepted. |
| `flutter analyze` | PASS — No issues found. |
| `flutter test --reporter expanded` | PASS — **27 tests passed**. |
| `cd firebase/functions && npm ci && npm run lint && npm run build` | PASS. |
| `npx firebase-tools@15.26.0 emulators:exec --only auth,firestore,functions …` | PASS — Functions **2** + Rules **7**. |
| `flutter build apk --release --target-platform android-arm64` | FAIL — Gradle daemon disappeared under sandbox resource constraint; APK absent. |

تعد رسائل `PERMISSION_DENIED` في rules tests نتائج متوقعة لـ`assertFails` وليست إخفاقات suite.

## N. الحواجز

التفاصيل التنفيذية في `docs/PHASE_9_BLOCKERS.md`. أهمها: Project ID/config/deploy/FCM مفقودة، لا جهاز أو AVD، لا macOS/Xcode، وrelease Gradle يحتاج عامل ذاكرة أعلى لإنتاج artifact. لا يمثل أي منها سببًا لتبديل Flutter أو إدخال أسرار أو إضعاف UID/cواعد الطفل.

## O. الإجراءات البشرية

يحتوي `HUMAN_ACTION_REQUIRED.md` checklist صريحة. تبدأ باختيار Firebase test project ومراجعة IAM ثم FlutterFire والنشر، تليها APK على عامل أكبر، Android device/AVD، ثم FCM state machine. لا يوجد بند Firebase أو device أو FCM معلّم مكتملًا بلا دليل.

## P. مصفوفة الجاهزية

راجع `docs/PHASE_9_PRODUCTION_READINESS_MATRIX.md`. الوضع الحالي: محلي وEmulator متحققان ضمن الحدود المذكورة، بينما Real Firebase وPhysical Android وProduction **BLOCKED**.

## Q. تدقيق الفجوات المحدث

راجع `docs/GAP_AUDIT_RECONCILED_PHASE9.md`. يربط كل مطلب بحالة واحدة: IMPLEMENTED + VERIFIED LOCALLY، VERIFIED IN EMULATOR، IMPLEMENTED — VALIDATION BLOCKED، HUMAN ACTION REQUIRED، NOT IMPLEMENTED، أو BLOCKED BY ENVIRONMENT.

## R. المرحلة الموصى بها التالية

المرحلة العاشرة يجب أن تكون **Artifact and Real Firebase Test-Project Validation**: تشغيل release APK على عامل Android بذاكرة كافية، ثم FlutterFire/Project test/deploy، ثم Flutter-to-Emulator vertical slice، وأخيرًا جهاز Android وFCM evidence. لا يوصى بإضافة ميزات مراقبة أو AI أو مدفوعات قبل هذه البوابات.

## المراجع

[1]: https://firebase.google.com/docs/flutter/setup "Add Firebase to a Flutter app"
[2]: https://firebase.google.com/docs/emulator-suite "Firebase Local Emulator Suite"
[3]: https://firebase.google.com/docs/cloud-messaging/send-message "Firebase Cloud Messaging message sending"
[4]: https://developer.android.com/studio/write/java8-support "Core library desugaring"
