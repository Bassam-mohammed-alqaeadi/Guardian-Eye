import 'guardian_models.dart';

class ModelArtifactRequired implements Exception {
  const ModelArtifactRequired();
}

abstract class SafetyModelAdapter {
  String get modelVersion;
  Future<SafetyObservation?> analyze(
      {required String source,
      required String contentReference,
      required DateTime observedAt});
}

class UnconfiguredSafetyModelAdapter implements SafetyModelAdapter {
  const UnconfiguredSafetyModelAdapter();
  @override
  String get modelVersion => 'unconfigured';
  @override
  Future<SafetyObservation?> analyze(
          {required String source,
          required String contentReference,
          required DateTime observedAt}) =>
      throw const ModelArtifactRequired();
}

class RiskDecision {
  const RiskDecision(
      {required this.createIncident, this.severity, required this.reason});
  final bool createIncident;
  final IncidentSeverity? severity;
  final String reason;
}

class RiskEngine {
  const RiskEngine(
      {this.mediumThreshold = 0.65,
      this.highThreshold = 0.82,
      this.criticalThreshold = 0.94});
  final double mediumThreshold;
  final double highThreshold;
  final double criticalThreshold;
  RiskDecision evaluate(SafetyObservation observation) {
    if (observation.confidence < mediumThreshold) {
      return const RiskDecision(
          createIncident: false, reason: 'below_threshold');
    }
    if (observation.confidence >= criticalThreshold) {
      return const RiskDecision(
          createIncident: true,
          severity: IncidentSeverity.critical,
          reason: 'critical_threshold');
    }
    if (observation.confidence >= highThreshold) {
      return const RiskDecision(
          createIncident: true,
          severity: IncidentSeverity.high,
          reason: 'high_threshold');
    }
    return const RiskDecision(
        createIncident: true,
        severity: IncidentSeverity.medium,
        reason: 'medium_threshold');
  }
}

class IncidentLifecycle {
  static bool canTransition(IncidentState from, IncidentState to) =>
      switch (from) {
        IncidentState.detected => to == IncidentState.localPending,
        IncidentState.localPending => {
            IncidentState.synced,
            IncidentState.delivered,
            IncidentState.acknowledged
          }.contains(to),
        IncidentState.synced =>
          {IncidentState.delivered, IncidentState.acknowledged}.contains(to),
        IncidentState.delivered =>
          {IncidentState.acknowledged, IncidentState.resolved}.contains(to),
        IncidentState.acknowledged => to == IncidentState.resolved,
        IncidentState.resolved => false,
      };
}

enum SosState {
  localCreated,
  pendingSync,
  synced,
  notified,
  acknowledged,
  failed,
  cancelled
}

enum NotificationState {
  pendingBackend,
  queued,
  notified,
  acknowledged,
  failed
}

class ParentNotificationContract {
  const ParentNotificationContract(
      {required this.id,
      required this.familyId,
      required this.kind,
      required this.state});
  final String id;
  final String familyId;
  final String kind;
  final NotificationState state;
}

class SosLifecycle {
  static bool canTransition(SosState from, SosState to) => switch (from) {
        SosState.localCreated =>
          {SosState.pendingSync, SosState.cancelled}.contains(to),
        SosState.pendingSync =>
          {SosState.synced, SosState.failed, SosState.cancelled}.contains(to),
        SosState.synced =>
          {SosState.notified, SosState.acknowledged}.contains(to),
        SosState.notified => SosState.acknowledged == to,
        SosState.failed =>
          {SosState.pendingSync, SosState.cancelled}.contains(to),
        SosState.acknowledged || SosState.cancelled => false,
      };
}
