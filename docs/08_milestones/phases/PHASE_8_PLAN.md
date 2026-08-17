# خطة المرحلة الثامنة — Firebase الحقيقي وأدلة التشغيل الشامل

**تاريخ الخطة:** 12 أغسطس 2026. **خط الأساس:** المرحلة السابعة وفّرت SQLite وOutbox وعقود Firestore وقواعد Emulator ودوال TypeScript، لكنها لم تربط تطبيق Flutter بنقطة تهيئة Firebase أو بمسار `OutboxSyncExecutor` الفعلي. لا توجد `firebase_options.dart` أو `google-services.json` أو `GoogleService-Info.plist` أو مشروع Firebase محدد في المستودع.

> قاعدة الدليل: لا يُوسَم أي بند بأنه «متحقق على خلفية حقيقية» أو «متحقق على جهاز فعلي» قبل وجود مخرجات قابلة لإعادة التشغيل من تلك البيئة. نجاح اختبار محلي أو Emulator لا ينوب عنهما.

## A. عمل يمكن إتمامه تلقائيًا في بيئة التطوير

| العمل | المخرج | معيار القبول | الحالة المبدئية |
|---|---|---|---|
| استبدال مسار الواجهة القديم `SyncEngine` بالمنفذ `OutboxSyncExecutor` | موفرو Riverpod لحالة Firebase والمزامنة ونتيجة قابلة للعرض | لا تستدعي الواجهة كتابة `sync_events` القديمة؛ يبقى التطبيق fail-closed بلا Firebase. | قيد التنفيذ |
| تهيئة Firebase مشروطة | bootstrap لا يستورد خيارات مولدة إلا عند وجودها صراحة | يبدأ التطبيق محليًا بلا خيارات، ويدعم مسارًا محددًا بعد FlutterFire. | قيد التنفيذ |
| اختبار التطبيق مقابل Auth/Firestore Emulator | إعداد منفصل غير إنتاجي واختبارات قابلة للتشغيل | أدلة online/offline/idempotency/rejection لا تلامس Firebase الحقيقي. | قيد التنفيذ |
| اختبارات Cloud Functions Emulator | اختبارات incident/SOS → notification event ومنع التكرار | نجاح trigger موثق؛ FCM نفسه يبقى خارج نطاق Emulator ما لم يقدم مزودًا مهيأ. | قيد التنفيذ |
| تقوية عقد child-device provisioning | عقد خادمي مميز ونصوص منع replay/role escalation | لا يُكتب `memberUid` للطفل من عميل الوالد ولا تقبل القواعد كتابة الإشارة قبل الربط. | قيد التنفيذ |
| المراقبة والتكلفة | وثائق error taxonomy والاحتفاظ وbackoff والحدود | لا محتوى طفل حساس في analytics/logs، ولا عمليات قراءة/كتابة غير محدودة بلا توثيق. | قيد التنفيذ |

## B. يتطلب تكوين مشروع Firebase

| المطلوب | الحد الأدنى | التحقق بعد التكوين |
|---|---|---|
| مشروع Firebase | معرف مشروع فعلي يملكه العميل وقاعدة Firestore | `flutterfire configure` يولد `firebase_options.dart` بلا تضمين أسرار إدارية. |
| Firebase Auth | مزود Email/Password مفعّل أو مزود معتمد صراحة | إنشاء حساب/دخول/خروج وانتهاء جلسة على مشروع حقيقي. |
| Firestore | قاعدة في المنطقة المختارة ومراجعة القواعد والفهارس | create family → primary member → child → outbox → write/read-back تحت UID فعلي. |
| Cloud Functions | مشروع مفعّل للفوترة أو المتطلبات التي تفرضها Cloud Functions v2 | نشر `functions:guardian` وتشغيل trigger بسجل server-side. |

## C. يتطلب حسابات أو اعتماديات بشرية

| الاعتماد | سبب عدم إمكان أتمتته | الإجراء البشري المطلوب |
|---|---|---|
| حساب مالك Firebase | تحديد المشروع والصلاحيات وسياسات الفوترة ملك قرار تشغيلي | تسجيل الدخول وربط المشروع ومراجعة قائمة الخدمات. |
| Apple Developer/APNs | مفاتيح APNs والتوقيع تعود لمالك المؤسسة | إنشاء/رفع APNs key وربط bundle identifier النهائي. |
| مفاتيح توقيع المتجر | لا يجوز إنشاؤها أو تخزينها داخل المستودع | توليدها وحفظها في مخزن أسرار المؤسسة. |

## D. يتطلب جهاز Android أو iOS فعليًا

| التحقق | سبب الجهاز الفعلي | دليل القبول |
|---|---|---|
| Android APK والتثبيت | أذونات النظام، background/Doze، Play services لا تحاكيها اختبارات SQLite | طراز الجهاز، الإصدار، build hash، ولقطات/سجل تدفق محدد. |
| FCM received/displayed/acknowledged | قبول FCM ليس عرض إشعار نظام التشغيل | فصل تسجيل token وbackend accepted وreceived وdisplayed وacknowledged. |
| iOS/APNs | macOS/Xcode/توقيع/iPhone مطلوبة | جهاز iPhone مسجل، إعداد APNs، ودليل foreground/background. |

## E. يتطلب تكوين Console للإنتاج

| العنصر | ما لا يُنفذ قبل المراجعة | شرط الإكمال |
|---|---|---|
| نشر القواعد والفهارس | لا نشر على مشروع مجهول | مراجعة rule diff ونسخة احتياطية/خطة rollback ثم `firebase deploy`. |
| نشر الدوال | لا تفعيل fanout إلى رموز حقيقية قبل سياسة الإشعار | مراجعة logs وquotas وFCM، ثم نشر codebase `guardian`. |
| Crashlytics/Analytics | لا جمع افتراضي لمحتوى طفل أو هوية حساسة | مخطط أحداث أدنى، سياسة احتفاظ، ومراجعة خصوصية. |

## مسار التنفيذ وترتيب الأدلة

أولًا تُثبت طبقة التطبيق المحلية وEmulator: bootstrapping محروس، مسار Outbox الموحد، اختبارات Auth/Firestore/Functions Emulator، ومنع child-device impersonation. ثانيًا ينفذ المالك تكوين Firebase وإعداد FlutterFire. ثالثًا يُشغّل vertical slice حقيقي منفصلًا عن أدلة Emulator. أخيرًا تُجرى دورة Android ثم iOS وFCM/APNs على أجهزة فعلية.

| تصنيف الدليل | أمثلة صالحة | لا يكفي لإثبات |
|---|---|---|
| **VERIFIED LOCALLY** | `flutter test`، SQLite FFI، TypeScript typecheck | Firestore حقيقي، FCM، جهاز فعلي. |
| **VERIFIED IN EMULATOR** | Firestore rules، Auth/Functions Emulator | قواعد منشورة أو push فعلي. |
| **VERIFIED ON REAL BACKEND** | Auth وFirestore من مشروع محدد وread-back | ظهور الإشعار على هاتف. |
| **VERIFIED ON PHYSICAL DEVICE** | APK/IPA مسجل وجهاز/OS محدد | صلاحية النشر التجاري الشامل. |

## مخاطر يجب التحكم بها

يبقى pairing المحلي غير كافٍ لإسناد Firebase UID إلى طفل. سيُنفذ أي provisioning فقط من Cloud Functions أو خادم مميز، مع جلسة أحادية الاستخدام، انتهاء صلاحية، منع replay، ومعاملة تربط المستخدم والعضو والجهاز. كما يجب إبقاء JSON الخاص بـOutbox صغيرًا ومحددًا، وحد backoff، وسقف لسجل الحوادث لتجنب تضخم عمليات Firestore أو retries.

## معايير الإغلاق

تغلق المرحلة بتقرير `PHASE_8_COMPLETION_REPORT.md` يفرق صراحة بين المحلي وEmulator والخلفية الحقيقية والجهاز الفعلي، ويذكر كل اختبار بأمره ونتيجته. إن غاب مشروع Firebase أو جهاز، يكون التصنيف الدقيق هو **IMPLEMENTED — REAL ENVIRONMENT VALIDATION BLOCKED** أو **HUMAN ACTION REQUIRED**، لا «جاهز للإنتاج».
