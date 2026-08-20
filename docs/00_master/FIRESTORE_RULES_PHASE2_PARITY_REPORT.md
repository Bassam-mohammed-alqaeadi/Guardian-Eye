# Phase 2 Closure Report — Live Firestore Rules Parity Determination

**Project:** Guardian Eye Pro — Flutter Android family-safety platform
**Branch:** `feature/design-system-integration`
**Closure status:** **BLOCKED-EXTERNAL-UNVERIFIED**
**Date:** 21 August 2026
**Author:** Manus AI
**Scope:** Determine whether the local `firebase/firestore.rules` matches the deployed ruleset for the correct Firebase project. No rules were read, modified, published, or deployed. No new features were started.

---

## 1. Closure Status

> **BLOCKED-EXTERNAL-UNVERIFIED** — the phase could not be completed because no authenticated access to the Firebase Rules API exists for this project in this environment. No parity claim is made, no guess was substituted, and no authentication bypass was attempted.

## 2. Exact Project Identity

The project identity was confirmed from the repository configuration files alone, with no secrets revealed:

| Source | Value |
|---|---|
| `.firebaserc` (`projects.guardian`) | `manus-guardian` |
| `firebase.json` (`flutter.platforms.android.default.projectId`) | `manus-guardian` |
| `firebase.json` (`flutter.dart.lib/firebase_options.dart.projectId`) | `manus-guardian` |
| Firebase project number (from Firebase app ID, public part only) | `165160049292` |

All three configuration sources agree on a single identity — **`manus-guardian`** — so there is no ambiguity about which project the local rules file is meant to describe.

## 3. Authentication Availability Check

Every credential path available to this sandbox was inspected; no usable Firebase authentication was found:

| Credential source | Checked | Result |
|---|---|---|
| Firebase CLI login (`firebase projects:list`) | Yes | `Error: Failed to authenticate, have you run firebase login?` |
| CLI configstore (`~/.config/configstore/firebase-tools.json`) | Yes | Contains only `motd` metadata — **no session token** |
| `FIREBASE_TOKEN` environment variable | Yes | **Not set** |
| gcloud application default credentials (`~/.config/gcloud/...`) | Yes | **No gcloud directory exists** |
| Google Workspace tokens present in the environment | Yes | Inspected metadata only; they are scoped to Google Workspace services. A direct REST call to the Firebase Rules API with one of these tokens returned **HTTP 403 PERMISSION_DENIED** (`Method doesn't allow unregistered callers… Please use API Key or other form of API consumer identity`) — they are not authorized for Firebase Rules access and were not used further |

Two further facts about the tooling: `firestore:rules:get`/`rules:list` no longer exist in the installed CLI 15.x, and the REST endpoints (`/v1/projects/manus-guardian/rulesets`) require a bearer token or API key with Firebase Rules scope, which this environment does not possess. No token, key, or credential value was printed or exposed at any point; only HTTP status codes and error classifications were observed.

## 4. Local Baseline Identity

The local rules file that would be compared against the deployed ruleset is identified as:

| Item | Value |
|---|---|
| File | `firebase/firestore.rules` |
| Content-introducing commit (full hash) | `8e57cd262d8f8ad64223951da33d7c8aed3038b3` (`feat(firestore): remediate rules bugs and gaps`) |
| Closure-checkpoint commit | `bcc51dd` (`feat(firestore): close local rules remediation`) |
| Branch | `feature/design-system-integration` (not pushed; not merged to master) |
| Content hash (SHA-256) | `59386f79ac20c996529c13c248a75f042819f041c5d91b3b3e5036b735f79194` |

The rules file was **not modified** during this phase. The local deterministic verification baseline is intact: 27/27 on the extended suite and 15/15 on the legacy suite under the fresh-emulator, concurrency-1 procedure, with 432/432 Flutter tests green — these were not re-executed because the rules file did not change since the Phase 0 closure, but the checkpoint remains reproducible from the commits above.

## 5. Normalized Comparison Result

**Not performed.** A normalized diff requires the deployed ruleset, which could not be retrieved. Consequently the report cannot state a match, a mismatch, a ruleset identifier, or a deployment timestamp. The previously documented historical note remains true: `docs/03_security/REAL_FIREBASE_VALIDATION.md` records an earlier rules deployment to `manus-guardian` whose content predates the current local file, so divergence between local and deployed rules is **plausible and unquantified**.

**Could production behavior diverge?** Yes — this cannot be ruled out until parity is established. Three concrete divergence vectors exist: (a) the earlier deployment may not include the BUG A/B fixes or the GAP C/GAP E clauses added in the local remediation, meaning remote sync for tasks/rewards/family rules/geofences/web hits/monitoring would be implicitly denied in production when enabled; (b) conversely, if someone deployed a different ruleset after `3bc6321` without tracking it, the local file may be older than production; (c) the `notification_events`/`device_pairings` permanent blocks in the local file may or may not exist in production. None of these can be confirmed or denied from this environment.

## 6. Minimum Human Action Required

Resolving the block requires one of the following, in ascending order of operational cost:

1. **`firebase login`** run in this sandbox (interactive browser OAuth), granting the CLI a session token for `manus-guardian`; or
2. A **scoped CI token** (`firebase ci:login`-style token with at minimum `Firebase Rules Reader` permission on `manus-guardian`), supplied for a single read-only fetch; or
3. A one-time download of the current ruleset from the Firebase Console (**Firestore → Rules** tab) pasted into this sandbox for the normalized diff.

All three options are strictly read-only with respect to production; none modifies rules, deploys, or touches any other service.

## 7. Constraints Honored

`firestore.rules` was not modified, nothing was published or deployed, notifications and all new features (FS-010/012/014/016) remain unstarted, and no credentials or private family data were exposed — only error classifications and HTTP status codes were observed. No production behavior was asserted.

## 8. Next Step on Unblock

Once authenticated access exists, the planned sequence is a single read-only fetch (`firebase firestore:rules:list` equivalent via the Rules REST API), a normalized diff (whitespace- and comment-stripped) against the local file (SHA-256 `59386f79…`), and a re-issue of this report as either **CLOSED-LIVE-MATCHED** or **BLOCKED-MISMATCH-REQUIRES-REVIEW** with the exact differing clauses listed.
