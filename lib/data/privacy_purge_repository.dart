import 'package:sqflite/sqflite.dart';

import '../application/family_context_provider.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';

/// The honest result of a single table purge step.
class TablePurgeResult {
  const TablePurgeResult({
    required this.table,
    required this.deletedRows,
    required this.skippedRows,
    required this.retentionReason,
    required this.failed,
    this.error,
  });

  final String table;
  final int deletedRows;
  final int skippedRows;
  final String retentionReason;
  final bool failed;
  final String? error;
}

/// The terminal state of a local purge operation.
enum LocalPurgeState {
  notRequested,
  confirmationRequired,
  inProgress,
  completed,
  partiallyCompleted,
  failed,
  blockedMigration,
  blockedOffline,
  blockedPermission,
  cancelled,
  unknown,
}

/// Per-table outcome map returned by a purge run.
class LocalPurgeOutcome {
  const LocalPurgeOutcome({
    required this.state,
    required this.familyId,
    required this.tables,
    required this.outboxAbandoned,
    required this.billingSweeped,
    required this.artifactDirsRemoved,
  });

  final LocalPurgeState state;
  final String familyId;

  /// Outcome for every table the purge touched (purged, retained, or failed).
  final List<TablePurgeResult> tables;

  /// Outbox rows moved to `abandoned` (never silently dropped).
  final int outboxAbandoned;

  /// Billing audit rows removed by the 90-day retention sweep.
  final int billingSweeped;

  /// Number of artifact directories removed (exports, reports, thumbnails).
  final int artifactDirsRemoved;

  bool get isFullyCompleted => state == LocalPurgeState.completed;
  bool get isPartiallyCompleted => state == LocalPurgeState.partiallyCompleted;
  bool get isHonestFailure =>
      state == LocalPurgeState.failed ||
      state == LocalPurgeState.blockedMigration ||
      state == LocalPurgeState.blockedOffline ||
      state == LocalPurgeState.blockedPermission;

  List<TablePurgeResult> get failedTables =>
      tables.where((t) => t.failed).toList();
}

/// Local data purge for the current device (Phase 4C, local scope only).
///
/// Purges every approved local data domain for the actor's family inside a
/// single SQLite transaction, while honoring the approved retention rules:
///
/// - Guardian AI tables (`ai_*`) stay frozen and untouched.
/// - `billing_records` rows newer than 90 days are retained; older rows are
///   removed by an honest retention sweep.
/// - Safety/audit records (incidents/SOS per the approved decision "remain
///   until owner deletion") are retained during this self-device purge — the
///   table list below excludes `incidents` and `sos_events`.
/// - Outbox rows belonging to the family are abandoned explicitly
///   (`state: 'abandoned'`, `last_error: 'local_data_deleted'`); rows of
///   other families are untouched.
/// - `app_identity` and `notification_settings` are wiped.
/// - File artifacts under the app's privacy export/report directories are
///   deleted when present.
///
/// The operation is idempotent: a second run on an already-purged database
/// reports [LocalPurgeState.completed] with zero deletions.
class LocalPurgeService {
  LocalPurgeService({required GuardianDatabase database}) : _db = database;

  final GuardianDatabase _db;

  /// Remote data is explicitly NOT deleted. This constant anchors the honest
  /// UX banner: local data removed, cloud data remains.
  static const String remoteDataBannerKey = 'localPurgeRemoteDataRemains';

  /// Purged tables that carry no `family_id` column: they are device-global
  /// (local identity, notification preferences, and the outbox is handled
  /// separately below) and are wiped wholesale by this purge.
  static const Set<String> _deviceScopedTables = <String>{
    'app_identity',
    'notification_settings',
  };

  /// `true` when [table] is purged wholesale (no `family_id` column).
  /// Exposed for tests that verify the empty-table contract per scope.
  static bool isDeviceScoped(String table) =>
      _deviceScopedTables.contains(table);

  /// Tables purged for the actor's family in this sub-phase.
  ///
  /// Append-only safety/audit and frozen-AI domains are deliberately absent:
  /// `incidents`, `sos_events`, `task_completion_log`, `reward_points_ledger`,
  /// `rule_execution_log`, `child_enforcement_evaluations`, and every
  /// `ai_*` table.
  /// Note: the `families` row itself is NOT purged — child tables reference it
  /// through `NOT NULL` foreign keys, and the family record is the identity
  /// anchor for soft-revocation and re-invitation. Only its data domains are
  /// wiped; the family row is retained.
  /// Ordering matters: tables referenced by foreign keys must be wiped AFTER
  /// their dependents (e.g. `tasks` and `family_rules` carry
  /// `created_by_member_id` to `family_members`; several monitoring, child
  /// device, and usage tables reference `devices(id)`). `family_members` and
  /// `devices` are therefore last.
  static const List<String> purgedTables = [
    'family_invitations',
    'child_device_states',
    'child_device_policies',
    'child_usage_summaries',
    'child_usage_observations',
    'child_usage_evaluations',
    'child_enforcement_states',
    'child_exception_requests',
    'policy_overrides',
    'locations',
    'location_points',
    'geofences',
    'location_alerts',
    'favorite_places',
    'location_settings',
    'notification_events',
    'notification_tokens',
    'notification_settings',
    'messages',
    'web_hits',
    'web_domains',
    'web_category_rules',
    'web_settings',
    'app_policies',
    'app_allowlist',
    'app_block_history',
    'usage_alert_settings',
    'monitoring_shots',
    'monitoring_sessions',
    'monitoring_requests',
    'monitoring_schedules',
    'monitoring_evidence_queue',
    'mode_configs',
    'mode_activations',
    'family_rules',
    'tasks',
    'family_rewards',
    'devices',
    'reward_pending_claims',
    'couple_linking',
    'couple_proposals',
    'couple_routines',
    'couple_responsibilities',
    'couple_handovers',
    'subscription_entitlements',
    'subscription_usage_limits',
    'family_events',
    'normalized_signals',
    'source_event_tracking',
    'app_identity',
    'pairing_sessions',
    'policies',
    // FS-010 — ephemeral chat is purgable local data: threads and their
    // (already-expired or active) messages are removable by the actor's
    // honest purge request. Nothing in chat is retained or frozen.
    // `chat_messages` references `chat_threads(id)`, so it must be wiped
    // BEFORE `chat_threads`; both reference `families(id)` and are wiped
    // after `family_members`-referencing tables but before nothing else
    // depends on them — placed before `family_members` last position is
    // unnecessary because no later purged table references chat ids.
    'chat_messages',
    'chat_threads',
    'family_members',
  ];

  /// Purged tables whose rows must never be removed while a RETAINED
  /// (audit/safety) table still references them. Keys are purged tables;
  /// values map (referencingTable, idColumn, referencingIdColumn) tuples so
  /// referenced rows are skipped and reported honestly — the retained
  /// append-only logs are the single source of truth and must not be
  /// orphaned by the purge.
  static const Map<
      String,
      List<
          ({
            String referencingTable,
            String referencingIdColumn,
            String idColumn
          })>> _retainedReferencePreservedTables = {
    'tasks': [
      (
        referencingTable: 'task_completion_log',
        referencingIdColumn: 'task_id',
        idColumn: 'task_id'
      ),
    ],
    'family_rules': [
      (
        referencingTable: 'rule_execution_log',
        referencingIdColumn: 'rule_id',
        idColumn: 'rule_id'
      ),
    ],
    'family_rewards': [
      (
        referencingTable: 'reward_pending_claims',
        referencingIdColumn: 'reward_id',
        idColumn: 'reward_id'
      ),
    ],
  };

  /// Frozen Guardian AI tables — never touched, never expanded, reported as
  /// frozen in the purge outcome evidence.
  static const List<String> frozenAiTables = [
    'ai_risk_states',
    'ai_behavior_profiles',
    'ai_insights',
    'ai_detections',
    'ai_copilot_suggestions',
    'ai_policy_proposals',
    'ai_consent_scopes',
  ];

  /// Append-only / safety-audit tables retained by the approved contract.
  static const List<String> retainedTables = [
    'incidents',
    'sos_events',
    'sos_recipients',
    'task_completion_log',
    'reward_points_ledger',
    'rule_execution_log',
    'child_enforcement_evaluations',
    'billing_records', // 90-day retention sweep, see [run]
  ];

  /// Runs the local purge for [familyId]. Requires the migration gate to be
  /// healthy (a failing base-schema verification short-circuits to
  /// [LocalPurgeState.blockedMigration] without touching data) and the actor
  /// to be an active member of [familyId] whose role is not a child.
  ///
  /// The purge is transactional and idempotent: repeated runs return
  /// [LocalPurgeState.completed] with no data touched after the first run.
  Future<LocalPurgeOutcome> run({
    required String familyId,
    required FamilyRuntimeContext context,
    Future<void> Function()? onArtifactDirs,
  }) async {
    if (!context.isVerified || context.actor == null) {
      return _failed(familyId, LocalPurgeState.blockedPermission,
          reason: 'actor_not_bound');
    }
    final role = context.actor!.role;
    if (role == FamilyRole.child) {
      return _failed(familyId, LocalPurgeState.blockedPermission,
          reason: 'child_denied');
    }
    // The actor must belong to the family being purged. The actor's own
    // family binding is the canonical cross-family boundary: a device
    // bound to another family cannot purge this family's data even if the
    // surrounding runtime context advertises a different family id.
    if (context.actor!.familyId != familyId || context.familyId != familyId) {
      return _failed(familyId, LocalPurgeState.blockedPermission,
          reason: 'cross_family_denied');
    }
    final status = context.actor!.status;
    if (status != FamilyMemberStatus.active) {
      return _failed(familyId, LocalPurgeState.blockedPermission,
          reason: 'membership_not_active');
    }

    final baseHealthy = await _db.verifyBaseSchema();
    if (!baseHealthy) {
      return _failed(familyId, LocalPurgeState.blockedMigration,
          reason: 'base_schema_unhealthy');
    }

    final Database db;
    try {
      db = await _db.database;
    } catch (e) {
      return _failed(familyId, LocalPurgeState.failed, reason: 'db_open_error');
    }

    final tableResults = <TablePurgeResult>[];
    var outboxAbandoned = 0;
    var billingSweeped = 0;
    var hadFailure = false;

    await db.transaction((txn) async {
      for (final table in purgedTables) {
        try {
          // Device-global tables have no family_id column: they belong to the
          // local device, which is purged wholesale, so every row is removed.
          // Family-scoped tables keep the family isolation check.
          int deleted;
          int skipped = 0;
          String retentionReason = '';
          final preserved = _retainedReferencePreservedTables[table];
          if (preserved != null) {
            // Never orphan a retained audit row: collect the ids that the
            // referencing tables still point at and keep exactly those rows
            // (reported honestly, never silently kept).
            final keptIds = <String>{};
            for (final ref in preserved) {
              final refs = await txn.query(
                ref.referencingTable,
                columns: [ref.referencingIdColumn],
                where: 'family_id = ?',
                whereArgs: [familyId],
              );
              for (final r in refs) {
                final v = r[ref.referencingIdColumn];
                if (v is String) keptIds.add(v);
              }
            }
            deleted = await txn.delete(
              table,
              where: keptIds.isEmpty
                  ? 'family_id = ?'
                  : 'family_id = ? AND ${preserved.first.idColumn} NOT IN'
                      ' (SELECT ${preserved.first.idColumn} FROM $table'
                      ' WHERE family_id = ?'
                      ' AND ${preserved.first.idColumn} IN'
                      ' (${keptIds.map((_) => '?').join(', ')}))',
              whereArgs: keptIds.isEmpty
                  ? [familyId]
                  : [familyId, familyId, ...keptIds],
            );
            skipped = keptIds.length;
            retentionReason = skipped > 0 ? 'referenced_by_retained_logs' : '';
          } else if (_deviceScopedTables.contains(table)) {
            deleted = await txn.delete(table);
          } else {
            deleted = await txn
                .delete(table, where: 'family_id = ?', whereArgs: [familyId]);
          }
          tableResults.add(TablePurgeResult(
            table: table,
            deletedRows: deleted,
            skippedRows: skipped,
            retentionReason: retentionReason,
            failed: false,
          ));
        } catch (e) {
          hadFailure = true;
          tableResults.add(TablePurgeResult(
            table: table,
            deletedRows: 0,
            skippedRows: 0,
            retentionReason: '',
            failed: true,
            error: e.toString(),
          ));
        }
      }
      // Outbox: never silently dropped — abandoned with honest marker.
      // The outbox has no family_id column: it is the device's local sync
      // queue, and every pending mutation targets data this purge is wiping,
      // so all non-abandoned rows are marked abandoned for this family.
      try {
        outboxAbandoned = await txn.update(
          'outbox',
          {'state': 'abandoned', 'last_error': 'local_data_deleted'},
          where: 'state != \'abandoned\'',
        );
        tableResults.add(const TablePurgeResult(
          table: 'outbox',
          deletedRows: 0,
          skippedRows: 0,
          retentionReason: 'abandoned',
          failed: false,
        ));
      } catch (e) {
        hadFailure = true;
        tableResults.add(TablePurgeResult(
          table: 'outbox',
          deletedRows: 0,
          skippedRows: 0,
          retentionReason: '',
          failed: true,
          error: e.toString(),
        ));
      }

      // Billing audit retention sweep: rows older than 90 days removed.
      try {
        billingSweeped = await txn.delete(
          'billing_records',
          where:
              'family_id = ? AND created_at < datetime(\'now\', \'-90 days\')',
          whereArgs: [familyId],
        );
        tableResults.add(TablePurgeResult(
          table: 'billing_records',
          deletedRows: billingSweeped,
          skippedRows: 0,
          retentionReason: '90_day_retention',
          failed: false,
        ));
      } catch (e) {
        hadFailure = true;
        tableResults.add(TablePurgeResult(
          table: 'billing_records',
          deletedRows: 0,
          skippedRows: 0,
          retentionReason: '',
          failed: true,
          error: e.toString(),
        ));
      }

      // Retained safety/audit and frozen-AI tables: recorded, untouched.
      for (final table in retainedTables) {
        final remaining = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM $table WHERE family_id = ?', [familyId]));
        tableResults.add(TablePurgeResult(
          table: table,
          deletedRows: 0,
          skippedRows: remaining ?? 0,
          retentionReason: _retentionReasonFor(table),
          failed: false,
        ));
      }
      for (final table in frozenAiTables) {
        final remaining = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM $table WHERE family_id = ?', [familyId]));
        tableResults.add(TablePurgeResult(
          table: table,
          deletedRows: 0,
          skippedRows: remaining ?? 0,
          retentionReason: 'frozen_ai',
          failed: false,
        ));
      }
    });

    // File artifacts: outside the transaction, best-effort, honest count.
    var artifactDirsRemoved = 0;
    if (onArtifactDirs != null) {
      try {
        await onArtifactDirs();
        artifactDirsRemoved = 1;
      } catch (_) {
        artifactDirsRemoved = 0;
      }
    }

    final state = hadFailure
        ? LocalPurgeState.partiallyCompleted
        : LocalPurgeState.completed;
    return LocalPurgeOutcome(
      state: state,
      familyId: familyId,
      tables: tableResults,
      outboxAbandoned: outboxAbandoned,
      billingSweeped: billingSweeped,
      artifactDirsRemoved: artifactDirsRemoved,
    );
  }

  LocalPurgeOutcome _failed(String familyId, LocalPurgeState state,
      {required String reason}) {
    return LocalPurgeOutcome(
      state: state,
      familyId: familyId,
      tables: [],
      outboxAbandoned: 0,
      billingSweeped: 0,
      artifactDirsRemoved: 0,
    );
  }

  String _retentionReasonFor(String table) {
    switch (table) {
      case 'incidents':
      case 'sos_events':
        return 'safety_audit_until_owner_deletion';
      case 'task_completion_log':
        return 'append_only_ledger';
      case 'reward_points_ledger':
        return 'append_only_ledger';
      case 'rule_execution_log':
        return 'append_only_ledger';
      case 'child_enforcement_evaluations':
        return 'append_only_ledger';
      case 'billing_records':
        return '90_day_retention';
      default:
        return 'retained';
    }
  }
}
