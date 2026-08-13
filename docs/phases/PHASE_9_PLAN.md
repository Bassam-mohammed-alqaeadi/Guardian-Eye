# خطة المرحلة التاسعة — Bootstrap بيئة حقيقية والتحقق من Android

**تاريخ الخطة:** 12 أغسطس 2026. **خط الأساس:** تحقق المرحلة الثامنة محليًا وضمن Auth/Firestore/Functions Emulator، لكن لا يوجد مشروع Firebase alias أو ملفات FlutterFire أو Android SDK/ADB أو جهاز Android متصل في البيئة الحالية. لا تُسوّي هذه الخطة بين Emulator وخلفية Firebase حقيقية أو جهاز فعلي.

> الهدف هو إزالة عدم اليقين القابل للإزالة تلقائيًا، وبناء APK فقط إن توفرت سلسلة Android اللازمة بالفعل أو أمكن تثبيتها بأمان، ثم توثيق كل حد خارجي بأوامر محددة.

## A. قابل للتنفيذ تلقائيًا

| العمل | الإجراء | الدليل المطلوب |
|---|---|---|
| تدقيق بيئة التطوير | تسجيل Flutter/Dart/Java/Gradle/Node/npm و`flutter doctor -v` وملفات Firebase | مخرجات أو جدول بيئة في تقرير المرحلة. |
| تدقيق مضيف Android | مراجعة package/minSdk/Java/Gradle وموضع Google Services | تقرير جاهزية لا يغير identifiers ولا signing. |
| تثبيت Android CLI الأدنى | تثبيت command-line tools/platform-tools/SDK platform/build-tools فقط إذا غابت وكان التنزيل متاحًا | `flutter doctor` يتعرف على Android toolchain، و`adb version`. |
| صحة Flutter/Functions | `flutter analyze` و`flutter test` وTypeScript lint/build وEmulator tests | exit code صفر ونتائج مسجلة. |
| أمان/كلفة/background | مراجعة retry/Outbox/FCM payload/logging وWorkManager | وثيقة مخاطر وإجراءات؛ لا background loop جديد. |

## B. يتطلب اعتماديات أو مشروع Firebase

| المتطلب | سبب الحظر | الإجراء التالي |
|---|---|---|
| Project ID وFlutterFire options | لا يجوز اختلاق خيارات أو API keys أو project alias | يختار المالك مشروع اختبار، ثم يشغل `flutterfire configure`. |
| Firebase Auth/Firestore الحقيقيان | لا يوجد provider أو قاعدة منشوران لهذا المشروع | تفعيلهما، نشر rules/indexes، وتوثيق UID وread-back منقحين. |
| Functions/FCM الحقيقيان | no deploy target ولا token حقيقي | نشر codebase `guardian` على Project ID موثق ثم فصل backend acceptance عن جهاز received/displayed. |

## C. يتطلب إجراء Firebase Console

| الإجراء | بوابة الأمان | التحقق |
|---|---|---|
| اختيار مشروع وتقييد IAM | لا نشر أو `firebase use` إلى مشروع مجهول | Project ID راجعه مالك بشري في Console. |
| Auth وFirestore وFCM | لا تفعيل provider إضافي بلا موافقة | Console settings وصور/سجل مراجعة داخلي منقح. |
| نشر rules/indexes/functions | لا نشر قبل Emulator/PR review | `firebase deploy --only … --project <ID>` بمخرجات محفوظة. |

## D. يتطلب Android SDK

| البند | الحد الأدنى | معيار الإغلاق |
|---|---|---|
| APK release | JDK 17، Android command-line tools، platform-tools، platform/build-tools المتوافقة وlicenses | `flutter build apk --release` مع exit code، path، size، variant، version. |
| محاكي Android | system image وAVD وموارد افتراضية مناسبة | AVD يعمل و`adb devices -l` يظهر الجهاز. |
| تنبيه signing | المشروع يستخدم debug signing للـrelease حاليًا | لا يُوزع build تجاري؛ يحتاج keystore من المالك قبل متجر. |

## E. يتطلب جهاز Android فعليًا

| التحقق | الدليل |
|---|---|
| تثبيت وتشغيل | طراز/OS/API/ABI، `adb install`، launch result. |
| Auth وfamily/child/sync | تسجيل منقح لـUID/document IDs وread-back في Firestore. |
| offline/recovery/background | سيناريو منفذ فعليًا مع وقت ونتيجة؛ لا ادعاء Doze/reboot بلا تنفيذ. |
| FCM | token stored، notification event، accepted، received، displayed، tap، acknowledged كحالات مستقلة. |

## F. إجراءات بشرية فقط

يتطلب iOS/APNs macOS/Xcode وApple Developer account وiPhone؛ كما يتطلب اختيار منطقة Firestore، IAM، billing/Functions v2، مفاتيح signing، وسياسة خصوصية قرارات مالك المشروع. لا يمكن لهذه البيئة اتخاذها أو محاكاتها.

## ترتيب التنفيذ

1. اكتمال تدقيق البيئة والملفات، ثم كتابة `FIREBASE_SETUP_REQUIRED.md` و`PHASE_9_BLOCKERS.md`.
2. تهيئة Android CLI الضرورية فقط والتحقق من licenses.
3. إعادة تنفيذ التحليل والاختبارات وEmulator، ثم محاولة بناء APK حقيقية إذا اكتملت toolchain.
4. عدم تنفيذ نشر Firebase أو تسجيل حسابات حقيقية حتى يحدد المالك Project ID صراحة.
5. بعد توصيل جهاز حقيقي وFirebase، تنفيذ vertical slice المحدد في checklist وتسجيل دليل منفصل.

## بوابة الإغلاق

إن لم يتوفر Firebase أو Android device، تصنّف المرحلة **ENGINEERING COMPLETE / REAL ENVIRONMENT VALIDATION BLOCKED**. لا تصبح **REAL ENVIRONMENT VALIDATED** إلا بدليل Firebase Auth + Firestore + Functions + Android + FCM حقيقي، ولا تصبح production-ready بهذه المرحلة وحدها.
