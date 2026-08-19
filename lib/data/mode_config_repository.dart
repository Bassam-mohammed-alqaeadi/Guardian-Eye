import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';
import '../domain/mode_config.dart';

/// FS-005 — Special & Custom Modes.
///
/// Local-first store for situational modes. Parents create homework,
/// bedtime, travel and custom modes, assign children to them, and flip
/// them on and off. Everything writes to local SQLite first with
/// `sync_state = queued`; delivery only becomes "applied" when the child
/// device agent confirms — never prematurely.
class ModeConfigRepository {
  ModeConfigRepository(this._database);
  final GuardianDatabase _database;

  // ------------------------------------------------------------- configs
  Future<void> saveMode(ModeConfig mode) async {
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;
    await db.insert(
      'mode_configs',
      {
        'mode_id': mode.modeId,
        'family_id': mode.familyId,
        'name': mode.name,
        'kind': mode.kind.name,
        'action': mode.action.name,
        'enabled': mode.enabled ? 1 : 0,
        'start_minute': mode.startMinute,
        'end_minute': mode.endMinute,
        'schedule_kind': mode.scheduleKind.name,
        'weekdays': mode.weekdays.join(','),
        'oneshot_at': mode.oneshotAt?.toIso8601String(),
        'assigned_child_ids': mode.assignedChildIds.join(','),
        'category_restrictions': mode.categoryRestrictions.join(','),
        'app_restrictions': mode.appRestrictions.join(','),
        'priority': mode.priority,
        'note': mode.note,
        'created_at': mode.createdAt?.toIso8601String() ?? now,
        'updated_at': now,
        'sync_state': SyncState.queued.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ModeConfig>> modesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query(
      'mode_configs',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'priority DESC, created_at ASC',
    );
    return rows.map(ModeConfig.fromMap).toList();
  }

  Future<ModeConfig?> modeById(String familyId, String modeId) async {
    final db = await _database.database;
    final rows = await db.query(
      'mode_configs',
      where: 'family_id = ? AND mode_id = ?',
      whereArgs: [familyId, modeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ModeConfig.fromMap(rows.first);
  }

  /// Modes currently assigned to one child in this family (child view).
  Future<List<ModeConfig>> childModesFor(String familyId, String childId) async {
    final db = await _database.database;
    final rows = await db.query(
      'mode_configs',
      where: 'family_id = ? AND enabled = 1 AND assigned_child_ids LIKE ?',
      whereArgs: [familyId, '%$childId%'],
    );
    return rows.map(ModeConfig.fromMap).toList();
  }

  /// Deletes the mode and its activation history together — a deleted mode
  /// has no surviving policy surface, so keeping its activations would
  /// only pollute the log with unresolvable references.
  Future<int> deleteMode(String familyId, String modeId) async {
    final db = await _database.database;
    await db.delete(
      'mode_activations',
      where: 'family_id = ? AND mode_id = ?',
      whereArgs: [familyId, modeId],
    );
    return db.delete(
      'mode_configs',
      where: 'family_id = ? AND mode_id = ?',
      whereArgs: [familyId, modeId],
    );
  }

  // ---------------------------------------------------------- activations
  Future<List<ModeActivation>> activationsForFamily(String familyId,
      {String? modeId, int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.query(
      'mode_activations',
      where: modeId == null
          ? 'family_id = ?'
          : 'family_id = ? AND mode_id = ?',
      whereArgs: modeId == null ? [familyId] : [familyId, modeId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(ModeActivation.fromMap).toList();
  }

  Future<void> saveActivation(ModeActivation activation) async {
    final db = await _database.database;
    await db.insert(
      'mode_activations',
      activation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Turn a mode ON for its assigned children. If the mode overlaps with
  /// a stronger mode for the same child, the conflict is still recorded
  /// (honest log) — the stronger mode wins deterministically.
  Future<void> activateMode({
    required String familyId,
    required String modeId,
    String? decidedBy,
  }) async {
    final mode = await modeById(familyId, modeId);
    if (mode == null) return;
    await saveMode(mode.copyWith(enabled: true));
    final allModes = await modesForFamily(familyId);
    final resolver = const ModeConflictResolver();
    for (final childId in mode.assignedChildIds) {
      final childOrdered = resolver.effectiveOrder(
          modes: allModes, childId: childId, moment: DateTime.now());
      final conflicts = resolver.conflicts(ordered: childOrdered, childId: childId);
      final winningMode = childOrdered.isNotEmpty ? childOrdered.first : mode;
      final isWinner = winningMode.modeId == modeId;
      await saveActivation(ModeActivation(
        activationId:
            '${mode.modeId}-${childId}-${DateTime.now().millisecondsSinceEpoch}',
        modeId: modeId,
        familyId: familyId,
        childId: childId,
        state: conflicts
                .any((c) => c.loser.modeId == modeId)
            ? 'requested'
            : (isWinner ? 'active' : 'applied'),
        startedAt: DateTime.now(),
        decidedBy: decidedBy,
        syncState: SyncState.queued,
      ));
    }
  }

  /// Turn a mode OFF and record an expiry activation for its children.
  Future<void> deactivateMode({
    required String familyId,
    required String modeId,
  }) async {
    final mode = await modeById(familyId, modeId);
    if (mode == null) return;
    await saveMode(mode.copyWith(enabled: false));
    for (final childId in mode.assignedChildIds) {
      await saveActivation(ModeActivation(
        activationId:
            '${mode.modeId}-${childId}-${DateTime.now().millisecondsSinceEpoch}',
        modeId: modeId,
        familyId: familyId,
        childId: childId,
        state: 'expired',
        startedAt: DateTime.now(),
        syncState: SyncState.queued,
      ));
    }
  }
}
