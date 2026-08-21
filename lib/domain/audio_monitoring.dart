import 'guardian_models.dart';

/// FS-008 — One-Way Audio domain models.
/// 
/// This subsystem governs live ambient audio monitoring with explicit 
/// consent gates and session-based lifecycle.

enum AudioSessionStatus {
  connecting,
  active,
  completed,
  failed,
  timedOut,
  rejected
}

enum AudioPrivacyClass {
  ephemeral, // Not recorded, live stream only
  safetyEvidence, // Recorded due to safety trigger, retained per policy
  archived // Explicitly saved by parent
}

class AudioSession {
  const AudioSession({
    required this.id,
    required this.familyId,
    required this.memberId,
    required this.deviceId,
    required this.status,
    required this.privacyClass,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.notes,
    this.syncState = SyncState.localOnly,
  });

  final String id;
  final String familyId;
  final String memberId; // The child being monitored
  final String deviceId; // The device being monitored
  final AudioSessionStatus status;
  final AudioPrivacyClass privacyClass;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? notes;
  final SyncState syncState;

  factory AudioSession.fromMap(Map<String, Object?> map) => AudioSession(
        id: map['id']! as String,
        familyId: map['family_id']! as String,
        memberId: map['member_id']! as String,
        deviceId: map['device_id']! as String,
        status: AudioSessionStatus.values.byName(map['status']! as String),
        privacyClass: AudioPrivacyClass.values.byName(map['privacy_class']! as String),
        startedAt: DateTime.parse(map['started_at']! as String),
        endedAt: map['ended_at'] == null ? null : DateTime.parse(map['ended_at']! as String),
        durationSeconds: map['duration_seconds'] as int?,
        notes: map['notes'] as String?,
        syncState: SyncState.values.byName(map['sync_state']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'family_id': familyId,
        'member_id': memberId,
        'device_id': deviceId,
        'status': status.name,
        'privacy_class': privacyClass.name,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'notes': notes,
        'sync_state': syncState.name,
      };
}

class AudioKeyword {
  const AudioKeyword({
    required this.id,
    required this.familyId,
    required this.phrase,
    this.enabled = true,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String phrase;
  final bool enabled;
  final DateTime createdAt;

  factory AudioKeyword.fromMap(Map<String, Object?> map) => AudioKeyword(
        id: map['id']! as String,
        familyId: map['family_id']! as String,
        phrase: map['phrase']! as String,
        enabled: (map['enabled'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'family_id': familyId,
        'phrase': phrase,
        'enabled': enabled ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

class AudioPolicy {
  const AudioPolicy({
    required this.familyId,
    this.enabled = false,
    this.maxDurationMinutes = 5,
    this.wifiOnly = true,
    this.requireSpouseConsent = false,
    this.keywordsEnabled = false,
  });

  final String familyId;
  final bool enabled;
  final int maxDurationMinutes;
  final bool wifiOnly;
  final bool requireSpouseConsent;
  final bool keywordsEnabled;

  factory AudioPolicy.fromMap(Map<String, Object?> map) => AudioPolicy(
        familyId: map['family_id']! as String,
        enabled: (map['enabled'] as int? ?? 0) == 1,
        maxDurationMinutes: map['max_duration_minutes'] as int? ?? 5,
        wifiOnly: (map['wifi_only'] as int? ?? 1) == 1,
        requireSpouseConsent: (map['require_spouse_consent'] as int? ?? 0) == 1,
        keywordsEnabled: (map['keywords_enabled'] as int? ?? 0) == 1,
      );

  Map<String, Object?> toMap() => {
        'family_id': familyId,
        'enabled': enabled ? 1 : 0,
        'max_duration_minutes': maxDurationMinutes,
        'wifi_only': wifiOnly ? 1 : 0,
        'require_spouse_consent': requireSpouseConsent ? 1 : 0,
        'keywords_enabled': keywordsEnabled ? 1 : 0,
      };
}
