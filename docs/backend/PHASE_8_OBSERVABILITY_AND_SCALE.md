# المراقبة والتوسع — المرحلة الثامنة

## حدود الخصوصية

تُعامل بيانات الأسرة والطفل والحادث والموقع بوصفها حساسة. لا تسجل الدوال في Cloud Logging محتوى الإشعار أو token أو كود pairing أو البريد الإلكتروني الكامل أو إحداثيات الموقع. السجلات الحالية تقتصر على معرفات تشغيلية مثل `familyId` و`pairingId` و`eventId`؛ عند النشر الإنتاجي يجب استبدالها بمعرفات مشتقة/مقنّعة في أي قناة تحليل مركزية، وتقييد الوصول إلى Logging بمبدأ أقل صلاحية.[1] [2]

| الإشارة | المصدر | حقل آمن مقترح | الغرض | محظور |
|---|---|---|---|---|
| فشل bootstrap | تطبيق Flutter | رمز سبب عام مثل `firebase_not_configured` | كشف خطأ الإعداد | Project secrets، البريد، UID الخام. |
| حالة Outbox | SQLite/UI محلي | queued/synced/failed/blocked + count | إبراز مشاكل المزامنة للمستخدم | payload أو محتوى الحادث. |
| فشل provisioning | Cloud Function | سبب مثل `pairing_expired` أو `pairing_locked` | اكتشاف سوء الاستخدام ومشكلات onboarding | code الخام أو code hash. |
| FCM backend | Cloud Function | tokenCount/acceptedCount/failedCount والحالة | قياس قبول مزود الرسائل فقط | token نفسه أو نص التنبيه. |
| Crashlytics | تطبيق فعلي بعد موافقة سياسة الخصوصية | stack trace منقح وإصدار التطبيق | معالجة التعطل | لقطة شاشة أو محتوى طفل. |

## سياسة الأخطاء والتشغيل

| طبقة | خطأ متوقع | السلوك المنفذ | دليل المستخدم/المشغل |
|---|---|---|---|
| Firebase bootstrap | ملف مشروع أو build flag غائب | fail-closed؛ يبقى SQLite محليًا | شاشة حساب Firebase تعلن `Firebase غير مهيأ`. |
| Auth | غير مصادق/جلسة منتهية | `OutboxSyncExecutor` لا يغير Outbox | يظل الحدث queued حتى مصادقة صالحة. |
| Firestore | unavailable/deadline/aborted | retry متدرج بوقت UTC | حالة failed و`next_attempt_at`. |
| Firestore | permission/unauthenticated/invalid/not-found | blocked لا retry أعمى | `last_error` منقح ومراجعة القواعد/الدور. |
| Functions provisioning | انتهاء/كود خاطئ/replay | callable error وحالة session محددة | لا UID binding ولا جهاز نشط. |
| FCM | لا رمز/كل الرموز مرفوضة/طلب فاشل | `noActiveToken` أو `backendFailed` | لا ادعاء received/displayed؛ يحتاج تصحيح token أو مزود. |

## الكلفة والتوسع

تصميم Outbox يفصل الكتابة المحلية عن الشبكة، ويحد كل تشغيل إلى 25 حدثًا مستحقًا ويطبق backoff متدرج. هذه بداية مناسبة، لكنها لا تكفي وحدها لحجم تجاري: ينبغي مراقبة طول Outbox، عمر أول حدث queued، وعدد الأحداث blocked، وعدم إجراء polling من الخلفية بلا سياسة نظام منصة. يجب استخدام بيانات Firestore المجمعة والفهارس المحددة، مع تجنب قراءة كل incidents أو كل tokens في واجهة واحدة.[3] [4]

| خطر التوسع | الوقاية المنفذة | العمل المطلوب قبل الإنتاج |
|---|---|---|
| تضخم Outbox | limit=25، حالة/next attempt، retry policy | إضافة عملية تنظيف مدققة للأحداث synced بعد مدة احتفاظ معتمدة، وقياس queue age. |
| تكرار حدث خلفي | idempotency key ومستند notification deterministic من kind/source ID | قياس duplicate rate واختبار crash بين قبول FCM وتثبيت الحالة. |
| fanout كبير | collection group للرموز وحالات invalid token | تقسيم batches وفق حد FCM، rate limit لكل عائلة، وسياسة quiet hours؛ لا تحمّل ملايين الرموز دفعة واحدة. |
| documents كبيرة | عقود عمل صغيرة ومؤشرات منفصلة | وضع حدود حجم/احتفاظ للحوادث ورفض screenshot/media في Firestore document. |
| حوادث تاريخية غير محدودة | حالة incident منفصلة | retention policy قانونية قابلة للتهيئة وarchival/deletion موثقين. |
| مراقبة حساسة مفرطة | لا محتوى طفل في telemetry design | Privacy review قبل Crashlytics/Analytics، مع عدم تفعيل screen/content collection افتراضيًا. |

## بوابة الإنتاج

لا تُفعّل Crashlytics أو Analytics أو Remote Config أو وظائف التنظيف قبل مراجعة قانونية وخصوصية تحدد الغرض، الاحتفاظ، صلاحيات الوصول، ومسار حذف البيانات. تحدد Cloud Functions وFCM حدودًا وفوترة وتتطلب تنبيهات تشغيلية، لكن لا يثبت Emulator أي كلفة إنتاجية أو latency أو quota.

## المراجع

[1]: https://firebase.google.com/docs/projects/iam/overview "Firebase and Google Cloud IAM"
[2]: https://firebase.google.com/docs/crashlytics/customize-crash-reports "Customize Crashlytics reports"
[3]: https://firebase.google.com/docs/firestore/manage-data/transactions "Cloud Firestore transactions and batched writes"
[4]: https://firebase.google.com/docs/cloud-messaging/send-message "Firebase Cloud Messaging message sending"
