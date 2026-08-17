# Guardian Eye Pro — Canonical Documentation Index

> **This file is the single entry point for the Guardian Eye Pro documentation corpus.**
> All 116+ documents are organized below by category.
> The [Master Product Blueprint](GUARDIAN_EYE_MASTER_PRODUCT_BLUEPRINT.md) and
> [Canonical Roadmap](GUARDIAN_EYE_CANONICAL_ROADMAP.md) are the primary
> conceptual and architectural authorities.

---

## 00 — Master Reference (This Directory)

| File | Purpose |
|------|---------|
| [GUARDIAN_EYE_MASTER_PRODUCT_BLUEPRINT.md](GUARDIAN_EYE_MASTER_PRODUCT_BLUEPRINT.md) | **Primary authority** — product vision, 5-layer architecture, all 17 milestones |
| [GUARDIAN_EYE_CANONICAL_ROADMAP.md](GUARDIAN_EYE_CANONICAL_ROADMAP.md) | Milestone definitions M4–M17 with scope, contracts, and acceptance criteria |
| [DESIGN_DECISION_LOG.md](DESIGN_DECISION_LOG.md) | Immutable architectural decision record |
| [CHANGE_PROPOSAL.md](CHANGE_PROPOSAL.md) | Approved change proposals log |

---

## 01 — Architecture

| File | Purpose |
|------|---------|
| [ARCHITECTURE_STATUS.md](../01_architecture/ARCHITECTURE_STATUS.md) | Current implementation status vs. blueprint |
| [SYSTEM_FLOW.md](../01_architecture/SYSTEM_FLOW.md) | End-to-end data flow diagrams |
| [CHILD_DEVICE_STATE_MACHINE.md](../01_architecture/CHILD_DEVICE_STATE_MACHINE.md) | Child device lifecycle state machine |
| [POLICY_ENFORCEMENT_MODEL.md](../01_architecture/POLICY_ENFORCEMENT_MODEL.md) | Policy evaluation and enforcement model |

---

## 02 — Product & UX

| File | Purpose |
|------|---------|
| [COMPETITIVE_PRODUCT_BASELINE.md](../02_product/COMPETITIVE_PRODUCT_BASELINE.md) | Market landscape |
| [TARGET_EXPERIENCE_BLUEPRINT.md](../02_product/TARGET_EXPERIENCE_BLUEPRINT.md) | UX design targets |
| [PRODUCT_REQUIREments.md](../02_product/PRODUCT_REQUIREments.md) | Feature requirements |
| [UX_SPRINT_01_V2_RECONCILIATION.md](../06_ux/UX_SPRINT_01_V2_RECONCILIATION.md) | Design system reconciliation |

---

## 03 — Security

| File | Purpose |
|------|---------|
| [GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md](../03_security/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md) | Security gap register |
| [M5_CHILD_CREATION_RULES_AUDIT.md](../03_security/M5_CHILD_CREATION_RULES_AUDIT.md) | Firestore rules audit for child creation |
| [REAL_FIREBASE_VALIDATION.md](../03_security/REAL_FIREBASE_VALIDATION.md) | Real Firebase validation evidence |

---

## 04 — Backend & Firebase

| File | Purpose |
|------|---------|
| [FIREBASE_CONFIGURATION_FORENSIC_REPORT.md](../04_backend/FIREBASE_CONFIGURATION_FORENSIC_REPORT.md) | Firebase config forensic analysis |
| [FIREBASE_REAL_ENVIRONMENT_SETUP.md](../04_backend/FIREBASE_REAL_ENVIRONMENT_SETUP.md) | Real Firebase setup guide |
| [GUARDIAN_EYE_REAL_TEST_ENVIRONMENT_SETUP.md](../04_backend/GUARDIAN_EYE_REAL_TEST_ENVIRONMENT_SETUP.md) | Full test environment setup |

---

## 05 — Android Platform

| File | Purpose |
|------|---------|
| [ANDROID_ENFORCEMENT_CAPABILITIES.md](../05_android/ANDROID_ENFORCEMENT_CAPABILITIES.md) | Android enforcement API survey |
| [ANDROID_ENFORCEMENT_RESEARCH.md](../05_android/ANDROID_ENFORCEMENT_RESEARCH.md) | Android enforcement research |
| [ANDROID_LIFECYCLE_AND_RECOVERY.md](../05_android/ANDROID_LIFECYCLE_AND_RECOVERY.md) | App lifecycle and crash recovery |
| [ANDROID_PERMISSION_MODEL.md](../05_android/ANDROID_PERMISSION_MODEL.md) | Android permission model |

---

## 07 — Environment & Operations

| File | Purpose |
|------|---------|
| [ENVIRONMENT_STRATEGY.md](../07_environment/ENVIRONMENT_STRATEGY.md) | Multi-environment strategy (emulator / real) |
| [GUARDIAN_EYE_TOOLCHAIN_BASELINE.md](../07_environment/GUARDIAN_EYE_TOOLCHAIN_BASELINE.md) | SDK / Gradle / Flutter version baseline |
| [GUARDIAN_EYE_REPRODUCIBLE_SETUP.md](../07_environment/GUARDIAN_EYE_REPRODUCIBLE_SETUP.md) | Reproducible local setup instructions |

---

## 08 — Milestone Evidence

### M1–M9 (UX Sprint 01)

Each milestone directory contains: `COMPLETION_REPORT`, `GAP_AUDIT`, `TEST_EVIDENCE`, `SCOPE_AND_CONTRACT`.

| Milestone | Directory |
|-----------|-----------|
| M1 — Family Foundation | [08_milestones/m1/](../08_milestones/m1/) |
| M2 — Invitation & Join | [08_milestones/m2/](../08_milestones/m2/) |
| M3 — Device Pairing | [08_milestones/m3/](../08_milestones/m3/) |
| M4 — Child Profile & Setup | [08_milestones/m4/](../08_milestones/m4/) |
| M5 — Child Device Provisioning | [08_milestones/m5/](../08_milestones/m5/) |
| M6 — Policy Administration | [08_milestones/m6/](../08_milestones/m6/) |
| M7 — Usage Measurement | [08_milestones/m7/](../08_milestones/m7/) |
| M8 — Child Enforcement | [08_milestones/m8/](../08_milestones/m8/) |
| M9 — Sync & Offline | [08_milestones/m9/](../08_milestones/m9/) |

### Phase Audit Archive

Internal agent phase reports (phases 4–18): [08_milestones/phases/](../08_milestones/phases/)

Historical gap audits: [08_milestones/archive/](../08_milestones/archive/)

---

## Event Contract Reference

The canonical identity/event contract is defined in:

```
lib/domain/guardian_event.dart
```

| Field | Type | Meaning |
|-------|------|---------|
| `eventId` | UUID | Unique event identifier |
| `familyId` | String | Firestore family document ID |
| `actorUid` | Firebase UID | Authenticated writer (verifiable by Firestore rules) |
| `memberId` | SQLite UUID | Local member record (survives sign-out) |
| `childId` | SQLite UUID | Child member record (child-targeted events only) |
| `deviceId` | SQLite UUID | Physical device producing the event |
| `eventType` | GuardianEventType | Enum of all canonical event types |
| `syncState` | SyncState | Outbox lifecycle (queued → synced) |
| `privacyClass` | GuardianPrivacyClass | Retention and redaction policy |

---

*Last updated: Pre-AI Reconciliation Sprint — 2026-08-17*
