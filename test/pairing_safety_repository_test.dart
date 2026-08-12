import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/safety_repositories.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/incident_engine.dart';
import 'test_database.dart';

void main() {
  test(
      'pairing locks after five invalid codes, enrolls exactly once, enforces owner revocation',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final child =
        await families.addChild(familyId: family.id, childName: 'Child');
    final pairing = PairingRepository(database);
    final rejected = await pairing.createParentAuthorizedRequest(
        familyId: family.id,
        requestedRole: DeviceRole.childDevice,
        targetMemberId: child.id);
    for (var attempt = 0; attempt < 4; attempt++) {
      expect(
          (await pairing.verifyAndEnroll(
                  requestId: rejected.id,
                  code: '000000',
                  memberId: child.id,
                  ownerMemberId: 'parent'))
              .state,
          PairingState.pending);
    }
    expect(
        (await pairing.verifyAndEnroll(
                requestId: rejected.id,
                code: '000000',
                memberId: child.id,
                ownerMemberId: 'parent'))
            .state,
        PairingState.rejected);
    final request = await pairing.createParentAuthorizedRequest(
        familyId: family.id,
        requestedRole: DeviceRole.childDevice,
        targetMemberId: child.id);
    final enrolled = await pairing.verifyAndEnroll(
        requestId: request.id,
        code: request.code,
        memberId: child.id,
        ownerMemberId: 'parent');
    expect(enrolled.succeeded, isTrue);
    expect(
        (await pairing.verifyAndEnroll(
                requestId: request.id,
                code: request.code,
                memberId: child.id,
                ownerMemberId: 'parent'))
            .succeeded,
        isFalse);
    expect(
        await pairing.revokeDevice(
            deviceId: enrolled.deviceId!, ownerMemberId: 'other'),
        isFalse);
    expect(
        await pairing.revokeDevice(
            deviceId: enrolled.deviceId!, ownerMemberId: 'parent'),
        isTrue);
    expect(
        await pairing.revokeDevice(
            deviceId: enrolled.deviceId!, ownerMemberId: 'parent'),
        isFalse);
    await database.close();
  });

  test(
      'incident and SOS persistence queue local notification contracts without claiming delivery',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final incidents = IncidentRepository(database, const RiskEngine());
    final incident = await incidents.recordObservation(
        familyId: family.id,
        observation: SafetyObservation(
            category: SafetyCategory.bullying,
            confidence: 0.9,
            source: 'adapter',
            observedAt: DateTime.utc(2026),
            modelVersion: 'model-v1'));
    expect(incident, isNotNull);
    expect(await incidents.acknowledge(incidentId: incident!.id), isTrue);
    expect(await incidents.acknowledge(incidentId: incident.id), isFalse);
    final sos = SosRepository(database);
    final sosId = await sos.createOfflineEvent(familyId: family.id);
    expect(
        await sos.transition(sosId: sosId, next: SosState.notified), isFalse);
    expect(await sos.transition(sosId: sosId, next: SosState.synced), isTrue);
    final db = await database.database;
    expect((await db.query('notification_events')).length, 2);
    expect(
        (await db.query('outbox',
                where: 'operation = ?', whereArgs: ['notification.requested']))
            .length,
        2);
    await database.close();
  });
}
