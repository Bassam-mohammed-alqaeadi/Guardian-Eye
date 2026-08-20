/// FS-013 — Couple Harmony.
///
/// Product governance (documented decisions):
///
/// 1. Observation is symmetric — either spouse may request to share the
///    same read-only view of the child layer. Neither spouse has any
///    device-management authority; authority stays with the owner.
/// 2. Every shared action passes an explicit approval gate. Proposals
///    default to `pending` and expire; nothing is ever granted silently.
/// 3. Handovers are time-boxed events with a clear before/after owner,
///    recorded in the append-only execution log, never silent.
/// 4. Routines and responsibilities are drafts until created by a
///    member with write permission; children see none of this layer.
library couple_harmony;

enum CoupleLinkingState { requested, accepted, declined }

enum CoupleProposalKind {
  locationSharing,
  appBlockingRule,
  screenTimeRule,
  routine,
  responsibility,
}

enum CoupleProposalStatus {
  pending,
  approved,
  rejected,
  expired,
}

enum HandoverStatus { pending, active, completed }

/// The owner-level linking state with a spouse member. The UI renders
/// the exact state (requested/accepted/declined) — never an assumed
/// "connected".
class CoupleLinking {
  const CoupleLinking({
    required this.familyId,
    required this.partnerMemberId,
    required this.requestState,
    required this.requestedBy,
    required this.requestedAt,
    this.respondedAt,
  });

  final String familyId;
  final String partnerMemberId;
  final CoupleLinkingState requestState;
  final String? requestedBy;
  final DateTime requestedAt;
  final DateTime? respondedAt;

  factory CoupleLinking.fromJson(Map<String, Object?> row) => CoupleLinking(
        familyId: row['family_id']! as String,
        partnerMemberId: row['partner_member_id']! as String,
        requestState:
            CoupleLinkingState.values.byName(row['request_state']! as String),
        requestedBy: row['requested_by'] as String?,
        requestedAt: DateTime.parse(row['requested_at']! as String),
        respondedAt: row['responded_at'] == null
            ? null
            : DateTime.parse(row['responded_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'family_id': familyId,
        'partner_member_id': partnerMemberId,
        'request_state': requestState.name,
        'requested_by': requestedBy,
        'requested_at': requestedAt.toIso8601String(),
        'responded_at': respondedAt?.toIso8601String(),
      };
}

/// A proposal submitted by one spouse and awaiting an explicit review
/// decision. `expiresAt` is enforced at read time — proposals never
/// silently self-apply when they age out; the status flips to `expired`
/// visibly.
class CoupleProposal {
  const CoupleProposal({
    required this.id,
    required this.familyId,
    required this.kind,
    required this.titleKey,
    this.bodyKey,
    required this.proposedBy,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final CoupleProposalKind kind;
  final String titleKey;
  final String? bodyKey;
  final String proposedBy;
  final CoupleProposalStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isDecidable => status == CoupleProposalStatus.pending;

  CoupleProposal withResolvedStatus(DateTime now) {
    if (status == CoupleProposalStatus.pending && now.isAfter(expiresAt)) {
      return CoupleProposal(
        id: id,
        familyId: familyId,
        kind: kind,
        titleKey: titleKey,
        bodyKey: bodyKey,
        proposedBy: proposedBy,
        status: CoupleProposalStatus.expired,
        reviewedBy: reviewedBy,
        reviewedAt: reviewedAt,
        expiresAt: expiresAt,
        createdAt: createdAt,
      );
    }
    return this;
  }

  factory CoupleProposal.fromJson(Map<String, Object?> row) => CoupleProposal(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        kind: CoupleProposalKind.values.byName(row['kind']! as String),
        titleKey: row['title']! as String,
        bodyKey: row['body'] as String?,
        proposedBy: row['proposed_by']! as String,
        status: CoupleProposalStatus.values.byName(row['status']! as String),
        reviewedBy: row['reviewed_by'] as String?,
        reviewedAt: row['reviewed_at'] == null
            ? null
            : DateTime.parse(row['reviewed_at']! as String),
        expiresAt: DateTime.parse(row['expires_at']! as String),
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'kind': kind.name,
        'title': titleKey,
        'body': bodyKey,
        'proposed_by': proposedBy,
        'status': status.name,
        'reviewed_by': reviewedBy,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

/// A shared routine draft covering one or more children on chosen
/// weekdays. Routines only take effect when a parent with write
/// permission creates them; a spouse-proposed routine is first a
/// [CoupleProposal].
class SharedRoutine {
  const SharedRoutine({
    required this.id,
    required this.familyId,
    required this.titleKey,
    required this.assignedChildIds,
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
    required this.enabled,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String familyId;
  final String titleKey;
  final List<String> assignedChildIds;
  final List<int> weekdays;
  final int startMinute;
  final int endMinute;
  final bool enabled;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SharedRoutine.fromJson(Map<String, Object?> row) => SharedRoutine(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        titleKey: row['title']! as String,
        assignedChildIds: (row['assigned_child_ids']! as String)
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        weekdays: (row['weekdays']! as String)
            .split(',')
            .map((s) => int.parse(s.trim()))
            .toList(),
        startMinute: row['start_minute']! as int,
        endMinute: row['end_minute']! as int,
        enabled: (row['enabled']! as int) == 1,
        createdBy: row['created_by'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'title': titleKey,
        'assigned_child_ids': assignedChildIds.join(','),
        'weekdays': weekdays.join(','),
        'start_minute': startMinute,
        'end_minute': endMinute,
        'enabled': enabled ? 1 : 0,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// One responsibility area owned by a parent, optionally delegated to a
/// spouse for a bounded window. `delegateMemberId == null` means the
/// owner retains full responsibility.
class Responsibility {
  const Responsibility({
    required this.id,
    required this.familyId,
    required this.areaKey,
    required this.ownerMemberId,
    this.delegateMemberId,
    required this.effectiveFrom,
    this.effectiveUntil,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String areaKey;
  final String ownerMemberId;
  final String? delegateMemberId;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final DateTime createdAt;

  bool get isDelegated => delegateMemberId != null;

  factory Responsibility.fromJson(Map<String, Object?> row) => Responsibility(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        areaKey: row['area']! as String,
        ownerMemberId: row['owner_member_id']! as String,
        delegateMemberId: row['delegate_member_id'] as String?,
        effectiveFrom: DateTime.parse(row['effective_from']! as String),
        effectiveUntil: row['effective_until'] == null
            ? null
            : DateTime.parse(row['effective_until']! as String),
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'area': areaKey,
        'owner_member_id': ownerMemberId,
        'delegate_member_id': delegateMemberId,
        'effective_from': effectiveFrom.toIso8601String(),
        'effective_until': effectiveUntil?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

/// A time-boxed supervision handover between spouses. Always explicitly
/// requested and explicitly completed; the execution log records both
/// edges.
class HandoverRequest {
  const HandoverRequest({
    required this.id,
    required this.familyId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String fromMemberId;
  final String toMemberId;
  final HandoverStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory HandoverRequest.fromJson(Map<String, Object?> row) => HandoverRequest(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        fromMemberId: row['from_member_id']! as String,
        toMemberId: row['to_member_id']! as String,
        status: HandoverStatus.values.byName(row['status']! as String),
        requestedAt: DateTime.parse(row['requested_at']! as String),
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.parse(row['completed_at']! as String),
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'from_member_id': fromMemberId,
        'to_member_id': toMemberId,
        'status': status.name,
        'requested_at': requestedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
