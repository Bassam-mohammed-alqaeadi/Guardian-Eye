import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'package:guardian_ai/application/child_enforcement_coordinator.dart';
import 'package:guardian_ai/core/platform/android_enforcement_adapter.dart';
import 'package:guardian_ai/core/platform/enforcement_platform_channel.dart';
import 'test_database.dart';

void main() {
  test('probe bool source with seeded device', () async {
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
    var deviceId = enrollment.deviceId!;
    final repo = ChildDeviceRepository(database,
        clock: () => DateTime.utc(2026, 8, 12, 22));
    await repo.initializeForEnrolledDevice(deviceId);
    // wipe in FK-safe order (dependent tables before their parents)
    final db = await database.database;
    for (final table in [
      'child_enforcement_evaluations',
      'child_enforcement_states',
      'child_device_policies',
      'child_device_states',
      'pairing_sessions',
      'family_invitations',
      'devices',
      'family_members',
      'outbox',
      'policies',
      'policy_overrides',
      'incidents',
      'messages',
      'locations',
      'sos_events',
      'notification_events',
      'notification_tokens',
      'families',
    ]) {
      try {
        await db.delete(table);
      } catch (_) {}
      print('deleted $table ok');
    }
    // reseed a fresh family/device after the wipe
    final family2 =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final child2 =
        await families.addChild(familyId: family2.id, childName: 'Child');
    final request2 = await pairings.createParentAuthorizedRequest(
        familyId: family2.id,
        requestedRole: DeviceRole.childDevice,
        targetMemberId: child2.id);
    final enrollment2 = await pairings.verifyAndEnroll(
        requestId: request2.id,
        code: request2.code,
        memberId: child2.id,
        ownerMemberId: 'parent');
    deviceId = enrollment2.deviceId!;
    await repo.initializeForEnrolledDevice(deviceId);
    await repo.deliverPolicy(
        deviceId: deviceId,
        policy: DigitalPolicy(
            id: 'probe-daily',
            familyId: family2.id,
            name: 'Probe daily',
            priority: 50,
            enabled: true,
            startMinute: 0,
            endMinute: 1439,
            restrictedTargets: {'video'},
            version: 1,
            syncState: SyncState.localOnly),
        knownMinimumVersion: 1);
    print('re-seeded');
    final adapter = AndroidEnforcementAdapter(platform: EnforcementPlatformChannel());
    final coordinator = ChildEnforcementCoordinator(repo, adapter);
    try {
      final snapshot = await coordinator.evaluate(deviceId,
          moment: DateTime.utc(2026, 8, 14));
      print('eval state=${snapshot.state} sync=${snapshot.syncState}');
    } catch (e, st) { print('eval fail: $e'); print(st); }
    try {
      final records = await repo.pendingEnforcementSyncRowsForDevice(deviceId: deviceId);
      print('pending=${records.length}');
    } catch (e, st) { print('pending fail: $e'); print(st); }
  });
}
