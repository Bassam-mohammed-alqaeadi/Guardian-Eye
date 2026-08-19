import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/guardian_models.dart';

/// FS-003 — Application Control.
///
/// Parents see installed apps on linked child devices and apply per-app
/// block/allow/time policies. The allowlist survives mode changes. Every
/// write follows the platform's honesty rhythm: local SQLite first,
/// `sync_state` stays 'queued' until the server confirms.
///
/// App metadata and usage aggregates come from existing child device sync
/// payloads and the usage tables (child_usage_summaries) — no new backend
/// fields are introduced.

/// One installed/known app record as seen on a child's device.
class InstalledAppRecord {
  final String packageId;
  final String displayName;
  final String category;
  final bool isAllowlisted;
  final DateTime? lastSeenAt;
  final String deviceId;

  const InstalledAppRecord({
    required this.packageId,
    required this.displayName,
    required this.category,
    required this.isAllowlisted,
    this.lastSeenAt,
    required this.deviceId,
  });
}

/// Per-app policy enforced for the family (optionally child-scoped).
class AppPolicyEntry {
  final String familyId;
  final String childId;
  final String target; // app package path / target id
  final AppPolicyAction action;
  final Duration? timeAllowance;
  final String ratingMax;
  final SyncState syncState;
  final DateTime updatedAt;

  const AppPolicyEntry({
    required this.familyId,
    required this.childId,
    required this.target,
    required this.action,
    this.timeAllowance,
    required this.ratingMax,
    required this.syncState,
    required this.updatedAt,
  });

  static SyncState _syncStateOf(String? raw) {
    if (raw == null) return SyncState.queued;
    switch (raw) {
      case 'synced':
        return SyncState.synced;
      case 'failed':
        return SyncState.failed;
      case 'blocked':
        return SyncState.blocked;
      case 'localOnly':
        return SyncState.localOnly;
      default:
        return SyncState.queued;
    }
  }

  Map<String, Object?> toMap() => {
        'family_id': familyId,
        'child_id': childId.isEmpty ? null : childId,
        'target': target,
        'action': action.name,
        'limit_milliseconds': timeAllowance?.inMilliseconds,
        'rating_max': ratingMax,
        'sync_state': syncState.name,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Apps the family trusts and never blocks.
class AppAllowlistEntry {
  final String familyId;
  final String target;
  final String reason;
  final String addedBy;
  final DateTime createdAt;

  const AppAllowlistEntry({
    required this.familyId,
    required this.target,
    required this.reason,
    required this.addedBy,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'family_id': familyId,
        'target': target,
        'reason': reason,
        'added_by': addedBy,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Honest audit event recorded whenever an app's enforcement changes.
class AppBlockEvent {
  final String familyId;
  final String target;
  final String? childId;
  final AppBlockEventType eventType;
  final String? reason;
  final DateTime createdAt;

  const AppBlockEvent({
    required this.familyId,
    required this.target,
    this.childId,
    required this.eventType,
    this.reason,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'family_id': familyId,
        'target': target,
        'child_id': childId,
        'event': eventType.name,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Threshold-based usage alert configured per app.
class UsageAlertSetting {
  final String familyId;
  final String? childId;
  final String target;
  final Duration threshold;
  final bool enabled;
  final DateTime updatedAt;

  const UsageAlertSetting({
    required this.familyId,
    this.childId,
    required this.target,
    required this.threshold,
    required this.enabled,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'family_id': familyId,
        'child_id': childId,
        'target': target,
        'threshold_milliseconds': threshold.inMilliseconds,
        'enabled': enabled ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// App policy categories used by per-child rules (AC-005).
enum AppPolicyAction { block, allow, limit }

enum AppBlockEventType { block, unblock, override, timeout, addedToAllowlist, removedFromAllowlist }

/// Persistence for FS-003 application control policies.
class ApplicationPolicyRepository {
  final GuardianDatabase _db;

  ApplicationPolicyRepository(this._db);

  Future<void> savePolicy(AppPolicyEntry entry) async {
    final db = await _db.database;
    await db.insert('app_policies', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await recordBlockEvent(AppBlockEvent(
      familyId: entry.familyId,
      target: entry.target,
      childId: entry.childId.isEmpty ? null : entry.childId,
      eventType: entry.action == AppPolicyAction.block
          ? AppBlockEventType.block
          : AppBlockEventType.unblock,
      reason: 'policy:${entry.action.name}',
      createdAt: entry.updatedAt,
    ));
  }

  Future<List<AppPolicyEntry>> resolvePolicies(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('app_policies',
        where: 'family_id = ?', whereArgs: [familyId],
        orderBy: 'updated_at DESC');
    return rows.map(_policyFromRow).toList(growable: false);
  }

  /// Resolves the effective policy for [childId]. A child-scoped policy
  /// (matching the exact child id) always wins over the family-wide
  /// general policy (empty child id) for the same target — even when the
  /// general policy was updated more recently. The two rules live in
  /// separate rows thanks to the `child_id` column in the primary key.
  Future<AppPolicyEntry?> resolvePolicy(
      String familyId, String childId, String target) async {
    final db = await _db.database;
    // If a child was given, prefer that child's own override.
    if (childId.isNotEmpty) {
      final childRows = await db.query('app_policies',
          where: 'family_id = ? AND child_id = ? AND target = ?',
          whereArgs: [familyId, childId, target],
          orderBy: 'updated_at DESC', limit: 1);
      if (childRows.isNotEmpty) {
        return _policyFromRow(childRows.first);
      }
    }
    // Fall back to the family-wide general policy (empty child id).
    final generalRows = await db.query('app_policies',
        where: "family_id = ? AND (child_id IS NULL OR child_id = '') AND target = ?",
        whereArgs: [familyId, target], orderBy: 'updated_at DESC', limit: 1);
    if (generalRows.isNotEmpty) {
      return _policyFromRow(generalRows.first);
    }
    return null;
  }

  Future<void> deletePolicy(String familyId, String target) async {
    final db = await _db.database;
    await db.delete('app_policies',
        where: 'family_id = ? AND target = ?',
        whereArgs: [familyId, target]);
  }

  Future<List<AppAllowlistEntry>> allowlistEntries(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('app_allowlist',
        where: 'family_id = ?', whereArgs: [familyId],
        orderBy: 'created_at DESC');
    return rows.map(_allowlistFromRow).toList(growable: false);
  }

  Future<void> addToAllowlist(AppAllowlistEntry entry) async {
    final db = await _db.database;
    await db.insert('app_allowlist', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await recordBlockEvent(AppBlockEvent(
      familyId: entry.familyId,
      target: entry.target,
      eventType: AppBlockEventType.addedToAllowlist,
      reason: entry.reason.isEmpty ? null : entry.reason,
      createdAt: entry.createdAt,
    ));
  }

  Future<void> removeFromAllowlist(String familyId, String target) async {
    final db = await _db.database;
    await db.delete('app_allowlist',
        where: 'family_id = ? AND target = ?',
        whereArgs: [familyId, target]);
    await recordBlockEvent(AppBlockEvent(
      familyId: familyId,
      target: target,
      eventType: AppBlockEventType.removedFromAllowlist,
      createdAt: DateTime.now().toUtc(),
    ));
  }

  Future<List<AppBlockEvent>> blockEvents(String familyId,
      {int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query('app_block_history',
        where: 'family_id = ?', whereArgs: [familyId],
        orderBy: 'created_at DESC', limit: limit);
    return rows.map(_eventFromRow).toList(growable: false);
  }

  Future<void> recordBlockEvent(AppBlockEvent event) async {
    final db = await _db.database;
    await db.insert('app_block_history', event.toMap());
  }

  Future<UsageAlertSetting?> resolveAlertSetting(
      String familyId, String target) async {
    final db = await _db.database;
    final rows = await db.query('usage_alert_settings',
        where: 'family_id = ? AND target = ?',
        whereArgs: [familyId, target], limit: 1);
    if (rows.isEmpty) return null;
    return _alertFromRow(rows.first);
  }

  Future<void> saveAlertSetting(UsageAlertSetting setting) async {
    final db = await _db.database;
    await db.insert('usage_alert_settings', setting.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<UsageAlertSetting>> resolveAlertSettings(
      String familyId) async {
    final db = await _db.database;
    final rows = await db.query('usage_alert_settings',
        where: 'family_id = ?', whereArgs: [familyId],
        orderBy: 'updated_at DESC');
    return rows.map(_alertFromRow).toList(growable: false);
  }

  static AppPolicyEntry _policyFromRow(Map<String, Object?> row) =>
      AppPolicyEntry(
        familyId: row['family_id'] as String,
        childId: row['child_id'] as String? ?? '',
        target: row['target'] as String,
        action: _actionOf(row['action'] as String?),
        timeAllowance: row['limit_milliseconds'] == null
            ? null
            : Duration(milliseconds: row['limit_milliseconds'] as int),
        ratingMax: row['rating_max'] as String? ?? 'all',
        syncState: _syncStateOf(row['sync_state'] as String?),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  static AppPolicyAction _actionOf(String? raw) {
    switch (raw) {
      case 'allow':
        return AppPolicyAction.allow;
      case 'limit':
        return AppPolicyAction.limit;
      default:
        return AppPolicyAction.block;
    }
  }

  static SyncState _syncStateOf(String? raw) =>
      AppPolicyEntry._syncStateOf(raw);

  static AppAllowlistEntry _allowlistFromRow(Map<String, Object?> row) =>
      AppAllowlistEntry(
        familyId: row['family_id'] as String,
        target: row['target'] as String,
        reason: row['reason'] as String? ?? '',
        addedBy: row['added_by'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  static AppBlockEvent _eventFromRow(Map<String, Object?> row) =>
      AppBlockEvent(
        familyId: row['family_id'] as String,
        target: row['target'] as String,
        childId: row['child_id'] as String?,
        eventType: _eventTypeOf(row['event'] as String?),
        reason: row['reason'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  static AppBlockEventType _eventTypeOf(String? raw) {
    switch (raw) {
      case 'unblock':
        return AppBlockEventType.unblock;
      case 'override':
        return AppBlockEventType.override;
      case 'timeout':
        return AppBlockEventType.timeout;
      case 'addedToAllowlist':
        return AppBlockEventType.addedToAllowlist;
      case 'removedFromAllowlist':
        return AppBlockEventType.removedFromAllowlist;
      default:
        return AppBlockEventType.block;
    }
  }

  static UsageAlertSetting _alertFromRow(Map<String, Object?> row) =>
      UsageAlertSetting(
        familyId: row['family_id'] as String,
        childId: row['child_id'] as String?,
        target: row['target'] as String,
        threshold: Duration(
            milliseconds: row['threshold_milliseconds'] as int),
        enabled: (row['enabled'] as int) == 1,
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
}
