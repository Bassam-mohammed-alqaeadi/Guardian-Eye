import 'policy_engine.dart';

enum ChildDeviceLifecycle {
  unlinked,
  pairingPending,
  enrolled,
  active,
  offline,
  restricted,
  suspended,
  revoked,
  recovering
}

enum EnforcementOutcome {
  allow,
  warn,
  restrict,
  bedtime,
  temporaryAllow,
  noEnforcement,
  policyStale,
  deviceRevoked
}

class ChildDeviceState {
  const ChildDeviceState(
      {required this.deviceId,
      required this.familyId,
      required this.memberId,
      required this.lifecycle,
      required this.requiredPolicyVersion,
      required this.updatedAt,
      this.lastValidPolicyAt,
      this.lastEvaluationAt,
      this.lastDecision,
      this.lastSyncAt,
      this.failureCode});

  final String deviceId;
  final String familyId;
  final String memberId;
  final ChildDeviceLifecycle lifecycle;
  final int requiredPolicyVersion;
  final DateTime updatedAt;
  final DateTime? lastValidPolicyAt;
  final DateTime? lastEvaluationAt;
  final EnforcementOutcome? lastDecision;
  final DateTime? lastSyncAt;
  final String? failureCode;

  factory ChildDeviceState.fromMap(Map<String, Object?> map) =>
      ChildDeviceState(
          deviceId: map['device_id']! as String,
          familyId: map['family_id']! as String,
          memberId: map['member_id']! as String,
          lifecycle:
              ChildDeviceLifecycle.values.byName(map['lifecycle']! as String),
          requiredPolicyVersion: map['required_policy_version']! as int,
          updatedAt: DateTime.parse(map['updated_at']! as String),
          lastValidPolicyAt: map['last_valid_policy_at'] == null
              ? null
              : DateTime.parse(map['last_valid_policy_at']! as String),
          lastEvaluationAt: map['last_evaluation_at'] == null
              ? null
              : DateTime.parse(map['last_evaluation_at']! as String),
          lastDecision: map['last_decision'] == null
              ? null
              : EnforcementOutcome.values
                  .byName(map['last_decision']! as String),
          lastSyncAt: map['last_sync_at'] == null
              ? null
              : DateTime.parse(map['last_sync_at']! as String),
          failureCode: map['failure_code'] as String?);
}

class ChildDeviceStateMachine {
  const ChildDeviceStateMachine();

  bool canTransition(ChildDeviceLifecycle from, ChildDeviceLifecycle to) {
    if (from == to) return true;
    return switch (from) {
      ChildDeviceLifecycle.unlinked =>
        to == ChildDeviceLifecycle.pairingPending,
      ChildDeviceLifecycle.pairingPending => {
          ChildDeviceLifecycle.unlinked,
          ChildDeviceLifecycle.enrolled,
          ChildDeviceLifecycle.revoked
        }.contains(to),
      ChildDeviceLifecycle.enrolled => {
          ChildDeviceLifecycle.recovering,
          ChildDeviceLifecycle.active,
          ChildDeviceLifecycle.offline,
          ChildDeviceLifecycle.suspended,
          ChildDeviceLifecycle.revoked
        }.contains(to),
      ChildDeviceLifecycle.active ||
      ChildDeviceLifecycle.offline ||
      ChildDeviceLifecycle.restricted ||
      ChildDeviceLifecycle.suspended =>
        {
          ChildDeviceLifecycle.active,
          ChildDeviceLifecycle.offline,
          ChildDeviceLifecycle.restricted,
          ChildDeviceLifecycle.suspended,
          ChildDeviceLifecycle.recovering,
          ChildDeviceLifecycle.revoked
        }.contains(to),
      ChildDeviceLifecycle.recovering => {
          ChildDeviceLifecycle.active,
          ChildDeviceLifecycle.offline,
          ChildDeviceLifecycle.restricted,
          ChildDeviceLifecycle.suspended,
          ChildDeviceLifecycle.revoked
        }.contains(to),
      ChildDeviceLifecycle.revoked => false,
    };
  }

  ChildDeviceState transition(ChildDeviceState state, ChildDeviceLifecycle to,
      {required DateTime at, String? failureCode}) {
    if (!canTransition(state.lifecycle, to)) {
      throw StateError(
          'invalid_child_device_transition:${state.lifecycle.name}->${to.name}');
    }
    return ChildDeviceState(
        deviceId: state.deviceId,
        familyId: state.familyId,
        memberId: state.memberId,
        lifecycle: to,
        requiredPolicyVersion: state.requiredPolicyVersion,
        updatedAt: at.toUtc(),
        lastValidPolicyAt: state.lastValidPolicyAt,
        lastEvaluationAt: state.lastEvaluationAt,
        lastDecision: state.lastDecision,
        lastSyncAt: state.lastSyncAt,
        failureCode: failureCode);
  }
}

class DeliveredChildPolicy {
  const DeliveredChildPolicy(
      {required this.deviceId,
      required this.policy,
      required this.deliveredAt});

  final String deviceId;
  final DigitalPolicy policy;
  final DateTime deliveredAt;
}

class ChildPolicyResolution {
  const ChildPolicyResolution(
      {required this.isValid,
      required this.restricted,
      required this.reason,
      this.policyId,
      this.policyVersion,
      this.temporaryOverrideActive = false});

  final bool isValid;
  final bool restricted;
  final String reason;
  final String? policyId;
  final int? policyVersion;
  final bool temporaryOverrideActive;
}

class ChildPolicyResolver {
  const ChildPolicyResolver();

  ChildPolicyResolution resolve(
      {required ChildDeviceState device,
      required String target,
      required DateTime moment,
      required Iterable<DeliveredChildPolicy> deliveries,
      Iterable<StoredPolicyOverride> overrides = const [],
      Duration maxPolicyAge = const Duration(days: 7)}) {
    final now = moment.toUtc();
    if (device.lifecycle == ChildDeviceLifecycle.revoked) {
      return const ChildPolicyResolution(
          isValid: false, restricted: false, reason: 'device_revoked');
    }
    final scoped = deliveries
        .where((delivery) => delivery.deviceId == device.deviceId)
        .toList();
    if (scoped.isEmpty || device.lastValidPolicyAt == null) {
      return const ChildPolicyResolution(
          isValid: false, restricted: false, reason: 'policy_missing');
    }
    final highestVersion = scoped.fold<int>(
        0,
        (highest, delivery) => delivery.policy.version > highest
            ? delivery.policy.version
            : highest);
    if (highestVersion < device.requiredPolicyVersion) {
      return ChildPolicyResolution(
          isValid: false,
          restricted: false,
          reason: 'policy_version_stale',
          policyVersion: highestVersion);
    }
    if (now.difference(device.lastValidPolicyAt!.toUtc()) > maxPolicyAge) {
      return ChildPolicyResolution(
          isValid: false,
          restricted: false,
          reason: 'policy_age_stale',
          policyVersion: highestVersion);
    }
    StoredPolicyOverride? activeOverride;
    for (final override in overrides) {
      if (override.target == target &&
          (override.childDeviceId == null ||
              override.childDeviceId == device.deviceId) &&
          override.isActiveAt(now)) {
        activeOverride = override;
        break;
      }
    }
    final decision = const PolicyEngine().resolve(
        target: target,
        moment: now,
        policies: scoped.map((delivery) => delivery.policy),
        override: activeOverride);
    final policy = decision.policyId == null
        ? null
        : scoped
            .where((delivery) => delivery.policy.id == decision.policyId)
            .map((delivery) => delivery.policy)
            .firstOrNull;
    return ChildPolicyResolution(
        isValid: true,
        restricted: decision.restricted,
        reason: decision.reason,
        policyId: decision.policyId,
        policyVersion: policy?.version ?? highestVersion,
        temporaryOverrideActive: decision.reason == 'temporary_override');
  }
}

class EnforcementDecision {
  const EnforcementDecision(
      {required this.outcome,
      required this.reason,
      required this.evaluatedAt,
      this.policyId,
      this.policyVersion});

  final EnforcementOutcome outcome;
  final String reason;
  final DateTime evaluatedAt;
  final String? policyId;
  final int? policyVersion;
}

class EnforcementEngine {
  const EnforcementEngine();

  EnforcementDecision decide(
      {required ChildDeviceState device,
      required ChildPolicyResolution resolution,
      required DateTime currentTime}) {
    final now = currentTime.toUtc();
    if (device.lifecycle == ChildDeviceLifecycle.revoked) {
      return EnforcementDecision(
          outcome: EnforcementOutcome.deviceRevoked,
          reason: 'device_revoked',
          evaluatedAt: now);
    }
    if (device.lifecycle == ChildDeviceLifecycle.suspended ||
        device.lifecycle == ChildDeviceLifecycle.unlinked ||
        device.lifecycle == ChildDeviceLifecycle.pairingPending) {
      return EnforcementDecision(
          outcome: EnforcementOutcome.noEnforcement,
          reason: 'device_not_enforcement_ready',
          evaluatedAt: now);
    }
    if (!resolution.isValid) {
      return EnforcementDecision(
          outcome: EnforcementOutcome.policyStale,
          reason: resolution.reason,
          evaluatedAt: now,
          policyVersion: resolution.policyVersion);
    }
    if (resolution.temporaryOverrideActive) {
      return EnforcementDecision(
          outcome: EnforcementOutcome.temporaryAllow,
          reason: resolution.reason,
          evaluatedAt: now,
          policyId: resolution.policyId,
          policyVersion: resolution.policyVersion);
    }
    return EnforcementDecision(
        outcome: resolution.restricted
            ? EnforcementOutcome.restrict
            : EnforcementOutcome.allow,
        reason: resolution.reason,
        evaluatedAt: now,
        policyId: resolution.policyId,
        policyVersion: resolution.policyVersion);
  }
}

/// M8 enforcement vocabulary. Appended without modifying the existing
/// enforcement engine; the states deliberately distinguish the four
/// non-interchangeable facts: policy exists, decision says over-limit,
/// enforcement requested, enforcement applied. Raw enum names are never
/// exposed to users — UI strings live in localization.
enum EnforcementState {
  /// No restriction evaluation has been requested yet.
  notRequested,

  /// Android usage-access permission must be granted before observation.
  permissionRequired,

  /// The device cannot observe or enforce (API unavailable).
  unsupported,

  /// A fresh policy exists and a decision can be evaluated.
  evaluationReady,

  /// A restriction decision exists and the OS action is being verified.
  enforcementRequested,

  /// Android confirmed the OS-level action (verified result).
  enforcementApplied,

  /// The OS action could not be confirmed.
  enforcementFailed,

  /// No valid fresh policy: restriction is honestly suspended.
  policyStale,

  /// The device cannot sync with the parent backend right now.
  deviceOffline,

  /// A recovery mechanism (boot, reopen, sync) is restoring enforcement.
  recoveryPending,

  /// The child manually revoked usage-access permission.
  permissionDenied
}

/// The verified result of applying a restriction on Android. Only
/// [EnforcementApplication.applied] counts as "Enforcement Applied".
enum EnforcementApplication { notRequested, requested, applied, failed }

/// Local durable enforcement row stored in the device repository.
class EnforcementStateRecord {
  const EnforcementStateRecord({
    required this.deviceId,
    required this.state,
    required this.outcome,
    required this.reason,
    required this.decidedAt,
    required this.appliedAt,
    required this.policyVersion,
    required this.enqueuedForSync,
  });
  final String deviceId;
  final EnforcementState state;
  final EnforcementOutcome? outcome;
  final String reason;
  final DateTime decidedAt;
  final DateTime? appliedAt;
  final int? policyVersion;
  final bool enqueuedForSync;

  /// Offline-safe freshness: a stale policy may not silently keep an
  /// old restriction active beyond the documented watermark.
  bool isWithinFreshnessWindow(DateTime now, {Duration maxAge = const Duration(days: 7)}) =>
      now.difference(decidedAt.toUtc()) <= maxAge;

  Map<String, Object?> toRow() => {
        'device_id': deviceId,
        'state': state.name,
        'outcome': outcome?.name,
        'reason': reason,
        'decided_at': decidedAt.toIso8601String(),
        'applied_at': appliedAt?.toIso8601String(),
        'policy_version': policyVersion,
        // Stored as 0/1 INTEGER — the sqflite FFI runtime rejects bool
        // values inside SQL statements, so booleans are normalized here.
        'enqueued_for_sync': enqueuedForSync ? 1 : 0,
      };

  factory EnforcementStateRecord.fromRow(Map<String, Object?> row) =>
      EnforcementStateRecord(
        deviceId: row['device_id'] as String,
        state: EnforcementState.values.firstWhere(
            (candidate) => candidate.name == row['state']),
        outcome: (row['outcome'] as String?) == null
            ? null
            : EnforcementOutcome.values
                .firstWhere((candidate) => candidate.name == row['outcome']),
        reason: row['reason'] as String,
        decidedAt: DateTime.parse(row['decided_at'] as String),
        appliedAt: (row['applied_at'] as String?) == null
            ? null
            : DateTime.parse(row['applied_at'] as String),
        policyVersion: row['policy_version'] as int?,
        enqueuedForSync: (row['enqueued_for_sync'] is int)
            ? (row['enqueued_for_sync'] as int) == 1
            : (row['enqueued_for_sync'] ?? 0) == 1,
      );
}

/// The sync evidence of the most recent enforcement record delivery.
enum EnforcementSyncState { synced, syncPending, syncFailed, neverSynced, offlineCached }

/// Snapshot presented to the child-context UI for the M8 enforcement section.
class EnforcementApplicationSnapshot {
  const EnforcementApplicationSnapshot({
    required this.deviceId,
    required this.state,
    required this.application,
    required this.freshness,
    required this.syncState,
    required this.decisionReason,
    required this.decidedAt,
    required this.appliedAt,
    required this.policyVersion,
  });
  final String deviceId;
  final EnforcementState state;
  final EnforcementApplication application;
  final bool freshness;
  final EnforcementSyncState syncState;
  final String decisionReason;
  final DateTime? decidedAt;
  final DateTime? appliedAt;
  final int? policyVersion;
}
