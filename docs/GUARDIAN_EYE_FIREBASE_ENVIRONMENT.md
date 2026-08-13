# Guardian Eye Pro — Firebase Environment

Single environment reference for the project's Firebase footprint. No tokens, private keys, or service-account files are stored in this document or the repository (repository policy: interactive browser login only).

## 1. Project Identity

| Item | Value |
| ---- | ----- |
| Project ID | `manus-guardian` |
| Project name | Manus-guardian-eye |
| Project number | `165160049292` |
| Android app ID | `1:165160049292:android:922e6c8a4749c42e4839a9` |
| Package / applicationId | `com.guardianeye.app` |
| CLI alias (`.firebaserc`) | `guardian` → `manus-guardian` |

## 2. Services Used

| Service | Usage | Notes |
| ------- | ----- | ----- |
| Auth | Real Google sign-in (owner interactive), emulator auth on port 9099 | No custom provider config in repo |
| Firestore | Core data: families, members, devices, policies, overrides, usage_summaries, enforcement_status, invitations, outbox | Rules: `firebase/firestore.rules` |
| Functions | Server-side coordination (codebase `guardian`, source `firebase/functions`, Node 20, tsc build) | Not deployed during sandbox work; emulator only |
| Storage | Bucket configured (`firebase/storage.rules`) | Not yet exercised by app features |
| FCM / Analytics / Crashlytics / Remote Config | SDK present (`pubspec.yaml`) | Wiring deferred to M9 (register GA-03) |

## 3. Billing Plan

Current plan: **Spark (free tier)**. Blaze must remain **inactive** until the owner explicitly activates it (register GA-21, BLOCKED — BILLING). Functions production deployment may eventually require Blaze; no autonomous change is ever made.

## 4. Deployed Rules Expectations

The deployed ruleset as of 2026-08-14 is `e22c310a-c24e-4101-abb7-9df31c57e5cc`. It includes the complete M5–M8 surface: `/families/{familyId}/policies`, `/policy_overrides/{overrideId}`, `/devices/{deviceId}/usage_summaries` (immutable append by child own-device), `/devices/{deviceId}/enforcement_status` (parent reads via `parent()`; child app writes own `current` status), and `/invitations/{invitationId}` (owner reads only). Verify the live id anytime with `firebase firestore:rules:list --project manus-guardian`. New ruleset publishes are one-command, owner-executed, never automatic.

## 5. Emulator Commands

```bash
firebase emulators:start                       # auth:9099 firestore:8080 functions:5001 ui:4000
firebase emulators:exec "./tool/run_firebase_emulator_tests.sh"
node --test firebase/functions/test/functions_emulator.test.mjs   # Functions harness
node firebase/tests/deployed_rules_tests.mjs    # harness against emulators or deployed ruleset
```

The emulator suite uses repo-local rules and functions; it never touches the live project. Emulator artifacts (`firebase/tests/firestore-debug.log` etc.) are log outputs, not evidence to commit.

## 6. Required Manual Login

`firebase login` uses the browser OAuth flow; the owner completes Google sign-in, MFA, and CLI access approval personally. The CLI token lives in the OS credential store (`~/.config/configstore/firebase-tools.json`) and is never committed or shared in chat.

## 7. Production-Only Operations (Owner-Executed)

Publishing rulesets, deploying functions, activating Blaze, creating test users in production, and any data inspection or export are production-only operations. Each requires explicit owner approval before execution and is recorded in the register.

## 8. Test Account Requirements

No pre-created accounts are committed. Test identities flow through the app's own invite/accept mechanism so production contains only family data the owner knowingly creates (register GA-01).

## 9. Data Safety Rules

Emulator runs never target the live project; production writes only occur through the app's own outbox after a real signed-in session (GA-01/GA-02). No Blaze activation, no billing change, and no production data destruction is performed autonomously.

## 10. Rollback Notes

Ruleset rollback: republish the previous ruleset id via `firebase firestore:rules:release <previous-id>` by the owner. Functions rollback: redeploy previous source commit. Firebase CLI rollback: `firebase logout` + re-login. Nothing in this environment is irreversible without the owner's credentials.

## 11. Firebase Asset Classification (mandate §19)

| Item | Classification | Rationale |
| ---- | -------------- | --------- |
| `firebase.json` | COMMIT | Emulator + platform config, no secrets |
| `.firebaserc` | COMMIT | Project alias only |
| `lib/firebase_options.dart` | COMMIT | Owner policy: platform config committed, regenerated only on approval |
| `android/app/google-services.json` | COMMIT | Owner policy, same as above |
| `firebase/firestore.rules` | COMMIT | Source of truth; deployed version verified via harness |
| `firebase/firestore.indexes.json` | COMMIT | Index definitions |
| `firebase/storage.rules` | COMMIT | Storage config |
| `firebase/functions/` (src + lock) | COMMIT | Functions source |
| `firebase/functions/node_modules/` | COMMIT (historical) | Tracked historically; do not commit new changes without owner decision (register GA-26) |
| Service-account JSON / refresh tokens | SECRET — NEVER COMMIT | Not present; never create or download |
| `firestore-debug.log`, emulator UI exports | GENERATED | Log artifacts; ignored/never committed |
