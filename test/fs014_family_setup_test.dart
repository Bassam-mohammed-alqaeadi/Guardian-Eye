import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FamilyMembershipRepository - Join Code Logic', () {
    late GuardianDatabase db;
    late FamilyMembershipRepository repo;

    setUp(() async {
      db = GuardianDatabase.forTesting(
        factory: databaseFactory,
        pathResolver: () async => inMemoryDatabasePath,
      );
      repo = FamilyMembershipRepository(db);
      await db.database; // Ensure initialized
    });

    test('inviteAdult stores invitation with a code', () async {
      // 0. Create the family and inviter as an owner
      final dbRaw = await db.database;
      await dbRaw.insert('families', {
        'id': 'fam_123',
        'name': 'Test Family',
        'created_at': DateTime.now().toIso8601String(),
      });
      await dbRaw.insert('family_members', {
        'id': 'actor_123',
        'family_id': 'fam_123',
        'display_name': 'Owner',
        'role': FamilyRole.primaryParent.name,
        'status': FamilyMemberStatus.active.name,
        'created_at': DateTime.now().toIso8601String(),
      });

      final invitation = await repo.inviteAdult(
        familyId: 'fam_123',
        actorMemberId: 'actor_123',
        targetEmail: 'test@example.com',
        proposedRole: FamilyRole.parent,
      );

      expect(invitation.code, isNotNull);
      expect(invitation.code!.length, 6);

      // Verify in DB
      final maps = await (await db.database).query(
        'family_invitations',
        where: 'id = ?',
        whereArgs: [invitation.id],
      );
      expect(maps.first['code'], invitation.code);
    });

    test('lookupInvitationByCode resolves invitation', () async {
      // 0. Create the family and inviter as an owner
      final dbRaw = await db.database;
      await dbRaw.insert('families', {
        'id': 'fam_lookup',
        'name': 'Lookup Family',
        'created_at': DateTime.now().toIso8601String(),
      });
      await dbRaw.insert('family_members', {
        'id': 'actor_lookup',
        'family_id': 'fam_lookup',
        'display_name': 'Owner',
        'role': FamilyRole.primaryParent.name,
        'status': FamilyMemberStatus.active.name,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 1. Create an invitation
      final invitation = await repo.inviteAdult(
        familyId: 'fam_lookup',
        actorMemberId: 'actor_lookup',
        targetEmail: 'lookup@example.com',
        proposedRole: FamilyRole.parent,
      );

      // 2. Lookup by code
      final resolved = await repo.lookupInvitationByCode(invitation.code!);
      expect(resolved, isNotNull);
      expect(resolved!.id, invitation.id);
    });

    test('acceptInvitation joins family successfully', () async {
      // 0. Create the family and inviter as an owner
      final dbRaw = await db.database;
      await dbRaw.insert('families', {
        'id': 'fam_join',
        'name': 'Join Family',
        'created_at': DateTime.now().toIso8601String(),
      });
      await dbRaw.insert('family_members', {
        'id': 'actor_owner',
        'family_id': 'fam_join',
        'display_name': 'Owner',
        'role': FamilyRole.primaryParent.name,
        'status': FamilyMemberStatus.active.name,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 1. Create an invitation (use coParent as spouse might be restricted in Phase 17 logic)
      final invitation = await repo.inviteAdult(
        familyId: 'fam_join',
        actorMemberId: 'actor_owner',
        targetEmail: 'joiner@example.com',
        proposedRole: FamilyRole.coParent,
      );

      // 2. Accept it
      final member = await repo.acceptInvitation(
        invitationId: invitation.id,
        accountUid: 'uid_456',
        accountEmail: 'joiner@example.com',
        displayName: 'Joined Spouse',
      );

      expect(member.familyId, 'fam_join');
      expect(member.role, FamilyRole.coParent);

      // 3. Verify member in DB
      final members = await (await db.database).query(
        'family_members',
        where: 'family_id = ? AND account_uid = ?',
        whereArgs: ['fam_join', 'uid_456'],
      );
      expect(members.length, 1);
    });

    test('lookupInvitationByCode returns null for invalid code', () async {
      final result = await repo.lookupInvitationByCode('INVALID');
      expect(result, isNull);
    });
  });
}
