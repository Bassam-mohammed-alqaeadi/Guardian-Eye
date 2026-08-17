# تقرير إكمال المرحلة الثامنة — Firebase الحقيقي وأدلة التشغيل الشامل

**المشروع:** Guardian Eye Pro. **التاريخ:** 12 أغسطس 2026. **حالة المرحلة:** **ENGINEERING AND EMULATOR VALIDATION COMPLETE / REAL ENVIRONMENT VALIDATION BLOCKED**. أُنجز كل ما لا يحتاج مشروع Firebase أو جهازًا، وارتفعت الأدلة من قواعد Firestore وحدها إلى Auth وFirestore وCloud Functions Emulator. لا يوجد مشروع Firebase مُعرّف أو Android/iOS device أو دليل FCM فعلي؛ لذلك لا يوجد ادعاء «جاهز للإنتاج».

## 1. الملخص التنفيذي

أغلقت المرحلة فجوتين معماريتين حقيقيتين: لم يعد زر المزامنة في الواجهة يستخدم writer القديم الذي يضع أحداثًا خامًا في `sync_events`، بل أصبح يستدعي `OutboxSyncExecutor` المحروس بالهوية وعقد أعمال Firestore. كما أصبح ربط طفل بجهازه يتم عبر Cloud Functions provisioning مميزة تستخدم UID طفل مختلفًا، session محدودة لعشر دقائق، hash SHA-256، قفلًا بعد خمس محاولات، redemption ذريًا، ورفض replay. بقيت قاعدة البيانات المحلية وOutbox مصدر الحقيقة حتى يتوفر إعداد Firebase صالح.

| مستوى الدليل | النتيجة | ما لا تثبته |
|---|---|---|
| VERIFIED LOCALLY | `flutter analyze` بلا مشاكل و**27/27** اختبار Flutter ناجح | مشروع Firebase أو جهاز Android/iOS. |
| VERIFIED IN EMULATOR | **7/7** اختبارات Firestore Rules و**2/2** اختبارات Auth/Firestore/Functions Emulator ناجحة | نشر القواعد أو الدوال على مشروع حقيقي. |
| VERIFIED ON REAL BACKEND | لا دليل | Auth أو Firestore أو Callable من مشروع Firebase حقيقي. |
| VERIFIED ON PHYSICAL DEVICE | لا دليل | APK/IPA أو FCM received/displayed/acknowledged. |

## 2. البيئة المستخدمة

| العنصر | الحالة المسجلة | الأثر على الدليل |
|---|---|---|
| نظام التشغيل | Ubuntu 24.04.4 LTS (Linux) | مناسب لاختبارات Flutter/Linux وEmulator، وليس iOS. |
| Flutter | 3.44.9 stable | التحليل والاختبارات المحلية نُفذت بهذا الإصدار. |
| Dart | 3.12.2 stable | نفس نطاق اختبارات Flutter. |
| Android SDK/ADB | غير موجودين على PATH ولا AVD/جهاز متصل | لا APK أو Android runtime evidence. |
| Xcode/macOS | غير متاحان على Linux | لا iOS build أو APNs/iPhone evidence. |
| Project ID/FlutterFire | لا `.firebaserc`، ولا `firebase_options.dart`، ولا ملفات Android/iOS Firebase | لا يمكن تشغيل Flutter ضد Firebase حقيقي أو Emulator من العميل بعد. |
| Firebase CLI العالمي | غير مثبت عالميًا؛ استُخدم CLI مؤقت داخل الجلسة | لم يمنع تشغيل Emulator المعزول، ولا يشكل إعداد إنتاج. |

## 3. أدلة الخلفية: محلي مقابل Emulator مقابل حقيقي

تعمل البنية المحلية مع SQLite v6 وOutbox باستقلال كامل. أضيف `GuardianFirebaseBootstrap` لا يلمس Firebase إطلاقًا ما لم يكن `GUARDIAN_FIREBASE_CONFIGURED=true`، ويحافظ على وضع fail-closed. يتهيأ Emulator فقط مع defines واضحة، ولا توجد إعدادات مضمّنة أو معرفات Firebase مختلقة.

| المكوّن | محلي | Emulator | خلفية حقيقية |
|---|---|---|---|
| Bootstrap/حارس Firebase | متحقق: disabled state | قابل للتشغيل بعد ملفات FlutterFire | محجوب: لا مشروع/ملفات config. |
| Auth context | متحقق: رفض unconfigured/unauthenticated | UID صالح في callable tests | محجوب: لا Auth provider/حساب حقيقي. |
| Firestore Rules | عقد موجود | 7 حالات allow/deny ناجحة | محجوب: لم تُنشر. |
| Cloud Functions | TypeScript lint/build ناجح | callable + triggers ناجحة | محجوب: لم تُنشر. |
| Flutter → Firestore | contracts وOutbox فقط | لا Flutter client config بعد | محجوب. |

## 4. أدلة المصادقة

خدمة `FirebaseAuthService` تقدم إنشاء حساب ودخولًا وخروجًا على Firebase Auth الفعلي عند تهيئته، وتتعامل `FirebaseAuthContext` مع unconfigured وunauthenticated وauthenticated وfailure. أضيفت شاشة حساب صغيرة متصلة بالخدمة وتعرض بوضوح أن التطبيق محلي إذا غاب الإعداد؛ اختبار واجهة يثبت هذه الرسالة ولا يسمح بإيهام المستخدم بالمزامنة.

في Emulator أنشأ اختبار Functions والدًا وطفلًا من Auth Emulator، وتحقق من أن callable provisioning لا تقبل إلا parent role وأن redemption يربط UID طفل مختلفًا. لم يُنفذ sign-in/sign-out أو invalid session من **تطبيق Flutter** ولا من مشروع Firebase الحقيقي، ولذلك الحالة الدقيقة للمصادقة الحقيقية هي **IMPLEMENTED — REAL ENVIRONMENT VALIDATION BLOCKED**.

## 5. أدلة Firestore

ينفذ `FirestoreOutboxRemoteWriter` family creation وprimary membership داخل batch واحد، ثم ينتظر `waitForPendingWrites` قبل اعتبار الكتابة متزامنة محليًا؛ timeout يصنف retryable ولا يغلق الحدث كنجاح. تحوّل عقود الأعمال أحداث الأسرة والعضو والجهاز والحادث وSOS والرمز إلى مستندات family-scoped، وتبقى مفاتيح idempotency موجودة في العقود.

دليل Emulator يثبت إنشاء أسرة وعضو الوالد الذري، عزل Parent A عن Family B، وحظر غير المصرح به. لكنه لا يثبت read-back من تطبيق Flutter أو شبكة Firebase حقيقية. يلزم تنفيذ vertical slice المحدد في `HUMAN_ACTION_REQUIRED.md` بعد FlutterFire والنشر.[1] [2]

## 6. أدلة قواعد الأمن

قواعد Firestore تمنع role escalation، وقراءة أسرة أخرى، وكتابة parent resource من طفل، وإنشاء incident/SOS من جهاز مسحوب، وكتابة `notification_events` من العميل. كما تغيرت قاعدة ملكية الجهاز: لا يستطيع الوالد وضع `memberUid` طفل من التطبيق، ولا يمكن ربط UID طفل إلا من provisioning المميزة. يُسمح لوالد بإنشاء token فقط لجهاز parent-owned role محدد، بينما يبقى child token مقيدًا بUID الطفل الموفر.

| اختبار Emulator | النتيجة | الحد |
|---|---|---|
| Parent A يقرأ Family A ويرفض Family B | PASS | قواعد Emulator، لا قواعد منشورة. |
| family + primary member في batch | PASS | لا Flutter runtime. |
| منع child role escalation/policy write | PASS | لا حساب حقيقي. |
| منع parent direct child UID binding | PASS | لا deployment. |
| token parent device مسموح وforged child token مرفوض | PASS | لا FCM token حقيقي. |
| device active incident مسموح وrevoked مرفوض | PASS | لا جهاز فعلي. |
| mobile notification event write مرفوض | PASS | لا Cloud Function منشورة. |

## 7. أدلة المزامنة

المسار النشط أصبح: `UI → Riverpod → OutboxSyncExecutor → AuthContext → FirestoreOutboxRemoteWriter`. `UnconfiguredOutboxRemoteWriter` يفشل مغلقًا ويحوّل الحدث إلى blocked بدلاً من إرساله إلى مسار قديم أو تسميته متزامنًا. تتحقق اختبارات Flutter من unauthenticated rejection بلا تعديل Outbox، النجاح مع idempotency key، retry transient، permanent block، ومنع إرسال عند غياب Firebase.

لا يوجد حتى الآن اختبار Flutter app إلى Emulator أو اختبار شبكة حقيقية أو process death على Android. الاتصال وoffline/recovery من الطبقة المحلية متحققان، لكن recovery أمام شبكة فعلية/عملية نظام يبقى **BLOCKED BY ENVIRONMENT**.

## 8. أدلة Outbox والاسترداد

تبقى الكتابة المحلية ذرية مع الأسرة/الطفل والحادث/SOS قبل الشبكة. تستخدم إعادة المحاولة وقت UTC وbackoff وتفصل `failed` عن `blocked`. يعالج المنفذ حداً افتراضياً 25 حدثًا في التنفيذ الواحد. لم ينفذ بعد policy تنظيف للأحداث المتزامنة أو قياس queue age؛ وثقت هذه متطلبات توسع قبل الإنتاج في `docs/backend/PHASE_8_OBSERVABILITY_AND_SCALE.md`.

## 9. أدلة Cloud Functions

| الدالة | دليل Emulator | الحالة |
|---|---|---|
| `createChildDeviceProvisioning` | parent Auth UID، child member، pairing response six-digit | VERIFIED IN EMULATOR |
| `redeemChildDeviceProvisioning` | child UID منفصل، binding ذري للعضو والجهاز، replay مرفوض | VERIFIED IN EMULATOR |
| `requestIncidentNotification` | ينشئ notification event deterministic | VERIFIED IN EMULATOR |
| `requestSosNotification` | ينشئ notification event deterministic | VERIFIED IN EMULATOR |
| `fanoutNotification` | `noActiveToken` متحقق؛ FCM متعمد أن يكون skipped في Emulator | PARTIALLY VERIFIED IN EMULATOR |

مصدر TypeScript يمر `tsc --noEmit` و`tsc`. لم تُنشر الدوال ولم يختبر retry من منصة Eventarc بعد crash أو App Check مفروضًا في بيئة إنتاج. يجب تفعيل ومراجعة App Check قبل الإنتاج، لأن سجل Emulator يؤكد أن auth موجود لكن app attestation غائب في الاختبار.[3]

## 10. أدلة FCM: نموذج الحالة الصارم

| الحالة | الحالة الحالية | الدليل |
|---|---|---|
| Notification Requested | VERIFIED LOCALLY | incident/SOS يسجلان Outbox محليًا. |
| Notification Event Created | VERIFIED IN EMULATOR | triggers تنشئ event deterministic. |
| FCM Processing | IMPLEMENTED | fanout server-side فقط مع claim ذري. |
| FCM Accepted | غير متحقق | لا Firebase Messaging project أو token حقيقي. |
| Device Received | محجوب | لا جهاز فعلي. |
| User Saw Notification | محجوب | لا جهاز فعلي/OS evidence. |
| Acknowledged | غير متحقق | لا client handler/device flow. |

لا تستخدم Functions Emulator FCM: عند وجود token اختباري تحفظ `fcmNotExercisedInEmulator` ولا تطلب اعتماديات خارجية. في الإنتاج فقط، حالة `backendAccepted` تتطلب `acceptedCount > 0`؛ إذا رفضت جميع الرموز تصبح `backendFailed`. حتى `backendAccepted` لا يعني استلام أو عرض المستخدم.[4]

## 11. أدلة الأجهزة الفعلية

لا يوجد Android SDK أو ADB أو AVD أو هاتف متصل في البيئة، ولا macOS/Xcode/iPhone. لم يُبن APK ولم يثبت تطبيق ولم تُفحص الأذونات أو Doze أو process death أو location أو token notification. لا يوجد iOS/APNs evidence. هذه ليست عناصر مؤجلة ضمنية؛ هي **PHYSICAL DEVICE VALIDATION REQUIRED** بخطوات مفصلة في `HUMAN_ACTION_REQUIRED.md`.

## 12. الاختبارات المنفذة

| الأمر | النتيجة الدقيقة |
|---|---|
| `flutter analyze` | PASS — `No issues found`. |
| `flutter test --reporter expanded` | PASS — **27 tests passed**. |
| `cd firebase/functions && npm run lint` | PASS — `tsc --noEmit`. |
| `cd firebase/functions && npm run build` | PASS — TypeScript build. |
| `emulators:exec --only auth,firestore,functions … npm run test:emulator` | PASS — **2 tests**: incident/SOS events وchild provisioning/replay. |
| `… && cd firebase/tests && npm test` | PASS — **7 tests**: isolation، atomic create، escalation، UID binding، token boundary، active/revoked device، notification write. |

رسائل `PERMISSION_DENIED` المعروضة في اختبارات القواعد كانت نتائج متوقعة لـ`assertFails`. لم تسجل الجلسة محاولة FCM خارجية بعد إضافة حارس Emulator.

## 13. الفجوات المتبقية

تسجل `docs/GAP_AUDIT_RECONCILED_PHASE8.md` الفجوات الحالية من المصدر. الأولوية: 1) FlutterFire وFlutter-to-Emulator vertical slice، 2) مشروع Firebase اختبار حقيقي ونشر القواعد/الدوال بعد مراجعة، 3) callable pairing UI/device flow، 4) Android ثم iOS وFCM/APNs physical evidence، 5) App Check وCrashlytics/Analytics الخصوصية وretention قبل الإنتاج.

## 14. الإجراءات البشرية

يوفر `docs/HUMAN_ACTION_REQUIRED.md` جدولًا من 15 خطوة يشمل اختيار المشروع وIAM وFirestore وAuth وAndroid/iOS وFlutterFire وCLI وEmulator والقواعد والفهارس والدوال وFlutter الحقيقي وFCM والجهاز. يحتوي كل صف على أمر/إجراء Console ونتيجة متوقعة وتحقيق وتراجع. لا يحتاج مالك المشروع لتخمين hostname Emulator أو codebase أو معنى حالات FCM.

## 15. مصفوفة جاهزية الإنتاج

| المجال | Local | Emulator | Real Backend | Physical Device | Production |
|---|---|---|---|---|---|
| Firebase bootstrap | GREEN | قابل للتشغيل بعد config | RED | RED | RED |
| Auth contracts/UI | GREEN | GREEN في callable UID | RED | RED | RED |
| Family/Firestore rules | GREEN للعقود | GREEN | RED | RED | RED |
| Outbox/retry | GREEN | جزئي: لا Flutter client | RED | RED | RED |
| Child-device provisioning | TypeScript GREEN | GREEN | RED | RED | RED |
| Incident/SOS notification event | GREEN محلي | GREEN | RED | RED | RED |
| FCM/APNs | contract فقط | FCM intentionally skipped | RED | RED | RED |
| Android/iOS | RED | غير منطبق | RED | RED | RED |
| AI inference | abstraction GREEN | غير منطبق | RED | RED | RED |

## 16. التوصية

التوصية التالية ليست إضافة شاشات جديدة، بل **Phase 9: Flutter-to-Emulator ثم Firebase test-project vertical slice**. بعد تزويد المالك بـFlutterFire config وAndroid SDK/جهاز، شغل التطبيق بالdefines الموثقة، ثم نفذ sign-in → family → child → Outbox → Firestore read-back، provisioning child ثم incident/SOS. عندها فقط ينتقل العمل إلى مشروع Firebase اختبار حقيقي، وFCM/APNs والجهاز الفعلي. لا يُوصى بإطلاق متجر أو دفع إنتاجي قبل أدلة هذه المصفوفة.

## المراجع

[1]: https://firebase.google.com/docs/flutter/setup "Add Firebase to a Flutter app"
[2]: https://firebase.google.com/docs/emulator-suite "Firebase Local Emulator Suite"
[3]: https://firebase.google.com/docs/app-check "Firebase App Check"
[4]: https://firebase.google.com/docs/cloud-messaging/send-message "Firebase Cloud Messaging message sending"
