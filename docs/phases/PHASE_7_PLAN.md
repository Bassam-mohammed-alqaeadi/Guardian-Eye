# PHASE 7 — Real Backend, Security & First End-to-End Production Path

## Current backend architecture

Guardian Eye Pro is Flutter-first and offline-first. Local repositories write SQLite business records and outbox entries. The current `SyncEngine` only gates a direct Firestore `sync_events` write behind connectivity, a compile-time configuration flag, Firebase initialization, and an authenticated user. It lacks an explicit auth context, operation mapping, due-event selection, transactional remote business writes, retry classification, permanent failure state, conflict handling, and remote-read verification.

## Missing pieces and security risks

The Firebase project, FlutterFire-generated options, Authentication provider configuration, deployed Firestore rules, Emulator Suite, FCM/APNs credentials, server-side notification producer, and physical-device verification are absent. A mobile client must never perform privileged notification fanout or include Admin credentials. Backend rules must reject unauthenticated users, cross-family access, child role escalation, unpaired devices, and revoked device writes.

## Implementation strategy

The phase will add an explicit authenticated identity contract that fails closed, Firestore document mapping with controlled collection paths, and a dependency-injected sync executor. The executor will select due outbox records, classify failures as retryable or permanent, compute deterministic backoff, preserve idempotency keys, and send safe client-owned writes only. A Firestore operation mapper will enforce which local events can become remote business documents; notification requests remain server-consumed events.

## Firebase and Emulator strategy

Firebase code will remain executable only after `firebase_options.dart` is generated through FlutterFire and a real Firebase project is configured. Emulator-ready security and flow tests will be documented and prepared, but no Emulator validation will be claimed until it is actually run. Production rules and indexes will remain templates until deployed by the project owner.

## Notification strategy

The app will register a device token only after authenticated Firebase initialization, bind it to an active device context, persist a token-refresh update as an outbox event, and distinguish notification requested, backend accepted, physically delivered, and parent acknowledged. Server-side fanout is a Cloud Function responsibility; the Flutter client must not send FCM messages directly.

## Test strategy

Unit tests will cover auth gate decisions, event mapping, idempotency, retry/permanent-failure classification, conflict policy, and notification token contract behavior. Repository tests will retain SQLite FFI evidence. Emulator and physical-device cases are documented as pending when unavailable.

## Environment blockers and human actions

The required Firebase project configuration, FlutterFire options, Authentication providers, Firestore/FCM/APNs setup, Firebase CLI/Emulator, Android device, and macOS/Xcode for iPhone verification are documented in `IMPLEMENTATION_BLOCKERS.md` and `HUMAN_ACTION_REQUIRED.md`. The code must still fail safely when they are absent.

## Acceptance criteria

1. Flutter analysis and all local tests are green.
2. Auth-required repositories reject absent identity.
3. Due outbox events are mapped deterministically, classified, and recorded locally after outcome.
4. Duplicate execution uses the same idempotency key and cannot generate a second remote business path.
5. Firestore collections, security model, conflict policy, Emulator plan, indexes, blockers, and human actions are documented.
6. Remote Firebase/FCM/device verification is labeled **implemented but not physically verified** until execution evidence exists.
