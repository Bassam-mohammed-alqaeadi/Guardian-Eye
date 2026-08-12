import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/child_policy_delivery_service.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';

import 'test_database.dart';

class _Source implements ChildPolicySource {
  _Source(this.policies, {this.failure});
  final List<RemoteChildPolicyMutation> policies;
  final Object? failure;
  @override
  Future<List<RemoteChildPolicyMutation>> fetchPolicies(String familyId) async {
    if (failure != null) throw failure!;
    return policies;
  }
}

Future<(ChildDeviceRepository, String)> _enrolledChild() async {
  final database = await openTestDatabase();
  final family = await FamilyRepository(database)
      .createFamily(familyName: 'Family', parentName: 'Parent');
  final child = await FamilyRepository(database)
      .addChild(familyId: family.id, childName: 'Child');
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
  return (ChildDeviceRepository(database), enrolled.deviceId!);
}

void main() {
  test('child delivery persists an allowed family policy snapshot idempotently',
      () async {
    final (repository, deviceId) = await _enrolledChild();
    final familyId = (await repository.getState(deviceId))!.familyId;
    final mutation = RemoteChildPolicyMutation(DigitalPolicy(
        id: 'policy',
        familyId: familyId,
        name: 'School',
        priority: 90,
        enabled: true,
        startMinute: 0,
        endMinute: 0,
        restrictedTargets: {'games'},
        version: 4));
    final service = ChildPolicyDeliveryService(repository, _Source([mutation]));
    final first = await service.synchronize(deviceId);
    final second = await service.synchronize(deviceId);
    expect((first.fetched, first.applied, first.offline), (1, 1, false));
    expect(second.idempotent, 1);
    expect((await repository.deliveredPolicies(deviceId)).single.policy.version,
        4);
  });

  test(
      'delivery failure marks the child offline without inventing a remote acknowledgement',
      () async {
    final (repository, deviceId) = await _enrolledChild();
    final report = await ChildPolicyDeliveryService(repository,
            _Source(const [], failure: StateError('network_unavailable')))
        .synchronize(deviceId);
    expect(report.offline, isTrue);
    expect(report.reason, 'policy_delivery_unavailable');
    expect((await repository.getState(deviceId))!.lifecycle.name, 'offline');
  });
}
