# FS-001 — Firestore Security Rules for Location & Geofencing

This document is the deployable rules specification for the FS-001 location and
geofencing collections. It requires **no backend code change**: the rules are
applied through the Firebase console or the `firebase deploy --only firestore`
pipeline, and the client app written in this phase already respects the same
boundaries (device-written locations, parent-written geofence configuration,
honest offline-first sync through the outbox).

## Collections introduced by FS-001

| Collection (per family) | Writer | Reader | Purpose |
| --- | --- | --- | --- |
| `locations/{locationId}` | Child device app (outbox sync) | Both parents, verified adults | Consent-gated location updates; audit trail of observed positions |
| `geofences/{geofenceId}` | Parent app (outbox sync) | Both parents, verified adults | Geofence configuration (name, center, radius, alerts) |
| `favorite_places/{placeKey}` | Parent app (outbox sync) | Both parents, verified adults | Named family places anchoring geofences |
| `location_settings/{key}` | Parent app (outbox sync) | Both parents, verified adults | Family location settings (battery saver, per-member sharing) |

Locations are **device-written and parent-read**: the child device produces
`location.updated` events (captured under consent), while parents never write
positions. Geofence configuration is the mirror image: only parents write,
and every mutation carries the family idempotency key so repeated syncs are
harmless merges, never duplicates.

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

    // ── FS-001 Location & Geofencing ────────────────────────────────
    // Locations: consent-gated, device-written, parent-read. Positions
    // are never deletable — the audit trail of where a device actually
    // was must stay intact (child enforcement relies on it).
    match /families/{familyId}/locations/{locationId} {
      allow read: if isParentOfFamily(familyId);
      allow create: if isFamilyMember(familyId)
        && request.resource.data.memberId is string
        && request.resource.data.latitude is number
        && request.resource.data.longitude is number;
      allow update: if isFamilyMember(familyId);
      allow delete: if false;
    }

    // Geofences: parent-written configuration. Parents may update and
    // disable; removal is performed as a soft disable (status =
    // 'disabled') through the merge path — hard delete is blocked so an
    // accidental local deletion can never erase family configuration.
    match /families/{familyId}/geofences/{geofenceId} {
      allow read: if isFamilyMember(familyId);
      allow create: if isParentOfFamily(familyId)
        && request.resource.data.name is string
        && request.resource.data.radiusMeters is number
        && request.resource.data.latitude is number
        && request.resource.data.longitude is number;
      allow update: if isParentOfFamily(familyId);
      allow delete: if false;
    }

    // Favorite places: parent-written anchors for geofences. Append-only
    // in practice — a repeat write with the same placeKey is a harmless
    // merge thanks to the idempotency key.
    match /families/{familyId}/favorite_places/{placeKey} {
      allow read: if isFamilyMember(familyId);
      allow create, update: if isParentOfFamily(familyId)
        && request.resource.data.name is string;
      allow delete: if isParentOfFamily(familyId);
    }

    // Location settings: parent-written family configuration. Keys are
    // bounded to known setting names ('battery_saver',
    // 'sharing_enabled:{memberId}'); the client validates values before
    // they ever leave the device.
    match /families/{familyId}/location_settings/{key} {
      allow read: if isFamilyMember(familyId);
      allow create, update: if isParentOfFamily(familyId)
        && request.resource.data.value is string;
      allow delete: if false;
    }
  }
}
```

## Deployment

No backend code change is required. Apply the rules through the Firebase
console (Firestore → Rules) or with `firebase deploy --only firestore:rules`.
The FS-001 client code writes exclusively through the outbox sync executor,
so every document mutation already carries the authenticated identity and
idempotency key the rules depend on.

## Boundaries this phase respects

- **Zero changes to existing Firebase rules, schema, or the Render backend.**
  FS-001 introduces only the four collections listed above.
- Parents cannot write positions into `locations/` — attempts are rejected by
  the rules and the client never attempts them (the pull side reads only).
- Children cannot write geofence configuration — role checks are enforced by
  the same membership document both sides share.
- Hard deletion is disabled everywhere; the local store resolves removals
  through soft states (`status = 'disabled'`, removal markers) and the sync
  applier honors them honestly.
