# Phase 18 — Test Evidence

**Project:** Guardian Eye Pro · **Author:** Manus AI · **Date:** August 13, 2026

All evidence below was produced by direct command execution in the sandbox. Test results are the source of truth; no test was weakened and no assertion was relaxed during Phase 18.

## 1. Static Analysis

```
$ flutter analyze
Analyzing guardian_eye...
No issues found! (ran in 4.2s)
```

**Result: GREEN — 0 issues** (previously 2 conflicting `const` lints in the new test file were resolved by extracting the `AuthSession` into a `const` variable and using `const _Auth(...)`; one non-const closure argument required `// ignore: prefer_const_constructors`).

## 2. Flutter Unit / Widget Test Suite

```
$ flutter test --reporter expanded
...
00:10 +80: ... family members screen renders local data and exposes the owner invitation form
00:10 +80: All tests passed!
```

**Result: GREEN — 80/80 passing** (73 inherited Phase 17 tests + 7 new Phase 18 tests). No regression in any prior test group (membership, actor binding, policies, exceptions, enforcement, timeline, sync, providers, screens).

### 2.1 New Phase 18 Tests (`test/family_context_provider_test.dart`, 7/7 PASS)

| # | Test | Verdict it proves |
|---|---|---|
| 1 | Verified parent sees the same family, children and devices as the verified co-parent | Multi-parent parity through the canonical context; identical member/child/device sets and identical permission matrix for `parent`/`coParent`; `can()` true for `viewPolicies`, `managePolicies`, `manageDevices`, `reviewExceptionRequests` |
| 2 | Child identity never verifies — isolation view denies every action | Trusted Actor Binding fail-closed: child members are rejected as actors; `isVerified` false, `actor` null, `managePolicies`/`manageDevices`/`requestOwnException` denied; family contents still readable for the child view |
| 3 | Unverified actor receives a closed context and no privileged action | A signed-in account bound to no membership role resolves to an unverified context; every permission denied |
| 4 | Empty family id returns the unverified closed context | Whitespace/empty family IDs return a closed context instead of throwing |
| 5 | Device context resolves owner, family and active state without duplication | `DeviceContextResolver` joins the canonical device state with the member lookup; `memberId`, role, child-device flag, active state, and family scope all correct |
| 6 | Device context is rejected across families and for unknown devices | Cross-family and unknown-device lookups return `null` (fail-closed) |
| 7 | Revocation closes the device while offline keeps it enrolled | `offline` lifecycle keeps `isActive` true; `revoked` lifecycle closes it; child-device classification persists across lifecycle transitions |

The test fixtures follow the established Phase 17 conventions (`test/test_database.dart`, in-memory sqflite, `_Auth`/`_Reader` test doubles, `_Fixture` with owner/parent/coParent/child members, `DeviceRole.childDevice.storageKey` for device-role insertion, and `initializeForEnrolledDevice` after `devices`-table insertion).

## 3. Firebase Emulator Validation (unchanged scripts, synthetic project)

```
$ ./tool/run_firebase_emulator_tests.sh
✔  Script exited successfully (code 0)
```

### 3.1 Firestore security rules — 15/15 PASS

| # | Rule test | Status |
|---|---|---|
| 1 | parent reads own family and cannot read another family | pass |
| 2 | new parent creates family and own primary-member record atomically | pass |
| 3 | child cannot escalate own role or change policy | pass |
| 4 | primary parent cannot escalate a child role or rebind its Firebase UID | pass |
| 5 | owner creates a family-scoped adult invitation and intended account accepts it atomically | pass |
| 6 | only the family owner can create a valid adult invitation for that family | pass |
| 7 | invitation acceptance rejects wrong, replayed, expired, cancelled, and child identities | pass |
| 8 | parent can manage family policies while child and another family are denied | pass |
| 9 | parent cannot bind a child UID directly to a device outside provisioning | pass |
| 10 | parent may register a token only for an owned parent device | pass |
| 11 | active device can create incident while revoked device cannot | pass |
| 12 | only the active child device can report its scoped enforcement status | pass |
| 13 | only an active child device may create its scoped usage summary | pass |
| 14 | child exception request is owned by its active device and parent review is constrained | pass |
| 15 | mobile client cannot write notification event directly | pass |

`# tests 15  # pass 15  # fail 0`

### 3.2 Cloud Functions — 2/2 PASS

| # | Function test | Status |
|---|---|---|
| 1 | incident and SOS creates produce durable notification events without claiming FCM delivery | pass |
| 2 | child provisioning binds a distinct child UID once and rejects replay | pass |

`# tests 2  # pass 2  # fail 0`

Both suites ran under the synthetic project `guardian-eye-emulator`; production project `manus-guardian` was never targeted. Callable request verification logged `auth: VALID` throughout.

## 4. Regression Summary

| Suite | Phase 17 baseline | Phase 18 result | Verdict |
|---|---|---|---|
| `flutter analyze` | 0 issues | 0 issues | GREEN |
| Flutter tests | 73/73 | 80/80 | GREEN (no regression) |
| Firestore emulator | 15/15 | 15/15 | GREEN |
| Functions emulator | 2/2 | 2/2 | GREEN |
| APK (debug) | built ~172 MB | exists from Phase 17 | GREEN |

## 5. Evidence Caveat (honesty note)

All Phase 18 behavior is evidenced at the unit, widget, and emulator level. **No physical device or Android emulator (AVD) run was performed** — the sandbox has no connected Android device/AVD; physical and production-Firebase validation are classified HUMAN ACTION REQUIRED (see `PHASE_18_HUMAN_ACTION_REQUIRED.md`).
