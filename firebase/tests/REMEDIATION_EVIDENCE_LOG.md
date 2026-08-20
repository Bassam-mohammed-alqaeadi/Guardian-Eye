# Firestore Rules Remediation — Evidence Log

## GAP E investigation (Phase 1)
Question: do geofences / web / app / monitoring / mode paths need Firestore rules?

Findings from `lib/data/firestore_contracts.dart` + codebase search:
- **geofences**: contract exists (`geofence.created`, `geofence.updated`, `geofence.disabled` at L799-860) and `location_repository.dart` (L489/548/586) DOES enqueue these for remote sync via the outbox. `favorite_places` contract exists too (parent-written). **ACTIVE SYNC → needs rules.**
- **web (web_hits, web_domains, web_category_rules, web_settings)**: contracts exist (L656-760) — FS-002 web filtering writes `web.hit` etc. Real backend tests exist (`web_filter_backend_test.dart`, 429 tests incl. these). **ACTIVE SYNC → needs rules.**
- **monitoring (monitoring_shots/sessions/requests/schedules/evidence)**: contract paths exist; DB has monitoring tables with sync_state queued; shots are parent-device written evidence. **ACTIVE SYNC candidate → needs rules (evidence path is sensitive).**
- **app (app_policies, app_allowlists, app_block_events, usage_alert_settings)**: contract paths exist. **needs rules.**
- **mode (mode_configs, mode_activations)**: contract paths exist; activations carry sync_state. **needs rules.**
- notification_events + device_pairings already permanently denied (existing rules) — keep.

Decision: add explicit rules for ALL GAP E paths with family-isolated, role-scoped clauses following the same patterns as incidents/locations:
- parent-only writes for config paths (geofences, favorite_places, location_settings*, app_policies, app_allowlists, web category/domain rules, web_settings, mode_configs, monitoring_requests, monitoring_schedules)
- device-bound writes for evidence/data (monitoring_shots, monitoring_sessions, monitoring_evidence, mode_activations) via activeOwnedDevice
- web_hits: child-device writes (activeOwnedDevice) + parent reads

## Current rules structure (firebase/firestore.rules, 197 lines)
- L29 families/{familyId}: read activeMember, create ownerUid==auth, update/delete owner()
- L33 members/{memberId}: read member()||activeMember&&memberId==uid; create: branch1 creatingOwnFamily+memberId-in-owners-family OR branch2 parent(familyId); update: owner()||member() w/ memberId==auth
- L60 invitations/{invitationId}: read: member; create: owner (proposedRole parent/coParent, expiresAt>now); update: owner cancel OR (member + role child + own status pending) accept w/ getAfter; delete: owner
- L93 policies: read member, write parent; L94 policy_overrides: parent both
- L95 exception_requests: read member; create: activeMember (requesterUid==auth); update/delete: false
- L126 devices/{deviceId}: read: member()&&deviceId in member.devices? (check); create: parent w/ ownerUid==primary check; update/delete: parent; sub: notification_tokens (blocked write), enforcement_status (activeOwnedDevice write, child read own), usage_summaries (activeTokenDevice)
- L159 incidents/{incidentId}: create: (a) activeMember && data.familyId==familyId NO deviceId bind [BUG A] (b) activeOwnedDevice; update: parent; delete: false
- L174 sos: same two branches [BUG A]
- L187 locations/{locationId}: read: parent; create: activeOwnedDevice(familyId, request.resource.data.deviceId) && data.familyId==familyId → evaluation error L189 [BUG B]
- L192 messages: member read/create/update, parent delete
- L193 sync_events: read parent, create member w/ authorUid==auth
- L194 notification_events: read parent, all writes false

## BUG A fix plan
Replace branch (a) `activeMember(familyId) && request.resource.data.familyId == familyId` in both incidents and sos with a device-bound branch: `activeOwnedDevice(familyId, request.resource.data.deviceId) && request.resource.data.familyId == familyId && request.resource.data.deviceId != null`.
BUT: incidents may be parent-reported without a device (app contract may not always include deviceId). Check app payload: search what app writes to incidents — look at FirestoreMutation builders for incident.created.

## BUG B fix plan
The evaluation error occurs because activeOwnedDevice does `get()` on the device path before `exists()` short-circuits? No — devices/{deviceId} exists via exists() first. Actual L189:26 points INSIDE activeOwnedDevice at `.data.status == 'active'` — but exists() guarded. Alternative: the error is because request.resource.data.deviceId is evaluated when missing field → `request.resource.data.deviceId` on a doc lacking deviceId throws → rule evaluation fails. FIX: require `request.resource.data.deviceId is string && request.resource.data.deviceId != ''` before the helper OR make helper defensive with `get().data.keys().hasAll(['status'])`. Also add explicit invalid-payload deny branch: `allow create: if invalid;` style: split into two allow lines: one for valid (returns true) and rely on default deny.

## GAP C rules plan
Collections: tasks, task_completions, rewards, reward_claims, reward_ledger, family_rules.
App contract (from firestore_contracts.dart L85-110):
- tasks: parent writes, child reads own (via assignedTo? check app payload fields: assignedToChildId, status)
- task_completions: child writes own (taskId references their assigned task), parent manages
- rewards: parent writes, child reads catalog
- reward_claims: child requests, parent approves
- reward_ledger: parent/admin only (append-only?)
- family_rules (FS-011): parent manages, child/spouse read own-rules view
Check contract field names before writing tests.

## CURRENT RULES SNAPSHOT (L126-200, exact text) — needed for edits
devices/{deviceId}: read member; create parent&&ownerUid==auth&&memberUid==null&&status active; update parent owner-locked; delete owner; subcollection rules unchanged.
incidents/{incidentId}: read parent; create: (a) activeMember && data.familyId==familyId [NO deviceId — BUG A] || (b) activeOwnedDevice(familyId, data.deviceId); update parent; delete owner.
sos/{sosId}: read parent; create: (a) activeMember && data.familyId==familyId || (b) data.deviceId is string && activeOwnedDevice(familyId, data.deviceId); update parent; delete false.
locations/{locationId}: read parent; create: activeOwnedDevice(familyId, data.deviceId) [BUG B: evaluation error L189]; update/delete owner.
messages: read/create/update member, delete parent.
sync_events: read parent, create member && authorUid==auth, update/delete false.
notification_events: read parent, writes false.

## App payload fields per collection (from contracts)
- incident.created: incidentId, category, severity, confidence?, source?, observedAtClient?, modelVersion?, deviceId? (OPTIONAL — if payload['deviceId']!=null), actorUid? → BUG A fix must handle OPTIONAL deviceId: activeOwnedDevice path requires data.deviceId is string; member branch keeps activeMember for parent-side reports BUT must add actorUid==auth? No — keep activeMember (parent observation) but ADD device binding: require data.deviceId is string && device activeOwnedDevice OR actorUid==auth? Keep semantics: branch a = parent observation → keep activeMember + familyId (documented design); BUG A fix = ADD deviceId binding ONLY to the member branch too OR document. DECISION: keep activeMember branch but require request.resource.data.deviceId is string && activeOwnedDevice — i.e., ALL incident writes must be device-bound. BUT incident.acknowledged updates: update if parent — fine.
  - CONFLICT: app comment says "deviceId — required by Firestore activeOwnedDevice rule" but payload optional. For BUG A fix we'll require deviceId. Check incident.created builders: location_remote_service? grep incident.created sources.
- family.rule payload fields: ruleId, kind, name, summary, enabled, startMinute, endMinute, scheduleKind, weekdays, oneshotAt, assignedChildIds, categoryTargets, appTargets, priority, action, createdAt, updatedAt, syncState + common (eventType, familyId, idempotencyKey, actorUid)
- family.task fields: taskId, title, description, dueMinute, dueDate, recurrence, weekdays, assignedChildIds, linkedRuleId, status, createdByMemberId, createdAt, updatedAt, syncState + common
- task completion (eventType family.task.completion): taskId, childId, action, actorMemberId, requestedAt, completedAt, declinedAt, note + common. NOTE: childId is payload (the child the task belongs to). path idempotencyKey-childId.
- family.reward: rewardId, name, description, costPoints, expiryDays, enabled, createdByMemberId, createdAt, updatedAt, syncState + common
- family.claim: claimId, rewardId, childId, costPoints, decision, decidedBy, requestedAt, decidedAt, note + common. operation 'requested' (child) vs 'decided' (parent).
- family.reward ledger: childId, delta, reason, referenceId, balanceAfter, actedBy, actedAt + common
- web payloads: web.hit (child-device writes), web.domain/web.category rules (parent), web.domain.updated/removal (parent)
- geofence.created/updated/disabled: parent-written (location_repository) — contract L799-860; favorite_places parent.
- monitoring_shots: device-written (child device evidence) via activeOwnedDevice; parent read; sessions/requests/schedules: parent; evidence: parent read.

## GAP E DECISION (approved by investigation)
Add rules for: geofences, favorite_places, location_settings, web_hits, web_domains, web_category_rules, web_settings, app_policies, app_allowlists, app_block_events, usage_alert_settings, monitoring_shots, monitoring_sessions, monitoring_requests, monitoring_schedules, monitoring_evidence, mode_configs, mode_activations.
Pattern per phase docs (GAP E = investigate BEFORE adding; findings show active sync paths):
- geofences/favorite_places/location_settings/app_policies/app_allowlists/web_domains/web_category_rules/web_settings/mode_configs/monitoring_requests/monitoring_schedules: read member; write parent (config = parent-authored).
- monitoring_shots/monitoring_evidence: read parent; write activeOwnedDevice.
- monitoring_sessions: parent write/read.
- mode_activations: read member; write: requested by device (activeOwnedDevice, childId==auth?) — simpler: write parent; device-bound request branch optional. Use: create if parent(familyId) or activeOwnedDevice w/ state requested.
- web_hits: read parent; write activeOwnedDevice (data.deviceId).
- app_block_events/usage_alert_settings: read parent; write activeOwnedDevice? usage_alert_settings is parent config → parent write. app_block_events = device event writes (activeOwnedDevice).
- notification events + device_pairings stay denied (existing).

## TEST PLAN for suite updates
1. Fix stale seeds in firestore.rules.test.mjs: expiresAt seeds must be far future (2030-01-01 like suite) + complete device/member fixtures.
2. Add remediation tests to firestore.rules.verification.mjs:
   - BUG A: revoked-device member cannot create incident/SOS without device binding; parent w/ actorUid can (if we keep parent branch) — verify behavior after fix.
   - BUG B: active owned device CAN write location (allowed); missing deviceId denied cleanly; unknown deviceId denied.
   - GAP C: tasks — parent creates (allowed), child creates (denied), child reads? family tasks read member; child writes task_completions own childId (allowed), other child denied; parent manages. rewards — parent create allowed, child denied; child reads rewards (member); claim — child request own allowed (childId==auth via member?), parent decide; ledger — parent only. family_rules — parent CRUD allowed, child/spouse read allowed, child write denied.
   - GAP E: geofences parent write/read, child denied; web_hits device write allowed parent read; monitoring_shots device write allowed; mode_configs parent write; monitoring_sessions parent.
3. Keep report doc in docs/00_master/FIRESTORE_RULES_VERIFICATION_REPORT.md unchanged (delivered).

## SMOKE DIAGNOSIS (round 1→2)
Smoke script results (fixed rules + familyId-seeded device): device-bound creates ALL denied with evaluation error, while parent creates work. Suspect: the rules' `data.keys().hasAll(['deviceId'])` guard — when deviceId is present in the write, the error persists, meaning the error comes from deviceStatus(): exists() on device path... BUT device doc was seeded. Wait — the error says "for 'create' @ L231" etc. The device-bound create evaluates deviceBoundEvent → data.keys() OK → activeOwnedDevice → deviceStatus(familyId, deviceId): exists() + get().data.familyId == familyId. If device doc exists w/ familyId, OK. The remaining failures include ledger parent create (uses parentId only) — but ledger parent create PASSES in run 1? In this run ledger parent create FAILED (run-to-run: stale emulator state). The emulator DB retains stale data across smoke runs; restart emulator for determinism. ALSO note: parent writes incidents w/ deviceId dev-child-a denied correctly (primary-a doesn't own device) — correct behavior, adjust smoke label.

## STATUS
- Phase 1 done (investigation). Phase 2: edit firebase/firestore.rules (BUG A+B).
- flutter analyze clean 0/0 at HEAD (7e21248 committed). 4 lib files still uncommitted (warning fixes): lib/application/guardian_ai_engine.dart, lib/data/family_event_registry_repository.dart, lib/domain/family_authorization.dart, lib/domain/guardian_ai_models.dart — ALSO uncommitted: docs/00_master/FIRESTORE_RULES_VERIFICATION_REPORT.md, firebase/tests/REMEDIATION_EVIDENCE_LOG.md
- Regression cmd: /opt/flutter/bin/flutter test $(ls test/*.dart | grep -v headless_validation | grep -v test_database)
- Emulator: firebase emulators:start --only firestore --project guardian-eye-emulator (port 8080), run suite: cd firebase/tests && node --test firestore.rules.verification.mjs
- Prior successful runs: 20/20 (3 consecutive).

## SMOKE ROUND 3 STATE (after fixes)
- FIX applied to rules: deviceStatus() removed; activeOwnedDevice & activeTokenDevice inline: signedIn && deviceId is string && deviceId != '' && exists(device) && device.familyId == familyId && device.status == 'active' && device.memberUid == auth (the 'Type error. Received:[string] Expected:[bool]' was the deviceStatus() third operand returning a string inside an && chain — fixed by comparing inside each &&).
- data.keys().hasAll(['deviceId']) guard in deviceBoundEvent remains.
- Seed issue found earlier: device docs MUST include familyId field (add 'familyId' to all seeded devices in tests).
- Smoke labels adjusted: parent writing incidents w/ child's device should DENY (correct) — smoke expects deny; child-a writing with deviceId dev-a ALLOWED.
- Smoke results before deviceStatus fix: 21 ok / 8 fail (all device-bound creates failed). Expect all PASS after fix on fresh emulator.
- Remaining to do: re-run smoke, then update firestore.rules.verification.mjs (add remediation tests: incidents/sos device-binding, locations BUG B, GAP C tasks/completions/rewards/claims/ledger/family_rules, GAP E geofences/web_hits/web_domains/monitoring_shots/mode_activations/app_block_events/app_policies), fix stale seeds in firestore.rules.test.mjs (expiredAt seeds → far future; add familyId to device seeds), run full verification suite (need fresh emulator), flutter analyze, regression, then commit everything (rules + tests + evidence log updates; ALSO pending: 4 lib warning-fix files + FIRESTORE_RULES_VERIFICATION_REPORT.md) and report.

## DETERMINISM FINDING
The 7 "failing" cases in this run (location/completion/ledger/web_hit/monitoring_shot/mode_activation/app_block_event device writes) are IDENTICAL to the ones that passed in the previous run against the same rules + same seed. The emulator does NOT reset its database between runs and leftover docs interact with rule side effects (e.g., parent() evaluation caching / get() reads). RULE OF RECORD: always kill the emulator and start a FRESH instance (new project dir) before each suite run, or pass --export-on-exit to inspect. The verification suite file itself should document: `firebase emulators:start --only firestore --project X --export-on-exit` not needed; instead kill+restart each time. For the final evidence run: pkill emulator, sleep 2, nohup start, sleep 16, run suite. Fresh emulator = empty DB.

## PROGRESS STATE (post-suite-extension)
Rules file: firebase/firestore.rules fully remediated — BUG A (incidents/SOS/locations via deviceBoundEvent), BUG B (activeOwnedDevice inline w/ exists guard + familyId cross-check + string id guard), GAP C (tasks, task_completions, rewards, reward_claims, reward_ledger, family_rules), GAP E (geofences, favorite_places, location_settings, web_hits, web_domains, web_category_rules, web_settings, app_policies, app_allowlists, app_block_events, usage_alert_settings, monitoring_shots, monitoring_sessions, monitoring_requests, monitoring_schedules, monitoring_evidence, mode_configs, mode_activations). No deviceStatus() helper (removed — caused Type error).

Verification suite firestore.rules.verification.mjs UPDATED: new tests — 'remediation BUG A', 'untrusted device: locations writes (remediated BUG B)' (assertSucceeds for active device + denies), FS-007 tasks, FS-008 rewards/ledger/claims, FS-011 family_rules, GAP E sections (geofencing, web filtering, app usage, monitoring, modes). Old sections 7 (gap-documented) replaced by these.

Smoke result on fresh emulator: 30 ok / 0 fail (smoke_remediation.mjs).

REMAINING: (1) fix stale seeds in firestore.rules.test.mjs (original legacy suite) — expiredAt seeds must be Timestamp SEED_FUTURE (2030) + device docs missing familyId if used; verify legacy suite still passes against remediated rules; (2) run full verification suite on FRESH emulator (kill+restart before run — emulator does NOT reset DB between runs; deterministic fresh runs required); (3) flutter analyze (expect 0 errors after warning fixes — files already edited), regression tests; (4) commit: firebase/firestore.rules + firebase/tests/* changed/new + the 4 lib warning-fix files + docs/00_master/FIRESTORE_RULES_VERIFICATION_REPORT.md + REMEDIATION_EVIDENCE_LOG.md (decide: commit report? user said commit only evidence in last turn; this turn asks to report every changed file — commit all remediation files except the delivered verification report? Safer: commit rules + tests + evidence log; leave report.md untracked? User said 'Update the emulator tests, including the stale test seeds, then run...' — commit the remediation batch as one checkpoint with clear message; deliver report separately as attachment). 
Emulator control: pkill -f "firebase emulators" alone; start: nohup firebase emulators:start --only firestore --project guardian-eye-emulator >/tmp/emulatorX.log 2>&1 & sleep 16
Suite run: cd firebase/tests && timeout 180 node --test firestore.rules.verification.mjs 2>&1 | tail -5

## LEGACY SUITE (firestore.rules.test.mjs) SEED FACTS — needs fixing for remediated rules
Seeds at L10-20 use family 'family-a'/'family-b' WITHOUT familyId field on devices (L16-17: device-a, revoked-a) → activeOwnedDevice's new familyId cross-check FAILS → legacy incident/device tests will now DENY when they expect success. MUST add familyId: 'family-a'/'family-b' to seeded devices. L13 family doc missing familyId field? L12 setDoc families/family-a {ownerUid,status} — no familyId. memberDoc L13 missing familyId too. member() uses /members/$(uid) so member docs OK (IDs == UIDs here). activeMember OK without familyId field.
L51 invitationData default expiresAt = 2026-08-20 — TODAY is 2026-08-20/21 (user TZ Aug 21) → request.time > expiresAt → invitation create test L103 'parent can create valid invitation' will FAIL (expiresAt must be in future). Fix: default expiresAt = 2030-01-01.
Legacy tests to expect-after-fix: 'active device can create incident' (L185) — incident payload {familyId, deviceId, status} — matches deviceBoundEvent (familyId, deviceId string, activeOwnedDevice) → should SUCCEED with fixed seeds. enforcement_status/usage tests unchanged (they don't use familyId cross-check). token test OK.
NOTE: legacy suite family docs lack familyId field — deviceDoc must carry familyId manually in seed (the device doc's familyId is what activeOwnedDevice reads).

## INTERMITTENT-FAILURE ROOT CAUSE (VERIFIED PATTERN)
Runs against the SAME emulator instance produce different pass counts (27/27 with smoke; then 19/27, 24/27, 19/27 with the suite). The suite's tests run CONCURRENTLY (node:test default) and share one Firestore DB. Tests 15-17 and 23-26 contain multi-step flows (create, read, update with merge, deny checks) whose intermediate docs collide or whose revoked-member toggle (test 11 writes revoked member then restores async) interacts with concurrent reads. FIX: run the suite with --test-concurrency=1 (Node 20+) OR mark all tests { concurrency: false }. Use --test-concurrency=1 on the node CLI: `node --test --test-concurrency=1 file.mjs`.

## DEEP DIAGNOSIS (sequential failures, fresh emulator)
Pattern across runs: first assertion in tests 15/16/17 (task create, reward create, rule create) fails with 'evaluation error at L230/L249/L295:26 for create'. These lines are the UPDATE rules of the previous/current match — the rules engine reports evaluation errors per condition in the allow expression even from sibling branches. L230 = task_completions UPDATE. Test 15's task create runs; the task's OWN update isn't evaluated for create. The reported line may be offset by my edits. ACTUAL suspect: evaluation error for 'create' @ reported line may belong to a DIFFERENT earlier branch (evaluation errors listed for whole request).
CRITICAL INSIGHT: my deviceBoundEvent/data.keys().hasAll guard works for incidents (smoke passes); but tasks create has NO hasAll guard and requires data fields; evaluation error means one field access failed: `request.resource.data.status is string` — if status missing → fine (false). The error points at the rule clause's get: parent(familyId) → get /members/parent-a → EXISTS in before() seed.
WAIT — the seed members have NO familyId field. activeOwnedDevice's device docs: the new smoke seed included familyId in devices and passed. The verification suite seed: devices DO have familyId (smoke passed with them). Members lack familyId — activeMember/member don't need it.
REAL DIFFERENCE between smoke (PASS) and suite (FAIL): suite runs 27 tests; test 11 temporarily REVOKES member /members/child-a via withSecurityRulesDisabled, then restores. BUT the restore writes doc ID /members/child-a while the rest of the suite reads /members/mem-* IDs! After restore, /members/child-a exists (active) + /members/mem-child-a exists (active). For parent-a: /members/parent-a exists → parent() works. Tests 15-17 fail even in run 1... unless test 11 RUNS CONCURRENTLY and revokes child-a mid way — tests 15-17 use parent-a context, not affected by child-a revoke. Hmm — BUT withSecurityRulesDisabled in test 11 is async — the revoke/restore happens while other tests execute. parent-a isn't child-a. No effect.
NEXT: reproduce with just tests 15+16 isolated on fresh emulator.

## ROOT CAUSE CONFIRMED
repro_gapc.mjs on a FRESH emulator: 10/10 PASS — the remediated GAP C rules are correct. The verification suite failures ONLY occur when the emulator instance carries leftover documents from an earlier suite run. node --test on the same DB reuses state; the emulator does not reset between runs. VERIFIED FIX: kill the emulator and start a brand-new instance before every suite run. All 30 smoke cases and 10 repro cases passed on fresh state. The suite's own design (shared seed + sequential test()) requires a fresh DB per run.

## DEFINITIVE DIAGNOSIS OF THE LAST 3 FAILURES
1) Test 11 (revoked member) @ line 263: `assertFails(setDoc(...incidents/forged {familyId, deviceId: dev-child-a}))` — expected fail but SUCCEEDED. Why? The revoked overwrite at /members/child-a happened via withSecurityRulesDisabled, BUT the device-bound create uses activeOwnedDevice (device doc) not member status... The test writer context is child-a; the device dev-child-a is active and memberUid == child-a → ALLOWED even though the member was revoked. Under my BUG A fix, safety writes are device-bound, not member-status-bound — so a revoked member CAN still write via their active device. That contradicts my expectation. FIX the RULE: deviceBoundEvent should ALSO require activeMember (member status check) — revoked members lose ALL write access. Update deviceBoundEvent to require activeMember(familyId) && activeOwnedDevice(...).
2) Test 16 rewards: 'evaluation error at L262:26 for create' — the child claims create at L262-272 is an OR with parent branch `request.resource.data.decision in [...]` — when the child writes a claim, the FIRST branch (activeOwnedDevice) should match; the engine still reports evaluation error from the SECOND branch because `decision` missing on child payload → Property undefined error makes the whole expression an evaluation error? In Firestore rules, OR branches short-circuit: if the first branch is TRUE, second not evaluated. BUT evaluation errors are collected... Actually when child writes claim with no decision, branch1: activeOwnedDevice(familyId, data.deviceId) — claim payload must include deviceId. My test payload DOES include deviceId: 'dev-child-a'. branch1 should evaluate: familyId match ✓, deviceId string ✓, activeOwnedDevice → signedIn ✓, deviceId string ✓, exists ✓, familyId ✓, status active ✓, memberUid == child-a ✓ → TRUE. So the create should succeed. Yet error says evaluation error for create. REASON: The engine evaluates the whole OR expression's conditions — when computing `request.resource.data.decision in ['approved','declined']` on a doc lacking decision → Property undefined → evaluation error. Firestore rules engine reports it even when another branch is true (known behavior: all expressions are evaluated; evaluation errors make the entire statement fail). FIX: guard each branch's field accesses: make the parent branch start with `request.resource.data.decision is string &&` and the child branch start with field guards; for claims child create: activeOwnedDevice && data.familyId == familyId && data.claimId == claimId && data.decision == null — but device-bound child writes include deviceId; and decision null means the child payload must have decision field. My test payload for child claim create lacks decision → branch1 `data.decision == null` needs decision present. Simpler: rewrite the two branches as: (branch1: activeOwnedDevice && deviceId string && data.decision == null → child request) OR (branch2: parent && data.decision is string → parent decision). Then each branch guards its own fields.
3) Test 17 family_rules: update with {} empty merge at the end (`setDoc(..., {}, {merge:true})`) — update rule requires request.resource.data.familyId == resource.data.familyId etc.; {} missing familyId → Property undefined. My test expectation was wrong: an empty merge SHOULD be denied. FIX the TEST: remove the final empty-merge assertion or expect failure.

## FIXES TO APPLY (final)
A) deviceBoundEvent in firebase/firestore.rules L41-46: add activeMember(familyId) requirement → revoked members cannot write device-bound events:
`return activeMember(familyId) && data.familyId == familyId && data.keys().hasAll(['deviceId']) && data.deviceId is string && data.deviceId != '' && activeOwnedDevice(familyId, data.deviceId);`
B) reward_claims create L262-272: guard each OR branch's own fields to prevent Property undefined evaluation errors:
branch1 (child request): activeOwnedDevice(familyId, request.resource.data.deviceId) && request.resource.data.familyId == familyId && request.resource.data.claimId == claimId && request.resource.data.decision == null && request.resource.data.decidedBy == null
branch2 (parent decision): parent(familyId) && request.resource.data.familyId == familyId && request.resource.data.claimId == claimId && request.resource.data.decision is string && request.resource.data.decision in ['approved','declined'] && request.resource.data.decidedBy == request.auth.uid
C) Test 17 FS-011 family_rules: last two assertions (merge-with-empty-data update + delete {}) — update with {} denied by current update rule (fine behavior: deny). Change final setDoc(..., {}) to expect failure (assertFails), keep delete parent success if rule allows (update/delete: if parent && resource.familyId == familyId — delete succeeds w/o field checks). Actually rule: allow update: if parent && resource.data.familyId==familyId && request...familyId==resource && request.ruleId==resource.ruleId — empty merge lacks familyId → denied (expected false); delete: if parent && resource.familyId==familyId → succeeds. Fix: change the merge-empty-data assertion to assertFails.
D) Task_completions create (L228-237) has same OR without field guards: child branch: activeOwnedDevice(...) && familyId && action=='requested'; parent branch: parent() && ... action in [completed,declined]. When child writes with action=='requested', parent branch evaluates `action in [...]` → false (fine, no undefined). But when child writes action missing → action==null → first branch data.action=='requested' false; second branch action in list false. No undefined → OK. When parent writes completed with no deviceId → branch1: activeOwnedDevice(familyId, data.deviceId) where data.deviceId undefined → activeOwnedDevice L21 guards deviceId is string → false, no error. OK. The test 15 failures in logs were actually from the SAME emulator-leftover + memberDoc mismatch? Repro passed 10/10. So no rule change needed for tasks/completions. But for consistency/robustness add `request.resource.data.action is string` guards: branch1: ... && request.resource.data.action is string && request.resource.data.action == 'requested'; branch2: ... && request.resource.data.action is string && ... in [...].
E) After A+B+D, re-run: kill emulator, fresh start, suite; also legacy suite (with fixed seeds: device familyId, invitation expiresAt 2030, expired test date 2020); then flutter analyze + regression; then commit batch: firebase/firestore.rules, firebase/tests/firestore.rules.verification.mjs, firebase/tests/firestore.rules.test.mjs, firebase/tests/firestore.rules.verification.mjs updated, lib edits (4 warning-fix files), docs/FIRESTORE_RULES_VERIFICATION_REPORT.md + REMEDIATION_EVIDENCE_LOG.md. Decide commit set at the end: commit rules + tests + lib fixes + evidence log + report? Deliver report + commit hash.
F) smoke_remediation.mjs also needs update: test 11 'revoked member reads' incidents denied still fine (member revoked → activeMember false → deviceBoundEvent false). Smoke's incident missing-deviceId cases unaffected. The revoked device cases unaffected. Smoke should still pass after A.
G) Known env quirk documented: emulator keeps DB between runs → ALWAYS kill + restart fresh before each suite run. Add a note to the suite header and evidence log.

## FINAL RUN RESULTS (after contract alignment fixes)
Verification suite on fresh emulator: **27/27 PASS**. Legacy suite (with fixed seeds: device familyId fields, invitation expiresAt 2030, expired test date 2020) on same instance: **15/15 PASS**.
Contract-alignment changes made:
- deviceBoundEvent now requires activeMember(familyId) (revoked members cannot write device-bound events from their still-active device).
- task_completions create: child branch uses active member + childId == own memberId (no deviceId — contract has none); parent branch action in [completed, declined].
- reward_claims create: child branch requires childId == own memberId and NO decision/decidedBy; parent branch requires decision is string + in [approved, declined] + decidedBy == uid.
- family_rules update with empty {} correctly denied (test expectation fixed to assertFails).
- Test expectations aligned: child claim uses childId; parent merge-decision succeeds; self-decide attempts denied; child cannot forge another child's claim or self-review a completion.

## CURRENT STATE (pre-commit)
Flutter analyze: 0 errors, 0 warnings (455 info-level pre-existing).
Regression suite: RUNNING (log /tmp/regression3.log) — reached +318 at 00:24, baseline is 432. Parse with /home/ubuntu/parse_regression.py.
Files ready to commit (git status clean except): firebase/firestore.rules (remediated), firebase/tests/firestore.rules.test.mjs (legacy seeds fixed), firebase/tests/firestore.rules.verification.mjs (contract-aligned), lib: 4 warning-fix files (guardian_ai_engine, family_event_registry_repository, family_authorization, guardian_ai_models), docs/00_master/FIRESTORE_RULES_VERIFICATION_REPORT.md, firebase/tests/REMEDIATION_EVIDENCE_LOG.md.
Remaining steps: (1) confirm regression 432 green via parse script; (2) commit all above with message feat(firestore): remediate rules bugs and gaps (local only); (3) deliver final report with allowed/denied matrix + commit hash; STOP. Do NOT push unless user asks. Do NOT deploy rules.
