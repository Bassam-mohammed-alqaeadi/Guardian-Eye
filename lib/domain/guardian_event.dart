/// Canonical Guardian event contract — Pre-AI Reconciliation Sprint.
///
/// This file is the authoritative definition of the [GuardianEvent] envelope.
/// Every safety signal, incident, SOS, and system audit entry that flows
/// through the outbox or appears in Firestore MUST conform to this contract.
///
/// ## Identity fields (never collapse — each has a distinct semantic meaning)
///
/// | Field       | Type   | Meaning                                                     |
/// |-------------|--------|-------------------------------------------------------------|
/// | [actorUid]  | String | Firebase Auth UID of the authenticated writer (client JWT). |
/// | [memberId]  | String | SQLite UUID assigned to this person in the local DB.        |
/// | [childId]   | String | SQLite UUID of the child record (for child-targeted events).|
/// | [deviceId]  | String | SQLite UUID of the physical device that produced the event. |
///
/// [actorUid] is the only field that can be verified by Firestore Security Rules.
/// [memberId] is a stable cross-session local identity that survives sign-out.
/// [deviceId] is required by Firestore Rules for device-scoped write authority.
///
/// ## Lifecycle
///
/// Events are created on-device and enter the outbox with [syncState] = queued.
/// The [OutboxSyncExecutor] promotes them to Firestore via [FirestoreEventContract].
/// On success the local record transitions to [SyncState.synced].
///
/// ## Privacy
///
/// [privacyClass] drives local-retention and remote-redaction policy.
/// AI normalization (M10+) MUST respect [privacyClass] before processing.

library guardian_event;

import 'guardian_models.dart';

// ---------------------------------------------------------------------------
// Privacy class
// ---------------------------------------------------------------------------

/// Data sensitivity classification for retention and redaction policy.
enum GuardianPrivacyClass {
  /// Non-sensitive operational data (sync metadata, policy events).
  operational,

  /// Content that touches child behaviour but carries no media (incident flags).
  behavioural,

  /// Location or timing data that enables physical tracking.
  locationSensitive,

  /// Biometric or device-content data — highest retention restrictions.
  biometric,
}

// ---------------------------------------------------------------------------
// Event types
// ---------------------------------------------------------------------------

/// Canonical set of event types flowing through the Guardian event pipeline.
enum GuardianEventType {
  // Family lifecycle
  familyCreated,
  memberCreated,
  memberRevoked,
  invitationSent,
  invitationAccepted,
  invitationCancelled,

  // Device lifecycle
  deviceEnrolled,
  deviceRevoked,

  // Policy
  policyCreated,
  policyUpdated,
  policyDeleted,
  policyOverrideCreated,
  policyDelivered,
  enforcementApplied,
  exceptionRequested,
  exceptionReviewed,

  // Safety events
  incidentCreated,
  incidentAcknowledged,
  incidentResolved,
  sosCreated,
  sosTransitioned,

  // Usage / measurement
  usageObserved,
  childDeviceStateUpdated,

  // Infrastructure
  notificationTokenRegistered,
  notificationRequested,
  syncMetadata,
}

// ---------------------------------------------------------------------------
// GuardianEvent envelope
// ---------------------------------------------------------------------------

/// Canonical event envelope for all Guardian Eye Pro domain events.
///
/// Producers MUST populate [deviceId] when the event originates from a device
/// (incidents, SOS, enforcement, usage). [childId] MUST be set when the event
/// concerns a specific child member. [actorUid] is always the Firebase Auth UID
/// of the writer and MUST match the ID token used to authorize the outbox write.
class GuardianEvent {
  const GuardianEvent({
    required this.eventId,
    required this.familyId,
    required this.actorUid,
    required this.eventType,
    required this.timestamp,
    required this.source,
    required this.severity,
    required this.confidence,
    required this.syncState,
    required this.privacyClass,
    this.memberId,
    this.childId,
    this.deviceId,
    this.metadata = const {},
  });

  // Core identity — see doc comments above for semantic distinction.
  final String eventId;
  final String familyId;

  /// Firebase Auth UID of the authenticated actor writing this event.
  final String actorUid;

  /// Local SQLite UUID of the family member (null for system events).
  final String? memberId;

  /// Local SQLite UUID of the child being monitored (null for non-child events).
  final String? childId;

  /// Local SQLite UUID of the physical device originating the event.
  /// Required for device-gated Firestore writes (incidents, SOS, enforcement).
  final String? deviceId;

  // Event classification
  final GuardianEventType eventType;
  final DateTime timestamp;

  /// Event source: 'device', 'parent_app', 'backend', 'system'.
  final String source;

  /// Risk severity level (mirrors [IncidentSeverity] for safety events).
  final String severity;

  /// Model confidence in range [0.0, 1.0]. 1.0 for rule-based events.
  final double confidence;

  // Lifecycle
  final SyncState syncState;
  final GuardianPrivacyClass privacyClass;

  /// Arbitrary event-specific payload fields.
  final Map<String, Object?> metadata;

  Map<String, Object?> toOutboxPayload() => {
        'eventId': eventId,
        'familyId': familyId,
        'actorUid': actorUid,
        if (memberId != null) 'memberId': memberId,
        if (childId != null) 'childId': childId,
        if (deviceId != null) 'deviceId': deviceId,
        'eventType': eventType.name,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'severity': severity,
        'confidence': confidence,
        'privacyClass': privacyClass.name,
        ...metadata,
      };
}
