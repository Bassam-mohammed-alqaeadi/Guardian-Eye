/// AI persistence layer — Layers 2 through 9 outputs plus the L1 signal
/// registry consumer contract.
///
/// Read-heavy, append-friendly. Every row is written through the same
/// idempotent helpers other repositories use, and every AI output
/// carries its provenance JSON so downstream screens can render exact
/// states instead of summaries.
library ai_repository;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/family_events.dart';
import '../domain/guardian_ai_models.dart';

class AiInsightRepository {
  const AiInsightRepository({required this.database});

  final GuardianDatabase database;

  Database get _db => database.activeDatabase!;

  // -------------------------------------------------------------------------
  // L1 signal registry — read surface the engines consume
  // -------------------------------------------------------------------------

  Future<void> registerEvent(GuardianFeatureEvent event) async {
    final now = DateTime.now().toUtc();
    await _db.insert(
        'family_events',
        {
          'id': event.id,
          'family_id': event.familyId,
          'type': event.type.name,
          'occurred_at': event.occurredAt.toUtc().toIso8601String(),
          'privacy_class': event.privacyClass.name,
          'member_id': event.memberId,
          'child_id': event.childId,
          'device_id': event.deviceId,
          'attributes_json': _encode(event.attributes),
          'created_at': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertSignal(NormalizedSignal signal) async {
    final now = DateTime.now().toUtc();
    await _db.insert(
        'normalized_signals',
        {
          'id': signal.id,
          'family_id': signal.familyId,
          'child_id': signal.childId,
          'signal_key': signal.signalKey,
          'weight': signal.weight,
          'occurred_at': signal.occurredAt.toUtc().toIso8601String(),
          'outcome': signal.outcome.name,
          'privacy_class': signal.privacyClass.name,
          'source_event_id': signal.sourceEventId,
          'reject_reason': signal.rejectReason,
          'consent_scope': signal.consentScope,
          'created_at': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NormalizedSignal>> listSignals(
      {required String familyId,
      int limit = 500,
      DateTime? after,
      String? childId}) async {
    final where = StringBuffer('family_id = ?');
    final args = <Object?>[familyId];
    if (childId != null) {
      where.write(' AND child_id = ?');
      args.add(childId);
    }
    if (after != null) {
      where.write(' AND occurred_at > ?');
      args.add(after.toUtc().toIso8601String());
    }
    final rows = await _db.query('normalized_signals',
        where: where.toString(),
        whereArgs: args,
        orderBy: 'occurred_at DESC',
        limit: limit);
    return rows.map(NormalizedSignal.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // L2 — On-device detections
  // -------------------------------------------------------------------------

  Future<void> recordDetection(AiDetectionResult detection) async {
    final now = DateTime.now().toUtc();
    await _db.insert('ai_detections',
        {...detection.toJson(), 'created_at': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markDetectionReviewed(String familyId, String detectionId,
      {bool reviewed = true}) async {
    await _db.update(
        'ai_detections',
        {'reviewed': reviewed ? 1 : 0},
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, detectionId]);
  }

  Future<List<AiDetectionResult>> listDetections(
      {required String familyId, int limit = 50}) async {
    final rows = await _db.query('ai_detections',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'detected_at DESC',
        limit: limit);
    return rows.map(AiDetectionResult.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // L3 — Behavior profiles (upsert)
  // -------------------------------------------------------------------------

  Future<void> recordBehaviorProfiles(List<BehaviorProfile> profiles) async {
    final now = DateTime.now().toUtc();
    for (final profile in profiles) {
      for (final bucket in profile.buckets) {
        await _db.insert('ai_behavior_profiles',
            {
              'family_id': profile.familyId,
              'child_id': profile.childId,
              'weekday': bucket.weekday,
              'hour': bucket.hour,
              'usage_seconds': bucket.usageSeconds,
              'deviation_percent': bucket.deviationPercent,
              'window_start': profile.windowStart.toUtc().toIso8601String(),
              'window_end': profile.windowEnd.toUtc().toIso8601String(),
              'created_at': now.toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  // -------------------------------------------------------------------------
  // L4 — Risk states
  // -------------------------------------------------------------------------

  Future<void> recordRiskStates(List<AiRiskState> states) async {
    final now = DateTime.now().toUtc();
    for (final state in states) {
      await _db.insert('ai_risk_states',
          {...state.toJson(), 'created_at': now.toIso8601String()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<AiRiskState>> listRiskStates(
      {required String familyId, int limit = 20}) async {
    final rows = await _db.query('ai_risk_states',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'evaluated_at DESC',
        limit: limit);
    return rows.map(AiRiskState.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // L7 — Insights
  // -------------------------------------------------------------------------

  Future<void> recordInsight(FamilyInsight insight) async {
    final now = DateTime.now().toUtc();
    await _db.insert('ai_insights',
        {...insight.toJson(), 'created_at': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FamilyInsight>> listInsights(
      {required String familyId, int limit = 12}) async {
    final rows = await _db.query('ai_insights',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'period_start DESC',
        limit: limit);
    return rows.map(FamilyInsight.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // L8 — Copilot suggestions
  // -------------------------------------------------------------------------

  Future<void> recordSuggestion(CopilotSuggestion suggestion) async {
    final now = DateTime.now().toUtc();
    await _db.insert('ai_copilot_suggestions',
        {...suggestion.toJson(), 'created_at': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CopilotSuggestion>> listSuggestions(
      {required String familyId, int limit = 25}) async {
    final rows = await _db.query('ai_copilot_suggestions',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC',
        limit: limit);
    return rows.map(CopilotSuggestion.fromJson).toList();
  }

  Future<void> decideSuggestion(String familyId, String suggestionId,
      {required CopilotSuggestionStatus status,
      DateTime? decidedAt,
      String? outcomeNote}) async {
    await _db.update(
        'ai_copilot_suggestions',
        {
          'status': status.name,
          if (status == CopilotSuggestionStatus.applied)
            'applied_at': (decidedAt ?? DateTime.now().toUtc())
                .toIso8601String(),
          if (status == CopilotSuggestionStatus.dismissed)
            'dismissed_at': (decidedAt ?? DateTime.now().toUtc())
                .toIso8601String(),
          if (outcomeNote != null) 'outcome_note': outcomeNote,
        },
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, suggestionId]);
  }

  // -------------------------------------------------------------------------
  // L9 — Policy proposals
  // -------------------------------------------------------------------------

  Future<void> recordPolicyProposal(PolicyProposal proposal) async {
    final now = DateTime.now().toUtc();
    await _db.insert('ai_policy_proposals',
        {...proposal.toJson(), 'created_at': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PolicyProposal>> listProposals(
      {required String familyId, int limit = 25}) async {
    final rows = await _db.query('ai_policy_proposals',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC',
        limit: limit);
    return rows.map(PolicyProposal.fromJson).toList();
  }

  Future<void> decideProposal(String familyId, String proposalId,
      {required PolicyProposalStatus status,
      DateTime? decidedAt,
      String? outcomeNote}) async {
    await _db.update(
        'ai_policy_proposals',
        {
          'status': status.name,
          if (status == PolicyProposalStatus.approved)
            'approved_at':
                (decidedAt ?? DateTime.now().toUtc()).toIso8601String(),
          if (status == PolicyProposalStatus.rejected)
            'rejected_at':
                (decidedAt ?? DateTime.now().toUtc()).toIso8601String(),
          if (status == PolicyProposalStatus.applied)
            'applied_rule_ids': '',
          if (outcomeNote != null) 'outcome_note': outcomeNote,
        },
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, proposalId]);
  }

  // -------------------------------------------------------------------------
  // Transparency center — family-wide purge
  // -------------------------------------------------------------------------

  Future<void> deleteFamilyAiData(String familyId) async {
    await _db.delete('family_events', where: 'family_id = ?',
        whereArgs: [familyId]);
    await _db.delete('normalized_signals',
        where: 'family_id = ?', whereArgs: [familyId]);
    await _db.delete('ai_detections', where: 'family_id = ?',
        whereArgs: [familyId]);
    await _db.delete('ai_behavior_profiles',
        where: 'family_id = ?', whereArgs: [familyId]);
    await _db.delete('ai_risk_states', where: 'family_id = ?',
        whereArgs: [familyId]);
    await _db.delete('ai_insights', where: 'family_id = ?',
        whereArgs: [familyId]);
    await _db.delete('ai_copilot_suggestions',
        where: 'family_id = ?', whereArgs: [familyId]);
    await _db.delete('ai_policy_proposals',
        where: 'family_id = ?', whereArgs: [familyId]);
  }
}

String _encode(Map<String, Object?> attributes) =>
    jsonEncode(attributes);
