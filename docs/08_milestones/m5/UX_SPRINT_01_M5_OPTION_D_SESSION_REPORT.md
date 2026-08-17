# M5 Option D — Session Report (Implementation + Verification Status)

Status: **IMPLEMENTED + locally verified. Real-device gate IN PROGRESS.**
No code pushed yet (working tree holds the full Option D change set).

---

## 1. What was implemented (Owner-approved Option D)

### Canonical architecture (as approved)
```
Parent addChild() → local SQLite child profile → NO remote member.created
Parent issues trusted provisioning (callable) → device_pairings session
Child authenticates → redeemChildDeviceProvisioning() (callable)
Trusted backend atomic transaction:
    create families/{familyId}/members/{childUid}   (document ID = child UID)
    create families/{familyId}/devices/{deviceId}   (memberUid = childUid, ownerUid = parent)
    mark provisioning session enrolled
Child actor verification succeeds → child context unlocks
```

### Files changed (tracked, not yet committed)

| File | Change |
|---|---|
| `firebase/functions/src/index.ts` | `createChildDeviceProvisioning`: removed the "remote child member must pre-exist" precondition; now carries `displayName`; keeps parent-role auth, SHA-256 code hash, 10-min expiry, pending state, attemptCount, issuedByUid. `redeemChildDeviceProvisioning`: removed `target_missing`; in one `runTransaction` creates UID-keyed `members/{childUid}` (role=child, memberUid=childUid, memberId=targetMemberId) + `devices/{deviceId}` + marks session `enrolled`; idempotent single-use; wrong code → `permission-denied pairing_invalid_code`; 5 failures → locked; expired → `failed-precondition pairing_expired`; replay of enrolled session → `failed-precondition`. |
| `firebase/functions/lib/index.js` | Compiled output (tracked in repo) — regenerated from the above. |
| `firebase/functions/test/functions_emulator.test.mjs` | Issuance now tested WITHOUT a pre-existing remote child; redemption asserted to create the UID-keyed member + device; duplicate-redemption idempotency test fixed (redeem once, then assert second redeem rejected); wait timeout raised 10s → 20s for slow Windows emulator cold starts. |
| `lib/data/guardian_repositories.dart` | `addChild` no longer enqueues a syncable `member.created` outbox op (local-only child). Added `PairingRepository.recordRemoteEnrollment` to mirror a server-confirmed enrollment into SQLite (no outbox op — delivery already confirmed server-side). |
| `lib/data/firestore_contracts.dart` | `member.created` now throws `FormatException` (defense-in-depth: a legacy child-role op can NEVER reach the remote writer). |
| `lib/application/remote_provisioning_service.dart` | NEW — thin client over the two Functions callables (`issue` / `redeem`), never writes Firestore itself; `RemoteProvisioningUnavailableException` when Firebase unconfigured → local SQLite fallback. |
| `lib/application/guardian_providers.dart` | `remoteProvisioningServiceProvider` added. |
| `lib/presentation/screens/pairing_screen.dart` | Parent issuance prefers the remote callable (QR/deep link carries the REMOTE pairingId); falls back to local SQLite pairing when Firebase unavailable. |
| `lib/presentation/screens/child_redemption_screen.dart` | Child redemption prefers `redeemChildDeviceProvisioning`; on success calls `recordRemoteEnrollment`; maps server errors honestly (invalid code / expired / locked / already used); local fallback preserved. Stable per-screen deviceId for idempotent retries. |
| `lib/core/firebase/guardian_firebase_bootstrap.dart` | `useFunctionsEmulator(host, 5001)` wired for emulator mode. |
| `pubspec.yaml` / `pubspec.lock` | `cloud_functions: ^6.3.6` added (pairs with pinned firebase_core ^4.x; toolchain freeze respected — no other dependency changed). |
| `test/local_repository_test.dart` | Updated: after `createFamily` + `addChild` the outbox holds **1** row (only `family.created`), not 2. |
| `test/m5_child_identity_option_d_test.dart` | NEW — 6 tests: local child created, no remote `member.created` enqueued, pending-sync count unaffected, `recordRemoteEnrollment` semantics, writer rejection of child-role ops. |
| `firebase/tests/real_backend_validation.mjs` | Corrected the contradictory assertion: direct parent child-member write now expects **403 denied** (`child_member_write_denied`) instead of 200 — matches the deployed rules and Option D. |

### Security invariants preserved
- Parent client can never create `members/{childUid}` or `members/{randomLocalUuid}`.
- Parent never chooses the child UID; `memberUid` comes only from `request.auth.uid` at redemption.
- Firestore rules: **NOT touched** (no loosening).
- Adult invitation flow (parent/coParent self-accept) unchanged.
- M9 outbox/sync architecture unchanged (no second sync engine).
- No WorkManager / Trigger D changes; no M8 changes; no dependency upgrades beyond `cloud_functions`.

---

## 2. Verification results (this session)

| Gate | Result |
|---|---|
| `tsc` (Functions) | GREEN |
| `flutter analyze` | GREEN — 0 errors/warnings (57 info lints are pre-existing in test files) |
| `flutter test` | **237/237 GREEN** (231 prior + 6 new Option D tests) |
| Functions emulator suite | **3/3 GREEN** (`GCLOUD_PROJECT=manus-guardian node --test firebase/functions/test/functions_emulator.test.mjs` against fresh emulators) |
| Firestore rules emulator suite | **15/15 GREEN** — note: only with `singleProjectMode` OFF; the same suite shows 7 failures when the emulator runs with `--project manus-guardian` + `singleProjectMode:true` because the harness uses project `guardian-eye-emulator`. Rules files untouched by Option D, so this is a pre-existing environment/config artifact, not a regression. |
| `deployed_rules_tests.mjs` | NOT runnable on this Windows machine — it reads `/home/ubuntu/m5_audit/deployed_ruleset_new.json` (original Linux env artifact). Rules unchanged, so the deployed-rules outcome is unchanged. |
| `real_backend_validation.mjs` | Corrected; not executed (it targets the REAL backend — reserved for the device gate). |
| APK build | GREEN — `flutter build apk --debug` with the 4 real-backend defines. |

**Toolchain notes**
- `firebase/functions/node_modules` and `firebase/tests/node_modules` are tracked in git but were shipped from the original Linux env as a partial snapshot (gitignored `build/` outputs missing). On this Windows machine the emulator harness required a clean `npm ci` to restore `build/` outputs and Windows `.cmd` shims. After running the suites, **all tracked node_modules / package.json / package-lock.json files were restored to their committed state** — the working tree contains only the Option D source/test changes (plus pre-existing untracked env artifacts).

---

## 3. Real-device gate — progress

**Device:** SM-S906U (RFCT420YY9B), Android 16 / API 36. **Firebase:** manus-guardian (Spark).

Done:
- Internet restored via WiFi (`..Altharia-net-( 89)@777044170` — ping + DNS OK).
- New APK installed with the full define set:
  `GUARDIAN_ENV=real_backend_validation`, `GUARDIAN_REAL_BACKEND_VALIDATION=true`,
  `GUARDIAN_EMULATOR=false`, **`GUARDIAN_FIREBASE_CONFIGURED=true`** (this 4th define was the missing piece — the first build without it ran with Firebase disabled, which is exactly what the session screen reported: "Firebase غير مهيأ").
- Firebase now **CONFIGURED + AUTHENTICATED** as `alibrother402@gmail.com` (M9Parent session restored).
- SQLite inspected (pulled via `adb exec-out run-as`):
  - Family `3e7a934a-ddb9-419e-8e45-dd542cdd3344` "M9Parent"
  - Primary member `063a1685-…` role `primaryParent`, **account_uid `3P5YoV4iKDasxorHi95AQhfAm9e2`**
  - Children `hh`, `jjg` (local-only)
  - Outbox: `d3bf72cf…` + `9e6128dd…` `family.member.invited` **synced** (M9 proof), plus legacy blocked ops (`member.created` ×2, `policy.override.created` ×4 — all `permission-denied`, honest).

Open items on device:
- Dashboard still shows the **actor-verification banner** ("read-only until verified") — the binding provider likely resolved before the session restore; needs a fresh restart / re-verify to clear.
- Then execute the Option D gate sequence (below).

---

## 4. Next steps (plan)

1. **Re-verify actor** — restart app, confirm banner clears → family management unlocks (proves M9 chain intact on the new build).
2. **Gate A — local child creation:** add a new child via UI → pull SQLite → prove child row exists and **no** `member.created` outbox op (6→ no increase / only local row).
3. **Gate B — remote provisioning:** parent issues via `createChildDeviceProvisioning` → verify `families/{familyId}/device_pairings/{pairingId}` in real Firestore (trusted read) with `displayName`, `codeHash`, pending, 10-min expiry.
4. **Gate C — child redemption:** sign out as parent → sign in as a fresh dedicated child account → redeem the code via `redeemChildDeviceProvisioning` → backend atomically creates `members/{childUid}` (memberUid == childUid, role child) + `devices/{deviceId}` (memberUid == childUid, ownerUid == parent UID) + session `enrolled`.
5. **Gate D — verification:** trusted read of both remote docs; outbox has no child `member.created`; child actor binding succeeds → child context unlocks.
6. **Final verification sweep:** re-run `flutter analyze`, `flutter test`, emulator suites (already GREEN) — then **commit** (focused commits, e.g. `fix(m5): create child identity during trusted device provisioning`) and **push** to `origin/master`, then report exact SHAs + the M5 gate result.

### Environment caveats for the gate
- Emulator suites were validated locally; the deployed-rules harness needs the original Linux env's `/home/ubuntu/m5_audit/deployed_ruleset_new.json` (rules unchanged → outcome unchanged).
- The 4-defines build command is the canonical real-backend build:
  `flutter build apk --debug --dart-define=GUARDIAN_ENV=real_backend_validation --dart-define=GUARDIAN_REAL_BACKEND_VALIDATION=true --dart-define=GUARDIAN_EMULATOR=false --dart-define=GUARDIAN_FIREBASE_CONFIGURED=true`

---

## 5. Final real-device gate results (this session)

### Root cause of Gate-1 failure (account mismatch) — RESOLVED per owner decision
- Persisted Firebase session on the device: `alibrother402@gmail.com` → UID `NY16roLTXWPTm7uLMagUjF9JLdg2`.
- The M9 test family `3e7a934a…` ("M9Parent") is owned by a **different** account: Firestore cache proved `ownerUid = 3P5YoV4iKDasxorHi95AQhfAm9e2`, member doc `members/3P5YoV4iK…`.
- Therefore the actor-verification read `members/{NY16ro…}` was denied (`PERMISSION_DENIED`) — that member doc does not exist in Firestore.
- Owner decision: **fresh test family under the current account** → implemented.

### Fresh family under current account — REAL FIREBASE PROVEN
- Archived the stale local family row (device SQLite only; on-device backup `guardian_eye_pro.db.bak` + local `ge_backup_before_archive.db` kept; **no Firestore data touched**).
- Created family **M5Gate** (`ff70cf2b-0fa7-4919-a1b5-5b617481e467`) through the app UI.
- Outbox `family.created` op `cd36b65b-571f-4389-9878-824dd0e43de0`: **queued → synced** via manual sync (Trigger C). The executor only marks `synced` after `waitForPendingWrites()` confirms delivery.
- **Real Firestore verified via the app's own Firestore cache (trusted read):**
  - `families/ff70cf2b-…` → name `M5Gate`, `ownerUid = NY16ro…`, `primaryParentId = 4cdde269…`, `syncStatus = client_submitted`, idempotencyKey == outbox op id.
  - `families/ff70cf2b-…/members/NY16roLTXWPTm7uLMagUjF9JLdg2` → `memberUid == NY16ro…` (doc key == current UID), role `primaryParent`, displayName `M5Parent`, status `active`.
- **Actor verification after restart: SUCCEEDED** — the read-only banner is gone; Family Management controls (`أعضاء الأسرة`, `إضافة طفل`, `ربط جهاز`) are ENABLED.

### Gate 2 — local child creation, no doomed op: PROVEN
- Created child **KidA** (`360829bc-16b4-453b-8cb9-08262ba6656e`) via UI: local `family_members` row, role `child`, `account_uid = NULL` (local-only).
- Outbox after creation: **only** the synced `family.created` op. **0 new `member.created` ops** since the fresh family.
- Children count tile on dashboard: 0 → 1. KidA shows "لا يوجد جهاز مربوط بعد" (no device linked yet) — honest local-first state.

### Gates B–D — remote provisioning/redeem: **BLOCKED (production plan constraint)**
- Attempted Gate B from the pairing screen (child KidA → "إنشاء رمز ربط").
- App called `createChildDeviceProvisioning` through `cloud_functions` → real backend returned:
  `[firebase_functions/not-found] NOT_FOUND`.
- Root cause: **no Functions are deployed to `manus-guardian`** (`firebase functions:list` → "No functions found in project manus-guardian"), and **deployment is impossible on the Spark plan** — `firebase deploy --only functions` fails because enabling `cloudbuild`/`artifactregistry` APIs requires upgrading to Blaze (explicitly forbidden).
- Therefore the trusted-backend redemption transaction (create `members/{childUid}` + `devices/{deviceId}` + mark enrolled) cannot be exercised against the real backend in this environment.
- The callable implementation itself is fully verified in the **Functions emulator suite (3/3 PASS)** and the Firestore rules suite (15/15 PASS).

### Final verification sweep (this session)
- `flutter analyze` → **0 errors / 0 warnings** (57 pre-existing info-level lints, none in changed files).
- `flutter test` → **237/237 PASS**.
- `flutter build apk --debug` with the 4 real-backend defines → **GREEN**.
- Functions emulator tests → **3/3 PASS**; Firestore rules emulator tests → **15/15 PASS** (needs `singleProjectMode` off — pre-existing env artifact; rules untouched).

### M5 final verdict
**PARTIAL — BLOCKED (HUMAN ACTION REQUIRED for the real-backend redemption gate).**

Proven on real device + real Firestore: local-first child creation (no doomed op), fresh family `family.created` queued → synced, real Firestore family + member docs keyed by the authenticated UID, actor verification + Family Management unlock, analyzer/tests/APK GREEN.

Blocked: remote provisioning issuance + child redemption against real `manus-guardian`, because the plan is Spark and deploying the Option D callables requires Blaze activation — which the task forbids. The code path is correct (emulator-proven); the backend simply has no deployed callables to call.

### Files changed (working tree, NOT committed — per "do not push an unverified implementation")
- Modified: `firebase/functions/src/index.ts`, `firebase/functions/lib/index.js` (compiled), `firebase/functions/test/functions_emulator.test.mjs`, `firebase/tests/real_backend_validation.mjs`, `lib/application/guardian_providers.dart`, `lib/core/firebase/guardian_firebase_bootstrap.dart`, `lib/data/firestore_contracts.dart`, `lib/data/guardian_repositories.dart`, `lib/presentation/screens/child_redemption_screen.dart`, `lib/presentation/screens/pairing_screen.dart`, `pubspec.yaml` (+`cloud_functions: ^6.3.6`), `pubspec.lock`, `test/local_repository_test.dart`
- Added (tracked-worthy): `lib/application/remote_provisioning_service.dart`, `test/m5_child_identity_option_d_test.dart`
- Untracked env artifacts kept out: `.idea/`, `.metadata`, `android/.kotlin/`, `guardian_ai*`, `linux/`, `macos/`, `ui2.xml`, README.md, docs, node_modules shims
