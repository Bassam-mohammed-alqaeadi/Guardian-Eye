# Phase 14 Human Action Required

## Android device validation

1. Produce an APK on an Android build host with sufficient Gradle memory, then record its hash and package metadata.
2. Attach a physical Android device or provision an AVD. Record model, API level, OEM build, and app build hash.
3. Open Guardian Eye Pro as the child identity and explicitly grant or deny **Usage Access** through Android Settings. Do not enable Accessibility for this phase.
4. Verify that foreground-app observation returns: unsupported/no permission, blocked-by-permission, and a real observation where the device/OEM supports it.
5. Test process death, restart, reboot, Doze, offline policy evaluation, network recovery, duplicate delivery, policy revocation, and status telemetry as separate cases.

## Firebase and server boundary

The current policy read path is family-scoped. Remote child delivery of temporary overrides requires a reviewed server-mediated delivery contract because parent-only override documents must remain unreadable to child identities. Do not weaken Firestore rules. If Cloud Functions are selected, the owner must approve Blaze billing before deployment and then validate only the reviewed Guardian function codebase.

## Store and compliance review

Before any application-blocking, Accessibility, screen capture, background monitoring, or Device Owner implementation, obtain a current Google Play policy review, explicit consent design review, privacy-policy/data-safety update, and physical-device validation. Never use a device-management capability in a hidden or deceptive way.

## iOS

iOS verification requires macOS/Xcode and an iPhone. System-wide Android-style app blocking and Usage Stats observation must not be promised for iOS.
