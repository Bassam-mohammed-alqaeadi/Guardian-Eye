import '../domain/guardian_models.dart' show SyncState;

// ─────────────────────────── FS-006: SOS & Emergency ──────────────────
//
// The readiness roster and the honest drill state machine. A family only
// learns that an SOS reached its recipients when the acknowledgement
// channel actually confirms it — nothing is ever assumed delivered.

/// The role a recipient plays in an emergency. [responder] is expected to
/// acknowledge and act on the alert; [notifyOnly] receives the notification
/// but is not part of the acknowledgement chain.
enum SosRecipientRole { responder, notifyOnly }

extension SosRecipientRoleStorage on SosRecipientRole {
  String get storageKey => name;
  static SosRecipientRole fromStorageKey(String? key) =>
      SosRecipientRole.values.firstWhere((r) => r.name == key,
          orElse: () => SosRecipientRole.responder);
}

/// One row in the `sos_recipients` table (v20). The roster is the heart of
/// the readiness view: without responders the dashboard honestly reports
/// that the family is not ready for an emergency.
class SosRecipient {
  const SosRecipient({
    required this.familyId,
    required this.recipientId,
    required this.role,
    required this.ordering,
    required this.addedAt,
    this.syncState = SyncState.queued,
  });

  final String familyId;
  final String recipientId;
  final SosRecipientRole role;
  final int ordering;
  final DateTime addedAt;
  final SyncState syncState;

  SosRecipient copyWith({
    String? familyId,
    String? recipientId,
    SosRecipientRole? role,
    int? ordering,
    DateTime? addedAt,
    SyncState? syncState,
  }) =>
      SosRecipient(
        familyId: familyId ?? this.familyId,
        recipientId: recipientId ?? this.recipientId,
        role: role ?? this.role,
        ordering: ordering ?? this.ordering,
        addedAt: addedAt ?? this.addedAt,
        syncState: syncState ?? this.syncState,
      );

  Map<String, Object?> toMap() => {
        'family_id': familyId,
        'recipient_id': recipientId,
        'role': role.storageKey,
        'ordering': ordering,
        'added_at': addedAt.toUtc().toIso8601String(),
        'sync_state': syncState.name,
      };

  factory SosRecipient.fromMap(Map<String, Object?> row) => SosRecipient(
        familyId: row['family_id'] as String,
        recipientId: row['recipient_id'] as String,
        role: SosRecipientRoleStorage.fromStorageKey(row['role'] as String?),
        ordering: row['ordering'] as int? ?? 0,
        addedAt: DateTime.tryParse(row['added_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        syncState: SyncState.values.firstWhere(
            (s) => s.name == row['sync_state'],
            orElse: () => SyncState.queued),
      );
}

/// A drill step in the guided SOS readiness test (SO-008). Each step only
/// advances when the underlying honest state confirms it — the checklist
/// never pretends that a step passed.
enum SosDrillStep { alertSent, alertReceived, alertAcknowledged, locationVerified }

extension SosDrillStepOrder on SosDrillStep {
  int get index => SosDrillStep.values.indexOf(this);
}

/// Terminal/active classification for the drill — separated from the step
/// set so the UI can render the checklist alongside the overall verdict.
enum SosDrillStateKind { notStarted, inProgress, passed, failed }

/// Honest snapshot of a guided drill. [confirmedSteps] contains only steps
/// whose underlying state was actually observed, never assumed.
class SosDrillState {
  const SosDrillState({
    required this.state,
    required this.confirmedSteps,
    this.startedAt,
    this.finishedAt,
  });

  final SosDrillStateKind state;
  final Set<SosDrillStep> confirmedSteps;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  SosDrillState copyWith({
    SosDrillStateKind? state,
    Set<SosDrillStep>? confirmedSteps,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) =>
      SosDrillState(
        state: state ?? this.state,
        confirmedSteps: confirmedSteps ?? this.confirmedSteps,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
      );
}

/// The result of one completed drill run, kept for history on the
/// readiness dashboard (SO-001).
class SosDrillRecord {
  const SosDrillRecord({
    required this.runAt,
    required this.result,
    required this.stepsConfirmed,
  });

  final DateTime runAt;
  final SosDrillStateKind result;
  final int stepsConfirmed;
}

/// Derives the drill state from honestly-observed facts: whether the test
/// event exists, whether recipients acknowledged, and whether the location
/// verified. This is a pure function — it never writes anything.
SosDrillState evaluateDrill({
  required DateTime? startedAt,
  required bool acknowledged,
  required bool locationVerified,
}) {
  if (startedAt == null) {
    return SosDrillState(
        state: SosDrillStateKind.notStarted, confirmedSteps: const {});
  }
  final steps = <SosDrillStep>{SosDrillStep.alertSent, SosDrillStep.alertReceived};
  if (acknowledged) steps.add(SosDrillStep.alertAcknowledged);
  if (locationVerified) steps.add(SosDrillStep.locationVerified);
  final passed = steps.length == SosDrillStep.values.length;
  return SosDrillState(
      state: passed ? SosDrillStateKind.passed : SosDrillStateKind.inProgress,
      confirmedSteps: steps,
      startedAt: startedAt,
      finishedAt: passed ? DateTime.now().toUtc() : null);
}
