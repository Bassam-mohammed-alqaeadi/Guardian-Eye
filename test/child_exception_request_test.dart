import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/child_exception_request_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/policy_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/child_exception_request.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

import 'test_database.dart';

class _Fixture {
  _Fixture(
      {required this.database,
      required this.familyId,
      required this.childId,
      required this.deviceId,
      required this.parentId,
      required this.requests,
      required this.policies});
  final dynamic database;
  final String familyId;
  final String childId;
  final String deviceId;
  final String parentId;
  final ChildExceptionRequestRepository requests;
  final PolicyRepository policies;
}

Future<_Fixture> _fixture(DateTime Function() clock) async {
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
  final childRepo = ChildDeviceRepository(database, clock: clock);
  await childRepo.initializeForEnrolledDevice(enrolled.deviceId!);
  final policies = PolicyRepository(database);
  final parentId = await policies.primaryParentMemberId(family.id);
  return _Fixture(
      database: database,
      familyId: family.id,
      childId: child.id,
      deviceId: enrolled.deviceId!,
      parentId: parentId,
      requests: ChildExceptionRequestRepository(database, policies, clock: clock),
      policies: policies);
}

void main() {
  test('exception request validates identity/duration and rejects duplicate pending target',
      () async {
    var now = DateTime.utc(2026, 8, 12, 12);
    final fixture = await _fixture(() => now);
    await expectLater(
        fixture.requests.create(
            familyId: fixture.familyId,
            childDeviceId: fixture.deviceId,
            childUid: 'child-uid',
            target: 'com.google.android.youtube',
            duration: Duration.zero,
            reason: ChildExceptionReason.homework),
        throwsArgumentError);
    final created = await fixture.requests.create(
        familyId: fixture.familyId,
        childDeviceId: fixture.deviceId,
        childUid: 'child-uid',
        target: 'com.google.android.youtube',
        duration: const Duration(minutes: 20),
        reason: ChildExceptionReason.homework);
    expect(created.status, ChildExceptionRequestStatus.pending);
    await expectLater(
        fixture.requests.create(
            familyId: fixture.familyId,
            childDeviceId: fixture.deviceId,
            childUid: 'child-uid',
            target: 'com.google.android.youtube',
            duration: const Duration(minutes: 20),
            reason: ChildExceptionReason.homework),
        throwsStateError);
    await fixture.database.close();
  });

  test('parent approval atomically writes approved request, existing override, and durable outbox events',
      () async {
    final now = DateTime.utc(2026, 8, 12, 12);
    final fixture = await _fixture(() => now);
    final requested = await fixture.requests.create(
        familyId: fixture.familyId,
        childDeviceId: fixture.deviceId,
        childUid: 'child-uid',
        target: 'com.google.android.youtube',
        duration: const Duration(minutes: 30),
        reason: ChildExceptionReason.schoolAssignment);
    final approved = await fixture.requests
        .approve(requestId: requested.id, parentMemberId: fixture.parentId);
    expect(approved.status, ChildExceptionRequestStatus.approved);
    expect(approved.overrideId, isNotNull);
    final overrides = await fixture.policies.overridesForFamily(fixture.familyId);
    expect(overrides.single.id, approved.overrideId);
    final db = await fixture.database.database;
    final events = await db.query('outbox',
        where: 'aggregate_id = ?', whereArgs: [requested.id]);
    expect(events.map((row) => row['operation']),
        containsAll(['child.exception.requested', 'child.exception.approved']));
    final overrideEvents = await db.query('outbox',
        where: 'aggregate_id = ?', whereArgs: [approved.overrideId]);
    expect(overrideEvents.single['operation'], 'policy.override.created');
    await fixture.database.close();
  });

  test('unauthorized approval rolls back without override and pending request can deny or cancel only through valid actor',
      () async {
    final now = DateTime.utc(2026, 8, 12, 12);
    final fixture = await _fixture(() => now);
    final requested = await fixture.requests.create(
        familyId: fixture.familyId,
        childDeviceId: fixture.deviceId,
        childUid: 'child-uid',
        target: 'com.google.android.youtube',
        duration: const Duration(minutes: 10),
        reason: ChildExceptionReason.importantCommunication);
    await expectLater(
        fixture.requests.approve(
            requestId: requested.id, parentMemberId: fixture.childId),
        throwsStateError);
    expect((await fixture.requests.forFamily(fixture.familyId)).single.status,
        ChildExceptionRequestStatus.pending);
    expect(await fixture.policies.overridesForFamily(fixture.familyId), isEmpty);
    final denied = await fixture.requests
        .deny(requestId: requested.id, parentMemberId: fixture.parentId);
    expect(denied.status, ChildExceptionRequestStatus.denied);
    final cancellable = await fixture.requests.create(
        familyId: fixture.familyId,
        childDeviceId: fixture.deviceId,
        childUid: 'child-uid',
        target: 'com.android.chrome',
        duration: const Duration(minutes: 10),
        reason: ChildExceptionReason.homework);
    await expectLater(
        fixture.requests.cancel(requestId: cancellable.id, childUid: 'other-child'),
        throwsStateError);
    final cancelled = await fixture.requests
        .cancel(requestId: cancellable.id, childUid: 'child-uid');
    expect(cancelled.status, ChildExceptionRequestStatus.cancelled);
    await fixture.database.close();
  });

  test('revoked child device cannot create an exception request', () async {
    final now = DateTime.utc(2026, 8, 12, 12);
    final fixture = await _fixture(() => now);
    final childDevices = ChildDeviceRepository(fixture.database, clock: () => now);
    await childDevices.transition(
        deviceId: fixture.deviceId, to: ChildDeviceLifecycle.revoked);
    await expectLater(
        fixture.requests.create(
            familyId: fixture.familyId,
            childDeviceId: fixture.deviceId,
            childUid: 'child-uid',
            target: 'com.google.android.youtube',
            duration: const Duration(minutes: 10),
            reason: ChildExceptionReason.homework),
        throwsStateError);
    await fixture.database.close();
  });

  test('pending and approved requests expire deterministically during local read',
      () async {
    var now = DateTime.utc(2026, 8, 12, 12);
    final fixture = await _fixture(() => now);
    final pending = await fixture.requests.create(
        familyId: fixture.familyId,
        childDeviceId: fixture.deviceId,
        childUid: 'child-uid',
        target: 'com.google.android.youtube',
        duration: const Duration(minutes: 5),
        reason: ChildExceptionReason.other,
        reasonDetail: 'Required for a family plan',
        requestWindow: const Duration(minutes: 1));
    now = now.add(const Duration(minutes: 2));
    final expiredPending = (await fixture.requests.forFamily(fixture.familyId))
        .singleWhere((item) => item.id == pending.id);
    expect(expiredPending.status, ChildExceptionRequestStatus.expired);
    final approvedCandidate = await fixture.requests.create(
        familyId: fixture.familyId,
        childDeviceId: fixture.deviceId,
        childUid: 'child-uid',
        target: 'com.android.chrome',
        duration: const Duration(minutes: 2),
        reason: ChildExceptionReason.homework);
    final approved = await fixture.requests
        .approve(requestId: approvedCandidate.id, parentMemberId: fixture.parentId);
    now = approved.expiresAt!.add(const Duration(seconds: 1));
    final expiredApproved = (await fixture.requests.forFamily(fixture.familyId))
        .singleWhere((item) => item.id == approved.id);
    expect(expiredApproved.status, ChildExceptionRequestStatus.expired);
    await fixture.database.close();
  });
}
