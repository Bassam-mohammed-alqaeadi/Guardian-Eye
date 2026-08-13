# Phase 13 Completion Report — Family Safety Policy Management

**Date:** 12 August 2026  
**Selected vertical slice:** Family safety policy management: scheduled screen-time/bedtime-style policies, restricted targets, temporary allows, and truthful synchronization state.  
**Canonical workspace:** `/home/ubuntu/guardian_eye_flutter` (Flutter/Dart).

> **Scope boundary:** Phase 13 configures, evaluates, persists, synchronizes, and authorizes family safety policies. It does **not** claim to prevent apps, read Usage Stats, run a background worker, capture a screen, or enforce a restriction on a child device.

## Outcome

The selected slice now flows from a parent-facing Flutter screen through `PolicyRepository`, SQLite, and the durable Outbox to a family-scoped Firestore contract. Policy write permissions remain limited to family parents. The screen declares that it is configuration only until Android enforcement is separately implemented and verified on a physical device.

| Layer | Delivered implementation | Evidence level | Evidence |
|---|---|---|---|
| Domain | `DigitalPolicy` now carries `familyId`, display name, optimistic version, and `SyncState`. `StoredPolicyOverride` persists a temporary allowance without losing expiry or creator data. | **IMPLEMENTED + VERIFIED LOCALLY** | `flutter analyze`; repository and engine tests. |
| SQLite | Policy creation, update, enable/disable, and overrides execute in one local transaction with their corresponding Outbox event. | **IMPLEMENTED + VERIFIED LOCALLY** | 34 Flutter tests passed, including four new repository lifecycle assertions. |
| Outbox | `policy.created`, `policy.updated`, and `policy.override.created` carry the full mutation data required by the remote writer. List state is derived from real Outbox records rather than a UI assumption. | **IMPLEMENTED + VERIFIED LOCALLY** | SQLite tests verify event operation, version increment, queued state, and synced-state derivation. |
| Firestore contract | Policies and overrides are family-scoped. Parent-only write paths are represented in rules and accepted by the remote writer contract. | **VERIFIED IN EMULATOR** | 9 Firestore rules tests passed, including parent allow and child/cross-family deny cases. |
| Firestore deployment | The reviewed rules and configured indexes were compiled and released to `manus-guardian`. | **VERIFIED ON REAL BACKEND** | `firebase deploy --only firestore:rules,firestore:indexes --project manus-guardian` completed successfully. |
| Presentation | `SafetyPoliciesScreen` lists actual policies, opens create/edit configuration, toggles enabled state, evaluates a selected target through `PolicyEngine`, creates a one-hour temporary allow, and displays its Outbox state. Arabic RTL and English LTR translations are included. | **IMPLEMENTED + VERIFIED LOCALLY** | A focused Widget test verifies policy rendering, queued state display, and toggle repository interaction; no APK/AVD/physical runtime is available for device validation. |
| Child-device enforcement | Usage Stats, app blocking, bedtime enforcement, background work, and notification delivery were deliberately not added. | **NOT IMPLEMENTED** | Explicitly out of Phase 13 scope. |

## Delivered behavior

The repository validates family scope, nonblank names, minute-of-day bounds, nonnegative priority, and at least one restricted target. Updating a policy creates the next immutable logical version; toggling uses the same update path and consequently has the same durable synchronization behavior. A temporary override is scoped to one family and target and carries an expiry and creating member identity.

The presentation layer reads SQLite through the Riverpod repository provider. It never creates a success state from a hard-coded fixture. An empty family shows an empty-policy state, repository failures show retry, and each policy shows a state derived from its current Outbox rows: local only, queued, synced, blocked, or failed. The policy-decision card calls `PolicyEngine` with the actual locally stored policies and currently active override.

## Security and privacy boundary

| Boundary | Phase 13 decision | Verification |
|---|---|---|
| Family isolation | Every policy and override has `familyId`; Firestore paths are nested under the corresponding family. | **VERIFIED IN EMULATOR** |
| Role boundary | A parent can create/read/update family policy records; a child cannot write them. | **VERIFIED IN EMULATOR** |
| Cross-family write | A parent from another family cannot write the target family policy. | **VERIFIED IN EMULATOR** |
| Sensitive data | The slice stores configuration metadata only; it does not collect child content, screenshots, microphone input, location, or usage data. | **IMPLEMENTED** |
| Remote safety | No Firebase Admin credential or server key was added to Flutter. | **IMPLEMENTED** |

## Validation record

| Command | Result | What it proves | What it does not prove |
|---|---|---|---|
| `flutter analyze` | Passed with no issues. | Flutter source is statically consistent. | Device rendering or native platform behavior. |
| `flutter test --reporter expanded` | **34 passed**. | Domain, repository, SQLite/Outbox, policy Widget behavior, app baseline, Firebase contract and environment tests. | Interaction on an Android/iPhone runtime. |
| `./tool/run_firebase_emulator_tests.sh` | **9 Firestore rules + 2 Functions tests passed**. | Auth/Firestore/Functions Emulator integration and policy authorization boundaries. | A production Firestore policy read/write from a Flutter client. |
| `firebase deploy --only firestore:rules,firestore:indexes --project manus-guardian` | Succeeded; rules compiled and were released, and indexes deployed. | The intended rules and indexes exist on the selected backend. | A new client policy write/read against that backend, APK networking, or enforcement. |

## Remaining verification and human actions

The implementation is not production ready. A memory-constrained sandbox has not produced an APK, no Android device/AVD is connected, and no iOS toolchain is available. The immediate next safe verification is a Flutter client session on an AVD or physical Android device using the Firebase Emulator. It must create a parent family, create/edit/toggle a policy offline, reconnect, run Outbox synchronization, read back the Firestore record, and verify the policy state remains correct after application restart. Device-level enforcement must remain disabled until a separate Android capability slice has transparent consent, policy review, real integration, and physical-device evidence.

Cloud Functions are still not deployable because `manus-guardian` is on the Spark plan. This does not block the Phase 13 policy contract: the mobile Outbox remote writer uses direct family-scoped Firestore mutation paths. It does block future callable or server-triggered production verification that depends on Functions.

## Changed files

| Area | Principal files |
|---|---|
| Domain and data | `lib/domain/policy_engine.dart`, `lib/data/policy_repository.dart`, `lib/data/firestore_contracts.dart` |
| State and UI | `lib/application/guardian_providers.dart`, `lib/presentation/screens/safety_policies_screen.dart`, `lib/presentation/screens/dashboard_screen.dart` |
| Localization | `lib/core/localization/app_localizations.dart` |
| Backend rules | `firebase/firestore.rules`, `firebase/tests/firestore.rules.test.mjs` |
| Tests | `test/local_repository_test.dart` |

## Phase classification

**Phase 13 is complete for its defined policy-management slice at the evidence levels recorded above.** It is not a claim of completed parental-control enforcement, completed physical-device validation, completed iOS validation, completed Function deployment, or production readiness.
