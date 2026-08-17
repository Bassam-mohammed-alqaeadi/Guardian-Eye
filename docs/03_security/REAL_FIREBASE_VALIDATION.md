# سجل تحقق Firebase الحقيقي

**قاعدة السجل:** كل صف يذكر مستوى الدليل، ولا يعاد تسمية Emulator أو Gradle configuration إلى Real Backend أو Physical Device.

| المستوى | الاختبار | المتوقع | الفعلي | الدليل | الحالة |
|---|---|---|---|---|---|
| LOCAL | package/config match | `manus-guardian` Android client يطابق `com.guardianeye.app` | متطابق | فحص local config وGradle | VERIFIED LOCALLY |
| LOCAL | no admin secret | لا private key/service account/client secret | لم تُكتشف الحقول المحظورة | static field check | VERIFIED LOCALLY |
| LOCAL | Google Services plugin config | Gradle يقبل config | `--config-only` exit 0 | `/tmp/guardian_phase10_google_services_config.log` | VERIFIED LOCALLY |
| LOCAL | Flutter analyze | no issues | PASS | `flutter analyze` | VERIFIED LOCALLY |
| LOCAL | Flutter test | all unit/widget tests pass | 27 tests passed | `flutter test --reporter expanded` | VERIFIED LOCALLY |
| LOCAL | anonymous auth contract | method/UI يوضحان session temporary | implemented; no network call in Flutter unit test | source + local analysis | IMPLEMENTED — VALIDATION BLOCKED |
| EMULATOR | Auth/Functions provisioning | one-time child UID binding/replay denied | 2 tests pass | Phase 9 emulator run | VERIFIED IN EMULATOR |
| EMULATOR | Firestore authorization | allow/deny rules pass | 8 tests pass, including role/UID immutability | `firebase emulators:exec --only firestore` | VERIFIED IN EMULATOR |
| REAL FIREBASE | CLI project access | authorized account can list `manus-guardian` | account authorized; project identity matched before deploy | `firebase login:list`, `firebase projects:list --json` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | FlutterFire generation | generated options match backend | Android options generated for `manus-guardian` only | `flutterfire configure --project=manus-guardian` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | anonymous auth | anonymous Firebase session succeeds | HTTP 200 via disposable validation account | `npm --prefix firebase/tests run test:real` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | email registration/login/session refresh | registration, login, and refresh succeed | HTTP 200 for each | `npm --prefix firebase/tests run test:real` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | Firestore bootstrap/read-back | authenticated parent creates family + primary parent atomically and reads it | HTTP 200 create/read-back | `npm --prefix firebase/tests run test:real` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | authorization boundaries | cross-family, unauthenticated, revoked-device, unauthorized-device, and role escalation writes deny | HTTP 403 for each denied request | `npm --prefix firebase/tests run test:real` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | Firestore rules and indexes deployment | target project receives Guardian rule/index manifests | Firebase CLI deploy completed | `firebase deploy --only firestore:rules,firestore:indexes --project manus-guardian` | VERIFIED ON REAL BACKEND |
| REAL FIREBASE | functions deploy/list/logs | Guardian codebase only deployed | deployment stopped before Functions because project is not Blaze; list has no Guardian function | Firebase CLI deployment and `functions:list` | HUMAN ACTION REQUIRED |
| PHYSICAL DEVICE | Android Firebase initialization | Firebase initialized in app | no APK/device | release Gradle daemon exits under sandbox limit | BLOCKED BY ENVIRONMENT |
| PHYSICAL DEVICE | FCM lifecycle | requested→event→accepted→received→displayed→ack | no token/device | FCM real path unavailable | BLOCKED BY ENVIRONMENT |

## التالية بعد الدليل الحالي

اكتمل Firebase Auth وFirestore الحقيقيان في مستوى API باستخدام حسابات اختبار عابرة ومعرفات منقحة. تظل بوابتان منفصلتان: ترقية مشروع Firebase إلى Blaze لنشر Cloud Functions Guardian، وAPK/جهاز Android لإثبات Flutter runtime وFCM. لا تضف بيانات أسرة حقيقية أو محتوى أطفال إلى مشروع الاختبار.
