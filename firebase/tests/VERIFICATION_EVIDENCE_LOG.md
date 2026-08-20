# Firestore Rules Live Verification — Evidence Log

## Phase 1: Live comparison with deployed ruleset
- Firebase CLI installed (firebase-tools 15.28.1, via `npm install -g firebase-tools`).
- Project ID: `manus-guardian` (from `.firebaserc` and `firebase/.firebaserc`).
- No authenticated Firebase session in sandbox: `~/.config/configstore/firebase-tools.json` is empty (`{}`), no `FIREBASE_TOKEN` env, no `gcloud` CLI.
- `firebase firestore:rules:get` does not exist in CLI 15.x (deprecated/removed). Tried `firebase firestore:rules:list` — not a command.
- REST attempt: no access token available → 0-length token.
- **LIVE COMPARISON STATUS: UNVERIFIED** — cannot fetch deployed ruleset without authenticated credentials. No rules were published (user constraint: do not publish without approval).

## Phase 2: Emulator tests (firebase emulators:start --only firestore, port 8080, project guardian-eye-emulator)
- npm dependencies reinstalled: firebase@10.12.5 + @firebase/rules-unit-testing@3.0.2 (previous firebase@^10 mismatch: ERR_MODULE_NOT_FOUND on @grpc/grpc-js).
- Test runner: `node --test firestore.rules.test.mjs` against LOCAL `firebase/firestore.rules` (197 lines).

### First run: 11 pass / 4 fail (15 tests)
### Second run: 9 pass / 6 fail — failures below.

All failures are DENIES where tests expected ALLOW — i.e., the LOCAL RULES are more restrictive than the test contracts. Root causes (evaluation errors = rule bugs in local rules file):

1. **Test 2 'new parent creates family + member atomically'**: PERMISSION_DENIED
   - `false for 'create' @ L31` — family create rule line 31: `allow create: if signedIn() && request.resource.data.ownerUid == request.auth.uid;` — FAILS. NOTE: test creates family with ownerUid 'parent-new' while authenticated as 'parent-new'; should succeed. Failure suggests rule evaluation error or missing fields. Actually error mentions evaluation errors at L32/L35/L52 too.
2. **Tests 5, 6, 7 (invitations)**: `false for 'create' @ L64, false for 'update' @ L72` — invitations create/update DENY when expected ALLOW. L64 = invitations create rule; L72 = update rule (owner cancel branch).
3. **Test 11 (incidents, active device)**: `evaluation error at L165:26 for 'create' @ L165, L171:26 for 'update'` — incidents create/update evaluation errors. L165 = incidents create `activeMember(familyId) && request.resource.data.familyId == familyId` — but device fixtures created in before() may lack `memberUid`? Device 'device-a' has memberUid: 'child-a'. Evaluation error at activeOwnedDevice likely because device doc lacks required fields in test seed (e.g., missing `ownerUid`/`memberUid` consistency).
4. **Test 13 (usage summaries)**: `evaluation error at L147:28` — same device-seed issue.
5. **Test 14 (exception requests)**: `evaluation error at L99:26` — same device-seed issue.
6. **Test 'parent reads own family...' (test 1)**: PASSED in both runs.

### Interpretation
- The 6 failing tests mostly fail because the LOCAL RULES themselves reject operations that the app contract expects (and that a prior "VERIFIED IN EMULATOR" run passed — but that prior run used different rules/tests; REAL_FIREBASE_VALIDATION.md references an older ruleset).
- Key candidate bug: family `create` rule only requires ownerUid; but test seed creates families WITHOUT `ownerUid` field consistency? Test 2 seed: `{ownerUid: 'parent-new', status: 'active'}` — ownerUid matches auth. Hmm — 'false for create @ L31' could be because the test batch also creates member at same time; create at L31 is pure allow — maybe emulator logs show 'false' as part of OR. NEEDS DIAGNOSIS.
- Device fixtures in `before()` lack fields like `role` (used by activeTokenDevice at L27). enforcement/usage create use `activeOwnedDevice` which checks memberUid only — but L165 incidents branch `activeMember` should work for child-a (member has status 'active', has key 'status' defined).
- INVITATIONS failure: L64 owner create requires `get(...members/$(request.auth.uid)).data.memberId` — in the invitation create, the inviter member doc exists (owner-local). Requires proposedRole in ['parent','coParent'] and expiresAt > request.time. Seed `expiresAt = new Date('2026-08-20')` — test time may be now (2026-08-20/21) → may not be > request.time → DENY. Also L67 uses `get()` on member doc written in before() — exists.
- Need diagnosis per test before fixing rules OR tests. The LOCAL RULES may be correct and TESTS stale (rules were evolved after tests written).

## Live deployed-rules evidence (docs/03_security/REAL_FIREBASE_VALIDATION.md)
- Prior report claims `firebase deploy --only firestore:rules,firestore:indexes --project manus-guardian` completed earlier ("VERIFIED ON REAL BACKEND"), but deployed ruleset content cannot be fetched now (no auth). Cannot confirm current deployed content == local content.

## Status of app tests baseline
- Flutter: 432/432 green at checkpoint 3bc6321. Regression cmd: /opt/flutter/bin/flutter test $(ls test/*.dart | grep -v headless_validation | grep -v test_database) 2>&1 | tee /tmp/regression.log | tail -1
- Git: HEAD d15498e, branch feature/design-system-integration, clean.

## Key local rules facts (firebase/firestore.rules, 197 lines)
- No collections for AI insights, couple_harmony, subscription_entitlements, billing_records, tasks, rewards — the local ruleset ONLY covers families + subcollections: members, invitations, policies, policy_overrides, exception_requests, devices(+notification_tokens/enforcement_status/usage_summaries), device_pairings(blocked), incidents, sos, locations, messages, sync_events, notification_events(blocked write).
- This is a COVERAGE GAP: new Phase-17 features (AI L1-L9, FS-013 Couple Harmony, Subscription & Entitlements, FS-007/FS-008 tasks+rewards) have NO Firestore rules paths — presumably because they are offline-first/local-only (SQLite) per architecture; but MUST be verified against firestore_contracts.dart whether app writes them to Firestore at all.

## Coverage gap: app vs local rules (firestore_contracts.dart)
FirestorePaths defines MANY subcollections the LOCAL RULES DO NOT COVER (no match clause ⇒ implicit deny for everything under them):
- family_rules, tasks, task_completions, rewards, reward_claims, reward_ledger (FS-007/FS-008/FS-011)
- geofences, favorite_places, location_settings, notifications, sync_metadata, web_hits, web_domains, web_category_rules, web_settings (FS-001/web)
- app_policies, app_allowlists, app_block_events, usage_alert_settings (FS-003 apps)
- monitoring_shots/sessions/requests/schedules/evidence (FS-006 monitoring)
- mode_configs, mode_activations (FS-005 modes)
AI insights / couple / subscription do NOT appear in FirestorePaths ⇒ they are offline/local-only (SQLite) — NO Firestore rules needed. CONFIRMED offline-first.
Implication: the outbox sync for tasks/rewards/family_rules will be DENIED by production rules because those paths are undefined (implicit deny). This is a REAL GAP to report: FS-007/FS-008 remote sync will fail in production unless rules are extended.

## Diagnosis of existing suite failures (local rules ARE largely correct; tests are stale)
Family `create` (L31) works when payload has ownerUid == auth. Member create branch-1 (creatingOwnFamily) works when familyId present. Member update (L52) works with merge when familyId present.
Root cause of test 2, 11, 13, 14 failures: the `before()` seed documents are INCOMPLETE vs what rules require — e.g., test 2 member batch lacked familyId (test bug, NOT rule bug); tests 11/13/14 devices lack fields needed by activeOwnedDevice/get() (device doc missing `role`/full shape used in evaluation). Incidents L165 activeMember branch: child-a member exists with status active — but error points at L165:26 evaluation error: `get(/databases/$(database)/documents/families/$(familyId)/members/$(request.auth.uid))` inside activeOwnedDevice — device seed lacks `memberUid`? Device 'device-a' has memberUid: 'child-a'. Actually L165 create evaluates both branches; activeMember() calls exists()+get() — fine. The L165 error at :26 is inside activeMember get — because test seed wrote members without all fields? No — evaluation error means a property access on undefined. activeOwnedDevice requires device doc with memberUid — present. Hmm, but device 'device-a' has `memberUid: 'child-a'` and status active — OK.
NEED: device docs in before() lack no field... except `role`. activeTokenDevice uses .data.role but activeOwnedDevice does not. So evaluation error elsewhere: maybe incidents create path 'device-a' — request.resource.data.deviceId is 'device-a' ✓.
=> Deeper test run per-operation needed.

## CONFIRMED LOCAL RULES BUG — incidents create (L159-173)
Incidents create has branch (a): `activeMember(familyId) && request.resource.data.familyId == familyId` — NO deviceId constraint. Test 11 'revoked device cannot create incident' passed in the old suite only because the revoked-device write used deviceId 'revoked-a' and relied on branch (b) failing; BUT branch (a) allows ANY active member (including the child whose device is revoked) to create incidents without binding to a device → incident-r was actually ALLOWED in my repro. This is a genuine authorization gap: a member whose device is revoked can still write incidents (and SOS! L174-186 has the same branch (a)) as an active member.
NOTE: is this a bug or design? Incidents can be parent-observed (documented) — but branch (a) doesn't require deviceId at all, so it also lets revoked-device owners bypass device trust entirely. MUST flag as GAP.
Also verified: family create + member create/update work; invitations need diagnosis; tasks/rewards paths implicit deny.

## Invitations diagnosis (tests 5-7 failures in old suite)
Invitation create/update DO work when seeded correctly. Failures in the existing suite trace to two things: (1) `before()` seed used `proposal: proposedRole` values with `new Date('2026-08-20')` expiresAt which is NOT strictly > request.time at run time (rules require expiresAt > request.time), and (2) the acceptance batch writes were rejected because the owner-create call itself failed (chain failure). With fresh seeds (expiresAt far future), owner create OK, accept also needs diagnosis separately but rule acceptance branch requires getAfter(member) which needs invitationId in member doc — test seeds appear compliant. => existing suite 4-6 failures = STALE TESTS vs evolved rules, NOT broken local rules. The ONLY real rule bug found so far is incidents/SOS branch (a) lacking device binding (see above).
IMPORTANT: do NOT modify firestore.rules in this phase (user: zero backend changes; do not publish). Tests will be extended to document behavior of CURRENT local rules exactly, including the gap.

## Verification suite FINAL result: 20/20 PASS (firestore.rules.verification.mjs)
All 20 scenarios pass against CURRENT local rules. Test 8 needed correction: policies read for parent-a SUCCEEDED — confirmed by diag6.mjs that member() works when the member doc exists under /members/$(uid); earlier member read failures trace to the verification seed using IDs != UIDs (mem-child-a vs child-a). The APP CONTRACT (member IDs == memberUid == UID) is what the rules assume; under that contract, member()/activeMember()/parent()/owner() all resolve correctly.
Verified final scenario facts:
- Unauthenticated: ALL deny (PASS)
- Cross-family: ALL deny incl. child of A vs family B (PASS)
- Child isolation: reads/writes deny incl. own profile under non-UID seed — under real contract child reads own profile OK (rule: activeMember && memberId==uid) — PASS as designed
- Spouse: can read family doc; cannot manage policies (parent can) — PASS
- Primary parent: can update member (owner); non-primary parent denied — PASS (with UID-keyed contract)
- Revoked member (status revoked): loses ALL access — PASS
- Untrusted device: location create denied for revoked/unknown; enforcement & usage scoped — PASS. LOCATIONS ACTIVE-DEVICE WRITE: DENIED with evaluation error at L189 — GAP (see bugs).
- FS-007 tasks / FS-008 rewards: no rule → implicit deny — remote sync WILL FAIL; GAP (rules need extension before FS-007/008 outbox sync goes live)
- AI / Couple / Subscription collections: no rule → deny — BY DESIGN (offline-first SQLite); NO GAP
- Device pairings + notification_events: permanently denied — PASS (backend-only)
- Device ownership: child cannot register; parent owner can — PASS

## Confirmed gaps/bugs in LOCAL firestore.rules (to report; rules NOT modified per constraints)
1. BUG A — incidents/sos create branch (a): `activeMember(familyId)` without deviceId binding lets a member whose device is REVOKED create incidents/SOS (verified earlier). Revoked MEMBER loses access via activeMember (fine) but a member whose MEMBER status is active while their DEVICE is revoked can still write incidents/SOS as "any active member". Also branch (a) permits incident creation WITHOUT deviceId — no device trust for parent-reported incidents.
2. BUG B — locations create: evaluation error at L189 under emulator (activeOwnedDevice lookup on request.resource.data.deviceId) — active child device cannot write locations; effectively all location writes deny. Location reporting (M9) would break in production.
3. GAP C — No rules for tasks, task_completions, rewards, reward_claims, reward_ledger, family_rules → FS-007/FS-008/FS-011 outbox sync writes will be denied. Needs rule extension.
4. GAP D (structural) — member() helper assumes /members/$(request.auth.uid) exists; app contract must guarantee member doc ID == memberUid == UID (seed mismatch causes deny-by-evaluation-error — unreliable). Recommend contract enforcement in FirestoreMutation builder.
5. GAP E — policies/update & members/update for non-owners rely on owner() which relies on member(); acceptable under contract.
6. GAP F — No rules for geofences/web/monitoring/apps/modes subcollections (older phases FS-001 web, FS-003, FS-006, FS-005) — if those phases' outbox syncs go live, they'd also deny; check whether those phases' remote sync is enabled currently.
AI/Couple/Subscription: NO GAP — verified offline-first (no FirestorePaths for them).
