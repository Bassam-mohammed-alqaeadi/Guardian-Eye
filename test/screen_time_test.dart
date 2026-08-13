import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'package:guardian_ai/domain/screen_time.dart';

import 'test_database.dart';

DigitalPolicy _dailyPolicy({bool enabled = true}) => DigitalPolicy(
    id: 'youtube-limit',
    familyId: 'family',
    name: 'YouTube daily limit',
    priority: 80,
    enabled: enabled,
    startMinute: 0,
    endMinute: 0,
    restrictedTargets: {'com.google.android.youtube'},
    dailyLimitMinutes: 60,
    version: 3);

ChildDeviceState _activeDevice() => ChildDeviceState(
    deviceId: 'device',
    familyId: 'family',
    memberId: 'child',
    lifecycle: ChildDeviceLifecycle.active,
    requiredPolicyVersion: 3,
    updatedAt: DateTime.utc(2026, 8, 12, 12),
    lastValidPolicyAt: DateTime.utc(2026, 8, 12, 12));

DailyUsageSummary _usage(int minutes) => DailyUsageSummary(
    deviceId: 'device',
    familyId: 'family',
    target: 'com.google.android.youtube',
    dayStart: DateTime.utc(2026, 8, 12),
    totalMilliseconds: Duration(minutes: minutes).inMilliseconds,
    capturedAt: DateTime.utc(2026, 8, 12, 12));

void main() {
  test('screen time evaluation preserves allowance, exceeds exactly at limit, and honors temporary allow',
      () {
    const engine = ScreenTimeEngine();
    final now = DateTime.utc(2026, 8, 12, 12);
    final within = engine.evaluate(
        target: 'com.google.android.youtube',
        moment: now,
        policies: [_dailyPolicy()],
        usage: _usage(58));
    expect(within.status, EnforcementStatus.evaluated);
    expect(within.remaining, const Duration(minutes: 2));
    expect(within.exceeded, isFalse);

    final exceeded = engine.evaluate(
        target: 'com.google.android.youtube',
        moment: now,
        policies: [_dailyPolicy()],
        usage: _usage(60));
    expect(exceeded.status, EnforcementStatus.enforcementRequested);
    expect(exceeded.exceeded, isTrue);
    expect(
        engine
            .toDecision(
                device: _activeDevice(), evaluation: exceeded, currentTime: now)
            .outcome,
        EnforcementOutcome.restrict);

    final overridden = engine.evaluate(
        target: 'com.google.android.youtube',
        moment: now,
        policies: [_dailyPolicy()],
        usage: _usage(70),
        override: TemporaryOverride(
            target: 'com.google.android.youtube',
            allowed: true,
            expiresAt: now.add(const Duration(minutes: 5))));
    expect(overridden.status, EnforcementStatus.evaluated);
    expect(overridden.reason, 'temporary_override');
    expect(overridden.exceeded, isFalse);
  });

  test('usage snapshot is durable, monotonic for its day, and queues a scoped telemetry event',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final child = await families.addChild(familyId: family.id, childName: 'Child');
    final pairing = PairingRepository(database);
    final request = await pairing.createParentAuthorizedRequest(
        familyId: family.id,
        requestedRole: DeviceRole.childDevice,
        targetMemberId: child.id);
    final enrolled = await pairing.verifyAndEnroll(
        requestId: request.id,
        code: request.code,
        memberId: child.id,
        ownerMemberId: 'parent');
    final repo = ChildDeviceRepository(database,
        clock: () => DateTime.utc(2026, 8, 12, 12));
    final deviceId = enrolled.deviceId!;
    await repo.initializeForEnrolledDevice(deviceId);
    final first = await repo.upsertUsageSummary(
        deviceId: deviceId,
        target: 'com.google.android.youtube',
        cumulativeMilliseconds: const Duration(minutes: 58).inMilliseconds,
        observedAt: DateTime.utc(2026, 8, 12, 12));
    final laterLower = await repo.upsertUsageSummary(
        deviceId: deviceId,
        target: 'com.google.android.youtube',
        cumulativeMilliseconds: const Duration(minutes: 20).inMilliseconds,
        observedAt: DateTime.utc(2026, 8, 12, 13));
    expect(first.totalDuration, const Duration(minutes: 58));
    expect(laterLower.totalDuration, const Duration(minutes: 58));
    final db = await database.database;
    final outbox = await db.query('outbox',
        where: 'operation = ?', whereArgs: ['child.usage.observed']);
    expect(outbox, hasLength(2));
    final payload = jsonDecode(outbox.first['payload_json']! as String)
        as Map<String, dynamic>;
    expect(payload['familyId'], family.id);
    expect(payload['deviceId'], deviceId);
    expect(payload['target'], 'com.google.android.youtube');
    expect(payload['totalMilliseconds'], const Duration(minutes: 58).inMilliseconds);
    await database.close();
  });
}
