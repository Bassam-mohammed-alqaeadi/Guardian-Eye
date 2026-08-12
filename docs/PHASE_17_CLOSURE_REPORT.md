# Phase 17 Closure Report — Family Membership and Trusted Actor Binding

**Closure status:** **IMPLEMENTED — VALIDATION BLOCKED**

> **This is not a GREEN or production-readiness claim.** The trusted actor binding is implemented and locally tested, but restoration of the original local Firebase artifacts and an Android runtime remain outstanding evidence gates.

## Scope completed

Phase 17 now resolves a Dashboard actor only through a server-backed, fail-closed reconciliation of the authenticated Firebase account and the local `FamilyMember` record. The resolver uses the exact UID-keyed remote member path `families/{familyId}/members/{uid}`, requires active status on both sides, compares family ID, member ID, account UID, and role, rejects child identities, and rejects any remote read failure, missing document, inactive/revoked record, or mismatch.

The Dashboard continues to display local family data, but its management actions now require a verified actor. Pairing, policy management, child management, child status, and safety timeline actions are disabled until the binding succeeds and the central `FamilyAuthorization` matrix grants the applicable permission. The Family Members route receives only the verified `actorMemberId`; it does not infer ownership from a local primary-parent row.

## Artifact restoration result

The approved canonical source for the required local-only artifacts was not present in the recovered sandbox. A read-only inventory found no project `lib/firebase_options.dart`; the only `google-services.json` was the separately supplied upload that the authoritative forensic report explicitly excludes as canonical evidence. All Phase 13–17 delivery archives also intentionally excluded both artifacts. Therefore neither file was copied, regenerated, edited, substituted, or created.

| Required artifact | Result | Evidence classification |
|---|---|---|
| `lib/firebase_options.dart` | Not available from a canonical approved source in this sandbox. | **HUMAN ACTION REQUIRED** |
| `android/app/google-services.json` | A matching-looking upload exists, but it is not accepted as the approved canonical source. It was not used. | **HUMAN ACTION REQUIRED** |

## Files changed during this closure pass

| Area | Files |
|---|---|
| Trusted actor binding | `lib/data/family_actor_binding_service.dart`, `lib/data/family_membership_repository.dart` |
| Riverpod and Dashboard integration | `lib/application/guardian_providers.dart`, `lib/presentation/screens/dashboard_screen.dart` |
| Arabic/English UI state | `lib/core/localization/app_localizations.dart` |
| Regression evidence | `test/family_actor_binding_service_test.dart` |
| Closure records | `docs/PHASE_17_CLOSURE_REPORT.md`, `docs/PHASE_17_TEST_EVIDENCE.md`, `docs/PHASE_17_GAP_AUDIT.md`, `docs/PHASE_17_HUMAN_ACTION_REQUIRED.md`, `docs/IMPLEMENTATION_BLOCKERS.md`, `todo.md` |

No Firebase configuration file, Firestore Rule, Firebase project, Blaze plan, Cloud Function deployment, FCM flow, or production resource was changed in this closure pass.

## Tests executed

| Verification | Result | Evidence classification |
|---|---|---|
| `flutter test test/family_actor_binding_service_test.dart --reporter expanded` | **10 passed**. Covers valid parent/co-parent, unknown UID, local inactive, remote revoked, cross-family mismatch, child identity, missing remote record, remote/local member mismatch, role mismatch, anonymous/unauthenticated/malformed UID, and remote read failure. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Targeted membership suite | **22 passed** across actor binding, membership lifecycle, Firestore contract, and members UI tests. | **VERIFIED LOCALLY** |
| `flutter analyze` | Blocked by exactly two errors from the absent `lib/firebase_options.dart`; no actor-binding or Dashboard diagnostic remains. | **IMPLEMENTED — VALIDATION BLOCKED** |
| `flutter test --reporter expanded` | **61 tests passed**; five existing UI/bootstrap test files failed only to load because `lib/firebase_options.dart` is absent. | **IMPLEMENTED — VALIDATION BLOCKED** |
| `./tool/run_firebase_emulator_tests.sh` | **15 Firestore Rules tests and 2 Functions tests passed**; process exited successfully. | **VERIFIED IN EMULATOR** |
| Debug APK conditional attempt | Skipped correctly because `ANDROID_HOME` is unset and no Android SDK directory exists. | **HUMAN ACTION REQUIRED** |

## Remaining blockers

The following blockers remain exact and unresolved.

1. The owner must provide access to the **original approved** local `lib/firebase_options.dart` and `android/app/google-services.json` from secure canonical storage. The separately uploaded Google Services file must not be promoted to canonical status without independent owner confirmation.
2. An Android SDK-equipped host is required for a debug APK and device/AVD validation. This recovered sandbox has no `ANDROID_HOME`.
3. After artifact restoration, the full Flutter suite must compile and pass; then the trusted actor binding must be exercised by a Flutter client against the Emulator with real authenticated parent, co-parent, and child identities.
4. Real-backend validation and any deployment remain outside this closure. No Phase 17 Firestore rules deployment to `manus-guardian` was performed or authorized.

## Exact recommendation for the next phase

**Do not start Phase 18.** Treat the next work as **Phase 17 closure remediation**. Restore only the two original approved local artifacts, then run:

```bash
export PATH=/home/ubuntu/flutter/bin:$PATH
cd /home/ubuntu/guardian_eye_flutter
flutter analyze
flutter test --reporter expanded
./tool/run_firebase_emulator_tests.sh
GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=1' flutter build apk --debug --no-pub
```

On an Android runtime host, verify the resolved actor against the Emulator with valid parent, valid co-parent, unknown UID, revoked member, child identity, offline remote-read failure, and family mismatch. Only then reassess the Phase 17 GREEN gate. Do not deploy rules, enable Blaze, implement FCM, or begin a subsequent product phase as part of this remediation.
