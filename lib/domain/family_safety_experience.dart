import 'child_device_enforcement.dart';
import 'child_exception_request.dart';
import 'guardian_models.dart';
import 'policy_engine.dart';
import 'screen_time.dart';

class ChildDailySafetySnapshot {
  const ChildDailySafetySnapshot(
      {required this.child,
      required this.devices,
      required this.policies,
      required this.activeOverrides,
      required this.pendingRequests,
      required this.queuedOperations});
  final FamilyMember child;
  final List<ChildDeviceDailySafety> devices;
  final List<DigitalPolicy> policies;
  final List<StoredPolicyOverride> activeOverrides;
  final List<ChildExceptionRequest> pendingRequests;
  final int queuedOperations;
}

class ChildDeviceDailySafety {
  const ChildDeviceDailySafety(
      {required this.deviceId,
      required this.state,
      required this.usage,
      required this.pendingRequests});
  final String deviceId;
  final ChildDeviceState? state;
  final List<DailyUsageSummary> usage;
  final List<ChildExceptionRequest> pendingRequests;
}

enum SafetyTimelineKind {
  policyCreated,
  policyUpdated,
  policyDelivered,
  usageMeasured,
  limitEvaluated,
  exceptionRequested,
  exceptionApproved,
  exceptionDenied,
  exceptionExpired,
  exceptionCancelled,
  deviceChanged,
  other
}

class SafetyTimelineEvent {
  const SafetyTimelineEvent(
      {required this.id,
      required this.familyId,
      required this.kind,
      required this.occurredAt,
      required this.titleKey,
      required this.syncState,
      this.detail});
  final String id;
  final String familyId;
  final SafetyTimelineKind kind;
  final DateTime occurredAt;
  final String titleKey;
  final String? detail;
  final SyncState syncState;
}
