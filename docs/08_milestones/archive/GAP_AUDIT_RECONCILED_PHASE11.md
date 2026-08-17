# تدقيق الفجوات المتصالح — المرحلة 11: Firebase الحقيقي

| المجال | الحالة | دليل التنفيذ أو التحقق | القيد التالي |
|---|---|---|---|
| هوية مشروع Firebase وAndroid app | VERIFIED ON REAL BACKEND | Firebase CLI يطابق `manus-guardian` وFlutterFire يولد Android options للتطبيق `com.guardianeye.app`. | iOS configuration منفصلة ومطلوبة لاحقًا. |
| Android Firebase bootstrap | IMPLEMENTED + VERIFIED LOCALLY | `GuardianFirebaseBootstrap` يستعمل `DefaultFirebaseOptions.currentPlatform` المولد رسميًا مع fail-closed flag. | يحتاج APK/جهاز لإثبات runtime فعلي. |
| Email/Auth anonymous الحقيقي | VERIFIED ON REAL BACKEND | registration/login/token refresh/anonymous HTTP 200 بحسابات اختبار عابرة. | Flutter signOut/session restoration UI يحتاج جهازًا أو APK. |
| Firestore rules/fهارس | VERIFIED ON REAL BACKEND | rules + indexes deployed successfully بعد compile، ثم REST tests على backend الحقيقي. | مراقبة index build وأحمال فعلية لاحقًا. |
| إنشاء أسرة وقراءة للخلفية | VERIFIED ON REAL BACKEND | atomic family+primary-parent REST commit/read-back HTTP 200 وفق contract. | تنفيذ السلسلة الكاملة من SQLite→OutboxSyncExecutor يحتاج Flutter runtime. |
| عزل الأسرة والتفويض | VERIFIED ON REAL BACKEND | HTTP 403 لاختبار cross-family، unauthenticated، role escalation، revoked-device، unauthorized device. | اختبار زوج Parent A/Family B في تطبيق مثبت لاحقًا. |
| منع role escalation | VERIFIED IN EMULATOR + VERIFIED ON REAL BACKEND | members rule يجمد `role` و`memberUid` بعد الإنشاء؛ 8 Emulator tests و403 حقيقي. | Cloud Function provisioning remains blocked by Functions deployment. |
| Cloud Functions Guardian | IMPLEMENTED — VALIDATION BLOCKED | TypeScript builds، لكن deploy توقف لأن project غير Blaze؛ `functions:list` لا يعرض Guardian functions. | تفعيل Blaze ثم deploy codebase `guardian` فقط. |
| FCM | IMPLEMENTED — VALIDATION BLOCKED | token/event/function contracts موجودة؛ لا functions ولا device token أو delivery proof. | Blaze + APK/device/notification permission. |
| APK release | BLOCKED BY ENVIRONMENT | Crashlytics plugin fixed; daemon still exits in sandbox without artifact. | Android builder ذاكرة أعلى. |

> لا يعني إثبات REST/Firestore أن تطبيق Flutter تلقى إشعارًا أو نفذ OutboxSyncExecutor على جهاز. لا يعني قبول FCM backend تسليمًا أو عرضًا أو acknowledgement.
