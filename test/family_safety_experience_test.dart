import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/child_exception_request_repository.dart';
import 'package:guardian_ai/data/family_safety_experience_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/policy_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/child_exception_request.dart';
import 'package:guardian_ai/domain/family_safety_experience.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

import 'test_database.dart';

void main() {
  test('approved child request creates a device-scoped override used only by that child resolver',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family = await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final firstChild = await families.addChild(familyId: family.id, childName: 'One');
    final secondChild = await families.addChild(familyId: family.id, childName: 'Two');
    final pairing = PairingRepository(database);
    final firstPair = await pairing.createParentAuthorizedRequest(
        familyId: family.id, requestedRole: DeviceRole.childDevice, targetMemberId: firstChild.id);
    final first = await pairing.verifyAndEnroll(requestId: firstPair.id, code: firstPair.code, memberId: firstChild.id, ownerMemberId: 'parent');
    final secondPair = await pairing.createParentAuthorizedRequest(
        familyId: family.id, requestedRole: DeviceRole.childDevice, targetMemberId: secondChild.id);
    final second = await pairing.verifyAndEnroll(requestId: secondPair.id, code: secondPair.code, memberId: secondChild.id, ownerMemberId: 'parent');
    final childDevices = ChildDeviceRepository(database);
    await childDevices.initializeForEnrolledDevice(first.deviceId!);
    await childDevices.initializeForEnrolledDevice(second.deviceId!);
    final policies = PolicyRepository(database);
    final policy = await policies.save(
        familyId: family.id, name: 'Video', priority: 1, enabled: true,
        startMinute: 0, endMinute: 0, restrictedTargets: {'video'});
    await childDevices.deliverPolicy(deviceId: first.deviceId!, policy: policy, knownMinimumVersion: 1);
    await childDevices.deliverPolicy(deviceId: second.deviceId!, policy: policy, knownMinimumVersion: 1);
    final requests = ChildExceptionRequestRepository(database, policies);
    final request = await requests.create(
        familyId: family.id, childDeviceId: first.deviceId!, childUid: 'child-one',
        target: 'video', duration: const Duration(minutes: 10),
        reason: ChildExceptionReason.homework);
    final parent = await policies.primaryParentMemberId(family.id);
    final approved = await requests.approve(requestId: request.id, parentMemberId: parent);
    final overrides = await policies.overridesForFamily(family.id);
    expect(overrides.single.childDeviceId, first.deviceId);
    const resolver = ChildPolicyResolver();
    final at = approved.reviewedAt!;
    final firstResolution = resolver.resolve(
        device: (await childDevices.getState(first.deviceId!))!, target: 'video',
        moment: at, deliveries: await childDevices.deliveredPolicies(first.deviceId!), overrides: overrides);
    final secondResolution = resolver.resolve(
        device: (await childDevices.getState(second.deviceId!))!, target: 'video',
        moment: at, deliveries: await childDevices.deliveredPolicies(second.deviceId!), overrides: overrides);
    expect(firstResolution.temporaryOverrideActive, isTrue);
    expect(secondResolution.restricted, isTrue);
    await database.close();
  });

  test('daily safety read model and local timeline are composed from actual SQLite state', () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family = await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final child = await families.addChild(familyId: family.id, childName: 'Child');
    final pairing = PairingRepository(database);
    final pair = await pairing.createParentAuthorizedRequest(
        familyId: family.id, requestedRole: DeviceRole.childDevice, targetMemberId: child.id);
    final enrolled = await pairing.verifyAndEnroll(requestId: pair.id, code: pair.code, memberId: child.id, ownerMemberId: 'parent');
    final childDevices = ChildDeviceRepository(database);
    await childDevices.initializeForEnrolledDevice(enrolled.deviceId!);
    final policies = PolicyRepository(database);
    final policy = await policies.save(
        familyId: family.id, name: 'Video', priority: 1, enabled: true,
        startMinute: 0, endMinute: 0, restrictedTargets: {'video'}, dailyLimitMinutes: 30);
    await childDevices.deliverPolicy(deviceId: enrolled.deviceId!, policy: policy, knownMinimumVersion: 1);
    await childDevices.upsertUsageSummary(
        deviceId: enrolled.deviceId!, target: 'video', cumulativeMilliseconds: 600000,
        observedAt: DateTime.now().toUtc());
    final requests = ChildExceptionRequestRepository(database, policies);
    await requests.create(
        familyId: family.id, childDeviceId: enrolled.deviceId!, childUid: 'child-uid',
        target: 'video', duration: const Duration(minutes: 10), reason: ChildExceptionReason.homework);
    final experience = FamilySafetyExperienceRepository(database, policies, requests);
    final snapshots = await experience.childrenForFamily(family.id);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.child.displayName, 'Child');
    expect(snapshots.single.devices.single.usage.single.totalDuration.inMinutes, 10);
    expect(snapshots.single.pendingRequests, hasLength(1));
    final timeline = await experience.timelineForFamily(family.id);
    expect(timeline.map((event) => event.kind), contains(SafetyTimelineKind.exceptionRequested));
    expect(timeline.any((event) => event.syncState == SyncState.queued), isTrue);
    await database.close();
  });
}
