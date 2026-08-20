/// FS-013 — Couple Harmony persistence.
///
/// Mirrors the honesty contract of the rest of the data layer: explicit
/// states only, no silent transitions, and every decision recorded by
/// the acting member id.
library couple_repository;

import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/couple_harmony.dart';

class CoupleRepository {
  const CoupleRepository({required this.database});

  final GuardianDatabase database;

  Database get _db => database.activeDatabase!;

  // -------------------------------------------------------------------------
  // Linking
  // -------------------------------------------------------------------------

  Future<void> recordLinking(CoupleLinking linking) async {
    await _db.insert('couple_linking', linking.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CoupleLinking?> linkingFor(String familyId,
      {required String partnerMemberId}) async {
    final rows = await _db.query('couple_linking',
        where: 'family_id = ? AND partner_member_id = ?',
        whereArgs: [familyId, partnerMemberId],
        limit: 1);
    if (rows.isEmpty) return null;
    return CoupleLinking.fromJson(rows.first);
  }

  Future<List<CoupleLinking>> listLinking(String familyId) async {
    final rows = await _db.query('couple_linking',
        where: 'family_id = ?', whereArgs: [familyId]);
    return rows.map(CoupleLinking.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // Proposals
  // -------------------------------------------------------------------------

  Future<void> recordProposal(CoupleProposal proposal) async {
    await _db.insert('couple_proposals', proposal.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CoupleProposal>> listProposals(String familyId) async {
    final rows = await _db.query('couple_proposals',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC');
    final now = DateTime.now().toUtc();
    return rows
        .map(CoupleProposal.fromJson)
        .map((p) => p.withResolvedStatus(now))
        .toList();
  }

  Future<void> decideProposal(String familyId, String proposalId,
      {required CoupleProposalStatus decision,
      required String reviewedBy,
      DateTime? decidedAt}) async {
    await _db.update(
        'couple_proposals',
        {
          'status': decision.name,
          'reviewed_by': reviewedBy,
          'reviewed_at': (decidedAt ?? DateTime.now().toUtc())
              .toIso8601String(),
        },
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, proposalId]);
  }

  // -------------------------------------------------------------------------
  // Routines
  // -------------------------------------------------------------------------

  Future<void> recordRoutine(SharedRoutine routine) async {
    await _db.insert('couple_routines', routine.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SharedRoutine>> listRoutines(String familyId) async {
    final rows = await _db.query('couple_routines',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'updated_at DESC');
    return rows.map(SharedRoutine.fromJson).toList();
  }

  Future<void> updateRoutine(String familyId, String routineId,
      {bool? enabled, String? titleKey, int? startMinute, int? endMinute,
      List<int>? weekdays, List<String>? assignedChildIds}) async {
    await _db.update(
        'couple_routines',
        {
          if (enabled != null) 'enabled': enabled ? 1 : 0,
          if (titleKey != null) 'title': titleKey,
          if (startMinute != null) 'start_minute': startMinute,
          if (endMinute != null) 'end_minute': endMinute,
          if (weekdays != null) 'weekdays': weekdays.join(','),
          if (assignedChildIds != null) 'assigned_child_ids': assignedChildIds.join(','),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, routineId]);
  }

  Future<void> deleteRoutine(String familyId, String routineId) async {
    await _db.delete('couple_routines',
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, routineId]);
  }

  // -------------------------------------------------------------------------
  // Responsibilities
  // -------------------------------------------------------------------------

  Future<void> recordResponsibility(Responsibility responsibility) async {
    await _db.insert('couple_responsibilities', responsibility.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Responsibility>> listResponsibilities(String familyId) async {
    final rows = await _db.query('couple_responsibilities',
        where: 'family_id = ?', whereArgs: [familyId]);
    return rows.map(Responsibility.fromJson).toList();
  }

  Future<void> delegateResponsibility(
      String familyId, String responsibilityId,
      {required String delegateMemberId}) async {
    await _db.update(
        'couple_responsibilities',
        {'delegate_member_id': delegateMemberId},
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, responsibilityId]);
  }

  // -------------------------------------------------------------------------
  // Handovers
  // -------------------------------------------------------------------------

  Future<void> requestHandover(HandoverRequest handover) async {
    await _db.insert('couple_handovers', handover.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HandoverRequest>> listHandovers(String familyId) async {
    final rows = await _db.query('couple_handovers',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'requested_at DESC');
    return rows.map(HandoverRequest.fromJson).toList();
  }

  Future<void> completeHandover(
      String familyId, String handoverId, String completedBy) async {
    await _db.update(
        'couple_handovers',
        {
          'status': HandoverStatus.completed.name,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'family_id = ? AND id = ? AND (to_member_id = ? OR from_member_id = ?)',
        whereArgs: [familyId, handoverId, completedBy, completedBy]);
  }
}
