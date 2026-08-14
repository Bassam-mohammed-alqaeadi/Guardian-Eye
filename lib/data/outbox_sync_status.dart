import 'dart:convert';

import '../core/database/guardian_database.dart';

/// M9 — Honest outbox sync status queries.
///
/// Derives UI truth directly from the SQLite outbox so no screen ever claims
/// "synced" while a mutation affecting it is still queued, syncing, failed,
/// or blocked. This is the E3 fix: family-level UI must consider the real
/// pending outbox state, including the `family.created` operation whose
/// aggregate type is `family` (not `familyMembership`).
class OutboxSyncStatus {
  OutboxSyncStatus(this._database);

  final GuardianDatabase _database;

  /// True when any outbox operation that affects [familyId] is still pending
  /// (queued / syncing / failed / blocked). Matching is done on:
  ///  - `family.created` (aggregate_type `family`, aggregate_id == familyId)
  ///  - any operation whose payload carries `familyId` (members, invitations,
  ///    policies, devices, incidents, ...).
  Future<bool> hasPendingForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('outbox',
        where: "state IN ('queued','syncing','failed','blocked')");
    for (final row in rows) {
      if (row['aggregate_type'] == 'family' &&
          row['aggregate_id'] == familyId) {
        return true;
      }
      final payloadRaw = row['payload_json'] as String?;
      if (payloadRaw == null || payloadRaw.isEmpty) continue;
      try {
        final payload = jsonDecode(payloadRaw);
        if (payload is Map<String, dynamic> &&
            payload['familyId'] == familyId) {
          return true;
        }
      } catch (_) {
        // A malformed payload is not pending-sync evidence.
      }
    }
    return false;
  }

  /// Global count of operations still waiting for delivery
  /// (queued / failed / blocked). Mirrors the dashboard's honest
  /// `queuedOperations` metric.
  Future<int> pendingCount() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM outbox WHERE state IN ('queued','failed','blocked')");
    return (rows.first['c'] as num).toInt();
  }
}
