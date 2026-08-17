# تدقيق الفجوات المتصالح — المرحلة 12: Emulator-first

| المجال | التصنيف | الدليل | الحد الفاصل التالي |
|---|---|---|---|
| Firebase project/app identity | VERIFIED ON REAL BACKEND | `manus-guardian` و`com.guardianeye.app` تحققا عبر CLI وFlutterFire. | iOS app config يحتاج جهاز/macOS لاحقًا. |
| Real Auth/Firestore | VERIFIED ON REAL BACKEND | HTTP 200 Auth/bootstrap/read-back وHTTP 403 لحدود التفويض. | Flutter client runtime، لا API-only proof. |
| قواعد Firestore/fهارس | VERIFIED ON REAL BACKEND | CLI rules/indexes deploy ناجح. | مراقبة أحمال production مستقبلاً. |
| Environment policy | VERIFIED LOCALLY | compile-time `GUARDIAN_ENV` مع approvals منفصلة وfail-closed. | Flutter runtime على device/AVD. |
| Emulator workflow | VERIFIED IN EMULATOR | سكربت اصطناعي يشغل Auth/Firestore/Functions بدون `manus-guardian`. | CI host لاحقًا. |
| Firestore authorization | VERIFIED IN EMULATOR | 8 اختبارات تشمل isolation/device/revocation/role UID immutability. | real Flutter UI interactions. |
| Functions workflow | VERIFIED IN EMULATOR | 2 tests لIncident/SOS events وprovisioning/replay. | Blaze لنشر Functions الحقيقية. |
| Outbox end-to-end من Flutter | IMPLEMENTED — VALIDATION BLOCKED | executor/rules/contracts موجودة؛ لا APK/AVD. | Android builder بذاكرة أكبر + device. |
| FCM device delivery | BLOCKED | Emulator يسجل contract فقط ويمنع FCM الفعلي. | Blaze + deployed functions + device token + physical device. |
| APK release | BLOCKED BY ENVIRONMENT | Gradle daemon exits داخل sandbox؛ لا artifact. | عامل Android بذاكرة كافية. |

> **قاعدة مستمرة:** لا يكتب DEVELOPMENT أو TEST إلى `manus-guardian`. ولا يسمح REAL_BACKEND_VALIDATION أو PRODUCTION إلا بـdefines مستقلة وصريحة.
