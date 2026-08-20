import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/guardian_database.dart';
import '../domain/family_events.dart';
import '../domain/guardian_event.dart';

/// Guardian AI — Layer 1 persistence: the family event registry.
///
/// Two tables back the intelligence foundation, both offline-first with
/// outbox sync like every other subsystem:
///
/// * `family_events` — every raw observed fact ([GuardianFeatureEvent]).
/// * `normalized_signals` — the canonical feature vectors ([NormalizedSignal])
///   produced by the [EventNormalizer]. All AI layers read only from this
///   table; the raw events exist purely for ingestion, retention, and the
///   transparency center.
///
/// Honesty contract: nothing is dropped silently. Normalization rejects
/// are stored with their reason so the AI transparency center can
/// disclose exactly which observations the AI did and did not see.
class FamilyEventRegistryRepository {
  FamilyEventRegistryRepository(this._database);

  final GuardianDatabase _database;

  Future<void> recordEvents(List<GuardianFeatureEvent> events) async {
    final db = await _database.database;
    for (final event in events) {
      await db.insert('family_events', {
        'id': event.id,
        'family_id': event.familyId,
        'type': event.type.name,
        'occurred_at': event.occurredAt.toUtc().toIso8601String(),
        'privacy_class': event.privacyClass.name,
        'member_id': event.memberId,
        'child_id': event.childId,
        'device_id': event.deviceId,
        'attributes_json': jsonEncode(event.attributes),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<GuardianFeatureEvent>> listEvents(String familyId,
      {int limit = 200}) async {
    final db = await _database.database;
    final rows = await db.query('family_events',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'occurred_at DESC',
        limit: limit);
    return rows.map(_eventFromRow).toList();
  }

  Future<List<GuardianFeatureEvent>> listRecentEvents(String familyId,
      {required Duration within}) async {
    final db = await _database.database;
    final since =
        DateTime.now().toUtc().subtract(within).toIso8601String();
    final rows = await db.query('family_events',
        where: 'family_id = ? AND occurred_at >= ?',
        whereArgs: [familyId, since],
        orderBy: 'occurred_at DESC');
    return rows.map(_eventFromRow).toList();
  }

  Future<int> recordSignals(List<NormalizedSignal> signals) async {
    final db = await _database.database;
    var count = 0;
    for (final signal in signals) {
      await db.insert('normalized_signals', {
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
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      count++;
    }
    return count;
  }

  Future<List<NormalizedSignal>> listSignals(String familyId,
      {int limit = 500}) async {
    final db = await _database.database;
    final rows = await db.query('normalized_signals',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'occurred_at DESC',
        limit: limit);
    return rows.map(_signalFromRow).toList();
  }

  Future<List<NormalizedSignal>> listRecentSignals(String familyId,
      {required Duration within}) async {
    final db = await _database.database;
    final since =
        DateTime.now().toUtc().subtract(within).toIso8601String();
    final rows = await db.query('normalized_signals',
        where: 'family_id = ? AND occurred_at >= ? AND outcome = ?',
        whereArgs: [familyId, since, EventNormalizationOutcome.normalized.name],
        orderBy: 'occurred_at DESC');
    return rows.map(_signalFromRow).toList();
  }

  Future<List<NormalizedSignal>> listSignalsForChild(
      String familyId, String childId,
      {required Duration within}) async {
    final db = await _database.database;
    final since =
        DateTime.now().toUtc().subtract(within).toIso8601String();
    final rows = await db.query('normalized_signals',
        where: 'family_id = ? AND child_id = ? AND occurred_at >= ? AND outcome = ?',
        whereArgs: [familyId, childId, since,
            EventNormalizationOutcome.normalized.name],
        orderBy: 'occurred_at DESC');
    return rows.map(_signalFromRow).toList();
  }

  /// Recent signal ids by key (dedup window), used by normalization.
  Future<Set<String>> recentSignalIds(String familyId,
      {required Duration within}) async {
    final db = await _database.database;
    final since =
        DateTime.now().toUtc().subtract(within).toIso8601String();
    final rows = await db.query('normalized_signals',
        columns: ['signal_key'],
        where: 'family_id = ? AND occurred_at >= ?',
        whereArgs: [familyId, since]);
    return rows.map((r) => r['signal_key']! as String).toSet();
  }

  Future<void> deleteFamilyEvents(String familyId) async {
    final db = await _database.database;
    await db.delete('normalized_signals', where: 'family_id = ?',
        whereArgs: [familyId]);
    await db.delete('family_events', where: 'family_id = ?',
        whereArgs: [familyId]);
  }

  GuardianFeatureEvent _eventFromRow(Map<String, Object?> row) =>
      GuardianFeatureEvent(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        type: GuardianEventType.values.byName(row['type']! as String),
        occurredAt: DateTime.parse(row['occurred_at']! as String),
        privacyClass:
            GuardianPrivacyClass.values.byName(row['privacy_class']! as String),
        memberId: row['member_id'] as String?,
        childId: row['child_id'] as String?,
        deviceId: row['device_id'] as String?,
        attributes: Map<String, String>.from(
            jsonDecode(row['attributes_json'] as String? ?? '{}') as Map),
        createdAt: row['created_at'] == null
            ? null
            : DateTime.parse(row['created_at']! as String),
      );

  NormalizedSignal _signalFromRow(Map<String, Object?> row) =>
      NormalizedSignal(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        childId: row['child_id']! as String,
        signalKey: row['signal_key']! as String,
        weight: (row['weight']! as num).toDouble(),
        occurredAt: DateTime.parse(row['occurred_at']! as String),
        outcome:
            EventNormalizationOutcome.values.byName(row['outcome']! as String),
        privacyClass:
            GuardianPrivacyClass.values.byName(row['privacy_class']! as String),
        sourceEventId: row['source_event_id'] as String?,
        rejectReason: row['reject_reason'] as String?,
        consentScope: row['consent_scope'] as String?,
      );
}

/// Consent scope for the family's AI processing consent.
///
/// Local-first: the owner sets scopes on-device; the honest contract is
/// that AI layers only see signals whose privacy class the family
/// explicitly consents to. The outbox carries these settings to the
/// server; nothing is processed remotely until the family confirms.
class AiConsentScope {
  const AiConsentScope({
    this.processOperational = true,
    this.processBehavioural = false,
    this.processLocation = false,
    this.processBiometric = false,
    this.familyId,
  });

  final String? familyId;
  final bool processOperational;
  final bool processBehavioural;
  final bool processLocation;
  final bool processBiometric;

  bool isConsented(GuardianPrivacyClass privacyClass) => switch (privacyClass) {
        GuardianPrivacyClass.operational => processOperational,
        GuardianPrivacyClass.behavioural => processBehavioural,
        GuardianPrivacyClass.locationSensitive => processLocation,
        GuardianPrivacyClass.biometric => processBiometric,
      };

  AiConsentScope copyWith({
    bool? processOperational,
    bool? processBehavioural,
    bool? processLocation,
    bool? processBiometric,
  }) =>
      AiConsentScope(
        familyId: familyId,
        processOperational: processOperational ?? true,
        processBehavioural: processBehavioural ?? true,
        processLocation: processLocation ?? true,
        processBiometric: processBiometric ?? true,
      );
}
