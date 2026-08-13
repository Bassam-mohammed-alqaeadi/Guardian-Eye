import 'guardian_models.dart';

class DigitalPolicy {
  const DigitalPolicy(
      {required this.id,
      required this.priority,
      required this.enabled,
      required this.startMinute,
      required this.endMinute,
      required this.restrictedTargets,
      this.familyId = '',
      this.name = '',
      this.version = 1,
      this.dailyLimitMinutes,
      this.syncState = SyncState.localOnly});
  final String id;
  final String familyId;
  final String name;
  final int priority;
  final bool enabled;
  final int startMinute;
  final int endMinute;
  final Set<String> restrictedTargets;
  final int version;
  final int? dailyLimitMinutes;
  final SyncState syncState;

  bool isActiveAt(DateTime moment) {
    if (!enabled) {
      return false;
    }
    final minute = moment.hour * 60 + moment.minute;
    if (startMinute == endMinute) {
      return true;
    }
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
  }
}

class TemporaryOverride {
  const TemporaryOverride(
      {required this.target, required this.expiresAt, required this.allowed});
  final String target;
  final DateTime expiresAt;
  final bool allowed;
  bool isActiveAt(DateTime moment) => expiresAt.isAfter(moment);
}

class StoredPolicyOverride extends TemporaryOverride {
  const StoredPolicyOverride(
      {required this.id,
      required this.familyId,
      required this.createdByMemberId,
      required this.createdAt,
      required super.target,
      required super.expiresAt,
      required super.allowed,
      required this.syncState,
      this.childDeviceId});
  final String id;
  final String familyId;
  final String createdByMemberId;
  final DateTime createdAt;
  final SyncState syncState;
  final String? childDeviceId;
}

class PolicyDecision {
  const PolicyDecision(
      {required this.restricted, this.policyId, required this.reason});
  final bool restricted;
  final String? policyId;
  final String reason;
}

class PolicyEngine {
  const PolicyEngine();
  PolicyDecision resolve(
      {required String target,
      required DateTime moment,
      required Iterable<DigitalPolicy> policies,
      TemporaryOverride? override}) {
    if (override != null &&
        override.target == target &&
        override.isActiveAt(moment)) {
      return PolicyDecision(
          restricted: !override.allowed, reason: 'temporary_override');
    }
    final active = policies
        .where((policy) =>
            policy.dailyLimitMinutes == null &&
            policy.isActiveAt(moment) &&
            policy.restrictedTargets.contains(target))
        .toList()
      ..sort((left, right) => right.priority.compareTo(left.priority));
    if (active.isEmpty) {
      return const PolicyDecision(
          restricted: false, reason: 'no_active_policy');
    }
    return PolicyDecision(
        restricted: true,
        policyId: active.first.id,
        reason: 'highest_priority_policy');
  }
}
