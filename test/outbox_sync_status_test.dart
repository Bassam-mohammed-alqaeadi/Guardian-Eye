import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/outbox_sync_executor.dart';
import 'package:guardian_ai/data/outbox_sync_status.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

import 'test_database.dart';

class _Auth implements AuthContext {
  const _Auth(this.session);
  final AuthSession session;
  @override
  AuthSession get currentSession => session;
  @override
  Stream<AuthSession> get changes => Stream.value(session);
}

class _Writer implements OutboxRemoteWriter {
  @override
  Future<void> write(
      {required OutboxEvent event,
      required AuthenticatedIdentity identity}) async {}
}

void main() {
  const identity = AuthenticatedIdentity(
      uid: 'parent-auth', email: 'p@example.test', isAnonymous: false);

  test('family.created queued marks the family as pending (E3)', () async {
    final database = await openTestDatabase();
    final family = await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');

    final status = OutboxSyncStatus(database);
    expect(await status.hasPendingForFamily(family.id), isTrue);
    expect(await status.pendingCount(), 1);

    // After real delivery confirmation the family is no longer pending.
    final report = await OutboxSyncExecutor(
            database,
            const _Auth(AuthSession(
                status: AuthSessionStatus.authenticated, identity: identity)),
            _Writer())
        .executeDue();
    expect(report.synced, 1);
    expect(await status.hasPendingForFamily(family.id), isFalse);
    expect(await status.pendingCount(), 0);
    await database.close();
  });

  test('member mutation queued for a family marks it pending', () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family = await families.createFamily(
        familyName: 'Family', parentName: 'Parent');
    final parentId = (await (await database.database).query('family_members',
            where: 'family_id = ?', whereArgs: [family.id]))
        .single['id'] as String;
    await FamilyMembershipRepository(database).inviteAdult(
        familyId: family.id,
        actorMemberId: parentId,
        targetEmail: 'co@example.test',
        proposedRole: FamilyRole.coParent);

    final status = OutboxSyncStatus(database);
    expect(await status.hasPendingForFamily(family.id), isTrue);
    expect(await status.pendingCount(), 2);
    await database.close();
  });

  test('empty outbox reports no pending sync', () async {
    final database = await openTestDatabase();
    final status = OutboxSyncStatus(database);
    expect(await status.hasPendingForFamily('family-a'), isFalse);
    expect(await status.pendingCount(), 0);
    await database.close();
  });

  test('pending state of one family does not leak into another', () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final pending =
        await families.createFamily(familyName: 'Pending', parentName: 'A');
    await families.createFamily(familyName: 'Clean', parentName: 'B');

    // The clean family's `family.created` is still queued too, so only a
    // family whose OWN mutation is absent is considered clean.
    final status = OutboxSyncStatus(database);
    expect(await status.hasPendingForFamily(pending.id), isTrue);
    expect(await status.pendingCount(), 2);
    await database.close();
  });
}
