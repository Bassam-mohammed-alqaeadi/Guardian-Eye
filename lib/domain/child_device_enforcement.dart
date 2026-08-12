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
