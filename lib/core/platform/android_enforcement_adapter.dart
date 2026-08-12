import '../../domain/child_device_enforcement.dart';

enum AndroidApplicationStatus {
  notRequested,
  notApplicable,
  unsupported,
  blockedByPermission,
  deferred,
  applied
}

class AndroidEnforcementResult {
  const AndroidEnforcementResult(
      {required this.status, required this.reason, required this.decision});
  final AndroidApplicationStatus status;
  final String reason;
  final EnforcementDecision decision;
}

/// This adapter is intentionally conservative. It exposes the boundary between
/// a domain restriction intent and an OS action; Phase 14 does not implement
/// app blocking and therefore never returns [AndroidApplicationStatus.applied]
/// for a restriction.
class AndroidEnforcementAdapter {
  const AndroidEnforcementAdapter();

  AndroidEnforcementResult apply(EnforcementDecision decision) {
    return switch (decision.outcome) {
      EnforcementOutcome.restrict ||
      EnforcementOutcome.bedtime =>
        AndroidEnforcementResult(
            status: AndroidApplicationStatus.unsupported,
            reason: 'android_app_blocking_not_implemented',
            decision: decision),
      EnforcementOutcome.policyStale => AndroidEnforcementResult(
          status: AndroidApplicationStatus.deferred,
          reason: 'policy_requires_fresh_delivery',
          decision: decision),
      EnforcementOutcome.deviceRevoked => AndroidEnforcementResult(
          status: AndroidApplicationStatus.notApplicable,
          reason: 'device_revoked',
          decision: decision),
      _ => AndroidEnforcementResult(
          status: AndroidApplicationStatus.notApplicable,
          reason: 'no_android_action_requested',
          decision: decision),
    };
  }
}
