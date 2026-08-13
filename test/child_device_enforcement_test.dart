import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';

import 'test_database.dart';

ChildDeviceState _state({
  ChildDeviceLifecycle lifecycle = ChildDeviceLifecycle.active,
  int requiredVersion = 2,
  DateTime? validAt,
}) =>
    ChildDeviceState(
        deviceId: 'child-device',
        familyId: 'family',
        memberId: 'child',
        lifecycle: lifecycle,
        requiredPolicyVersion: requiredVersion,
        updatedAt: DateTime.utc(2026, 8, 12, 12),
        lastValidPolicyAt: validAt ?? DateTime.utc(2026, 8, 12, 12));

DeliveredChildPolicy _delivery({int version = 2, int priority = 50}) =>
    DeliveredChildPolicy(
        deviceId: 'child-device',
        deliveredAt: DateTime.utc(2026, 8, 12, 12),
        policy: DigitalPolicy(
            id: 'bedtime',
            familyId: 'family',
            name: 'Bedtime',
            priority: priority,
            enabled: true,
            startMinute: 0,
            endMinute: 0,
            restrictedTargets: {'video'},
            version: version));

void main() {
  test(
      'child lifecycle allows only explicit transitions and revocation is terminal',
      () {
    const machine = ChildDeviceStateMachine();
    expect(
        machine.canTransition(
            ChildDeviceLifecycle.unlinked, ChildDeviceLifecycle.pairingPending),
        isTrue);
    expect(
        machine.canTransition(
            ChildDeviceLifecycle.unlinked, ChildDeviceLifecycle.active),
        isFalse);
    expect(
        machine.canTransition(
            ChildDeviceLifecycle.revoked, ChildDeviceLifecycle.active),
        isFalse);
    expect(
        () => machine.transition(
            _state(lifecycle: ChildDeviceLifecycle.revoked),
            ChildDeviceLifecycle.active,
            at: DateTime.utc(2026, 8, 12, 12)),
        throwsStateError);
  });

  test(
      'child policy resolver honors version, expiry, override, offline and revocation',
      () {
    const resolver = ChildPolicyResolver();
    const engine = EnforcementEngine();
    final now = DateTime.utc(2026, 8, 12, 22);
    final restricted = resolver.resolve(
        device: _state(validAt: now),
        target: 'video',
        moment: now,
        deliveries: [_delivery()]);
    expect(restricted.isValid, isTrue);
    expect(restricted.restricted, isTrue);
    expect(
        engine
            .decide(
                device: _state(validAt: now),
                resolution: restricted,
                currentTime: now)
            .outcome,
        EnforcementOutcome.restrict);

    final temporaryAllow = resolver.resolve(
        device: _state(validAt: now),
        target: 'video',
        moment: now,
        deliveries: [
          _delivery()
        ],
        overrides: [
          StoredPolicyOverride(
              id: 'override',
              familyId: 'family',
              createdByMemberId: 'parent',
              createdAt: now,
              target: 'video',
              allowed: true,
              expiresAt: now.add(const Duration(minutes: 5)),
              syncState: SyncState.localOnly)
        ]);
    expect(temporaryAllow.temporaryOverrideActive, isTrue);
    expect(
        engine
            .decide(
                device: _state(validAt: now),
                resolution: temporaryAllow,
                currentTime: now)
            .outcome,
        EnforcementOutcome.temporaryAllow);

    final staleVersion = resolver.resolve(
        device: _state(requiredVersion: 3, validAt: now),
        target: 'video',
        moment: now,
        deliveries: [_delivery(version: 2)]);
    expect(staleVersion.reason, 'policy_version_stale');
    expect(
        engine
            .decide(
                device: _state(requiredVersion: 3, validAt: now),
                resolution: staleVersion,
                currentTime: now)
            .outcome,
        EnforcementOutcome.policyStale);

    final staleAge = resolver.resolve(
        device: _state(validAt: now.subtract(const Duration(days: 8))),
        target: 'video',
        moment: now,
        deliveries: [_delivery()]);
    expect(staleAge.reason, 'policy_age_stale');

    final revoked = resolver.resolve(
        device: _state(lifecycle: ChildDeviceLifecycle.revoked, validAt: now),
        target: 'video',
        moment: now,
        deliveries: [_delivery()]);
    expect(revoked.reason, 'device_revoked');
  });

  test(
      'enrolling a child creates durable state and versioned delivery is transactional',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final child =
        await families.addChild(familyId: family.id, childName: 'Child');
    final pairings = PairingRepository(database);
    final request = await pairings.createParentAuthorizedRequest(
        familyId: family.id,
        requestedRole: DeviceRole.childDevice,
        targetMemberId: child.id);
    final enrollment = await pairings.verifyAndEnroll(
        requestId: request.id,
        code: request.code,
        memberId: child.id,
        ownerMemberId: 'parent');
    final deviceId = enrollment.deviceId!;
    final repository = ChildDeviceRepository(database,
        clock: () => DateTime.utc(2026, 8, 12, 22));
    expect((await repository.getState(deviceId))!.lifecycle,
        ChildDeviceLifecycle.enrolled);

    final policy = DigitalPolicy(
        id: 'bedtime',
        familyId: family.id,
        name: 'Bedtime',
        priority: 50,
        enabled: true,
        startMinute: 1260,
        endMinute: 420,
        restrictedTargets: {'video'},
        version: 2);
    expect(
        await repository.deliverPolicy(
            deviceId: deviceId, policy: policy, knownMinimumVersion: 2),
        ChildPolicyDeliveryResult.applied);
    expect(
        await repository.deliverPolicy(
            deviceId: deviceId, policy: policy, knownMinimumVersion: 2),
        ChildPolicyDeliveryResult.idempotent);
    final older = DigitalPolicy(
        id: policy.id,
        familyId: policy.familyId,
        name: policy.name,
        priority: policy.priority,
        enabled: policy.enabled,
        startMinute: policy.startMinute,
        endMinute: policy.endMinute,
        restrictedTargets: policy.restrictedTargets,
        version: 1);
    expect(
        await repository.deliverPolicy(
            deviceId: deviceId, policy: older, knownMinimumVersion: 2),
        ChildPolicyDeliveryResult.ignoredOlder);
    expect((await repository.deliveredPolicies(deviceId)).single.policy.version,
        2);
    final decision = const EnforcementEngine().decide(
        device: (await repository.getState(deviceId))!,
        resolution: ChildPolicyResolution(
            isValid: true,
            restricted: true,
            reason: 'policy_match',
            policyId: policy.id,
            policyVersion: policy.version),
        currentTime: DateTime.utc(2026, 8, 12, 22));
    expect(
        (await repository.recordEvaluation(
                deviceId: deviceId, decision: decision))
            .lifecycle,
        ChildDeviceLifecycle.restricted);
    final db = await database.database;
    expect(
        (await db.query('child_enforcement_evaluations',
                where: 'device_id = ?', whereArgs: [deviceId]))
            .single['outcome'],
        'restrict');
    await database.close();
  });
}
