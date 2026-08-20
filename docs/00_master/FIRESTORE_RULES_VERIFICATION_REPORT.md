# Firestore Rules Live Verification Report

**Project:** Guardian Eye Pro — Flutter Android family-safety platform
**Branch:** `feature/design-system-integration` (HEAD `d15498e`, checkpoint parent `3bc6321`)
**File under audit:** `firebase/firestore.rules` (197 lines)
**Date:** 21 August 2026
**Author:** Manus AI
**Scope:** Live comparison with the deployed ruleset + safe emulator tests. No rules were modified and no rules were published. No new features were started.

---

## 1. Executive Summary

The local `firestore.rules` file was verified against every authorization scenario in the mandate using a local Firestore emulator (project `guardian-eye-emulator`, port 8080). A dedicated 20-case verification suite (`firebase/tests/firestore.rules.verification.mjs`) was written and executed against the rules **exactly as they exist locally**; it passes **20/20**.

The single most important finding is honesty-bound: **live comparison with the deployed ruleset is UNVERIFIED**. The sandbox has no authenticated Firebase session for project `manus-guardian` (empty `firebase-tools.json`, no `FIREBASE_TOKEN`, no `gcloud`), and the `firestore:rules:get` command no longer exists in the installed CLI version, so the REST fallback also had no token to use. No claim of parity between local and deployed rules is made.

Two genuine rule defects and one coverage gap were found in the local ruleset. **The rules were not changed** (user constraint: zero backend changes, no publishing without approval) — the gaps are documented below with proposed fixes ready for a separate approval step.

## 2. Live Comparison Status

| Item | Result |
|---|---|
| Firebase project ID (from `.firebaserc`) | `manus-guardian` |
| Firebase CLI | firebase-tools 15.28.1 (installed in-session) |
| Authenticated session | **None** — configstore empty, no CI token, no gcloud |
| `firestore:rules:get` / `rules:list` | Not available in CLI 15.x (removed/deprecated) |
| REST ruleset fetch | Attempted — no access token → **not possible** |
| **Live comparison status** | **UNVERIFIED** — cannot confirm deployed ruleset equals local rules |
| Rules published | **No** — read-only audit only, per user constraint |

A prior report (`docs/03_security/REAL_FIREBASE_VALIDATION.md`) records that rules were deployed to `manus-guardian` in an earlier phase, but its content is older than the current `firestore.rules`, so the deployed ruleset may no longer match the local file. This must be confirmed by an authenticated fetch before any production reliance.

## 3. Emulator Test Results

A new verification suite (`firebase/tests/firestore.rules.verification.mjs`) exercises all ten mandated scenarios against the local rules. The emulator jar was downloaded on demand by `firebase emulators:start --only firestore`; tests ran exclusively against the local rules file. The final run passed **20/20**:

```
# tests 20
# pass 20
# fail 0
```

The existing suite (`firestore.rules.test.mjs`, 15 cases) is **stale relative to the evolved rules**: on a clean fresh emulator run it fails 6 of 15, and diagnosis showed the failures are seed-data defects in the tests (e.g., an `expiresAt` seed not strictly later than `request.time`, incomplete member/device fixtures), not rule defects. It was not modified during this phase.

### 3.1 Scenario-by-scenario allowed/denied matrix

| # | Scenario | Path / Operation | Actor | Result |
|---|---|---|---|---|
| 1 | Unauthenticated access | `families/{id}` read + write | anonymous | **DENIED** |
| 2 | Unauthenticated access | all subcollections (members, policies, devices, locations, incidents, sos) read + write | anonymous | **DENIED** |
| 3 | Cross-family reads/writes | `families/fam-b` read, members read, forged policy write | primary parent of family A | **DENIED** |
| 4 | Cross-family reads/writes | family B data read + forged incident write | child of family A | **DENIED** |
| 5 | Child isolation | read other members' profiles (`mem-primary-a`, `mem-spouse-a`) | child | **DENIED** |
| 6 | Child isolation | write policies / members / devices / invitations | child | **DENIED** |
| 7 | Child isolation | read parent-only collections (incidents, locations, sos) | child | **DENIED** |
| 8 | Spouse/parent boundaries | read own family document; read policies | spouse / parent | **ALLOWED** |
| 9 | Spouse/parent boundaries | write policies | spouse | **DENIED**; **parent ALLOWED** |
| 10 | Spouse/parent boundaries | modify family / member records | non-primary parent | **DENIED**; **primary parent ALLOWED** |
| 11 | Revoked members | read family, own member record; write incidents | member with `status: revoked` | **DENIED** (all) |
| 12 | Untrusted devices | `locations` write with revoked / unknown `deviceId` | child | **DENIED** (all) |
| 13 | Untrusted devices | `devices/{dev}/enforcement_status` writes | child on active device: **ALLOWED**; on revoked device: **DENIED**; parent impersonating: **DENIED** | mixed, correct |
| 14 | FS-007 tasks | `families/{id}/tasks/{taskId}` write | parent | **DENIED** — no rule exists (implicit deny) — **coverage gap** |
| 15 | FS-008 rewards | `rewards` and `reward_claims` write | child | **DENIED** — no rule exists — **coverage gap** |
| 16 | AI paths | `families/{id}/ai_insights/*` read + write | parent | **DENIED** — by design (offline-first; no Firestore paths in the app) — **no gap** |
| 17 | Couple Harmony paths | `couple_decisions/*` read + write | spouse | **DENIED** — by design (local SQLite only) — **no gap** |
| 18 | Subscription paths | `subscription_entitlements`, `billing_records` read + write | primary parent | **DENIED** — by design (local-only entitlements) — **no gap** |
| 19 | Device pairings / notification events | read + write | parent | **DENIED** — permanently blocked (backend-only) |
| 20 | Device ownership | child registering a device: **DENIED**; parent owner writing own device: **ALLOWED** | child / parent | mixed, correct |

## 4. Defects and Gaps Found in the Local Ruleset

The rules file was **not modified**. The following defects and gaps are documented for a separate approval step.

### BUG A — incidents/sos create permits revoked devices (authorization gap)

The `incidents` and `sos` create rules contain a branch `activeMember(familyId) && request.resource.data.familyId == familyId` with **no `deviceId` constraint**. A member whose own member status is `active` but whose **device** is `revoked` can still create incidents and SOS records through this branch, bypassing device trust entirely. Confirmed by a targeted reproducer: a child with a revoked device created an incident successfully through the `activeMember` branch. The intended behavior (incident creation bound to an `activeOwnedDevice`) only applies to the second branch of the rule, so the first branch needs the same device binding added.

### BUG B — locations create fails with an evaluation error (functional break)

Under the emulator, `families/{id}/locations` create evaluates with an **evaluation error at L189** (inside the `activeOwnedDevice` helper when it inspects `request.resource.data.deviceId`). In practice this means **even an active, trusted child device cannot write location reports**, which would break M9 background-location reporting and ordinary location sharing in production if this ruleset were deployed. The rule needs its field contract tightened (or the helper rewritten defensively) so an active owned device is allowed and an invalid payload is cleanly denied.

### GAP C — FS-007/FS-008/FS-011 paths are undefined (coverage gap)

The local ruleset defines no match clauses for `tasks`, `task_completions`, `rewards`, `reward_claims`, `reward_ledger`, or `family_rules`. Firestore's implicit-deny default means any future outbox sync for FS-007 (tasks), FS-008 (rewards), or FS-011 (family rules) would be **silently denied in production**. The app's contracts define these paths in `lib/data/firestore_contracts.dart`, so the rules must be extended before those syncs are enabled remotely. AI, Couple Harmony, and Subscription collections are deliberately absent from the contracts and remain local-only (SQLite) — verified, no gap there.

### GAP D — structural: member document identity contract

Every permission helper (`member()`, `activeMember()`, `parent()`, `owner()`) resolves the actor via `/members/$(request.auth.uid)`. The rules therefore silently deny any member whose document ID does not equal its `memberUid` and the UID used at authentication — denial arrives as an evaluation-failure deny rather than a principled role deny, which is hard to diagnose. The application's mutation builders must guarantee member doc IDs equal member UIDs, and the helpers should defensively handle missing documents.

### GAP E — older-phase subcollections also uncovered

`geofences`, `web_*`, `app_*`, `monitoring_*`, and `mode_*` subcollections likewise have no local match clauses. If those phases' remote sync is currently enabled in production, they would also be implicitly denied — this should be checked when the deployed ruleset comparison becomes possible.

## 5. Flutter Baseline Integrity

The four files edited during this phase (removing five pre-existing analyzer warnings) were regression-checked. The full suite remains green and analyze is clean:

| Check | Result |
|---|---|
| `flutter analyze lib/` | **0 errors, 0 warnings** (5 warnings fixed: unused imports ×3, unused variable ×1, unreachable switch case ×1) |
| `flutter test` (432 files, excl. `headless_validation`/`test_database`) | **432/432 green** |
| Emulator suite (`firestore.rules.verification.mjs`) | **20/20 green** |

## 6. Working Tree State

The working tree contains only two new untracked files, both part of this verification phase and **not committed** (pending your instruction):

```
?? firebase/tests/VERIFICATION_EVIDENCE_LOG.md
?? firebase/tests/firestore.rules.verification.mjs
```

`firebase/tests/node_modules` changes (dependency install for the emulator run) were restored so the repository stays pristine; the emulator jar is not checked in.

## 7. Recommendations (no action taken)

First, complete the live comparison once an authenticated Firebase session is available (`firebase login` or a CI token for `manus-guardian`) to establish whether the deployed ruleset matches the local file — this is the only remaining unknown. Second, approve a follow-up rules fix batch covering BUG A (bind incidents/sos creates to an active owned device), BUG B (defensive `activeOwnedDevice` evaluation), and GAP C (rule clauses for tasks/rewards/family rules) before those syncs are enabled. Third, extend the emulator suite to assert the corrected behaviors once fixes are approved, and update the stale `firestore.rules.test.mjs` seeds in the same step. No rules have been published and none will be without your explicit approval.
