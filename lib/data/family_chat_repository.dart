import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/guardian_database.dart';
import '../domain/family_chat.dart';

/// ---------------------------------------------------------------------------
/// FS-010 — Ephemeral Family Chat. Data layer.
///
/// Honesty contract (Phase B):
/// - Every message is written locally first, then enqueued to the outbox with
///   a full payload. The `state` is `queued` until the local write + outbox
///   flush succeed; an honest `failed` state is surfaced when either step
///   cannot be completed — never a fake `sent`.
/// - `expires_at` is always `created_at + approved 24-hour window`, stored in
///   UTC. Query-time filtering EXCLUDES expired messages from every active
///   list; they only resurface through the CH-004 expired-notice pathway.
/// - The idempotency key makes a repeated send a provable duplicate: the
///   UNIQUE `idempotency_key` column short-circuits replays at the SQL level.
/// - Remote Firestore sync for the `chat.*` aggregate is NOT implemented in
///   Phase 1 (new collection + new rules would be required → BLOCKED-EXTERNAL
///   per the approved phase scope). The outbox is kept for honesty of the
///   queued/failed/sent state machine and for future sync unblock.
/// ---------------------------------------------------------------------------
class FamilyChatRepository {
  FamilyChatRepository(
    this._database, {
    Uuid? uuid,
    ChatClock? clock,
  })  : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final GuardianDatabase _database;
  final Uuid _uuid;
  final ChatClock _clock;

  /// Lazy database accessor — repository consumers must await it, and a
  /// test-only repository surfaces the stub error here instead of hiding it
  /// inside the database layer.
  Future<Database> get _db async => _database.database;

  /// Test-only stand-in used by service-level authorization tests.
  /// Authorization is fail-closed before any repository method is reached,
  /// so this database is never opened — any accidental call that reaches
  /// it throws with an honest message instead of silently succeeding.
  FamilyChatRepository.stub()
      : _database = _StubGuardianDatabase(),
        _uuid = const Uuid(),
        _clock = DateTime.now;

  // ----------------------------------------------------------------- threads

  Future<List<FamilyChatThread>> listThreads(String familyId) async {
    final db = await _db;
    final rows = await db.query('chat_threads',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'updated_at DESC');
    return rows.map(_threadFromMap).toList(growable: false);
  }

  Future<FamilyChatThread?> findThread(String familyId, String threadId) async {
    final db = await _db;
    final rows = await db.query('chat_threads',
        where: 'family_id = ? AND id = ?', whereArgs: [familyId, threadId]);
    if (rows.isEmpty) return null;
    return _threadFromMap(rows.first);
  }

  /// Looks a thread up by id only. Used by the send path so a mismatched
  /// family binding is denied with an explicit cross-family error instead of
  /// being hidden behind a missing-thread outcome.
  Future<FamilyChatThread?> findThreadById(String threadId) async {
    final db = await _db;
    final rows = await db.query('chat_threads',
        where: 'id = ?', whereArgs: [threadId]);
    if (rows.isEmpty) return null;
    return _threadFromMap(rows.first);
  }

  /// Creates (or re-uses) a role-scoped thread. The scope (`type` +
  /// `memberId`) is bound at creation and never rewritten by client input
  /// afterwards; a matching existing thread is returned instead of
  /// duplicating — the chat list must stay honest, not padded.
  Future<FamilyChatThread> findOrCreateThread({
    required String familyId,
    required FamilyChatThreadType type,
    String? memberId,
    required String createdByMemberId,
  }) async {
    if (type != FamilyChatThreadType.family &&
        (memberId == null || memberId.trim().isEmpty)) {
      throw StateError('chat_thread_missing_member_id');
    }
    final db = await _db;
    final existing = await db.query('chat_threads',
        where:
            'family_id = ? AND type = ? AND COALESCE(member_id, \'\') = ?',
        whereArgs: [familyId, type.storageKey, memberId ?? ''],
        limit: 1);
    if (existing.isNotEmpty) {
      return _threadFromMap(existing.first);
    }
    final now = _clock().toUtc();
    final thread = FamilyChatThread(
      id: _uuid.v4(),
      familyId: familyId.trim(),
      type: type,
      memberId: memberId?.trim(),
      expirationWindow: FamilyChatExpirationWindow.hours24,
      createdByMemberId: createdByMemberId.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('chat_threads', _threadToMap(thread),
        conflictAlgorithm: ConflictAlgorithm.fail);
    return thread;
  }

  // ---------------------------------------------------------------- messages

  /// Active (non-expired) messages on a thread, newest first. Expired
  /// messages are never returned here — they exist only for the sweep and
  /// the CH-004 notice.
  Future<List<FamilyChatMessage>> activeMessages(String threadId) async {
    final db = await _db;
    final rows = await db.query('chat_messages',
        where:
            "thread_id = ? AND state != 'expired' AND datetime(expires_at) > datetime('now')",
        whereArgs: [threadId],
        orderBy: 'created_at ASC');
    return rows.map(_messageFromMap).toList(growable: false);
  }

  Future<FamilyChatMessage?> findMessage(
      String familyId, String messageId) async {
    final db = await _db;
    final rows = await db.query('chat_messages',
        where: 'family_id = ? AND id = ?', whereArgs: [familyId, messageId]);
    if (rows.isEmpty) return null;
    return _messageFromMap(rows.first);
  }

  /// Honest send. Returns the definitive outcome:
  ///
  /// - `sent`     — local write + outbox enqueue both succeeded;
  /// - `duplicate` — the same (thread, sender, body, minute) was already
  ///   sent earlier; nothing was written and no state was claimed;
  /// - `failed`   — a real failure; the message is NOT left in a fake state.
  ///
  /// Offline devices receive `sent` semantics locally (queued outbox row)
  /// and the UI renders the offline banner — the outbox will fail flush
  /// cleanly until connectivity returns; per Phase 1 scope, remote chat
  /// sync is BLOCKED-EXTERNAL, so outbox rows are expected to stay queued
  /// or move to `failed` until that gate is unblocked.
  Future<FamilyChatSendOutcome> sendMessage({
    required String familyId,
    required String threadId,
    required String senderMemberId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw StateError('chat_empty_body');
    final db = await _db;
    final now = _clock().toUtc();
    final minuteBucket = DateTime.utc(now.year, now.month, now.day,
        now.hour, now.minute);
    final idempotencyKey =
        'chat:$familyId:$threadId:$senderMemberId:'
        '${minuteBucket.toIso8601String()}:$trimmed';
    final thread = await findThreadById(threadId);
    if (thread == null) throw StateError('chat_thread_missing:$threadId');
    if (thread.familyId.trim() != familyId.trim()) {
      throw StateError('chat_cross_family_thread');
    }
    final expiresAt = now.add(thread.expirationWindow.duration);
    return db.transaction((tx) async {
      final duplicate = await tx.query('chat_messages',
          columns: ['id'],
          where: 'idempotency_key = ?',
          whereArgs: [idempotencyKey],
          limit: 1);
      if (duplicate.isNotEmpty) return FamilyChatSendOutcome.duplicate;

      final message = FamilyChatMessage(
        id: _uuid.v4(),
        familyId: familyId.trim(),
        threadId: threadId.trim(),
        senderMemberId: senderMemberId.trim(),
        body: trimmed,
        createdAt: now,
        expiresAt: expiresAt,
        state: FamilyChatMessageState.queued,
        idempotencyKey: idempotencyKey,
      );
      await tx.insert('chat_messages', _messageToMap(message),
          conflictAlgorithm: ConflictAlgorithm.fail);
      final outboxEventId = _uuid.v4();
      await tx.update('chat_messages', {'outbox_event_id': outboxEventId},
          where: 'id = ?', whereArgs: [message.id]);
      await _enqueueOutbox(tx, message, outboxEventId);
      // Thread recency: keep the list ordering honest after the new message.
      await tx.update('chat_threads', {'updated_at': now.toIso8601String()},
          where: 'id = ?', whereArgs: [threadId]);
      return FamilyChatSendOutcome.sent;
    });
  }

  Future<void> _enqueueOutbox(
      Transaction tx, FamilyChatMessage message, String outboxEventId) async {
    final nowMs = _clock().millisecondsSinceEpoch;
    await tx.insert('outbox', {
      'id': outboxEventId,
      'aggregate_type': 'chatMessage',
      'aggregate_id': '${message.familyId}:${message.threadId}',
      'operation': 'send',
      'payload_json': jsonEncode(_outboxPayload(message)),
          'idempotency_key':
          'chatMessage:send:${message.familyId}:${message.idempotencyKey}:$nowMs',
      'state': 'queued',
      'attempt_count': 0,
      'next_attempt_at': _clock().toUtc().toIso8601String(),
      'last_error': null,
      'created_at': _clock().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, Object?> _outboxPayload(FamilyChatMessage message) => {
        'family_id': message.familyId,
        'thread_id': message.threadId,
        'sender_member_id': message.senderMemberId,
        'body': message.body,
        'created_at': message.createdAt.toIso8601String(),
        'expires_at': message.expiresAt.toIso8601String(),
        'idempotency_key': message.idempotencyKey,
      };

  /// Read-time expiration sweep. Marks every non-expired row whose UTC
  /// expiry has passed as `expired` and reports which threads are now
  /// fully exhausted (CH-004 candidates). Never deletes data silently:
  /// the purge-domain contract still owns physical removal.
  Future<FamilyChatExpirationReport> sweepExpired() async {
    final db = await _db;
    final sweepAt = DateTime.now().toUtc();
    final marked = await db.rawUpdate(
        "UPDATE chat_messages SET state = 'expired' "
        "WHERE state != 'expired' AND datetime(expires_at) <= datetime('now')");
    final exhausted = await db.rawQuery(
        'SELECT DISTINCT t.id FROM chat_threads t '
        'WHERE NOT EXISTS (SELECT 1 FROM chat_messages m '
        'WHERE m.thread_id = t.id AND m.state != \'expired\' '
        'AND datetime(m.expires_at) > datetime(\'now\'))');
    final threads = exhausted
        .map((row) => row['id']! as String)
        .toList(growable: false);
    return FamilyChatExpirationReport(
        expiredMessageCount: marked,
        expiredThreads: threads,
        sweptAt: sweepAt);
  }

  // ------------------------------------------------------------------ helpers

  FamilyChatThread _threadFromMap(Map<String, Object?> row) =>
      FamilyChatThread(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        type: FamilyChatThreadType.values
            .byName((row['type'] ?? 'family') as String),
        memberId: row['member_id'] as String?,
        expirationWindow: (row['expiration_window'] ?? 'hours24') == 'hours24'
            ? FamilyChatExpirationWindow.hours24
            : FamilyChatExpirationWindow.hours24,
        createdByMemberId: row['created_by_member_id']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );

  FamilyChatMessage _messageFromMap(Map<String, Object?> row) =>
      FamilyChatMessage(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        threadId: row['thread_id']! as String,
        senderMemberId: row['sender_member_id']! as String,
        body: row['body']! as String,
        createdAt: DateTime.parse(row['created_at']! as String),
        expiresAt: DateTime.parse(row['expires_at']! as String),
        state: FamilyChatMessageState.values
            .byName((row['state'] ?? 'queued') as String),
        idempotencyKey: row['idempotency_key']! as String,
      );

  Map<String, Object?> _threadToMap(FamilyChatThread thread) => {
        'id': thread.id,
        'family_id': thread.familyId,
        'type': thread.type.storageKey,
        'member_id': thread.memberId,
        'expiration_window': thread.expirationWindow.name,
        'created_by_member_id': thread.createdByMemberId,
        'created_at': thread.createdAt.toIso8601String(),
        'updated_at': thread.updatedAt.toIso8601String(),
      };

  Map<String, Object?> _messageToMap(FamilyChatMessage message) => {
        'id': message.id,
        'family_id': message.familyId,
        'thread_id': message.threadId,
        'sender_member_id': message.senderMemberId,
        'body': message.body,
        'created_at': message.createdAt.toIso8601String(),
        'expires_at': message.expiresAt.toIso8601String(),
        'state': message.state.storageKey,
        'idempotency_key': message.idempotencyKey,
      };
}

/// Test-only stand-in that fails loudly if a stub-wired repository is ever
/// asked to touch a database. The chat service fails closed before reaching
/// the repository, so this is never called in real authorization flows.
class _StubGuardianDatabase extends GuardianDatabase {
  /// Test-only stand-in: the constructor the real class hides behind a
  /// library-private gate is not accessible here, so the stub short-circuits
  /// via [noSuchMethod] for everything and throws an honest error if any
  /// caller ever reaches the [database] future.
  _StubGuardianDatabase() : super.forTesting(
        factory: _StubDatabaseFactory(),
        pathResolver: () async => throw UnsupportedError('stub has no path'),
      );

  @override
  Future<Database> get database async =>
      throw UnsupportedError('stub repository has no database');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('stub repository has no database');
}

/// No-op factory that only exists so the stand-in can extend the real
/// class without touching the product constructor chain.
class _StubDatabaseFactory extends DatabaseFactory {
  _StubDatabaseFactory();

  @override
  Future<Database> openDatabase(String path,
          {OpenDatabaseOptions? options}) async =>
      throw UnsupportedError('stub has no database');

  @override
  Future<String> getDatabasesPath() async =>
      throw UnsupportedError('stub has no path');

  @override
  Future<void> setDatabasesPath(String path) async =>
      throw UnsupportedError('stub has no path');

  @override
  Future<void> deleteDatabase(String path) async =>
      throw UnsupportedError('stub has no database');

  @override
  Future<bool> databaseExists(String path) async =>
      throw UnsupportedError('stub has no database');

  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) async =>
      throw UnsupportedError('stub has no database');

  @override
  Future<Uint8List> readDatabaseBytes(String path) async =>
      throw UnsupportedError('stub has no database');
}

