import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/incident_engine.dart';
import 'package:guardian_ai/domain/policy_engine.dart';

void main() {
  test('higher-priority bedtime policy wins while active', () {
    const engine = PolicyEngine();
    final decision = engine.resolve(
        target: 'com.example.video',
        moment: DateTime(2026, 8, 12, 22),
        policies: const [
          DigitalPolicy(
              id: 'bedtime',
              priority: 100,
              enabled: true,
              startMinute: 1260,
              endMinute: 420,
              restrictedTargets: {'com.example.video'})
        ]);
    expect(decision.restricted, isTrue);
    expect(decision.policyId, 'bedtime');
  });

  test('temporary allow override takes precedence until expiry', () {
    const engine = PolicyEngine();
    final moment = DateTime(2026, 8, 12, 22);
    final decision = engine.resolve(
        target: 'com.example.video',
        moment: moment,
        policies: const [
          DigitalPolicy(
              id: 'bedtime',
              priority: 100,
              enabled: true,
              startMinute: 1260,
              endMinute: 420,
              restrictedTargets: {'com.example.video'})
        ],
        override: TemporaryOverride(
            target: 'com.example.video',
            allowed: true,
            expiresAt: moment.add(const Duration(minutes: 10))));
    expect(decision.restricted, isFalse);
    expect(decision.reason, 'temporary_override');
  });

  test('risk engine creates only threshold-qualified incidents', () {
    const engine = RiskEngine();
    final low = engine.evaluate(SafetyObservation(
        category: SafetyCategory.bullying,
        confidence: 0.2,
        source: 'model',
        observedAt: DateTime.utc(2026),
        modelVersion: 'v1'));
    final high = engine.evaluate(SafetyObservation(
        category: SafetyCategory.bullying,
        confidence: 0.9,
        source: 'model',
        observedAt: DateTime.utc(2026),
        modelVersion: 'v1'));
    expect(low.createIncident, isFalse);
    expect(high.severity, IncidentSeverity.high);
  });

  test('incident and SOS state machines reject invalid delivery claims', () {
    expect(
        IncidentLifecycle.canTransition(
            IncidentState.localPending, IncidentState.acknowledged),
        isTrue);
    expect(
        IncidentLifecycle.canTransition(
            IncidentState.resolved, IncidentState.acknowledged),
        isFalse);
    expect(SosLifecycle.canTransition(SosState.localCreated, SosState.synced),
        isFalse);
    expect(SosLifecycle.canTransition(SosState.pendingSync, SosState.synced),
        isTrue);
    expect(
        SosLifecycle.canTransition(SosState.synced, SosState.notified), isTrue);
    expect(SosLifecycle.canTransition(SosState.notified, SosState.acknowledged),
        isTrue);
  });
}
