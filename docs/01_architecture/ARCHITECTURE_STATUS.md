# Guardian Eye Pro — Architecture Status

## Canonical decision

> **Flutter/Dart is the canonical mobile stack for Guardian Eye Pro.**

The source now contains generated Android and iOS host projects plus a Flutter application foundation. The former Expo workspace is not part of this product implementation. The available GitHub repository contained only an initial README, while the available Flutter snapshot supplied the starting code and is now the canonical local project.

## Implemented foundation

The Flutter application now follows an offline-first path: **UI → Riverpod → SQLite → Outbox → Sync transport → Firebase when configured**. The local database creates records for families, members, devices, policies, incidents, pairing sessions, messages, locations, and an idempotent outbox. The app starts with no sample family data; a parent creates a local family and child records through the interface.

| Layer | Current implementation | Status |
|---|---|---|
| Presentation | Material 3 design system, RTL-first Arabic and English, onboarding, family dashboard, child creation, pairing code, and permission ladder | IMPLEMENTED locally |
| Application | Riverpod providers for dashboard, family repository, pairing, incidents, sync transport, and capabilities | IMPLEMENTED |
| Domain | Family roles, device roles, policy precedence, risk scoring, incident states, pairing request model | IMPLEMENTED |
| Local data | SQLite schema, explicit outbox records and idempotency keys | IMPLEMENTED |
| Sync | Firestore transport that refuses to send without compile-time Firebase configuration and authenticated user | PARTIALLY IMPLEMENTED |
| Firebase | Service dependencies and security-rule templates | HUMAN ACTION REQUIRED |
| Android native | Transparent method channel for usage stats, accessibility, overlay settings, and explicit Android declarations | PARTIALLY IMPLEMENTED |
| iPhone | Flutter iOS host, privacy usage descriptions, cross-platform local layers | PARTIALLY IMPLEMENTED |
| On-device AI | Risk pipeline and model-artifact contract | PARTIALLY IMPLEMENTED; model blocked |

## Platform boundary

Android-only concepts such as usage statistics, Accessibility, overlay, device-owner controls, MediaProjection, and system-wide app enforcement are never treated as iPhone capabilities. On iPhone, Guardian Eye Pro must present only Apple-supported, opt-in, transparent features such as account-based family coordination, location where permitted, messaging, notifications, and local safety functions that the user explicitly starts.

## Privacy boundary

No permanent pairing secret is written to source. Pairing records persist only a SHA-256 code hash and an expiry. Firebase transport requires a compile-time opt-in and an authenticated user. No Firebase admin credentials, child evidence payload, image capture, or model prediction is fabricated.
