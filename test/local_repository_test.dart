import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/policy_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'test_database.dart';

void main() {
  test(
      'family persistence creates a durable family outbox event; addChild is local-only',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    await families.addChild(familyId: family.id, childName: 'Child');
    final db = await database.database;
    expect((await db.query('families')).length, 1);
    expect((await db.query('family_members')).length, 2);
    // M5 Option D: only `family.created` is syncable; a child is local-only
    // until trusted provisioning, so no `member.created` outbox row exists.
    final outbox = await db.query('outbox');
    expect(outbox.length, 1);
    expect(outbox.single['operation'], 'family.created');
    await database.close();
  });

  test('foreign-key failure rolls back child and outbox writes', () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    await expectLater(
        families.addChild(familyId: 'missing', childName: 'Child'),
        throwsA(anything));
    final db = await database.database;
    expect(await db.query('family_members'), isEmpty);
    expect(await db.query('outbox'), isEmpty);
    await database.close();
  });

  test(
      'stored policy and override remain evaluable offline and create outbox events',
      () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family =
        await families.createFamily(familyName: 'Family', parentName: 'Parent');
    final policies = PolicyRepository(database);
    await policies.save(
        familyId: family.id,
        name: 'Bedtime',
        priority: 50,
        enabled: true,
        startMinute: 1260,
        endMinute: 420,
        restrictedTargets: {'video'});
    final now = DateTime.now();
    final override = await policies.createOverride(
        familyId: family.id,
        createdByMemberId: 'parent',
        target: 'video',
        allowed: true,
        expiresAt: now.toUtc().add(const Duration(minutes: 10)));
    final decision = const PolicyEngine().resolve(
        target: 'video',
        moment: now,
        policies: await policies.forFamily(family.id),
        override: override);
    expect(decision.restricted, isFalse);
    expect((await (await database.database).query('outbox')).length, 3);
    await database.close();
  });

  test('updating a policy increments its version and queues policy.updated',
      () async {
    final database = await openTestDatabase();
    final family = await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final policies = PolicyRepository(database);
    final created = await policies.save(
        familyId: family.id,
        name: 'Bedtime',
        priority: 50,
        enabled: true,
        startMinute: 1260,
        endMinute: 420,
        restrictedTargets: {'video'});
    await policies.update(
        existing: created,
        name: 'School night',
        priority: 70,
        enabled: true,
        startMinute: 1200,
        endMinute: 390,
        restrictedTargets: {'video', 'games'});
    final stored = (await policies.forFamily(family.id)).single;
    final events = await (await database.database)
        .query('outbox', where: 'aggregate_id = ?', whereArgs: [created.id]);
    expect(stored.name, 'School night');
    expect(stored.version, 2);
    expect(events.map((event) => event['operation']), contains('policy.updated'));
    await database.close();
  });

  test('toggling a policy writes the new enabled state and a durable event',
      () async {
    final database = await openTestDatabase();
    final family = await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final policies = PolicyRepository(database);
    final created = await policies.save(
        familyId: family.id,
        name: 'Bedtime',
        priority: 50,
        enabled: true,
        startMinute: 1260,
        endMinute: 420,
        restrictedTargets: {'video'});
    await policies.setEnabled(existing: created, enabled: false);
    final stored = (await policies.forFamily(family.id)).single;
    expect(stored.enabled, isFalse);
    expect(stored.version, 2);
    await database.close();
  });

  test('stored overrides are returned for their family with queued sync state',
      () async {
    final database = await openTestDatabase();
    final family = await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final policies = PolicyRepository(database);
    final created = await policies.createOverride(
        familyId: family.id,
        createdByMemberId: 'parent',
        target: 'browser',
        allowed: true,
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)));
    final stored = (await policies.overridesForFamily(family.id)).single;
    expect(stored.id, created.id);
    expect(stored.target, 'browser');
    expect(stored.syncState, SyncState.queued);
    await database.close();
  });

  test('forFamily derives policy sync state from the durable outbox record',
      () async {
    final database = await openTestDatabase();
    final family = await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final policies = PolicyRepository(database);
    final created = await policies.save(
        familyId: family.id,
        name: 'Bedtime',
        priority: 50,
        enabled: true,
        startMinute: 1260,
        endMinute: 420,
        restrictedTargets: {'video'});
    final db = await database.database;
    await db.update('outbox', {'state': 'synced'},
        where: 'aggregate_type = ? AND aggregate_id = ?',
        whereArgs: ['policy', created.id]);
    expect((await policies.forFamily(family.id)).single.syncState,
        SyncState.synced);
    await database.close();
  });
}
