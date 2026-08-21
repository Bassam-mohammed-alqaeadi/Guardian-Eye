// FS-011 — Family Rules & Policy Engine. Honest-state checks:
// rules survive a real SQLite round-trip through the v21 migration;
// duplicate ids are rejected explicitly; enable/disable flips honestly;
// conflicts are deterministic (priority desc, creation asc) and never
// silently suppressed; one-time rules collide only with exact siblings;
// the execution log records real verdicts only; outbox rows are
// dispatched for every write operation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/family_rules_repository.dart';
import 'package:guardian_ai/domain/family_rules.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs011-db-');
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => '${dir.path}/db.sqlite');
  await database.initialize();
  return database;
}

final DateTime _seededAt = DateTime.utc(2025, 7, 1, 10, 0, 0);

Future<void> _seedFamily(Database db) async {
  await db.insert('families', {
    'id': 'family-fr',
    'name': 'Rules Family',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-fr',
    'family_id': 'family-fr',
    'display_name': 'Parent',
    'role': 'primary_parent',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'child-a-fr',
    'family_id': 'family-fr',
    'display_name': 'Child A',
    'role': 'child',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'child-b-fr',
    'family_id': 'family-fr',
    'display_name': 'Child B',
    'role': 'child',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
}

FamilyRule _rule(
    {required String ruleId,
    String name = 'Bedtime',
    RuleKind kind = RuleKind.bedtime,
    RuleAction action = RuleAction.block,
    bool enabled = true,
    int startMinute = 1260,
    int endMinute = 420,
    RuleScheduleKind scheduleKind = RuleScheduleKind.daily,
    Set<int> weekdays = const {1, 2, 3, 4, 5},
    DateTime? oneshotAt,
    Set<String> assignedChildIds = const {'child-a-fr'},
    Set<String> appTargets = const {},
    Set<String> categoryTargets = const {},
    int? limitMinutes,
    int priority = 50,
    DateTime? createdAt}) {
  return FamilyRule(
    ruleId: ruleId,
    familyId: 'family-fr',
    name: name,
    kind: kind,
    action: action,
    enabled: enabled,
    startMinute: startMinute,
    endMinute: endMinute,
    scheduleKind: scheduleKind,
    weekdays: weekdays,
    oneshotAt: oneshotAt,
    assignedChildIds: assignedChildIds,
    appTargets: appTargets,
    categoryTargets: categoryTargets,
    limitMinutes: limitMinutes,
    priority: priority,
    createdAt: createdAt ?? _seededAt,
  );
}

void main() {
  group('FS-011 database and schema', () {
    test('v21 migration creates family_rules and rule_execution_log tables',
        () async {
      final database = await openTestDatabase();
      final db = await database.database;
      final tables = (await db.rawQuery("""
          SELECT name FROM sqlite_master WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
        """)).map((r) => r['name'] as String).toSet();
      expect(tables, contains('family_rules'),
          reason: 'FS-011 rule table must exist');
      expect(tables, contains('rule_execution_log'),
          reason: 'FS-011 verdict log must exist');
      // The log references rules through the composite foreign key.
      final logInfo =
          await db.rawQuery('PRAGMA foreign_key_list(rule_execution_log)');
      expect(logInfo, isNotEmpty);
      expect(logInfo.first['table'], 'family_rules');
    });
  });

  group('FS-011 honest CRUD', () {
    late GuardianDatabase database;
    late FamilyRulesRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await _seedFamily(await database.database);
      repo = FamilyRulesRepository(database);
    });

    test('create then read round-trips every field through SQLite',
        () async {
      final rule = _rule(
          ruleId: 'bedtime-1',
          limitMinutes: 60,
          appTargets: {'com.example.game'},
          categoryTargets: {'gambling'},
          priority: 75);
      final created =
          await repo.create(rule, createdByMemberId: 'parent-fr');
      expect(created.syncState, SyncState.localOnly,
          reason: 'queued until server confirms');
      final fetched = await repo.find('family-fr', 'bedtime-1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Bedtime');
      expect(fetched.kind, RuleKind.bedtime);
      expect(fetched.limitMinutes, 60);
      expect(fetched.appTargets, {'com.example.game'});
      expect(fetched.categoryTargets, {'gambling'});
      expect(fetched.priority, 75);
      expect(fetched.weekdays, {1, 2, 3, 4, 5});
    });

    test('duplicate rule id is rejected explicitly, never overwritten',
        () async {
      final rule = _rule(ruleId: 'dup-rule');
      await repo.create(rule, createdByMemberId: 'parent-fr');
      expect(() => repo.create(rule, createdByMemberId: 'parent-fr'),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains('family_rule_exists'))));
      expect((await repo.listForFamily('family-fr')).length, 1);
    });

    test('missing rule id throws on update, delete and toggle', () async {
      expect(() => repo.update(_rule(ruleId: 'ghost')),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains('family_rule_missing'))));
      expect(() => repo.delete('family-fr', 'ghost'),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains('family_rule_missing'))));
      expect(() => repo.toggleEnabled(familyId: 'family-fr', ruleId: 'ghost'),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains('family_rule_missing'))));
    });

    test('toggle flips the enabled flag honestly in both directions',
        () async {
      await repo.create(_rule(ruleId: 'tog-1'),
          createdByMemberId: 'parent-fr');
      await repo.toggleEnabled(familyId: 'family-fr', ruleId: 'tog-1');
      expect((await repo.find('family-fr', 'tog-1'))!.enabled, false);
      await repo.toggleEnabled(familyId: 'family-fr', ruleId: 'tog-1');
      expect((await repo.find('family-fr', 'tog-1'))!.enabled, true);
    });

    test('delete removes the rule and dispatches an outbox row', () async {
      await repo.create(_rule(ruleId: 'del-1'),
          createdByMemberId: 'parent-fr');
      final outboxBefore = await database.database
          .then((db) => db.query('outbox',
              where: 'aggregate_id = ? AND operation = ?',
              whereArgs: ['del-1', 'delete']));
      expect(outboxBefore, isEmpty);
      await repo.delete('family-fr', 'del-1');
      expect(await repo.find('family-fr', 'del-1'), isNull);
      final outboxAfter = await database.database.then(
          (db) => db.query('outbox', where: 'aggregate_id = ?',
              whereArgs: ['del-1']));
      expect(outboxAfter.length, greaterThanOrEqualTo(1));
      expect(outboxAfter.map((r) => r['operation'] as String),
          contains('delete'));
    });

    test('create and update each dispatch exactly one outbox row', () async {
      await repo.create(_rule(ruleId: 'out-1'),
          createdByMemberId: 'parent-fr');
      await repo.update(_rule(ruleId: 'out-1', name: 'Renamed'),);
      final outbox = await database.database.then(
          (db) => db.query('outbox', where: 'aggregate_id = ?',
              whereArgs: ['out-1']));
      expect(outbox.length, 2);
      final operations = outbox.map((r) => r['operation'] as String).toSet();
      expect(operations, {'create', 'update'});
      expect(outbox.first['state'], 'queued');
    });
  });

  group('FS-011 conflict engine', () {
    late GuardianDatabase database;
    late FamilyRulesRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await _seedFamily(await database.database);
      repo = FamilyRulesRepository(database);
    });

    test('higher priority wins; equal priority breaks by creation order',
        () async {
      await repo.create(_rule(ruleId: 'hi', priority: 90,
              startMinute: 1260, endMinute: 420, name: 'High',
              assignedChildIds: {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'lo', priority: 10,
              startMinute: 1320, endMinute: 1400, name: 'Low',
              assignedChildIds: {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      final all = await repo.listForFamily('family-fr');
      expect(all, hasLength(2),
          reason: 'both conflicting rules must be persisted');
      final conflicts = repo.conflictsFor(all);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.winner.ruleId, 'hi');
      expect(conflicts.first.loser.ruleId, 'lo');

      // Equal priority: the older rule wins (created_at ascending).
      await repo.update(_rule(ruleId: 'hi', priority: 10,
          createdAt: DateTime.utc(2025, 7, 1),
          assignedChildIds: {'child-a-fr'}));
      await repo.update(_rule(ruleId: 'lo', priority: 10,
          createdAt: DateTime.utc(2025, 7, 2),
          assignedChildIds: {'child-a-fr'}));
      final freshConflicts =
          repo.conflictsFor(await repo.listForFamily('family-fr'));
      expect(freshConflicts.first.winner.ruleId, 'hi',
          reason: 'older creation wins the tie');
    });

    test('one-time rules collide only with an exact sibling', () async {
      await repo.create(_rule(ruleId: 'once-1',
              scheduleKind: RuleScheduleKind.oneTime,
              oneshotAt: DateTime.utc(2025, 7, 5, 20, 0)),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'once-2',
              scheduleKind: RuleScheduleKind.oneTime,
              oneshotAt: DateTime.utc(2025, 7, 5, 20, 0, 30)),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'once-3',
              scheduleKind: RuleScheduleKind.oneTime,
              oneshotAt: DateTime.utc(2025, 7, 6, 20, 0)),
          createdByMemberId: 'parent-fr');
      final conflicts =
          repo.conflictsFor(await repo.listForFamily('family-fr'));
      expect(conflicts, hasLength(1));
      final involved = {conflicts.first.first.ruleId,
          conflicts.first.second.ruleId};
      expect(involved, {'once-1', 'once-2'});
    });

    test('disjoint daily windows do not conflict; unassigned rules skip',
        () async {
      await repo.create(_rule(ruleId: 'morning',
              startMinute: 420, endMinute: 600,
              assignedChildIds: {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'evening',
              startMinute: 1260, endMinute: 1380,
              assignedChildIds: {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'all-children',
              startMinute: 500, endMinute: 560,
              assignedChildIds: const {}),
          createdByMemberId: 'parent-fr');
      final conflicts =
          repo.conflictsFor(await repo.listForFamily('family-fr'));
      expect(conflicts, isEmpty,
          reason: 'no time overlap and no assigned-child conflict');
    });
  });

  group('FS-011 execution log and child scoping', () {
    late GuardianDatabase database;
    late FamilyRulesRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await _seedFamily(await database.database);
      repo = FamilyRulesRepository(database);
    });

    test('verdicts are recorded and read back in reverse order', () async {
      // Verdicts reference a real rule (FK integrity).
      await repo.create(_rule(ruleId: 'bedtime-1'),
          createdByMemberId: 'parent-fr');
      final at = DateTime.utc(2025, 7, 1, 21, 0);
      await repo.logExecution(RuleExecutionEntry(
        id: 'verdict-1',
        ruleId: 'bedtime-1',
        familyId: 'family-fr',
        childId: 'child-a-fr',
        outcome: 'applied',
        reason: 'inside bedtime window',
        evaluatedAt: at,
      ));
      await repo.logExecution(RuleExecutionEntry(
        id: 'verdict-2',
        ruleId: 'bedtime-1',
        familyId: 'family-fr',
        childId: 'child-a-fr',
        outcome: 'skipped',
        reason: 'rule disabled',
        evaluatedAt: at.add(const Duration(minutes: 5)),
      ));
      final log = await repo.logForFamily(familyId: 'family-fr');
      expect(log, hasLength(2));
      expect(log.first.outcome, 'skipped',
          reason: 'newest verdict first');
      final since = await repo.logForFamily(
          familyId: 'family-fr',
          since: at.add(const Duration(minutes: 2)));
      expect(since, hasLength(1));
    });

    test('applicableForChild lists enabled rules touching that child only',
        () async {
      await repo.create(_rule(ruleId: 'ca-only',
              assignedChildIds: {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'cb-only',
              assignedChildIds: {'child-b-fr'}),
          createdByMemberId: 'parent-fr');
      await repo.create(_rule(ruleId: 'disabled',
              enabled: false,
              assignedChildIds: {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      // Rule defaults to Bedtime (21:00 to 07:00). SeededAt is 10:00.
      // We need a moment inside the window, e.g., 23:00.
      final inside = _seededAt.add(const Duration(hours: 13));
      final visible = await repo.applicableForChild(
          familyId: 'family-fr', childId: 'child-a-fr', at: inside);
      expect(visible.map((r) => r.ruleId).toSet(), {'ca-only'});
    });

    test('reserved kinds expose isExecutable flag truthfully', () async {
      final live = RuleKind.values.where((k) => k.isExecutable).toList();
      final reserved =
          RuleKind.values.where((k) => !k.isExecutable).toSet();
      expect(live, hasLength(7));
      expect(reserved.map((k) => k.name).toSet(),
          {'taskGated', 'rewardUnlocked', 'eventOverride'});
    });
  });
}
