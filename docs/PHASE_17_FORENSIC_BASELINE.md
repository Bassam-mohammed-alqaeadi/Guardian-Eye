# Phase 17 Forensic Baseline — Family Membership, Multi-Parent & Device Relationship

**Date:** 12 August 2026  
**Method:** Read-only source, schema, rules, contract, presentation, test, documentation, and Firebase-configuration presence inspection before Phase 17 production edits.

> **Forensic conclusion:** Guardian Eye already has the beginnings of a family membership model, multiple adult role values, explicit member-to-device rows, child lifecycle, and account-level Firebase authentication. It does **not** yet have membership status, account-to-member binding in SQLite, canonical permissions, invitation lifecycle, adult-device association flow, or a remote contract that safely resolves the current local member UUID versus Firebase account UID distinction.

## Existing canonical model

| Concern | Existing implementation | Reuse decision |
|---|---|---|
| Firebase account | `AuthenticatedIdentity` contains `uid`, optional email, and anonymous flag only. | Reuse unchanged. Account remains distinct from member, role, and device. |
| Family | `GuardianFamily` and `families` hold UUID, name, created time, optional archive. | Reuse; do not add a second family table. |
| Membership | `FamilyMember` and `family_members` hold UUID, family UUID, name, role, and created time. Current values: `primaryParent`, `parent`, `coParent`, `spouse`, `child`. | Extend the existing row with account binding, membership status, invitation provenance, revocation, and update time. Do not replace it. |
| Device relationship | `devices` has UUID, family ID, member ID, owner member ID, role, sync state, timestamps, and revocation. Child state is explicitly in `child_device_states`. | Reuse unchanged in principle; add no device copy. Adult device association can reuse pairing/device rows after membership is active. |
| Child model | Child is an existing `FamilyMember` with `role=child`; child device pairing and state are separate. | Reuse. Do not introduce father/mother or a duplicate child profile. |
| Policies, usage, requests | Existing family-scoped policies, device-scoped child delivery, usage, exception requests, overrides, and timeline work through SQLite/Outbox. | Preserve. New authority checks must call a canonical permission model instead of rebuilding these flows. |
| Offline synchronization | `outbox` plus `OutboxSyncExecutor` is canonical. | Reuse only. No second queue or sync worker. |

## Current authority and identity assumptions

| Surface | Current behavior | Phase 17 risk / required correction |
|---|---|---|
| Local roles | `FamilyRole.primaryParent` is used as a legacy owner equivalent; `parent`, `coParent`, and `spouse` already exist. | Preserve storage compatibility; define owner semantics centrally rather than renaming data destructively. |
| Local authorization | `FamilyAuthorization` has only coarse role checks. Device management is owner-member or `primaryParent`; no permissions enum or membership status. | Extend this existing foothold into a canonical role→permission matrix. |
| Safety review | Phase 16 parent review calls `PolicyRepository.primaryParentMemberId`, so UI/repository assume a single permanent authority. | Replace the caller path with a permission-authorized active adult member lookup; retain legacy helper only where compatibility requires it. |
| Firestore member lookup | Rules locate membership at `families/{familyId}/members/{request.auth.uid}` while local member IDs are UUIDs and current member mutation writes by local `memberId`. | This is a real identity-path mismatch. Phase 17 must make remote adult member document IDs account UIDs while retaining `memberId` as the local/domain UUID field. |
| Firestore status | Existing rules have no membership status check and member updates lock role/memberUid but are primary-owner-only. | Add active/revoked status semantics without weakening current child/device checks. |
| Device identity | Child device identity is correctly bound through active device documents and `memberUid`; parent device token logic has an owner-device compatibility branch. | Preserve child binding/revocation/replay protection. Do not infer a child identity from an adult. |

## Live and legacy UI paths

| Path | Classification | Phase 17 action |
|---|---|---|
| `presentation/guardian_app.dart` → `DashboardScreen` | **Live.** MaterialApp shell with Riverpod and localization. | Extend with a progressive-disclosure Family Members entry. |
| `FamilyDailySafetyScreen`, policy manager, child status, exception review | **Live Phase 13–16 flows.** | Preserve their repository paths and update only adult authority lookup through canonical permission APIs. |
| `presentation/providers/router_provider.dart` and `ParentDashboardScreen` | Legacy GoRouter/static path, not connected to active app shell. | Do not revive or modify as product flow. |

## Schema and contract impact

SQLite is currently schema version 11. Phase 17 requires one compatible migration that extends `family_members` and adds one family invitation table with indexes. Existing active member rows must migrate to `active`; account binding is nullable for offline-created/cached legacy rows. Existing devices, pairings, child states, policies, exception requests, overrides, usage, and Outbox tables must remain untouched.

Firestore already uses `families/{familyId}/members`, `devices`, and family-scoped product data. Phase 17 must add only `families/{familyId}/invitations` and make adult membership contract paths account-UID-addressable. Invitation acceptance needs an atomic remote invitation-status update plus adult-membership creation; the existing remote writer currently emits a single mutation, so Phase 17 must either extend that same writer/contract to support an atomic Firestore batch or classify remote acceptance as blocked. A separate sync engine or a blind two-event acceptance is prohibited.

## Security impact

Phase 17 must preserve family isolation, child device UID binding, revocation, exception-request ownership, and policy/override scope. The owner is the only role that may invite, revoke members, or assign adult roles. Parent and co-parent safety permissions must be explicit and cannot grant ownership transfer. Child members cannot invite, accept an invitation for another account, create adult memberships, change roles, revoke members, or read parent-only invitation/membership data.

## Test impact

Existing pairing, child lifecycle, policy, screen-time, exception, timeline, Outbox, contract, widget, and Emulator tests remain regression gates. New evidence must cover role-to-permission mapping, member status, invitation creation/cancellation/expiry/acceptance/idempotency, transaction rollback, device/member relationship, cross-family denial, revoked actor denial, forged UID/device denial, role escalation denial, and parent/co-parent behavior. Firebase Emulator evidence remains Emulator-only.

## Firebase configuration finding

`.firebaserc`, `firebase.json`, local `android/app/google-services.json`, and local `lib/firebase_options.dart` are present. The canonical workspace has no `.git` metadata. No Firebase configuration content was read, changed, regenerated, or deployed during this audit.

## Architectural decision before implementation

Phase 17 can proceed safely provided it uses the current `family_members`, `devices`, `outbox`, `FamilyAuthorization`, and Firestore contract/rules surfaces. The primary conflict is the local member UUID versus remote account UID path. The implementation will resolve it by retaining local `memberId` as the domain identity, adding nullable `accountUid`, and using account UID as the remote adult member document ID. Invitation acceptance will not be represented as two independently synchronized remote events; it will require a single existing-Outbox event whose canonical writer performs one atomic batch, or it will remain explicitly blocked.
