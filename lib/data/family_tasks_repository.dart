import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/family_tasks.dart';
import '../domain/guardian_models.dart';

/// FS-007 — Family Tasks & Daily Schedules. Data layer.
///
/// Honesty contract: a task's `status` is derived, the completion log is
/// truth. A task only becomes `completed` when a log row with action
/// `completed` exists — this repository never writes status alone.
/// Every mutation enqueues an outbox row with a full payload so the
/// Firestore sync worker can replicate `family.task.*` events.
class FamilyTasksRepository {
  final GuardianDatabase _db;

  FamilyTasksRepository(this._db);

  Future<List<TaskEntry>> listForFamily(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('tasks',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at ASC');
    return rows.map(TaskEntry.fromMap).toList(growable: false);
  }

  Future<TaskEntry?> find(String familyId, String taskId) async {
    final db = await _db.database;
    final rows = await db.query('tasks',
        where: 'family_id = ? AND task_id = ?', whereArgs: [familyId, taskId]);
    if (rows.isEmpty) return null;
    return TaskEntry.fromMap(rows.first);
  }

  /// Tasks that concern a specific child — the honest child-device view.
  Future<List<TaskEntry>> applicableForChild(
      {required String familyId, required String childId}) async {
    final all = await listForFamily(familyId);
    return all.where((t) => t.appliesToChild(childId)).toList(growable: false);
  }

  Future<TaskEntry> create(TaskEntry task,
      {required String createdByMemberId}) async {
    final db = await _db.database;
    final existing = await find(task.familyId, task.taskId);
    if (existing != null) {
      throw StateError('family_task_exists:${task.taskId}');
    }
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail);
    await _dispatchOutbox(db, task.familyId, task.taskId, 'create',
        payload: task.toMap());
    return task.copyWith(syncState: SyncState.localOnly);
  }

  Future<TaskEntry> update(TaskEntry task) async {
    final db = await _db.database;
    final existing = await find(task.familyId, task.taskId);
    if (existing == null) {
      throw StateError('family_task_missing:${task.taskId}');
    }
    final now = DateTime.now().toIso8601String();
    await db.update('tasks', task.toMap()..['updated_at'] = now,
        where: 'family_id = ? AND task_id = ?',
        whereArgs: [task.familyId, task.taskId]);
    await _dispatchOutbox(db, task.familyId, task.taskId, 'update',
        payload: task.toMap()..['updated_at'] = now);
    return task.copyWith(syncState: SyncState.localOnly);
  }

  Future<void> cancel(String familyId, String taskId) async {
    final db = await _db.database;
    final task = await find(familyId, taskId);
    if (task == null) throw StateError('family_task_missing:$taskId');
    final now = DateTime.now();
    await db.update(
        'tasks',
        {
          'status': 'cancelled',
          'updated_at': now.toIso8601String(),
        },
        where: 'family_id = ? AND task_id = ?',
        whereArgs: [familyId, taskId]);
    await db.insert('task_completion_log', {
      'id': '${DateTime.now().millisecondsSinceEpoch}-cancel',
      'task_id': taskId,
      'family_id': familyId,
      'child_id': '',
      'action': 'cancelled',
      'actor_member_id': '',
      'acted_at': now.toIso8601String(),
      'note': 'parent_cancelled',
    });
    await _dispatchOutbox(db, familyId, taskId, 'cancel', payload: {
      'task_id': taskId,
      'family_id': familyId,
      'status': 'cancelled',
      'cancelled_at': now.toIso8601String(),
    });
  }

  static String _encodePayload(
      Map<String, Object?> payload, String familyId, String taskId) {
    final merged = <String, Object?>{
      'familyId': familyId,
      'taskId': taskId,
      ...payload,
    };
    return jsonEncode(merged);
  }

  Future<void> _dispatchOutbox(
      Database db, String familyId, String taskId, String operation,
      {required Map<String, Object?> payload}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.insert('outbox', {
      'id': 'taskId-$operation-$nowMs',
      'aggregate_type': 'family_task',
      'aggregate_id': taskId,
      'operation': operation,
      'payload_json': _encodePayload(payload, familyId, taskId),
      'idempotency_key': 'family_task:$operation:$familyId:$taskId:$nowMs',
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Completion log (honest truth source) ──────────────────────────────

  /// A child self-reports completion; the honest state becomes
  /// `requested` until a parent (or self-verify policy) writes
  /// `completed`. Never writes task status directly.
  Future<void> requestCompletion({
    required String familyId,
    required String taskId,
    required String childId,
    required String actorMemberId,
    String? note,
  }) async {
    final db = await _db.database;
    final task = await find(familyId, taskId);
    if (task == null) throw StateError('family_task_missing:$taskId');
    if (task.status == TaskStatus.completed ||
        task.status == TaskStatus.cancelled) {
      throw StateError('family_task_terminal:$taskId');
    }
    final now = DateTime.now();
    await db.insert('task_completion_log', {
      'id': '${now.millisecondsSinceEpoch}-request',
      'task_id': taskId,
      'family_id': familyId,
      'child_id': childId,
      'action': 'requested',
      'actor_member_id': actorMemberId,
      'acted_at': now.toIso8601String(),
      'note': note,
    });
    await db.update(
        'tasks',
        {
          'status': TaskStatus.inProgress.name,
          'updated_at': now.toIso8601String(),
        },
        where: 'family_id = ? AND task_id = ?',
        whereArgs: [familyId, taskId]);
    await _dispatchOutbox(db, familyId, taskId, 'completion-requested',
        payload: {
          'child_id': childId,
          'action': 'requested',
          'actor_member_id': actorMemberId,
          'requested_at': now.toIso8601String(),
        });
  }

  /// Parent (or self-verify policy) confirms the self-report. This is
  /// the ONLY path to `completed` — and it lives in the log.
  Future<void> verifyCompletion({
    required String familyId,
    required String taskId,
    required String childId,
    required String actorMemberId,
    String? note,
  }) async {
    final db = await _db.database;
    final task = await find(familyId, taskId);
    if (task == null) throw StateError('family_task_missing:$taskId');
    if (task.status == TaskStatus.cancelled) {
      throw StateError('family_task_terminal:$taskId');
    }
    final now = DateTime.now();
    await db.insert('task_completion_log', {
      'id': '${now.millisecondsSinceEpoch}-completed',
      'task_id': taskId,
      'family_id': familyId,
      'child_id': childId,
      'action': 'completed',
      'actor_member_id': actorMemberId,
      'acted_at': now.toIso8601String(),
      'note': note,
    });
    await db.update(
        'tasks',
        {
          'status': TaskStatus.completed.name,
          'updated_at': now.toIso8601String(),
        },
        where: 'family_id = ? AND task_id = ?',
        whereArgs: [familyId, taskId]);
    await _dispatchOutbox(db, familyId, taskId, 'completed', payload: {
      'child_id': childId,
      'action': 'completed',
      'actor_member_id': actorMemberId,
      'completed_at': now.toIso8601String(),
    });
  }

  Future<void> declineCompletion({
    required String familyId,
    required String taskId,
    required String childId,
    required String actorMemberId,
    String? note,
  }) async {
    final db = await _db.database;
    final task = await find(familyId, taskId);
    if (task == null) throw StateError('family_task_missing:$taskId');
    final now = DateTime.now();
    await db.insert('task_completion_log', {
      'id': '${now.millisecondsSinceEpoch}-declined',
      'task_id': taskId,
      'family_id': familyId,
      'child_id': childId,
      'action': 'declined',
      'actor_member_id': actorMemberId,
      'acted_at': now.toIso8601String(),
      'note': note,
    });
    await _dispatchOutbox(db, familyId, taskId, 'completion-declined',
        payload: {
          'child_id': childId,
          'action': 'declined',
          'actor_member_id': actorMemberId,
          'declined_at': now.toIso8601String(),
        });
  }

  Future<List<TaskCompletionEntry>> logForTask(
      String familyId, String taskId) async {
    final db = await _db.database;
    final rows = await db.query('task_completion_log',
        where: 'family_id = ? AND task_id = ?',
        whereArgs: [familyId, taskId],
        orderBy: 'acted_at ASC');
    return rows.map(TaskCompletionEntry.fromMap).toList(growable: false);
  }

  Future<List<TaskCompletionEntry>> logForFamily(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('task_completion_log',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'acted_at DESC');
    return rows.map(TaskCompletionEntry.fromMap).toList(growable: false);
  }

  /// Children for whom [taskId] has a terminal `completed` row — the data
  /// `TaskGateResolver` reads for `taskGated` FS-011 rules.
  Future<Set<String>> completedChildren(String familyId, String taskId) async {
    final db = await _db.database;
    final rows = await db.query('task_completion_log',
        columns: ['child_id'],
        where: 'family_id = ? AND task_id = ? AND action = ?',
        whereArgs: [familyId, taskId, 'completed']);
    return rows.map((r) => r['child_id'] as String).toSet();
  }

  /// Bulk gate read for a family: which (taskId, childId) pairs show a
  /// completed action, for resolving many `taskGated` rules at once.
  Future<Map<String, Set<String>>> gateCompletions(String familyId,
      {required List<String> taskIds}) async {
    final db = await _db.database;
    if (taskIds.isEmpty) return const {};
    final placeholders = List.filled(taskIds.length, '?').join(',');
    final rows = await db.rawQuery(
        'SELECT task_id, child_id FROM task_completion_log '
        'WHERE family_id = ? AND action = ? AND task_id IN ($placeholders)',
        [familyId, 'completed', ...taskIds]);
    final byTask = <String, Set<String>>{};
    for (final r in rows) {
      byTask
          .putIfAbsent(r['task_id'] as String, () => {})
          .add(r['child_id'] as String);
    }
    return byTask;
  }
}
