# تقرير إكمال المرحلة السابعة — Firebase والمزامنة والإشعارات

**المشروع:** Guardian Eye Pro. **التاريخ:** 12 أغسطس 2026. **حالة المرحلة:** **مكتملة كمرحلة هندسية محلية، وليست اعتمادًا إنتاجيًا**. حققت المرحلة عقودًا قابلة للبناء، قواعد Firestore قابلة للتنفيذ في Emulator، واختبارات محلية صريحة؛ أما مشروع Firebase الحقيقي، هوية طفل فعلية، نشر القواعد، ودفع FCM/APNs فما زالت **محجوبة أو تتطلب إجراءً بشريًا**.

## A. الملخص التنفيذي

عُزز المسار المحدد للمشروع، وهو `Flutter → Riverpod → SQLite → Outbox → Sync → Firebase`، من دون قلب المصدر المحلي للحقيقة أو إدخال مفاتيح إدارية في العميل. ينفذ `OutboxSyncExecutor` بوابة هوية متشددة، وتحويلات Firestore محددة لأحداث الأسرة والعضو والجهاز والحادث وSOS ورمز الإشعار. أضيف مصدر Cloud Functions يستجيب لوثائق الحوادث وSOS لإنشاء طلب إشعار من جانب الخادم، ثم يعالج token fanout عبر Admin SDK في بيئة الدوال فقط.[1] [2]

| بند التحقق | النتيجة | الحد الدقيق للنتيجة |
|---|---|---|
| `flutter analyze` | **نجح: لا ملاحظات** | فحص ساكن فقط، وليس بناء جهاز. |
| `flutter test --reporter expanded` | **نجح: 24 اختبارًا** | SQLite FFI/وحدات/عقود/واجهة محلية؛ لا Firebase مشروع فعلي. |
| `npm run lint` ضمن `firebase/functions` | **نجح** | بناء TypeScript بلا تشغيل دالة. |
| Firestore Emulator | **نجح: 5 اختبارات قواعد** | قواعد وعزل فقط، لا FlutterFire ولا Functions Emulator. |

## B. بنية الخلفية: المنفذ مقابل التعاقدي

المنفذ محليًا هو SQLite v6 وOutbox ومعاملات المستودعات، مع عقد مصادقة ومحرّك مزامنة ومصدر Firestore وعقود `firebase.json` وCloud Functions. يظل SDK غير مفعل فعليًا ما لم يُمرر إعداد Firebase صريح وتُولد `firebase_options.dart`؛ وهذا تصميم fail-closed مقصود. لا توجد قاعدة بيانات خلفية مصطنعة ولا مسار UI يدعي مزامنة بلا هوية.

| الطبقة | ما نُفذ | ما لم يُثبت |
|---|---|---|
| مصدر الحقيقة | SQLite محلي + Outbox دائم | استعادة عملية Android حقيقية أو هجرة تطبيق مثبت. |
| Firestore | paths وعقود تحويل وقواعد وفهارس | اتصال Flutter بمشروع/Emulator مهيأ. |
| الدوال | `requestIncidentNotification` و`requestSosNotification` و`fanoutNotification` | استدعاء trigger وFCM fanout داخل Emulator. |
| الإنتاج | لم يُنشر شيء | مشروع Firebase وفحوص النشر والمراقبة. |

## C. المصادقة

يعرّف `FirebaseAuthContext` حالة غير مهيأة وغير مصادق عليها ومصادق عليها، ويتطلب `FirestoreAuthorizationGate` هوية قبل أي تنفيذ remote. تحقق اختباران أصليان من رفض السياق غير المهيأ وغير المصادق عليهما. لم يُسجل مستخدم حقيقي ولم يُشغل Firebase Auth Emulator من Flutter؛ لذلك تصنيف تسجيل الدخول هو **منفذ لكنه غير متحقق وقت التشغيل**.

## D. Firestore: المجموعات والمستودعات والفهارس والقواعد

توجد مسارات عائلية محددة للأعضاء والأجهزة والسياسات والحوادث وSOS والمواقع والإشعارات وبيانات المزامنة. تحوّل عقود الأعمال أحداث Outbox إلى مستندات عائلية محددة بدلاً من وضع كل شيء في metadata. ينفذ إنشاء الأسرة الأولي دفعة تحتوي وثيقة الأسرة وعضو الوالد الأساسي، وتسمح القواعد بذلك من خلال `existsAfter` فقط عندما يطابق `ownerUid` و`memberUid` هوية الطالب.[3]

قواعد `firebase/firestore.rules` تعزل الأسر، تمنع تصعيد الطفل لدوره، تشترط أن يكون جهاز إنشاء الحوادث/SOS نشطًا ومملوكًا للهوية، وتمنع عميل الهاتف من إنشاء `notification_events`. يوجد `firebase/firestore.indexes.json` و`firebase.json` لتحديد القواعد والفهارس والدوال وEmulator. لم تُنشر هذه المواد على مشروع Firebase.

## E. الأمن والتفويض

تم اختبار خمس خصائص في Firestore Emulator: قراءة الأسرة الذاتية ورفض الأسرة الأخرى، إنشاء الأسرة/الوالد الذري، رفض تصعيد الطفل وكتابة السياسة، السماح لجهاز طفل نشط بإنشاء حادث ورفض جهاز مسحوب، ومنع كتابة notification event مباشرة. رسائل `PERMISSION_DENIED` في سجل Emulator هي النتائج المتوقعة لاختبارات `assertFails` وليست أعطالًا.

الحد الأمني المتبقي حاسم: المزاوجة المحلية لا تُنشئ Firebase UID لطفل. أزيل أي افتراض يوحي بأن UID الوالد هو `memberUid` لجهاز الطفل، لذا تتوقف كتابة إشارات الطفل البعيدة بأمان إلى أن ينفذ pairing-broker خلفي مميز. هذا **حاجز تصميمي مقصود** وليس دليلاً على اكتمال المزاوجة البعيدة.

## F. المزامنة

يظل Outbox المحلي المصدر الأول، ويختار المنفذ أحداثًا مستحقة فقط، ويتطلب هوية، ويحافظ على idempotency key، ويصنف الفشل إلى قابل لإعادة المحاولة أو دائم أو محجوب. تتحقق اختبارات Flutter من رفض تنفيذ بلا هوية، ومن تعليم الحدث المتزامن مع حفظ مفتاح idempotency، ومن retry/failure classification. تحكم سياسة backoff زمن UTC للاسترداد بعد موت العملية.

لم يُثبت idempotency مع Firestore حقيقي أو مع Flutter client على Emulator. كما أن سياسة التعارض موثقة في `docs/backend/SYNC_CONFLICT_POLICY.md`، لكنها ليست بعد دليل سباق متعدد أجهزة. تصنيف هذا الجزء هو **منفذ ومتحقق محليًا، غير متحقق شبكيًا**.

## G. الإشعارات

يتعامل العميل مع token كبيان حساس مسجل محليًا وحدث Outbox، ولا يعلن تسليمًا. تمت إضافة دوال خلفية تنشئ طلب إشعار من وثيقة incident أو SOS بعد قبول Firestore، ثم تستدعي FCM من Admin SDK على الخادم. تسجل حالة `backendAccepted` عدد القبول والفشل، وهي لا تعني أن نظام التشغيل عرض إشعارًا؛ يظل التسليم والتأكيد منفصلين.[1] [2]

لا توجد بيانات اعتماد FCM أو APNs، ولا رمز جهاز حقيقي، ولا اختبار مقدمة/خلفية/إنهاء التطبيق. لذلك فالإشعارات **بنية منفذة فقط**، وليست تسليمًا مثبتًا.

## H. تدفق شامل: ما اكتمل فعلاً

أُكمل محليًا: شاشة/مستودع إنشاء الأسرة والطفل → معاملة SQLite → Event Outbox → اختبار يثبت الذرية والاسترداد. كما أُكمل في Firestore Emulator من عميل اختبار معزول: والد جديد يكتب الأسرة وعضوه الأساسي في دفعة واحدة، وتطبّق القواعد العزل والتفويض. ولم يكتمل تدفق Flutter الفعلي إلى Emulator أو الإنتاج، لأن FlutterFire options وAuth project وهوية الطفل غير موجودة.

> لا يصح وصف «إشعار حادث من جهاز طفل وصل إلى والد» بأنه مكتمل. المسار يتطلب بعد: هوية طفل مربوطة، Flutter Emulator، Functions Emulator، FCM، وجهاز فعلي.

## I. الاختبارات والأدلة

| مجموعة الأدلة | النتيجة | ما تثبته |
|---|---|---|
| Flutter widget/domain/repository/sync/FCM contracts | 24/24 ناجح | لا عينات UI، حدود الدور، SQLite، pairing المحلي، السياسة، الحادث/SOS، retry، Auth contracts، executor، token contract. |
| Firestore Emulator rules | 5/5 ناجح | عزل الأسرة، إنشاء ذري، منع التصعيد، جهاز نشط/مسحوب، منع event الإشعار العميل. |
| TypeScript Cloud Functions | `tsc --noEmit` ناجح | نوعية وبناء مصدر الدوال فقط. |

تمت الأوامر في بيئة العمل في 12 أغسطس 2026. لا توجد نتيجة APK أو iOS أو FCM أو Functions trigger ضمن هذا الدليل.

## J. الحواجز

الحواجز الحية موثقة في `docs/IMPLEMENTATION_BLOCKERS.md`: لا مشروع Firebase أو ملفات FlutterFire، لا pairing-broker لهوية الطفل، لا اختبار Flutter مقابل Emulator، لا اختبارات Functions/FCM، ولا جهاز Android/iPhone فعلي. تتضمن الوثيقة أوامر التحقق والإجراء المطلوب بدل تعويض الحاجز بنموذج وهمي.

## K. الإجراءات البشرية المطلوبة

يلزم مالك المشروع اختيار Firebase project، تسجيل Android/iOS، تشغيل FlutterFire، مراجعة ثم نشر القواعد والفهارس والدوال، تهيئة Auth وFCM/APNs، وتوفير أجهزة فعلية. يلزم كذلك اعتماد تصميم pairing-broker وعقده قبل تمكين كتابة إشارات الطفل. تسجل الخطوات والأوامر الدقيقة في `docs/HUMAN_ACTION_REQUIRED.md`، ولا ينبغي تشغيلها على مشروع إنتاج قبل اكتمال Emulator ودورة مراجعة الخصوصية.

## L. تدقيق الفجوات المحدث

وثيقة `docs/GAP_AUDIT_RECONCILED_PHASE7.md` هي مصدر حالة المرحلة. الخلاصة هي أن **العزل والقواعد أصبحا متحققين في Emulator**، وأن **دورة مزامنة Flutter إلى Firebase والإشعار الفعلي ما زالت غير متحققة**. لا تُرفع هذه البنود إلى أخضر إنتاجي بفضل وجود الشيفرة أو اجتياز TypeScript فقط.

## M. توصية المرحلة التالية

المرحلة الثامنة الموصى بها هي «**Flutter↔Firebase Emulator وهوية جهاز الطفل**»: إنشاء pairing-broker مميز، اختبار one-time pairing/replay، تشغيل FlutterFire ضد Auth وFirestore Emulator، ثم اختبار incident/SOS إلى Functions Emulator والتحقق من حالة `backendAccepted` بلا ادعاء تسليم FCM. بعد اكتمالها تأتي مرحلة Android device وFCM/APNs الفعلية.

## المراجع

[1]: https://firebase.google.com/docs/cloud-messaging "Firebase Cloud Messaging documentation"
[2]: https://firebase.google.com/docs/functions "Cloud Functions for Firebase documentation"
[3]: https://firebase.google.com/docs/firestore/manage-data/transactions "Cloud Firestore transactions and batched writes"
