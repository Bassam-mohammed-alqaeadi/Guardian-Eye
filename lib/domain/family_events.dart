/// Guardian AI — Layer 1 foundation: canonical family event registry.
///
/// Every AI layer consumes **normalized signals**, never raw feature rows.
/// This module is the normalization boundary:
///
/// * [GuardianFeatureEvent] — one observed fact produced by an FS subsystem
///   (web filter hit, app session, screenshot, location update, geofence
///   event, SOS, incident, policy evaluation, device transition).
/// * [NormalizedSignal] — the canonical, deduplicated, timestamped feature
///   vector that the intelligence layers actually evaluate.
///
/// ## Honesty contract
///
/// Normalization NEVER fabricates signals. A failure anywhere in the
/// pipeline returns an **empty feature set** — AI layers evaluate to
/// "no insight" rather than crashing or inventing data. Events that fail
/// schema validation are recorded as [EventNormalizationOutcome.rejected]
/// with a reason so the transparency center can disclose them.
///
/// ## Privacy
///
/// Each event carries a [GuardianPrivacyClass]. AI normalization may only
/// emit a signal if the family's consent scope permits processing of that
/// class; otherwise the event is normalized to an empty feature set and
/// recorded with [EventNormalizationOutcome.consentBlocked].
library family_events;

import 'guardian_event.dart';

/// One observed fact from a Guardian subsystem.
class GuardianFeatureEvent {
  const GuardianFeatureEvent({
    required this.id,
    required this.familyId,
    required this.type,
    required this.occurredAt,
    required this.privacyClass,
    this.memberId,
    this.childId,
    this.deviceId,
    this.attributes = const {},
    this.createdAt,
  });

  final String id;
  final String familyId;
  final GuardianEventType type;
  final DateTime occurredAt;
  final GuardianPrivacyClass privacyClass;
  final String? memberId;
  final String? childId;
  final String? deviceId;

  /// Type-specific payload (category, app name, latitude, radius, severity …).
  final Map<String, String> attributes;

  /// Ingestion time. Null until the event is persisted.
  final DateTime? createdAt;

  factory GuardianFeatureEvent.fromJson(Map<String, Object?> json) =>
      GuardianFeatureEvent(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        type: GuardianEventType.values.byName(json['type'] as String),
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        privacyClass:
            GuardianPrivacyClass.values.byName(json['privacy_class'] as String),
        memberId: json['member_id'] as String?,
        childId: json['child_id'] as String?,
        deviceId: json['device_id'] as String?,
        attributes:
            Map<String, String>.from((json['attributes'] as Map?) ?? const {}),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'type': type.name,
        'occurred_at': occurredAt.toIso8601String(),
        'privacy_class': privacyClass.name,
        'member_id': memberId,
        'child_id': childId,
        'device_id': deviceId,
        'attributes': attributes,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// Outcome of attempting to normalize one feature event.
enum EventNormalizationOutcome {
  normalized,
  rejected,
  consentBlocked,
  duplicate,
}

/// Canonical normalized signal — the only thing AI layers evaluate.
class NormalizedSignal {
  const NormalizedSignal({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.signalKey,
    required this.weight,
    required this.occurredAt,
    required this.outcome,
    required this.privacyClass,
    this.sourceEventId,
    this.rejectReason,
    this.consentScope,
  });

  final String id;
  final String familyId;
  final String childId;

  /// Stable key used by the evaluation layers (e.g. `web.category.hit`,
  /// `app.session.night`, `location.geofence.entry`).
  final String signalKey;

  /// Magnitude in [0.0, 1.0]. 0.0 means "observed but benign".
  final double weight;

  final DateTime occurredAt;
  final EventNormalizationOutcome outcome;
  final GuardianPrivacyClass privacyClass;
  final String? sourceEventId;
  final String? rejectReason;

  /// The consent scope that permitted processing, if any.
  final String? consentScope;

  bool get isProcessable =>
      outcome == EventNormalizationOutcome.normalized && weight > 0;

  factory NormalizedSignal.fromJson(Map<String, Object?> json) =>
      NormalizedSignal(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        childId: json['child_id'] as String,
        signalKey: json['signal_key'] as String,
        weight: (json['weight'] as num).toDouble(),
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        outcome:
            EventNormalizationOutcome.values.byName(json['outcome'] as String),
        privacyClass:
            GuardianPrivacyClass.values.byName(json['privacy_class'] as String),
        sourceEventId: json['source_event_id'] as String?,
        rejectReason: json['reject_reason'] as String?,
        consentScope: json['consent_scope'] as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'child_id': childId,
        'signal_key': signalKey,
        'weight': weight,
        'occurred_at': occurredAt.toIso8601String(),
        'outcome': outcome.name,
        'privacy_class': privacyClass.name,
        'source_event_id': sourceEventId,
        'reject_reason': rejectReason,
        'consent_scope': consentScope,
      };
}

/// Stable signal keys produced by Layer 1 (L1 — Event Normalization).
/// Every AI layer filters on this closed set; adding a key is a
/// documented cross-layer decision.
class GuardianSignalKeys {
  GuardianSignalKeys._();

  // L2 inputs (content / media).
  static const String screenshotFlagged = 'media.screenshot.flagged';
  static const String webCategoryHit = 'web.category.hit';

  // L3 inputs (usage behavior).
  static const String appSession = 'app.session';
  static const String appNightSession = 'app.session.night';
  static const String usageLimitEvaluated = 'policy.usage.evaluated';

  // L4 inputs (risk precursors).
  static const String geofenceEntry = 'location.geofence.entry';
  static const String geofenceExit = 'location.geofence.exit';
  static const String sosActivated = 'sos.activated';
  static const String incidentCreated = 'incident.created';

  // L5 inputs (family context).
  static const String deviceStateTransition = 'device.state.transition';
  static const String policyEvaluated = 'policy.evaluated';
  static const String modeSwitched = 'mode.switched';
}

/// L1 — Event Normalization: converts raw feature events into normalized
/// signals with consent enforcement and deduplication.
///
/// Pure Dart, deterministic, fail-open-to-empty (never throws, never
/// invents signals).
class EventNormalizer {
  const EventNormalizer({
    this.maxWeightPerKey = 1.0,
    this.deduplicateWindowMinutes = 5,
  });

  final double maxWeightPerKey;
  final int deduplicateWindowMinutes;

  /// Normalize a batch. `seen` is the set of signal ids already known
  /// (from persistence) used for the deduplication window check.
  List<NormalizedSignal> normalize(
      List<GuardianFeatureEvent> events,
      Set<String> recentSignalIds,
      bool Function(GuardianPrivacyClass) isConsented) {
    final result = <NormalizedSignal>[];
    for (final event in events) {
      result.add(normalizeOne(event, recentSignalIds, isConsented));
    }
    return result;
  }

  NormalizedSignal normalizeOne(
      GuardianFeatureEvent event,
      Set<String> recentSignalIds,
      bool Function(GuardianPrivacyClass) isConsented) {
    if (!event.isValid) {
      return _outcome(event, EventNormalizationOutcome.rejected, 0,
          rejectReason: 'invalid_schema');
    }
    if (!isConsented(event.privacyClass)) {
      return _outcome(event, EventNormalizationOutcome.consentBlocked, 0,
          rejectReason: 'consent_blocked:${event.privacyClass.name}');
    }
    final key = signalKeyFor(event);
    if (key == null) {
      return _outcome(event, EventNormalizationOutcome.rejected, 0,
          rejectReason: 'unmapped_type:${event.type.name}');
    }
    if (recentSignalIds.contains(key)) {
      return _outcome(event, EventNormalizationOutcome.duplicate, 0,
          rejectReason: 'within_dedup_window');
    }
    return _outcome(event, EventNormalizationOutcome.normalized,
        weightFor(event, key).clamp(0.0, maxWeightPerKey));
  }

  /// Map a feature event to a canonical signal key. Returns null for
  /// event types the normalizer does not yet map (recorded honestly).
  String? signalKeyFor(GuardianFeatureEvent event) {
    switch (event.type) {
      // L3 inputs — usage behavior (measured via device usage summaries).
      case GuardianEventType.usageObserved:
        return _nightKey(event)
            ? GuardianSignalKeys.appNightSession
            : GuardianSignalKeys.appSession;
      case GuardianEventType.childDeviceStateUpdated:
      case GuardianEventType.enforcementApplied:
        return GuardianSignalKeys.usageLimitEvaluated;
      // L4 inputs — risk precursors. The location subsystem records
      // geofence crossings through the incident pipeline; the normalizer
      // dispatches on the incident's `domain` attribute.
      case GuardianEventType.sosCreated:
        return GuardianSignalKeys.sosActivated;
      case GuardianEventType.incidentCreated:
        final domain = event.attributes['domain'] ?? '';
        if (domain == 'geofence_entry') {
          return GuardianSignalKeys.geofenceEntry;
        }
        if (domain == 'geofence_exit') {
          return GuardianSignalKeys.geofenceExit;
        }
        if (domain == 'content' || domain == 'screenshot') {
          return GuardianSignalKeys.screenshotFlagged;
        }
        return GuardianSignalKeys.incidentCreated;
      // L5 inputs — family context.
      case GuardianEventType.deviceEnrolled:
      case GuardianEventType.deviceRevoked:
        return GuardianSignalKeys.deviceStateTransition;
      case GuardianEventType.policyCreated:
      case GuardianEventType.policyUpdated:
      case GuardianEventType.policyDelivered:
        return GuardianSignalKeys.policyEvaluated;
      default:
        return null;
    }
  }

  bool _nightKey(GuardianFeatureEvent event) {
    final hour = event.occurredAt.hour;
    return hour >= 22 || hour < 6;
  }

  /// Magnitude heuristics — deterministic, documented, never learned.
  double weightFor(GuardianFeatureEvent event, String key) {
    switch (key) {
      case GuardianSignalKeys.sosActivated:
        return 1.0;
      case GuardianSignalKeys.incidentCreated:
        switch (event.attributes['severity'] ?? '') {
          case 'critical':
            return 1.0;
          case 'high':
            return 0.8;
          case 'medium':
            return 0.6;
          case 'low':
            return 0.3;
          default:
            return 0.6;
        }
      case GuardianSignalKeys.webCategoryHit:
        return 0.4;
      case GuardianSignalKeys.screenshotFlagged:
        return 0.5;
      case GuardianSignalKeys.appNightSession:
        return 0.3;
      case GuardianSignalKeys.appSession:
        return 0.1;
      case GuardianSignalKeys.usageLimitEvaluated:
        return 0.3;
      case GuardianSignalKeys.geofenceEntry:
        return 0.5;
      case GuardianSignalKeys.geofenceExit:
        return 0.1;
      case GuardianSignalKeys.deviceStateTransition:
        return 0.1;
      case GuardianSignalKeys.policyEvaluated:
        return 0.1;
      case GuardianSignalKeys.modeSwitched:
        return 0.1;
      default:
        return 0.0;
    }
  }

  NormalizedSignal _outcome(GuardianFeatureEvent event,
      EventNormalizationOutcome outcome, double weight,
      {String? rejectReason}) {
    final hash = _signalHash(event.type.name, event.id);
    return NormalizedSignal(
      id: hash,
      familyId: event.familyId,
      childId: event.childId ?? '',
      signalKey: signalKeyFor(event) ?? 'unmapped',
      weight: weight,
      occurredAt: event.occurredAt,
      outcome: outcome,
      privacyClass: event.privacyClass,
      sourceEventId: event.id,
      rejectReason: rejectReason,
    );
  }

  String _signalHash(String type, String eventId) {
    final codeUnits = '$type:$eventId'.codeUnits;
    var hash = 0;
    for (final unit in codeUnits) {
      hash = (hash * 31 + unit) % 0x100000000;
    }
    return 'sig-${eventId.hashCode.abs().toRadixString(36)}-$hash';
  }
}

extension on GuardianFeatureEvent {
  /// Schema validity: every event needs an identity and a family anchor.
  /// Timestamps are normalized to UTC at ingestion time by the registry.
  bool get isValid => id.trim().isNotEmpty && familyId.trim().isNotEmpty;
}

/// Deterministic dedup bucket for the last `minutes` window.
Set<String> dedupKeysSince(
        Iterable<NormalizedSignal> signals, int windowMinutes, DateTime now) =>
    {
      for (final s in signals)
        if (now.difference(s.occurredAt) <= Duration(minutes: windowMinutes))
          s.signalKey
    };
