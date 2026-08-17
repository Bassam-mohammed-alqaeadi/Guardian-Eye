# مصفوفة جاهزية الإنتاج — المرحلة التاسعة

**تاريخ الدليل:** 12 أغسطس 2026. الحالات المستخدمة محصورة في: **VERIFIED**، **PARTIAL**، **BLOCKED**، **NOT IMPLEMENTED**، و**HUMAN ACTION REQUIRED**. لا توجد خانة خضراء عامة؛ كل حالة مقيدة بالطبقة التي اختبرت فيها.

| Capability | Local | Emulator | Real Firebase | Physical Android | Production |
|---|---|---|---|---|---|
| Flutter/Dart analysis and widget/domain/repository tests | VERIFIED — `flutter analyze` و27 tests | غير مطلوب | BLOCKED | BLOCKED | PARTIAL |
| SQLite + Outbox persistence/retry | VERIFIED | PARTIAL — عقود بعيدة فقط | BLOCKED | BLOCKED | PARTIAL |
| Firebase bootstrap fail-closed | VERIFIED | PARTIAL بعد FlutterFire فقط | BLOCKED — لا config | BLOCKED | BLOCKED |
| Firebase Auth | PARTIAL — service/UI contracts | VERIFIED — callable Auth UID | BLOCKED | BLOCKED | BLOCKED |
| Firestore family isolation/rules | PARTIAL — contracts | VERIFIED — 7 rules tests | BLOCKED — لا deploy | BLOCKED | BLOCKED |
| Outbox → Firestore read-back من تطبيق Flutter | BLOCKED — لا FlutterFire options | BLOCKED — لا Android runtime/host config | BLOCKED | BLOCKED | BLOCKED |
| Child UID provisioning/replay | PARTIAL — TypeScript build | VERIFIED — 2 Functions tests | BLOCKED — لا deploy | BLOCKED | BLOCKED |
| Incident/SOS notification event | VERIFIED محليًا كOutbox | VERIFIED — trigger events | BLOCKED | BLOCKED | BLOCKED |
| FCM backend accepted | PARTIAL — code semantics | PARTIAL — intentional skip | BLOCKED | BLOCKED | BLOCKED |
| FCM received/displayed/tap/acknowledged | NOT IMPLEMENTED evidence | NOT IMPLEMENTED | BLOCKED | BLOCKED | BLOCKED |
| Android SDK/JDK/ADB toolchain | VERIFIED — SDK 36/JDK 17/ADB installed | PARTIAL — no AVD | غير مطلوب | BLOCKED — no device | PARTIAL |
| Android release APK | BLOCKED — Gradle daemon exits under sandbox memory after source fixes | غير مطلوب | غير مطلوب | BLOCKED | BLOCKED |
| Android app runtime/permissions/background | NOT IMPLEMENTED evidence | BLOCKED — no AVD | BLOCKED | BLOCKED | BLOCKED |
| Android signing/release distribution | HUMAN ACTION REQUIRED | غير مطلوب | غير مطلوب | HUMAN ACTION REQUIRED | BLOCKED |
| iOS build/APNs | BLOCKED — Linux host | غير مطلوب | BLOCKED | BLOCKED — no iPhone | BLOCKED |
| On-device AI inference | NOT IMPLEMENTED — no reviewed model artifact | غير مطلوب | غير مطلوب | BLOCKED | BLOCKED |
| Privacy/security contract review | PARTIAL — rules/contracts/logging review | VERIFIED relevant rules tests | HUMAN ACTION REQUIRED — deploy review | HUMAN ACTION REQUIRED — consent evidence | BLOCKED |

## بوابة الترقية

لترتفع أي خانة **BLOCKED** لا يكفي تغيير النص أو نجاح Emulator. يجب جمع الدليل المحدد في `docs/HUMAN_ACTION_REQUIRED.md` و`docs/FIREBASE_SETUP_REQUIRED.md`: Project ID مراجع، FlutterFire config، deploy، حسابات اختبار، APK، جهاز Android، وسلسلة FCM المنفصلة. يظل الإنتاج محجوبًا حتى تكتمل الأدلة الأمنية والخصوصية والاعتمادية وليس فقط حتى ينجح build.
