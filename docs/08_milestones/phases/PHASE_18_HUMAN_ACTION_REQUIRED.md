# Phase 18 — Human Action Required

**Project:** Guardian Eye Pro · **Author:** Manus AI · **Date:** August 13, 2026

The following actions cannot be completed in the sandbox environment and require human execution. Each item includes exact steps, expected outcomes, and the verification evidence to collect.

## 1. Physical Device / AVD Validation (HIGH PRIORITY)

**Why required:** `flutter devices` in the sandbox reports no connected Android device or AVD. All Phase 18 behavior is evidenced at unit/widget/emulator level only; runtime rendering on a real Android device is not evidenced.

**Steps:**

1. Connect an Android device (USB debugging) or start an AVD on your workstation.
2. Install the existing debug APK: `build/app/outputs/flutter-apk/app-debug.apk` (~172 MB, `com.guardianeye.app`).
3. Sign in with the Firebase Auth account **24160037@su.edu.ye** (linked to `manus-guardian`) on a **parent/co-parent** member role.
4. Verify on the dashboard: family name renders; actor resolves as verified; `can()` gates (policies, devices, exceptions) behave per the role matrix; pull-to-refresh refreshes the canonical context.
5. Sign in as a **child** member role. Verify: the isolation view renders, every management action is disabled, and the actor is not verified.
6. Sign in with an account that has **no membership** in the family. Verify: closed/unverified dashboard view.
7. Verify device screens: the child device shows its owner (child member), active state, and correct family scope; revoke the device in a parent session and confirm the device closes; set a child device `offline` and confirm it stays enrolled.

**Expected outcome:** dashboard and device screens render with the canonical context; fail-closed behavior matches the 7 new unit tests.

**Evidence to collect:** screenshots of the three sign-in scenarios, a short screen recording of the revocation/offline transitions, and the device/AVD model details.

## 2. Production Firebase Validation

**Why required:** All emulator coverage (17/17 tests) targets the synthetic project `guardian-eye-emulator`. Production `manus-guardian` was deliberately not targeted (no deployment, no Blaze, no production writes per project rules).

**Steps (read-only only):**

1. Sign in on a physical device with **24160037@su.edu.ye** against the production app.
2. Confirm the account resolves to its family and role in the production UI (read-only observation).
3. Optionally, with Firebase Console access, confirm the `manus-guardian` project shows the expected Android app (`1:165160049292:android:922e6c8a4749c42e4839a9`, `com.guardianeye.app`) — this was already verified read-only in Phase 17.

**Do NOT:** deploy functions/rules, enable Blaze, create resources, or write to production Firestore from the sandbox.

**Evidence to collect:** confirmation that the production account resolves to the expected family/role, and any production-specific issues observed.

## 3. Optional Extended Validation

- Run the full production suite on CI with a real Firebase project credential (outside this sandbox) if remote outbox delivery needs validation.
- Re-run `flutter build apk --release` on your workstation to obtain a signed APK for distribution testing.

## 4. Completion Criteria for This Document

Mark this document closed when: (a) all three sign-in scenarios of §1 are evidenced with screenshots, (b) revocation/offline transitions are evidenced, and (c) production account resolution is confirmed or explicitly waived. Until then, Phase 18's final gate remains **GREEN with HUMAN ACTION REQUIRED items outstanding** (see `PHASE_18_COMPLETION_REPORT.md`).
