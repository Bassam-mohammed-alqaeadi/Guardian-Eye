# FS-002 — Firestore Security Rules for Web Filtering

This document is the deployable rules specification for the FS-002 web
filtering collections. It requires **no backend code change**: the rules are
applied through the Firebase console or the `firebase deploy --only firestore`
pipeline, and the client app written in this phase already respects the same
boundaries (parent-only writes via authenticated membership, child-app
read-only consumption).

## Collections introduced by FS-002

| Collection (per family) | Writer | Reader | Purpose |
| --- | --- | --- | --- |
| `web_hits/{hitId}` | Parent app (outbox sync) | Both parents, child app | Observed block events; audit-proof history |
| `web_domains/{domainId}` | Parent app (outbox sync) | Both parents, child app | Blocklist and allowlist entries |
| `web_category_rules/{ruleId}` | Parent app (outbox sync) | Both parents, child app | Per-child category toggles |
| `web_settings/{key}` | Parent app (outbox sync) | Both parents | Family web settings (safe search, etc.) |
| `web_policy` (family-level doc) | Render backend / aggregation | Both parents, child app | Verified server summary for pull |

## Recommended rules (Firebase console → Firestore → Rules)

```
rules_version = '2';

service cloud.firestore {
  match /databases/{db}/documents {

    function isAuthenticated() {
      return request.auth != null;
    }

    // A signed-in account that is a verified member of this family.
    function isFamilyMember(familyId) {
      return isAuthenticated() &&
        exists(/databases/$(db)/documents/families/$(familyId)
               /members/$(request.auth.uid)) &&
        get(/databases/$(db)/documents/families/$(familyId)
            /members/$(request.auth.uid)).data.status == 'verified';
    }

    function isParentOfFamily(familyId) {
      return isFamilyMember(familyId) &&
        get(/databases/$(db)/documents/families/$(familyId)
            /members/$(request.auth.uid)).data.role == 'parent';
    }

    // ── FS-002 Web Filtering ────────────────────────────────────────

    // Hits: parents create/update their own observations; history is
    // append-only after creation (no delete, no overwrite of decision).
    match /families/{familyId}/web_hits/{hitId} {
      allow read: if isFamilyMember(familyId);
      allow create: if isParentOfFamily(familyId)
        && request.resource.data.childId is string
        && request.resource.data.domain is string;
      allow update: if isParentOfFamily(familyId)
        && resource.data.childId == request.resource.data.childId
        && resource.data.domain == request.resource.data.domain;
      allow delete: if false;
    }

    // Domains: parent-managed blocklist / allowlist.
    match /families/{familyId}/web_domains/{domainId} {
      allow read: if isFamilyMember(familyId);
      allow create, update: if isParentOfFamily(familyId)
        && request.resource.data.kind in ['block', 'allow'];
      allow delete: if false;
    }

    // Category rules: parent-managed per-child category toggles.
    match /families/{familyId}/web_category_rules/{ruleId} {
      allow read: if isFamilyMember(familyId);
      allow create, update: if isParentOfFamily(familyId)
        && request.resource.data.childId is string;
      allow delete: if false;
    }

    // Settings: parent-managed family web settings.
    match /families/{familyId}/web_settings/{key} {
      allow read: if isFamilyMember(familyId);
      allow create, update: if isParentOfFamily(familyId);
      allow delete: if false;
    }

    // Server summary document consumed by the pull path.
    match /families/{familyId}/web_policy {
      allow read: if isFamilyMember(familyId);
      allow write: if false; // Render backend only (service account)
    }
  }
}
```

## Honesty guarantees enforced by the rules

The rules make the platform's honesty promises structural rather than
behavioral: deletion is impossible (`allow delete: if false`), so a block
event can never disappear from the family record; only a parent of the same
family may write, so a sibling or guest cannot fabricate protection state;
and the `web_policy` document is read-only to clients, meaning every value
the pull path displays was written by the server and never by a device.

## Validation before deployment

Run `firebase deploy --only firestore --dry-run` (Firebase CLI) from any
checkout that contains a `firestore.rules` file with the block above. No
app code changes are required for the rules to take effect; existing
outbox writes simply begin landing in real documents instead of being
silently absorbed by the sync-metadata fallback.
