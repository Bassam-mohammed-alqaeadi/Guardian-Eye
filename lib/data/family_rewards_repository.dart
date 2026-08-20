import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/family_rewards.dart';
import '../domain/guardian_models.dart';

/// FS-008 — Family Points & Rewards. Data layer.
///
/// Honesty contract: the balance of a child is ALWAYS
/// `sum(delta)` over `reward_points_ledger`. There is no writable
/// `balance` column anywhere, so a balance can never silently drift or
/// lie. A redemption request only enqueues a pending claim; the ledger
/// is touched — a negative `parentApprovedSpend` row — strictly after a
/// parent writes the approval decision.
class FamilyRewardsRepository {
  final GuardianDatabase _db;

  FamilyRewardsRepository(this._db);

  // ── Catalog ────────────────────────────────────────────────────────────

  Future<List<FamilyReward>> listForFamily(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('family_rewards',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at ASC');
    return rows.map(FamilyReward.fromMap).toList(growable: false);
  }

  Future<FamilyReward?> find(String familyId, String rewardId) async {
    final db = await _db.database;
    final rows = await db.query('family_rewards',
        where: 'family_id = ? AND reward_id = ?',
        whereArgs: [familyId, rewardId]);
    if (rows.isEmpty) return null;
    return FamilyReward.fromMap(rows.first);
  }

  Future<FamilyReward> create(FamilyReward reward,
      {required String createdByMemberId}) async {
    final db = await _db.database;
    final existing = await find(reward.familyId, reward.rewardId);
    if (existing != null) {
      throw StateError('family_reward_exists:${reward.rewardId}');
    }
    await db.insert('family_rewards', reward.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail);
    await _dispatchRewardOutbox(db, reward.familyId, reward.rewardId, 'create',
        payload: reward.toMap());
    return reward.copyWith(syncState: SyncState.localOnly);
  }

  Future<FamilyReward> update(FamilyReward reward) async {
    final db = await _db.database;
    final existing = await find(reward.familyId, reward.rewardId);
    if (existing == null) {
      throw StateError('family_reward_missing:${reward.rewardId}');
    }
    final now = DateTime.now().toIso8601String();
    await db.update('family_rewards', reward.toMap()..['updated_at'] = now,
        where: 'family_id = ? AND reward_id = ?',
        whereArgs: [reward.familyId, reward.rewardId]);
    await _dispatchRewardOutbox(db, reward.familyId, reward.rewardId, 'update',
        payload: reward.toMap()..['updated_at'] = now);
    return reward.copyWith(syncState: SyncState.localOnly);
  }

  Future<void> toggleEnabled(
      {required String familyId, required String rewardId}) async {
    final db = await _db.database;
    final reward = await find(familyId, rewardId);
    if (reward == null) throw StateError('family_reward_missing:$rewardId');
    final now = DateTime.now().toIso8601String();
    await db.update('family_rewards',
        reward.copyWith(enabled: !reward.enabled).toMap()..['updated_at'] = now,
        where: 'family_id = ? AND reward_id = ?',
        whereArgs: [familyId, rewardId]);
    await _dispatchRewardOutbox(db, familyId, rewardId, 'toggle',
        payload: {'enabled': !reward.enabled, 'updated_at': now});
  }

  // ── Ledger (sole balance source) ───────────────────────────────────────

  /// Current balance of a child: the sum of every ledger row. Zero for a
  /// child with no history — never negative, because approvals check the
  /// balance first and recompute per row.
  Future<int> balanceFor(String familyId, String childId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(delta), 0) AS total FROM reward_points_ledger '
        'WHERE family_id = ? AND child_id = ?',
        [familyId, childId]);
    return (rows.first['total'] as num).toInt();
  }

  /// Append-only earning row — the only way a balance goes up.
  Future<void> earn({
    required String familyId,
    required String childId,
    required int points,
    required LedgerReason reason,
    String? referenceId,
    required String actedBy,
  }) async {
    if (points <= 0)
      throw ArgumentError('earn_points_must_be_positive:$points');
    await _writeLedger(familyId, childId, points, reason, referenceId, actedBy);
  }

  /// Deduction row written only after a parent approves a claim — the
  /// only way a balance goes down.
  Future<void> recordApprovedSpend({
    required String familyId,
    required String childId,
    required int points,
    required String claimId,
    required String actedBy,
  }) async {
    if (points <= 0)
      throw ArgumentError('spend_points_must_be_positive:$points');
    await _writeLedger(familyId, childId, -points,
        LedgerReason.parentApprovedSpend, claimId, actedBy);
  }

  Future<void> _writeLedger(String familyId, String childId, int delta,
      LedgerReason reason, String? referenceId, String actedBy) async {
    final db = await _db.database;
    final current = await balanceFor(familyId, childId);
    final after = current + delta;
    if (after < 0) {
      throw StateError('reward_balance_underflow:$childId');
    }
    final rowId = 'ledger-${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('reward_points_ledger', {
      'id': rowId,
      'family_id': familyId,
      'child_id': childId,
      'delta': delta,
      'reason': reason.name,
      'reference_id': referenceId,
      'balance_after': after,
      'acted_by': actedBy,
      'acted_at': DateTime.now().toIso8601String(),
      'sync_state': 'queued',
    });
    await _dispatchLedgerOutbox(db, familyId, childId,
        operation: delta > 0 ? 'earned' : 'spent',
        payload: {
          'child_id': childId,
          'delta': delta,
          'reason': reason.name,
          'reference_id': referenceId,
          'balance_after': after,
          'acted_by': actedBy,
        });
  }

  Future<List<PointsLedgerEntry>> ledgerForFamily(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('reward_points_ledger',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'acted_at DESC');
    return rows.map(PointsLedgerEntry.fromMap).toList(growable: false);
  }

  Future<List<PointsLedgerEntry>> ledgerForChild(
      String familyId, String childId) async {
    final db = await _db.database;
    final rows = await db.query('reward_points_ledger',
        where: 'family_id = ? AND child_id = ?',
        whereArgs: [familyId, childId],
        orderBy: 'acted_at DESC');
    return rows.map(PointsLedgerEntry.fromMap).toList(growable: false);
  }

  // ── Pending claims (parent decides before any deduction) ──────────────

  Future<List<RewardClaim>> pendingClaims(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('reward_pending_claims',
        where: 'family_id = ? AND decision IS NULL',
        whereArgs: [familyId],
        orderBy: 'requested_at ASC');
    return rows.map(RewardClaim.fromMap).toList(growable: false);
  }

  Future<List<RewardClaim>> claimsForFamily(String familyId) async {
    final db = await _db.database;
    final rows = await db.query('reward_pending_claims',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'requested_at DESC');
    return rows.map(RewardClaim.fromMap).toList(growable: false);
  }

  Future<RewardClaim?> findClaim(String familyId, String claimId) async {
    final db = await _db.database;
    final rows = await db.query('reward_pending_claims',
        where: 'family_id = ? AND claim_id = ?',
        whereArgs: [familyId, claimId]);
    if (rows.isEmpty) return null;
    return RewardClaim.fromMap(rows.first);
  }

  /// A child requests a redemption. Nothing is deducted; the claim
  /// awaits a parent decision.
  Future<RewardClaim> requestRedemption({
    required String familyId,
    required String rewardId,
    required String childId,
    required String actorMemberId,
  }) async {
    final db = await _db.database;
    final reward = await find(familyId, rewardId);
    if (reward == null) throw StateError('family_reward_missing:$rewardId');
    if (!reward.enabled) throw StateError('reward_disabled:$rewardId');
    final now = DateTime.now();
    final claimId = 'claim-${now.millisecondsSinceEpoch}';
    await db.insert('reward_pending_claims', {
      'claim_id': claimId,
      'family_id': familyId,
      'reward_id': rewardId,
      'child_id': childId,
      'requested_at': now.toIso8601String(),
      'sync_state': 'queued',
    });
    await _dispatchClaimOutbox(db, familyId, claimId, 'requested', payload: {
      'reward_id': rewardId,
      'child_id': childId,
      'cost_points': reward.costPoints,
      'requested_at': now.toIso8601String(),
    });
    return RewardClaim(
      claimId: claimId,
      familyId: familyId,
      rewardId: rewardId,
      childId: childId,
      requestedAt: now,
      syncState: SyncState.localOnly,
    );
  }

  /// A parent approves a claim — this is the ONLY point a spend enters
  /// the ledger, and only if the balance still covers the cost.
  Future<void> approveClaim({
    required String familyId,
    required String claimId,
    required String decidedByMemberId,
  }) async {
    final db = await _db.database;
    final claim = await findClaim(familyId, claimId);
    if (claim == null) throw StateError('claim_missing:$claimId');
    if (claim.decision != null)
      throw StateError('claim_already_decided:$claimId');
    final reward = await find(familyId, claim.rewardId);
    if (reward == null)
      throw StateError('family_reward_missing:${claim.rewardId}');
    final now = DateTime.now();
    await recordApprovedSpend(
      familyId: familyId,
      childId: claim.childId,
      points: reward.costPoints,
      claimId: claimId,
      actedBy: decidedByMemberId,
    );
    await db.update(
        'reward_pending_claims',
        {
          'decided_by': decidedByMemberId,
          'decision': 'approved',
          'decided_at': now.toIso8601String(),
          'ledger_row_id': 'ledger-${now.millisecondsSinceEpoch}',
        },
        where: 'family_id = ? AND claim_id = ?',
        whereArgs: [familyId, claimId]);
    await _dispatchClaimOutbox(db, familyId, claimId, 'decided', payload: {
      'decision': 'approved',
      'child_id': claim.childId,
      'cost_points': reward.costPoints,
      'decided_by': decidedByMemberId,
      'decided_at': now.toIso8601String(),
    });
  }

  /// A parent declines — no ledger movement, claim closes honestly.
  Future<void> declineClaim({
    required String familyId,
    required String claimId,
    required String decidedByMemberId,
    String? note,
  }) async {
    final db = await _db.database;
    final claim = await findClaim(familyId, claimId);
    if (claim == null) throw StateError('claim_missing:$claimId');
    if (claim.decision != null)
      throw StateError('claim_already_decided:$claimId');
    final now = DateTime.now();
    await db.update(
        'reward_pending_claims',
        {
          'decided_by': decidedByMemberId,
          'decision': 'declined',
          'decided_at': now.toIso8601String(),
        },
        where: 'family_id = ? AND claim_id = ?',
        whereArgs: [familyId, claimId]);
    await _dispatchClaimOutbox(db, familyId, claimId, 'decided', payload: {
      'decision': 'declined',
      'child_id': claim.childId,
      'decided_by': decidedByMemberId,
      'decided_at': now.toIso8601String(),
      if (note != null) 'note': note,
    });
  }

  // ── Outbox dispatchers ─────────────────────────────────────────────────

  static String _encodePayload(
      Map<String, Object?> payload, String familyId, String aggregateId) {
    final merged = <String, Object?>{
      'familyId': familyId,
      'aggregateId': aggregateId,
      ...payload,
    };
    return jsonEncode(merged);
  }

  Future<void> _dispatchRewardOutbox(
      Database db, String familyId, String rewardId, String operation,
      {required Map<String, Object?> payload}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.insert('outbox', {
      'id': 'rewardId-$operation-$nowMs',
      'aggregate_type': 'family_reward',
      'aggregate_id': rewardId,
      'operation': operation,
      'payload_json': _encodePayload(payload, familyId, rewardId),
      'idempotency_key': 'family_reward:$operation:$familyId:$rewardId:$nowMs',
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _dispatchLedgerOutbox(
    Database db,
    String familyId,
    String childId, {
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await db.insert('outbox', {
      'id': 'ledger-$operation-${DateTime.now().millisecondsSinceEpoch}',
      'aggregate_type': 'family_reward',
      'aggregate_id': childId,
      'operation': operation,
      'payload_json': _encodePayload(payload, familyId, childId),
      'idempotency_key':
          'family_reward:$operation:$familyId:$childId:${DateTime.now().millisecondsSinceEpoch}',
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _dispatchClaimOutbox(
      Database db, String familyId, String claimId, String operation,
      {required Map<String, Object?> payload}) async {
    await db.insert('outbox', {
      'id': 'claimId-$operation-${DateTime.now().millisecondsSinceEpoch}',
      'aggregate_type': 'family_claim',
      'aggregate_id': claimId,
      'operation': operation,
      'payload_json': _encodePayload(payload, familyId, claimId),
      'idempotency_key':
          'family_claim:$operation:$familyId:$claimId:${DateTime.now().millisecondsSinceEpoch}',
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
