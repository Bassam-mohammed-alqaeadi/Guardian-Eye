import 'guardian_models.dart';

/// FS-008 — Family Points & Rewards.
///
/// An honest ledger is the heart of this subsystem: every point a child
/// has ever earned or spent lives in `reward_points_ledger` with a
/// machine-readable reason, so the dashboard balance is always the sum
/// of the ledger and never a separately-writable field that could drift
/// or lie. A spend is only deducted when a parent **approves** a pending
/// redemption — a child's "redeem" merely enqueues a claim; no silent
/// deduction, ever.
///
/// Integration with FS-011: a `rewardUnlocked` family rule carries a
/// `linkedRewardCost` plus an `automationCondition` — when the condition
/// evaluates true, the automation handler here writes a `manualGrant`
/// ledger row (same honesty contract as task gates) and re-enables the
/// purchased relaxation. Automation rules are listed in RW-006.

/// Why a ledger row exists. Exhaustive on purpose — every row must have
/// a provable source.
enum LedgerReason {
  /// Earned because a parent-verified task completed (reference: task id).
  earnedFromTask,

  /// Parent granted points by hand (no automation, no task).
  manualGrant,

  /// Automation rule granted points (reference: rule id).
  automation,

  /// Parent-approved spend (reference: claim id).
  parentApprovedSpend,

  /// Reversal of an approved spend when the claim was refunded.
  spendRefund,
}

/// A single ledger row — one immutable movement of points for one child.
class PointsLedgerEntry {
  const PointsLedgerEntry({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.delta,
    required this.reason,
    this.referenceId,
    required this.balanceAfter,
    required this.actedBy,
    required this.actedAt,
    this.syncState = SyncState.queued,
  });

  final String id;
  final String familyId;
  final String childId;
  final int delta;
  final LedgerReason reason;
  final String? referenceId;
  final int balanceAfter;
  final String actedBy;
  final DateTime actedAt;
  final SyncState syncState;

  bool get isEarning => delta > 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'family_id': familyId,
        'child_id': childId,
        'delta': delta,
        'reason': reason.name,
        'reference_id': referenceId,
        'balance_after': balanceAfter,
        'acted_by': actedBy,
        'acted_at': actedAt.toIso8601String(),
        'sync_state': syncState.name,
      };

  factory PointsLedgerEntry.fromMap(Map<String, Object?> row) =>
      PointsLedgerEntry(
        id: row['id'] as String,
        familyId: row['family_id'] as String,
        childId: row['child_id'] as String,
        delta: row['delta'] as int,
        reason: LedgerReason.values.firstWhere((r) => r.name == row['reason'],
            orElse: () => LedgerReason.manualGrant),
        referenceId: row['reference_id'] as String?,
        balanceAfter: row['balance_after'] as int,
        actedBy: (row['acted_by'] ?? '') as String,
        actedAt: DateTime.tryParse(row['acted_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        syncState: SyncState.values.firstWhere(
            (s) => s.name == row['sync_state'],
            orElse: () => SyncState.queued),
      );
}

/// A reward the parent offers in the catalog; children spend points on it.
class FamilyReward {
  const FamilyReward({
    required this.rewardId,
    required this.familyId,
    required this.name,
    this.description,
    required this.costPoints,
    this.expiryDays,
    this.enabled = true,
    this.createdByMemberId,
    required this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.queued,
  });

  final String rewardId;
  final String familyId;
  final String name;
  final String? description;
  final int costPoints;

  /// Days after redemption the reward stays claimable; null = no expiry.
  final int? expiryDays;
  final bool enabled;
  final String? createdByMemberId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  FamilyReward copyWith({
    String? name,
    String? description,
    int? costPoints,
    int? expiryDays,
    bool? enabled,
    SyncState? syncState,
  }) =>
      FamilyReward(
        rewardId: rewardId,
        familyId: familyId,
        name: name ?? this.name,
        description: description ?? this.description,
        costPoints: costPoints ?? this.costPoints,
        expiryDays: expiryDays ?? this.expiryDays,
        enabled: enabled ?? this.enabled,
        createdByMemberId: createdByMemberId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncState: syncState ?? this.syncState,
      );

  Map<String, Object?> toMap() => {
        'reward_id': rewardId,
        'family_id': familyId,
        'name': name,
        'description': description,
        'cost_points': costPoints,
        'expiry_days': expiryDays,
        'enabled': enabled ? 1 : 0,
        'created_by_member_id': createdByMemberId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toIso8601String(),
        'sync_state': syncState.name,
      };

  factory FamilyReward.fromMap(Map<String, Object?> row) => FamilyReward(
        rewardId: row['reward_id'] as String,
        familyId: row['family_id'] as String,
        name: row['name'] as String,
        description: row['description'] as String?,
        costPoints: row['cost_points'] as int,
        expiryDays: row['expiry_days'] as int?,
        enabled: (row['enabled'] as int) == 1,
        createdByMemberId: row['created_by_member_id'] as String?,
        createdAt: DateTime.tryParse((row['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
        syncState: SyncState.values.firstWhere(
            (s) => s.name == row['sync_state'],
            orElse: () => SyncState.queued),
      );
}

/// A child's redemption request. Never deducts anything by itself — a
/// parent decision row is required before the ledger moves.
enum ClaimDecision { approved, declined }

class RewardClaim {
  const RewardClaim({
    required this.claimId,
    required this.familyId,
    required this.rewardId,
    required this.childId,
    required this.requestedAt,
    this.decidedBy,
    this.decision,
    this.decidedAt,
    this.ledgerRowId,
    this.syncState = SyncState.queued,
  });

  final String claimId;
  final String familyId;
  final String rewardId;
  final String childId;
  final DateTime requestedAt;
  final String? decidedBy;
  final ClaimDecision? decision;
  final DateTime? decidedAt;
  final String? ledgerRowId;
  final SyncState syncState;

  bool get isPending => decision == null;
  bool get isApproved => decision == ClaimDecision.approved;

  Map<String, Object?> toMap() => {
        'claim_id': claimId,
        'family_id': familyId,
        'reward_id': rewardId,
        'child_id': childId,
        'requested_at': requestedAt.toIso8601String(),
        'decided_by': decidedBy,
        'decision': decision?.name,
        'decided_at': decidedAt?.toIso8601String(),
        'ledger_row_id': ledgerRowId,
        'sync_state': syncState.name,
      };

  factory RewardClaim.fromMap(Map<String, Object?> row) => RewardClaim(
        claimId: row['claim_id'] as String,
        familyId: row['family_id'] as String,
        rewardId: row['reward_id'] as String,
        childId: row['child_id'] as String,
        requestedAt: DateTime.tryParse((row['requested_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        decidedBy: row['decided_by'] as String?,
        decision: row['decision'] == null
            ? null
            : ClaimDecision.values.firstWhere(
                (d) => d.name == (row['decision'] ?? ''),
                orElse: () => ClaimDecision.declined),
        decidedAt: DateTime.tryParse(row['decided_at'] as String? ?? ''),
        ledgerRowId: row['ledger_row_id'] as String?,
        syncState: SyncState.values.firstWhere(
            (s) => s.name == row['sync_state'],
            orElse: () => SyncState.queued),
      );
}

/// FS-011 bridge: one automation rule definition. When the linked
/// `rewardUnlocked` rule evaluates true for a child, the automation
/// handler writes an `automation` ledger row for that child.
class RewardAutomation {
  const RewardAutomation({
    required this.ruleId,
    required this.familyId,
    required this.name,
    required this.grantPoints,
    required this.targetChildIds,
    this.enabled = true,
  });

  final String ruleId;
  final String familyId;
  final String name;
  final int grantPoints;

  /// Empty = family-wide grant for each evaluation.
  final Set<String> targetChildIds;
  final bool enabled;
}

/// The honest state a rewards dashboard renders.
enum RewardsListState { loading, empty, error }
