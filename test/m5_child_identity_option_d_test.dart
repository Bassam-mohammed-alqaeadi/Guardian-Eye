import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/firestore_contracts.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'test_database.dart';

void main() {
  group('M5 Option D — child identity is local-only until trusted provisioning',
      () {
    test('addChild persists a local child without a remote member.created op',
        () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final db = await database.database;
      expect(child.id, isNotEmpty);
      expect(child.role, FamilyRole.child);
      final members = await db.query('family_members',
          where: 'id = ?', whereArgs: [child.id]);
      expect(members.single['role'], FamilyRole.child.storageKey);
      // The only outbox row is `family.created`; no `member.created` for the child.
      final outbox = await db.query('outbox');
      expect(outbox.length, 1);
      expect(outbox.single['operation'], 'family.created');
      await database.close();
    });

    test('pending sync count is unaffected by a local-only child', () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      await families.addChild(familyId: family.id, childName: 'Child');
      final db = await database.database;
      final pending = await db.rawQuery(
          "SELECT COUNT(*) AS c FROM outbox WHERE state IN ('queued','failed','blocked')");
      expect((pending.first['c'] as num).toInt(), 1); // family.created only
      await database.close();
    });

    test('child-role member.created payload is rejected by the contract',
        () async {
      const contract = FirestoreEventContract();
      expect(
          () => contract.businessMutation(
                operation: 'member.created',
                payload: const {
                  'familyId': 'family',
                  'memberId': 'child-local',
                  'displayName': 'Child',
                  'role': 'child',
                },
                identity: _identity('parent-uid'),
                idempotencyKey: 'op-1',
              ),
          throwsA(isA<FormatException>()));
    });

    test('recordRemoteEnrollment mirrors a server-confirmed enrollment locally',
        () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      final result = await pairing.recordRemoteEnrollment(
        familyId: family.id,
        deviceId: 'server-device-1',
        memberId: child.id,
        ownerMemberId: child.id,
        role: DeviceRole.childDevice.storageKey,
      );
      expect(result.succeeded, isTrue);
      expect(result.deviceId, 'server-device-1');
      final db = await database.database;
      final devices = await db.query('devices',
          where: 'id = ?', whereArgs: ['server-device-1']);
      expect(devices.single['sync_state'], SyncState.synced.storageKey);
      final states = await db.query('child_device_states',
          where: 'device_id = ?', whereArgs: ['server-device-1']);
      expect(states.single['lifecycle'], 'enrolled');
      // No outbox op is enqueued: delivery is confirmed server-side.
      final outbox = await db.query('outbox');
      expect(outbox.length, 1); // family.created only
      await database.close();
    });

    test('recordRemoteEnrollment is idempotent for an existing device',
        () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      await pairing.recordRemoteEnrollment(
        familyId: family.id,
        deviceId: 'server-device-2',
        memberId: child.id,
        ownerMemberId: child.id,
        role: DeviceRole.childDevice.storageKey,
      );
      final again = await pairing.recordRemoteEnrollment(
        familyId: family.id,
        deviceId: 'server-device-2',
        memberId: child.id,
        ownerMemberId: child.id,
        role: DeviceRole.childDevice.storageKey,
      );
      expect(again.succeeded, isTrue);
      final db = await database.database;
      expect((await db.query('devices')).length, 1);
      expect((await db.query('child_device_states')).length, 1);
      await database.close();
    });

    test('remote enrollment payload decodes without member.created semantics',
        () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      await families.addChild(familyId: family.id, childName: 'Child');
      final db = await database.database;
      final outbox = await db.query('outbox');
      final payload =
          jsonDecode(outbox.single['payload_json']! as String) as Map;
      expect(payload['familyId'], family.id);
      await database.close();
    });
  });
}

AuthenticatedIdentity _identity(String uid) => AuthenticatedIdentity(
    uid: uid, email: '$uid@example.test', isAnonymous: false);
