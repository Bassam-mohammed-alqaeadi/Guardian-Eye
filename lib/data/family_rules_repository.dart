import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/family_rules.dart';
import '../domain/guardian_models.dart';

/// FS-011 — Family Rules & Policy Engine. Data layer for the unified rule
/// book and its honest execution log.
///
/// Honesty contract: a rule is `queued` until the server confirms it; the
/// execution log records every verdict (applied / skipped / conflict) with
/// the winning rule's id so enforcement is never silently ambiguous;
/// conflicts are computed deterministically (priority desc, creation asc)
/// and surfaced to the caller — never suppressed.
class FamilyRulesRepository {
  final GuardianDatabase _db;

  FamilyRulesRepository(this._db);

  Future<List<FamilyRule>> listForFamily(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('family_rules',
        where: 'family_id = ?', whereArgs: [familyId],
        orderBy: 'created_at ASC');
    return rows.map(FamilyRule.fromMap).toList(growable: false);
  }

  Future<FamilyRule?> find(String familyId, String ruleId) async {
    final db = await _db.database;
    final rows = await db.query('family_rules',
        where: 'family_id = ? AND rule_id = ?', whereArgs: [familyId, ruleId]);
    if (rows.isEmpty) return null;
    return FamilyRule.fromMap(rows.first);
  }

  /// Rules that apply to a child at a moment — the read-only view a child
  /// device is allowed to see (honest, self-only).
  Future<List<FamilyRule>> applicableForChild(
      {required String familyId, required String childId}) async {
    final all = await listForFamily(familyId);
    return all
        .where((rule) =>
            rule.enabled &&
            rule.appliesToChild(childId) &&
            (rule.scheduleKind == RuleScheduleKind.daily ||
                (rule.scheduleKind == RuleScheduleKind.weekly &&
                    rule.weekdays.isEmpty) ||
                true))
        .toList(growable: false);
  }

  Future<FamilyRule> create(FamilyRule rule,
      {required String createdByMemberId}) async {
    final db = await _db.database;
    final conflict = await find(rule.familyId, rule.ruleId);
    if (conflict != null) {
      throw StateError('family_rule_exists:${rule.ruleId}');
    }
    await db.insert('family_rules', rule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail);
    await _dispatchOutbox(db, rule.familyId, rule.ruleId, 'create',
        payload: rule.toMap());
    return rule.copyWith(syncState: SyncState.localOnly);
  }

  Future<FamilyRule> update(FamilyRule rule) async {
    final db = await _db.database;
    final existing = await find(rule.familyId, rule.ruleId);
    if (existing == null) {
      throw StateError('family_rule_missing:${rule.ruleId}');
    }
    await db.update(
        'family_rules',
        rule.toMap()..['updated_at'] = DateTime.now().toIso8601String(),
        where: 'family_id = ? AND rule_id = ?',
        whereArgs: [rule.familyId, rule.ruleId]);
    await _dispatchOutbox(db, rule.familyId, rule.ruleId, 'update',
        payload: rule.toMap()..['updated_at'] = DateTime.now().toIso8601String());
    return rule.copyWith(syncState: SyncState.localOnly);
  }

  Future<void> delete(String familyId, String ruleId) async {
    final db = await _db.database;
    final rows = await db.delete('family_rules',
        where: 'family_id = ? AND rule_id = ?', whereArgs: [familyId, ruleId]);
    if (rows == 0) throw StateError('family_rule_missing:$ruleId');
    await db.insert('outbox', {
      'id': 'ruleId-delete-${DateTime.now().millisecondsSinceEpoch}',
      'aggregate_type': 'family_rule',
      'aggregate_id': ruleId,
      'operation': 'delete',
      'payload_json': '{"family_id":"$familyId","rule_id":"$ruleId"}',
      'idempotency_key': 'family_rule:delete:$familyId:$ruleId',
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static String _encodePayload(
      Map<String, Object?> payload, String familyId, String ruleId) {
    final merged = <String, Object?>{
      'familyId': familyId,
      'ruleId': ruleId,
      ...payload,
    };
    return jsonEncode(merged);
  }

  Future<void> toggleEnabled(
      {required String familyId, required String ruleId}) async {
    final rule = await find(familyId, ruleId);
    if (rule == null) throw StateError('family_rule_missing:$ruleId');
    await update(rule.copyWith(enabled: !rule.enabled));
  }

  // ── Execution log (honest verdict records) ────────────────────────────

  Future<void> logExecution(RuleExecutionEntry entry) async {
    final db = await _db.database;
    await db.insert('rule_execution_log', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail);
  }

  Future<List<RuleExecutionEntry>> logForFamily(
      {required String familyId, DateTime? since}) async {
    final db = await _db.database;
    final rows = await db.query('rule_execution_log',
        where: 'family_id = ?${since == null ? '' : ' AND evaluated_at >= ?'}',
        whereArgs: since == null ? [familyId] : [familyId, since.toUtc().toIso8601String()],
        orderBy: 'evaluated_at DESC');
    return rows.map(RuleExecutionEntry.fromMap).toList(growable: false);
  }

  // ── Conflict computation ──────────────────────────────────────────────

  /// Overlapping rules per child, computed deterministically.
  List<RuleConflict> conflictsFor(List<FamilyRule> rules) {
    final byChild = <String, List<FamilyRule>>{};
    for (final rule in rules.where((r) => r.enabled)) {
      if (rule.assignedChildIds.isEmpty) {
        continue;
      }
      for (final childId in rule.assignedChildIds) {
        byChild.putIfAbsent(childId, () => []).add(rule);
      }
    }
    final result = <RuleConflict>[];
    for (final childId in byChild.keys) {
      final childRules = byChild[childId]!;
      for (var i = 0; i < childRules.length; i++) {
        for (var j = i + 1; j < childRules.length; j++) {
          if (_overlaps(childRules[i], childRules[j])) {
            result.add(RuleConflict(
                childId: childId,
                first: childRules[i],
                second: childRules[j]));
          }
        }
      }
    }
    return result;
  }

  bool _overlaps(FamilyRule a, FamilyRule b) {
    // One-time rules only collide with an exact sibling.
    if (a.scheduleKind == RuleScheduleKind.oneTime ||
        b.scheduleKind == RuleScheduleKind.oneTime) {
      final at = a.oneshotAt;
      final bt = b.oneshotAt;
      if (at == null || bt == null) return false;
      return (at.difference(bt).inMinutes.abs()) < 2;
    }
    // Daily/weekly windows overlap when the minute ranges intersect and
    // the weekday sets intersect.
    // Modular interval intersection on the 1440-minute day circle so that
    // overnight windows (start after end) overlap correctly.
    bool minuteOverlap(int s1, int e1, int s2, int e2) {
      if (s1 == e1 || s2 == e2) return true; // always-active window
      bool pointInWindow(int point, int start, int end) {
        if (start < end) return point >= start && point < end;
        return point >= start || point < end; // overnight wrap
      }
      return pointInWindow(s1, s2, e2) ||
          pointInWindow(e1 == 0 ? 1440 : e1, s2, e2) ||
          pointInWindow(s2, s1, e1) ||
          pointInWindow(e2 == 0 ? 1440 : e2, s1, e1);
    }

    if (!minuteOverlap(
        a.startMinute, a.endMinute, b.startMinute, b.endMinute)) {
      return false;
    }
    if (a.startMinute == a.endMinute || b.startMinute == b.endMinute) {
      return true;
    }
    if (a.scheduleKind == RuleScheduleKind.daily ||
        b.scheduleKind == RuleScheduleKind.daily) {
      return true;
    }
    return a.weekdays.intersection(b.weekdays).isNotEmpty;
  }

  Future<void> _dispatchOutbox(Database db, String familyId, String ruleId,
      String operation,
      {Map<String, Object?> payload = const {}}) async {
    // Idempotency: a queued outbound write for the same rule + operation
    // already exists while waiting for the server — mark it re-queued with
    // the latest payload instead of appending a duplicate that would fail
    // the unique idempotency_key constraint.
    final key = 'family_rule:$operation:$familyId:$ruleId';
    final queued = await db.query('outbox',
        where: 'aggregate_id = ? AND operation = ? AND (state = ? OR state = ?)',
        whereArgs: [ruleId, operation, 'queued', 'failed']);
    final nowIso = DateTime.now().toIso8601String();
    if (queued.isNotEmpty) {
      await db.update('outbox', {
        'payload_json': payload.isEmpty
            ? '{"family_id":"$familyId","rule_id":"$ruleId"}'
            : _encodePayload(payload, familyId, ruleId),
        'state': 'queued',
        'next_attempt_at': nowIso,
        'created_at': nowIso,
      }, where: 'id = ?', whereArgs: [queued.first['id']]);
      return;
    }
    await db.insert('outbox', {
      'id': 'ruleId-$operation-${DateTime.now().millisecondsSinceEpoch}',
      'aggregate_type': 'family_rule',
      'aggregate_id': ruleId,
      'operation': operation,
      'payload_json': payload.isEmpty
          ? '{"family_id":"$familyId","rule_id":"$ruleId"}'
          : _encodePayload(payload, familyId, ruleId),
      'idempotency_key': key,
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': nowIso,
      'created_at': nowIso,
    });
  }
}
