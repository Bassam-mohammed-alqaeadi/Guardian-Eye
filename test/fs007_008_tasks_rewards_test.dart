// FS-007 — Family Tasks & Daily Schedules + FS-008 — Family Points &
// Rewards. Honest-state checks: the v24 schema creates all five tables;
// tasks round-trip through SQLite with every field; the completion log
// is the only path to `completed` (a parent decision is required);
// terminal tasks refuse new completion requests; `taskGated` bridge
// rules read the honest log; rewards CRUD is idempotent; the ledger is
// append-only and the balance is always `sum(delta)`; a redemption only
// spends after a parent approval; disabled rewards refuse claims; and
// every write dispatches exactly one outbox row.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/family_rewards_repository.dart';
import 'package:guardian_ai/data/family_rules_repository.dart';
import 'package:guardian_ai/data/family_tasks_repository.dart';
import 'package:guardian_ai/domain/family_rewards.dart';
import 'package:guardian_ai/domain/family_rules.dart';
import 'package:guardian_ai/domain/family_tasks.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs007-db-');
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
    'name': 'Tasks & Rewards Family',
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

TaskEntry _task(
    {required String taskId,
    String title = 'Read 20 minutes',
    DateTime? dueDate,
    TaskRecurrence recurrence = TaskRecurrence.none,
    Set<int> weekdays = const {1, 2, 3, 4, 5},
    Set<String> assignedChildIds = const {'child-a-fr', 'child-b-fr'},
    String? linkedRuleId,
    TaskStatus status = TaskStatus.scheduled}) {
  return TaskEntry(
    taskId: taskId,
    familyId: 'family-fr',
    title: title,
    description: 'Before screen time starts',
    dueMinute: 1050,
    dueDate: dueDate ?? DateTime.utc(2025, 7, 1),
    recurrence: recurrence,
    weekdays: weekdays,
    assignedChildIds: assignedChildIds,
    linkedRuleId: linkedRuleId,
    status: status,
    createdByMemberId: 'parent-fr',
    createdAt: _seededAt,
  );
}

FamilyReward _reward(
    {required String rewardId,
    String name = 'Ice cream outing',
    int costPoints = 50,
    int? expiryDays,
    bool enabled = true}) {
  return FamilyReward(
    rewardId: rewardId,
    familyId: 'family-fr',
    name: name,
    description: 'Weekend treat for the family',
    costPoints: costPoints,
    expiryDays: expiryDays,
    enabled: enabled,
    createdByMemberId: 'parent-fr',
    createdAt: _seededAt,
  );
}

void main() {
  // ── FS-007 database and schema ───────────────────────────────────────
  group('FS-007 database and schema', () {
    test('v22/v24 migration creates tasks and task_completion_log tables',
        () async {
      final database = await openTestDatabase();
      final db = await database.database;
      final tables = (await db.rawQuery("""
          SELECT name FROM sqlite_master
          WHERE type='table' AND name IN
          ('tasks','task_completion_log','reward_points_ledger',
           'family_rewards','reward_pending_claims')
          ORDER BY 1""")).map((Map r) => r['name'] as String).toSet();
      expect(tables, const {
        'tasks',
        'task_completion_log',
        'reward_points_ledger',
        'family_rewards',
        'reward_pending_claims'
      });

      final cols = (await db.rawQuery("PRAGMA table_info(family_rules)"))
          .map((Map r) => r['name'] as String)
          .toList(growable: false);
      expect(cols, contains('linked_task_id'));
    });

    test('create then read round-trips every task field through SQLite',
        () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyTasksRepository(database);

      final task = _task(
          taskId: 'task-roundtrip',
          recurrence: TaskRecurrence.weekly,
          weekdays: const {1, 3, 5},
          assignedChildIds: const {'child-a-fr'},
          linkedRuleId: 'rule-gate-1');
      final created = await repo.create(task, createdByMemberId: 'parent-fr');

      final read = await repo.find('family-fr', 'task-roundtrip');
      expect(read, isNotNull);
      expect(read!.title, 'Read 20 minutes');
      expect(read.description, 'Before screen time starts');
      expect(read.dueMinute, 1050);
      expect(read.recurrence, TaskRecurrence.weekly);
      expect(read.weekdays, const {1, 3, 5});
      expect(read.assignedChildIds, const {'child-a-fr'});
      expect(read.linkedRuleId, 'rule-gate-1');
      expect(read.createdByMemberId, 'parent-fr');
      expect(created.syncState, SyncState.localOnly);
    });

    test('duplicate task id is rejected explicitly, never overwritten',
        () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyTasksRepository(database);

      await repo.create(_task(taskId: 'task-dup'),
          createdByMemberId: 'parent-fr');
      expect(
          () => repo.create(_task(taskId: 'task-dup'),
              createdByMemberId: 'parent-fr'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_task_exists'))));
    });

    test('missing task id throws on update and cancel', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyTasksRepository(database);

      expect(
          () => repo.update(_task(taskId: 'task-ghost')),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_task_missing'))));
      expect(
          () => repo.cancel('family-fr', 'task-ghost'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_task_missing'))));
    });

    test('task create dispatches exactly one outbox row', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyTasksRepository(database);

      await repo.create(_task(taskId: 'task-outbox'),
          createdByMemberId: 'parent-fr');
      final rows = await (await database.database).query('outbox',
          where: 'aggregate_id = ?', whereArgs: ['task-outbox']);
      expect(rows.length, 1);
      expect(rows.first['operation'], 'create');
      expect(rows.first['aggregate_type'], 'family_task');
    });
  });

  // ── FS-007 completion honesty machine ────────────────────────────────
  group('FS-007 completion honesty machine', () {
    late GuardianDatabase database;
    late FamilyTasksRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await _seedFamily(await database.database);
      repo = FamilyTasksRepository(database);
    });

    test('request marks the task in progress and logs a requested entry',
        () async {
      await repo.create(_task(taskId: 'task-req'),
          createdByMemberId: 'parent-fr');

      await repo.requestCompletion(
          familyId: 'family-fr',
          taskId: 'task-req',
          childId: 'child-a-fr',
          actorMemberId: 'child-a-fr',
          note: 'I finished reading');

      final task = await repo.find('family-fr', 'task-req');
      expect(task!.status, TaskStatus.inProgress);
      final log = await repo.logForTask('family-fr', 'task-req');
      expect(log.length, 1);
      expect(log.first.action, TaskCompletionAction.requested);
      expect(log.first.childId, 'child-a-fr');
    });

    test('verifyCompletion is the only path to completed', () async {
      await repo.create(_task(taskId: 'task-verify'),
          createdByMemberId: 'parent-fr');
      await repo.requestCompletion(
          familyId: 'family-fr',
          taskId: 'task-verify',
          childId: 'child-a-fr',
          actorMemberId: 'child-a-fr');
      await repo.verifyCompletion(
          familyId: 'family-fr',
          taskId: 'task-verify',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');

      final task = await repo.find('family-fr', 'task-verify');
      expect(task!.status, TaskStatus.completed);
      final actions = (await repo.logForTask('family-fr', 'task-verify'))
          .map((e) => e.action)
          .toList();
      expect(actions,
          [TaskCompletionAction.requested, TaskCompletionAction.completed]);
    });

    test('declineCompletion records an honest declined entry', () async {
      await repo.create(_task(taskId: 'task-decline'),
          createdByMemberId: 'parent-fr');
      await repo.requestCompletion(
          familyId: 'family-fr',
          taskId: 'task-decline',
          childId: 'child-b-fr',
          actorMemberId: 'child-b-fr');
      await repo.declineCompletion(
          familyId: 'family-fr',
          taskId: 'task-decline',
          childId: 'child-b-fr',
          actorMemberId: 'parent-fr',
          note: 'Not done yet');

      final task = await repo.find('family-fr', 'task-decline');
      expect(task!.status, TaskStatus.inProgress);
      final actions = (await repo.logForTask('family-fr', 'task-decline'))
          .map((e) => e.action)
          .toList();
      expect(actions,
          [TaskCompletionAction.requested, TaskCompletionAction.declined]);
    });

    test('cancel sets cancelled and keeps history', () async {
      await repo.create(_task(taskId: 'task-cancel'),
          createdByMemberId: 'parent-fr');
      await repo.cancel('family-fr', 'task-cancel');

      final task = await repo.find('family-fr', 'task-cancel');
      expect(task!.status, TaskStatus.cancelled);
      final log = await repo.logForTask('family-fr', 'task-cancel');
      expect(log.map((e) => e.action), [TaskCompletionAction.cancelled]);
    });

    test('terminal tasks refuse new completion requests', () async {
      await repo.create(_task(taskId: 'task-terminal'),
          createdByMemberId: 'parent-fr');
      await repo.cancel('family-fr', 'task-terminal');

      expect(
          () => repo.requestCompletion(
              familyId: 'family-fr',
              taskId: 'task-terminal',
              childId: 'child-a-fr',
              actorMemberId: 'child-a-fr'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_task_terminal'))));
    });

    test('gate reads the honest log and covers all assigned children',
        () async {
      await repo.create(
          _task(
              taskId: 'task-gate',
              assignedChildIds: const {'child-a-fr', 'child-b-fr'},
              linkedRuleId: 'rule-gate-2'),
          createdByMemberId: 'parent-fr');
      await repo.requestCompletion(
          familyId: 'family-fr',
          taskId: 'task-gate',
          childId: 'child-a-fr',
          actorMemberId: 'child-a-fr');
      await repo.verifyCompletion(
          familyId: 'family-fr',
          taskId: 'task-gate',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');
      await repo.verifyCompletion(
          familyId: 'family-fr',
          taskId: 'task-gate',
          childId: 'child-b-fr',
          actorMemberId: 'parent-fr');

      final gates =
          await repo.gateCompletions('family-fr', taskIds: const ['task-gate']);
      expect(gates['task-gate'], const {'child-a-fr', 'child-b-fr'});
      final completed = await repo.completedChildren('family-fr', 'task-gate');
      expect(completed, const {'child-a-fr', 'child-b-fr'});
    });

    test('applicableForChild filters by assignment', () async {
      await repo.create(
          _task(taskId: 'task-only-a', assignedChildIds: const {'child-a-fr'}),
          createdByMemberId: 'parent-fr');
      await repo.create(
          _task(taskId: 'task-only-b', assignedChildIds: const {'child-b-fr'}),
          createdByMemberId: 'parent-fr');

      expect(
          (await repo.applicableForChild(
                  familyId: 'family-fr', childId: 'child-a-fr'))
              .map((t) => t.taskId)
              .toSet(),
          const {'task-only-a'});
    });
  });

  // ── FS-011 bridge: taskGated rule gate resolver ──────────────────────
  group('FS-007 ↔ FS-011 taskGated bridge', () {
    test('taskGated rule stores and exposes linkedTaskId', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyRulesRepository(database);

      await repo.create(
          FamilyRule(
              ruleId: 'rule-gated',
              familyId: 'family-fr',
              name: 'App unlocked after homework',
              kind: RuleKind.taskGated,
              action: RuleAction.allowlistOnly,
              assignedChildIds: const {'child-a-fr'},
              appTargets: const {'com.example.game'},
              linkedTaskId: 'task-homework',
              createdAt: _seededAt),
          createdByMemberId: 'parent-fr');

      final read = await repo.find('family-fr', 'rule-gated');
      expect(read!.linkedTaskId, 'task-homework');
      expect(read.kind.isExecutable, isFalse);

      // The pure gate resolver opens only when every assigned child has
      // a completed log row.
      const resolver = TaskGateResolver();
      expect(
          resolver.isGateOpen(
              assignedChildIds: const {'child-a-fr'},
              completedForChildren: const {}),
          isFalse);
      expect(
          resolver.isGateOpen(
              assignedChildIds: const {'child-a-fr'},
              completedForChildren: const {'child-a-fr'}),
          isTrue);
    });
  });

  // ── FS-008 rewards CRUD ──────────────────────────────────────────────
  group('FS-008 rewards catalog', () {
    test('create then read round-trips every reward field', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyRewardsRepository(database);

      await repo.create(
          _reward(rewardId: 'reward-rt', expiryDays: 30, costPoints: 75),
          createdByMemberId: 'parent-fr');
      final read = await repo.find('family-fr', 'reward-rt');
      expect(read, isNotNull);
      expect(read!.name, 'Ice cream outing');
      expect(read.costPoints, 75);
      expect(read.expiryDays, 30);
      expect(read.enabled, isTrue);
      expect(read.createdByMemberId, 'parent-fr');
    });

    test('duplicate reward id is rejected explicitly', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyRewardsRepository(database);

      await repo.create(_reward(rewardId: 'reward-dup'),
          createdByMemberId: 'parent-fr');
      expect(
          () => repo.create(_reward(rewardId: 'reward-dup'),
              createdByMemberId: 'parent-fr'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_reward_exists'))));
    });

    test('toggleEnabled flips the flag honestly in both directions', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyRewardsRepository(database);

      await repo.create(_reward(rewardId: 'reward-toggle'),
          createdByMemberId: 'parent-fr');
      await repo.toggleEnabled(
          familyId: 'family-fr', rewardId: 'reward-toggle');
      expect((await repo.find('family-fr', 'reward-toggle'))!.enabled, isFalse);
      await repo.toggleEnabled(
          familyId: 'family-fr', rewardId: 'reward-toggle');
      expect((await repo.find('family-fr', 'reward-toggle'))!.enabled, isTrue);
    });

    test('missing reward id throws on update and toggle', () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyRewardsRepository(database);

      expect(
          () => repo.update(_reward(rewardId: 'reward-ghost')),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_reward_missing'))));
      expect(
          () => repo.toggleEnabled(
              familyId: 'family-fr', rewardId: 'reward-ghost'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('family_reward_missing'))));
    });
  });

  // ── FS-008 append-only ledger ────────────────────────────────────────
  group('FS-008 append-only ledger', () {
    late GuardianDatabase database;
    late FamilyRewardsRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await _seedFamily(await database.database);
      repo = FamilyRewardsRepository(database);
    });

    test('earn adds a positive row and balance equals sum(delta)', () async {
      await repo.earn(
          familyId: 'family-fr',
          childId: 'child-a-fr',
          points: 30,
          reason: LedgerReason.earnedFromTask,
          referenceId: 'task-t1',
          actedBy: 'parent-fr');
      await repo.earn(
          familyId: 'family-fr',
          childId: 'child-a-fr',
          points: 20,
          reason: LedgerReason.manualGrant,
          actedBy: 'parent-fr');

      expect(await repo.balanceFor('family-fr', 'child-a-fr'), 50);
      final rows = await repo.ledgerForChild('family-fr', 'child-a-fr');
      expect(rows.map((r) => r.delta).toSet(), const {30, 20});
      expect(rows.first.balanceAfter, 50);
    });

    test('earn refuses non-positive points', () async {
      expect(
          () => repo.earn(
              familyId: 'family-fr',
              childId: 'child-a-fr',
              points: 0,
              reason: LedgerReason.manualGrant,
              actedBy: 'parent-fr'),
          throwsArgumentError);
      expect(
          () => repo.earn(
              familyId: 'family-fr',
              childId: 'child-a-fr',
              points: -5,
              reason: LedgerReason.manualGrant,
              actedBy: 'parent-fr'),
          throwsArgumentError);
    });

    test('spend row exists only through parent-approved deduction', () async {
      await repo.earn(
          familyId: 'family-fr',
          childId: 'child-b-fr',
          points: 60,
          reason: LedgerReason.earnedFromTask,
          actedBy: 'parent-fr');
      await repo.recordApprovedSpend(
          familyId: 'family-fr',
          childId: 'child-b-fr',
          points: 25,
          claimId: 'claim-spend',
          actedBy: 'parent-fr');

      expect(await repo.balanceFor('family-fr', 'child-b-fr'), 35);
      final rows = await repo.ledgerForChild('family-fr', 'child-b-fr');
      expect(
          rows.any((r) =>
              r.delta == -25 && r.reason == LedgerReason.parentApprovedSpend),
          isTrue);
    });
  });

  // ── FS-008 claims (parent decides before money moves) ────────────────
  group('FS-008 redemption claims', () {
    late GuardianDatabase database;
    late FamilyRewardsRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await _seedFamily(await database.database);
      repo = FamilyRewardsRepository(database);
      await repo.create(_reward(rewardId: 'reward-claim', costPoints: 40),
          createdByMemberId: 'parent-fr');
      await repo.earn(
          familyId: 'family-fr',
          childId: 'child-a-fr',
          points: 100,
          reason: LedgerReason.earnedFromTask,
          actedBy: 'parent-fr');
    });

    test('requestRedemption enqueues a pending claim', () async {
      final claim = await repo.requestRedemption(
          familyId: 'family-fr',
          rewardId: 'reward-claim',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');
      expect(claim.isPending, isTrue);

      final pending = await repo.pendingClaims('family-fr');
      expect(pending, hasLength(1));
      expect(pending.first.claimId, claim.claimId);
    });

    test('approveClaim spends points and closes the claim', () async {
      final claim = await repo.requestRedemption(
          familyId: 'family-fr',
          rewardId: 'reward-claim',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');
      await repo.approveClaim(
          familyId: 'family-fr',
          claimId: claim.claimId,
          decidedByMemberId: 'parent-fr');

      expect(await repo.balanceFor('family-fr', 'child-a-fr'), 60);
      final read = await repo.findClaim('family-fr', claim.claimId);
      expect(read!.decision, ClaimDecision.approved);
      expect(read.decidedBy, 'parent-fr');
    });

    test('declineClaim closes the claim without moving the ledger', () async {
      final claim = await repo.requestRedemption(
          familyId: 'family-fr',
          rewardId: 'reward-claim',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');
      await repo.declineClaim(
          familyId: 'family-fr',
          claimId: claim.claimId,
          decidedByMemberId: 'parent-fr',
          note: 'Not this week');

      expect(await repo.balanceFor('family-fr', 'child-a-fr'), 100);
      final read = await repo.findClaim('family-fr', claim.claimId);
      expect(read!.decision, ClaimDecision.declined);
    });

    test('a claim cannot be decided twice', () async {
      final claim = await repo.requestRedemption(
          familyId: 'family-fr',
          rewardId: 'reward-claim',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');
      await repo.declineClaim(
          familyId: 'family-fr',
          claimId: claim.claimId,
          decidedByMemberId: 'parent-fr');
      expect(
          () => repo.declineClaim(
              familyId: 'family-fr',
              claimId: claim.claimId,
              decidedByMemberId: 'parent-fr'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('claim_already_decided'))));
    });

    test('claims on disabled rewards are refused honestly', () async {
      await repo.toggleEnabled(familyId: 'family-fr', rewardId: 'reward-claim');
      expect(
          () => repo.requestRedemption(
              familyId: 'family-fr',
              rewardId: 'reward-claim',
              childId: 'child-a-fr',
              actorMemberId: 'parent-fr'),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'message', contains('reward_disabled'))));
    });
  });

  // ── FS-008 outbox honesty ────────────────────────────────────────────
  group('FS-008 outbox honesty', () {
    test('create, toggle, earn and claim each dispatch one outbox row',
        () async {
      final database = await openTestDatabase();
      await _seedFamily(await database.database);
      final repo = FamilyRewardsRepository(database);

      await repo.create(_reward(rewardId: 'reward-outbox'),
          createdByMemberId: 'parent-fr');
      await repo.toggleEnabled(
          familyId: 'family-fr', rewardId: 'reward-outbox');
      await repo.toggleEnabled(
          familyId: 'family-fr', rewardId: 'reward-outbox');
      await repo.earn(
          familyId: 'family-fr',
          childId: 'child-a-fr',
          points: 10,
          reason: LedgerReason.manualGrant,
          actedBy: 'parent-fr');
      await repo.requestRedemption(
          familyId: 'family-fr',
          rewardId: 'reward-outbox',
          childId: 'child-a-fr',
          actorMemberId: 'parent-fr');

      final rows = await (await database.database).query('outbox',
          where: 'idempotency_key LIKE ?', whereArgs: ['%:family-fr:%']);
      final operations =
          rows.map((r) => r['operation'] as String).toList(growable: false);
      expect(operations, ['create', 'toggle', 'toggle', 'earned', 'requested']);
      expect(rows.length, 5);
    });
  });
}
