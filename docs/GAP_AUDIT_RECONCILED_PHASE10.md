# تدقيق الفجوات المتصالح — المرحلة العاشرة

| المجال | حالة المرحلة التاسعة | دليل المرحلة العاشرة | التصنيف الحالي | البوابة التالية |
|---|---|---|---|---|
| Android Firebase client identity | لا config حقيقي | `google-services.json` supplied يطابق package/applicationId؛ لا fields إدارية؛ file mode 0600 | IMPLEMENTED + VERIFIED LOCALLY | APK/device initialization. |
| Google Services Gradle | غير مطبق | root/app plugin added، config-only exit 0 | IMPLEMENTED + VERIFIED LOCALLY | build على عامل ذاكرة كافية. |
| Firebase Core bootstrap | fail-closed contract | Android default config موجود عند compile؛ no runtime enabled flag/device | IMPLEMENTED — VALIDATION BLOCKED | FlutterFire/device startup. |
| Firebase Auth anonymous | لا service method/UI | wrapper method + honest temporary-session UI؛ analyze/tests pass | IMPLEMENTED — VALIDATION BLOCKED | real Auth call with test account/device. |
| Email auth/logout/restoration | contracts فقط | لا real session/credential | HUMAN ACTION REQUIRED | Firebase CLI auth ثم testing. |
| FlutterFire options | غير موجود | CLI 1.4.1 installed; official configure refused due no authorized account; no manual output | BLOCKED BY ENVIRONMENT | `firebase login` by project member. |
| Real Firestore vertical slice | Emulator only | no real project access/deploy/write | BLOCKED BY ENVIRONMENT | CLI access → reviewed deploy → test identities. |
| Real functions | Emulator only | no list/deploy/log evidence | HUMAN ACTION REQUIRED | CLI access and confirm deploy scope. |
| FCM delivery | contract/emulator only | no device token or backend access | BLOCKED BY ENVIRONMENT | APK/device/real backend. |
| Android release APK | Gradle sandbox daemon exit | retried after Google Services; still daemon exits; no artifact | BLOCKED BY ENVIRONMENT | larger-memory Android builder. |
| Flutter local quality | 27 pass/no issues | revalidated after Auth/UI change | IMPLEMENTED + VERIFIED LOCALLY | device integration. |

## نتيجة القرار

لم تتغير معمارية Flutter/Riverpod/SQLite/Outbox. لا يصح اختراع `firebase_options.dart` من Android config حتى لو ظهرت بيانات client به؛ FlutterFire CLI هي جهة التوليد الرسمية المطلوبة. لا يصح نشر rules/functions أو إنشاء مشروع بديل قبل توافر هوية CLI لمشروع `manus-guardian`.
