# Phase 18 — Gap Audit

**Project:** Guardian Eye Pro · **Author:** Manus AI · **Date:** August 13, 2026

This audit compares the Phase 18 mandate against the delivered state, lists the gaps that were addressed, the gaps that remain open (with honest classification), and the items deliberately out of scope.

## 1. Mandate vs. Delivery

| Mandate (Phase 18 brief) | Status | Evidence |
|---|---|---|
| Forensic baseline of Phase 17 components | DONE | `docs/phases/PHASE_18_FORENSIC_BASELINE.md`; checkpoint `ff3a64a`, all components verified intact |
| Canonical family runtime graph (single source of truth) | DONE | `FamilyRuntimeContext` + `FamilyContextResolver` + `familyRuntimeContextProvider` |
| Device context resolution (WHO / WHICH / IS active / revocation / child-or-not / policy) | DONE | `DeviceRuntimeContext` + `DeviceContextResolver` + `deviceRuntimeContextProvider`; ownership answered via `memberId` join, never inferred from local rows |
| Multi-parent runtime parity | DONE | Test: parent and co-parent resolve identical family/children/devices/permissions |
| Child isolation (fail-closed binding) | DONE | Test: child identity never verifies; isolation permissions denied; family readable |
| Offline-first continuity | DONE (verified unchanged) | All mutations route through SQLite + outbox; `UnconfiguredOutboxRemoteWriter` degrades gracefully |
| Idempotency / conflict handling | DONE (verified unchanged) | Policy delivery `applied/ignoredOlder/idempotent`; invitation status machine; version handling; stale-version policy resolution |
| Timeline truthfulness | DONE (verified unchanged) | `SafetyTimelineEvent` labels map only from real outbox `SyncState` rows |
| Exception request runtime | DONE (verified unchanged) | Approval → device-scoped `StoredPolicyOverride` with expiry via `createOverrideInTransaction`; child-initiated cancel checks |
| UI unification | DONE | Dashboard consumes `familyRuntimeContextProvider`; per-screen actor/authorization reconstruction removed |
| Test suite (no regression) | DONE | 80/80 Flutter; 15/15 Firestore; 2/2 Functions; analyze 0 issues |
| Documentation (6 files) | DONE | This audit + baseline + architecture + test evidence + human action + completion report |

## 2. Gaps Addressed in Phase 18

1. **Fragmented family graph** — five per-screen reconstructions consolidated into two canonical providers. The dashboard no longer constructs `FamilyAuthorization` locally; `can()` flows through the single matrix via the runtime context.
2. **Missing device-ownership resolver** — `DeviceContextResolver` joins the canonical device state with the membership repository so device ownership is never re-derived ad hoc.
3. **Cross-screen authorization drift risk** — eliminated by routing every UI permission check through `FamilyRuntimeContext.can`, which itself delegates to `FamilyAuthorization.permissionsFor(role)`.
4. **Conflicting lint in the new test file** — resolved by extracting a `const AuthSession` variable and using `const _Auth(...)`; one closure argument carries an explicit `// ignore:` (the lint pair `prefer_const_constructors` / `unnecessary_const` cannot both be satisfied inline).

## 3. Open Gaps (honest classification)

| Gap | Classification | Reason |
|---|---|---|
| Physical-device validation (dashboard rendering, provider refresh, child-device enrollment UI) | **HUMAN ACTION REQUIRED** | No Android device or AVD available in the sandbox; `flutter devices` finds none. An APK exists (`build/app/outputs/flutter-apk/app-debug.apk`) and can be installed manually. |
| Production Firebase validation (`manus-guardian`) with real accounts | **HUMAN ACTION REQUIRED** | Emulator coverage is complete (17/17), but production Auth/Firestore behavior (FCM, real Cloud Functions, production security rules against the live project) was deliberately not exercised — no Blaze, no deployment, no production writes. |
| Outbox remote delivery to production Firestore | **DOCUMENTED LIMITATION** | `UnconfiguredOutboxRemoteWriter` is used when the Firebase remote writer is not configured; local truth is complete, remote sync to `manus-guardian` requires Firebase tooling access (restricted by project rules). |
| Widget-level smoke tests of the new providers inside screens | PARTIAL | Provider resolution is covered by unit tests; full widget smoke (dashboard with live provider) was not added to avoid touching widget-test surfaces of other screens. |

## 4. Out of Scope (not gaps)

The following were explicitly excluded by user requirements and were not modified: Firebase configuration files (`firebase_options.dart`, `google-services.json`, `firebase.json`, `.firebaserc`), domain/security/business logic files, Firestore rules, Cloud Functions, deployment, Blaze activation, and any new Firebase resources. Phase 19 has not been started.

## 5. Net Assessment

All Phase 18 mandates that are verifiable in the sandbox are evidenced GREEN. The two open items are environmental (no physical device/AVD) and environmental-policy (no production Firebase writes permitted) — both correctly classified HUMAN ACTION REQUIRED rather than claimed complete.
