# Phase 16 Baseline — Forensic Reconciliation

**Date:** 12 August 2026  
**Canonical workspace:** `/home/ubuntu/guardian_eye_flutter`  
**Method:** Read-only source, schema, rules, test, and Phase 14–15 evidence review before Phase 16 implementation.

> **Selected gap:** Guardian Eye has a real local policy, child device, usage, override, and Outbox foundation, but no child-authenticated exception-request entity, no parent review transaction, and no local safety timeline. Phase 16 will connect only that missing dialogue path.

## Active implementation inventory

| Area | Current implementation | Evidence classification | Phase 16 consequence |
|---|---|---|---|
| Active parent entry | `GuardianApp` opens `DashboardScreen`; its data comes from `FamilyRepository.loadDashboard()`. | **IMPLEMENTED + VERIFIED LOCALLY** | Refine this live dashboard; do not revive the legacy GoRouter dashboard. |
| Parent policies | `PolicyRepository` persists versioned policies and daily limits, queues Outbox events, and creates `StoredPolicyOverride` records. | **IMPLEMENTED + VERIFIED LOCALLY** | Approval must reuse the existing override table and payload contract. |
| Expiration | `StoredPolicyOverride.isActiveAt()` is already evaluated by timestamp in the policy/child resolvers. | **IMPLEMENTED + VERIFIED LOCALLY** | Expiration remains deterministic; no worker is needed. |
| Child delivery/state | Child policy delivery, lifecycle, revocation, version/idempotency, local recovery, and child usage summaries exist. | **IMPLEMENTED + VERIFIED LOCALLY** | Exception creation must reject a revoked device and scope itself to one child device/family. |
| Screen time | Usage Access bridge source, local daily accounting, screen-time engine, and truthful unsupported adapter boundary exist. | **IMPLEMENTED + VERIFIED LOCALLY** for accounting; Android bridge **IMPLEMENTED — VALIDATION BLOCKED** | UI must say measured/evaluated/requested/unsupported, never app blocked. |
| Firestore policies and telemetry | Family policy security and active child-device usage/status telemetry rules are Emulator-tested. | **VERIFIED IN EMULATOR** | Add a narrow exception-request path; do not relax existing policy or device rules. |
| Firebase real backend | Prior validated rules/indexes were deployed before Phase 15; Phase 14/15 local rule additions were not deployed. | **IMPLEMENTED — VALIDATION BLOCKED** for later local rule changes | Do not deploy Phase 16 rules without explicit owner authorization. |
| Physical Android/FCM/APK | No physical-device evidence; APK attempts stop at Flutter kernel snapshot before Kotlin compilation; no FCM delivery claim. | **PHYSICAL DEVICE REQUIRED** | Phase 16 evidence remains local/Emulator only. |

## Confirmed data gaps

| Requirement | Existing reusable foundation | Missing canonical capability |
|---|---|---|
| Child exception request | Child device state and family/device identity; Outbox transaction pattern. | Request entity/status, SQLite persistence, child-create validation, request Outbox event. |
| Parent review | `PolicyRepository.createOverride()` and parent member lookup. | Atomic request approval/denial transaction that inserts exactly one override and corresponding events. |
| Request expiration/cancellation | Timestamp-based policy override resolution. | Request status transition semantics and deterministic request expiry sweep on evaluation/read. |
| Family safety timeline | Outbox rows, policy records, usage observations/evaluations, and child enforcement records. | Read model that composes these local sources with request/review events and labels sync truthfully. |
| Daily parent dashboard | Active dashboard has family, children, incidents, and queue count. | Per-child device/policy/usage/override/request summary based on SQLite rather than placeholders. |
| Child policy experience | Child state, delivered policies, usage summaries, and resolvers. | A child-focused view and exception-request entry point using only local persisted facts. |

## Dead, duplicate, and unsafe paths

| Item | Finding | Phase 16 decision |
|---|---|---|
| `parent_dashboard_screen.dart` | Legacy GoRouter screen contains static safety claims and is not part of the active `MaterialApp(home: DashboardScreen())` path. | **OUT OF SCOPE:** do not reuse or expand. It remains technical debt for a later removal/migration decision. |
| `child_profile_screen.dart` | Legacy static placeholder uses fabricated child/time/progress content and is only referenced by the legacy router. | **OUT OF SCOPE:** do not reuse or expand. |
| `router_provider.dart` | Legacy GoRouter wiring refers only to old static screens; active app does not consume it. | **OUT OF SCOPE:** no route migration in this vertical slice. |
| Override flow | Parent can directly create an override from policy manager; it lacks a child request/review source. | Reuse override persistence only after a parent review transaction, not as a second override system. |
| Timeline | No canonical exception/timeline table or request path exists. | Add one local read model/event record, not another sync engine. |

## Explicit Phase 16 scope

The coherent vertical slice is: **child request → locally persisted pending request → parent review → atomic approved/denied status plus existing temporary override → deterministic expiry → local timeline/dashboard/child explanation → Outbox → Firestore Emulator authorization.**

Android app blocking, Accessibility, overlays, Device Owner, continuous monitoring, Doze/reboot work, real Firebase deployment, FCM delivery, and physical device validation are **NOT IMPLEMENTED** and **OUT OF SCOPE** for this phase.
