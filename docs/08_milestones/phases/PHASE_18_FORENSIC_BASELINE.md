# Phase 18 — Forensic Baseline

**Project:** Guardian Eye Pro (Flutter 3.35.5 / Dart 3.9.2, Firebase, Riverpod)
**Package:** com.guardianeye.app · **Firebase project:** manus-guardian (165160049292)
**Baseline checkpoint:** `origin/master = ff3a64a` — "feat(phase17): complete family membership and trusted actor binding"
**Author:** Manus AI · **Date:** August 13, 2026

---

## 1. Purpose

This document records the forensic inventory of the codebase at the Phase 17 checkpoint, the disconnections identified between Phase 17 components, and the canonical runtime-graph design adopted for Phase 18. It is the evidence baseline against which the Phase 18 implementation and test results are audited. No source files were modified to produce this baseline.

## 2. Checkpoint State (read-only verification)

| Gate | Evidence | Result |
|---|---|---|
| GitHub checkpoint | `origin/master = ff3a64a`, working tree clean | GREEN |
| Firebase config identity | `projectId = manus-guardian`, `package = com.guardianeye.app`, App ID `1:165160049292:android:922e6c8a4749c42e4839a9` (read-only, no regeneration) | GREEN |
| `flutter analyze` | 0 issues | GREEN |
| Flutter test suite | 73/73 passing (inherited Phase 17 suite) | GREEN |
| Firestore emulator rules | 15/15 passing (`./tool/run_firebase_emulator_tests.sh`) | GREEN |
| Functions emulator | 2/2 passing | GREEN |
| APK build | `build/app/outputs/flutter-apk/app-debug.apk` (~172 MB) | GREEN |
| Gradle / toolchain | AGP 9.0.1, Kotlin 2.1.21, dynamic jvmTarget mirroring | GREEN |

Firebase configuration files (`firebase_options.dart`, `google-services.json`, `firebase.json`, `.firebaserc`) were inspected only and left byte-identical; they are gitignored and were not regenerated.

## 3. Component Inventory (Phase 17 artifacts)

The forensic scan covered 46 Dart source files under `lib/` and 23 test files under `test/`. The Phase 17 components of record, all verified intact at `ff3a64a`, are summarized below.

| Domain | Component | Role |
|---|---|---|
| Authorization | `lib/domain/family_authorization.dart` | Single role-based permission matrix (`FamilyAuthorization.permissionsFor(role)`) |
| Binding | `lib/data/family_actor_binding_service.dart` | Trusted Actor Binding — fail-closed UID-path resolution, explicitly rejects child role |
| Membership | `lib/data/family_membership_repository.dart` | Members, invitations, role binding, revocation, expiry |
| Devices | `lib/data/child_device_repository.dart` | Enrollment, lifecycle state machine, policy delivery |
| Exceptions | `lib/data/child_exception_request_repository.dart` | Child-initiated exception requests with parent review |
| Policies | `lib/data/policy_repository.dart` + `domain/policy_engine.dart` | Digital policy CRUD, versioning, temporary overrides |
| Providers | `lib/application/guardian_providers.dart` | Riverpod provider graph (repos, states, usage, delivered policies) |
| Sync | `lib/data/outbox_sync_executor.dart` | Offline-first mutation outbox with `SyncState` labels |
| Timeline | `lib/data/family_safety_experience_repository.dart` | `SafetyTimelineEvent` with truthful local/synced status |
| Database | `lib/core/database/guardian_database.dart` | SQLite schema incl. `devices` (`role` = `DeviceRole.storageKey`), `family_members`, `child_device_states` |
| Tests | 15 Firestore rule tests + 2 Functions tests | Emulator validation under synthetic project `guardian-eye-emulator` |

All multi-parent, child-isolation, offline-first, idempotency, and timeline-truthfulness behaviors verified present in Phase 17 (see the verified-findings record in the working notes):

1. **Multi-parent parity** — `FamilyAuthorization` grants identical permission sets to `parent` and `coParent`; membership mutations are owner-checked.
2. **Child isolation** — child role receives only `viewFamily`, `requestOwnException`, `viewOwnPolicy`, `viewOwnUsage`, `viewOwnStatus`; binding service rejects child members as actors.
3. **Offline-first mutations** — every mutation writes SQLite + outbox event; UI reads local repositories; `UnconfiguredOutboxRemoteWriter` degrades gracefully.
4. **Policy delivery idempotency** — `ChildPolicyDeliveryResult` (applied / ignoredOlder / idempotent) with version and payload-conflict semantics.
5. **Timeline truthfulness** — sync labels map only from real outbox `SyncState` rows; no fabricated "remote confirmed" label exists.
6. **Exception runtime** — approval creates a device-scoped, expiry-bound `StoredPolicyOverride` through `createOverrideInTransaction`, enqueued as `child.exception.approved`.

## 4. Disconnections Identified

The forensic review found five structural disconnections between otherwise correct Phase 17 components:

1. **No single family runtime view.** The dashboard resolved the actor through its own per-screen `ref.watch(familyActorBindingProvider)` plus a locally constructed `FamilyAuthorization`, while other screens reconstructed member/child/device sets from independent `FutureProvider.family` calls. Each screen held a partial, duplicated reconstruction of the same family graph.
2. **Per-screen actor reconstruction.** Actor resolution (binding + authorization) was re-implemented at each consumer site rather than delegated to one resolver.
3. **No device-ownership context.** `ChildDeviceState` carries `memberId`, but no resolver joined it with the membership repository, so "WHO owns this device" required ad-hoc lookups.
4. **Family graph fragmentation.** Family, members, children, devices, and permissions were available only as separate providers with no canonical composition for the UI.
5. **Context duplication risk.** Independent reconstruction sites risked diverging permission and membership behavior across screens (e.g., one screen using `hasPermission`, another using raw role checks).

No data loss, security regression, or schema defect was found. The disconnections are architectural duplication, not correctness failures.

## 5. Canonical Graph Design Adopted

Phase 18 closes the disconnections with one canonical runtime graph, as mandated by the phase brief:

```
Authenticated User → Trusted Actor Binding (fail-closed) → Family Runtime Context
    ├── Family
    ├── Member  (the actor)
    ├── Role
    ├── Permissions (delegated verbatim to the single FamilyAuthorization matrix)
    ├── Devices  (ChildDeviceRepository states, family-scoped)
    └── Children (active child members)
```

Person identity and device identity remain strictly separate; authority always flows from `FamilyActorBindingService`, which is fail-closed. No new authorization mechanism is introduced — permissions delegate to the existing `FamilyAuthorization` matrix. The Phase 18 deliverables are `lib/application/family_context_provider.dart` (resolver classes + Riverpod providers), the dashboard integration, the new 7-test suite, and this documentation set.

## 6. Constraints Honored

Firebase configuration files were not modified or regenerated. Domain/security/business logic files were not altered (the resolver delegates to them). No Firebase deployment, Blaze activation, or new resources were created. The test suite remains the source of truth; fixture data was corrected where needed and no test was weakened.
