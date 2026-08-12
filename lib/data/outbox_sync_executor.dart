import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/guardian_database.dart';
import 'firebase_auth_context.dart';
import 'firestore_contracts.dart';
import 'sync_services.dart';

enum SyncFailureKind { retryable, permanent, malformed }

class RemoteSyncException implements Exception {
  const RemoteSyncException(this.kind, this.reason);
  final SyncFailureKind kind;
  final String reason;
}

class OutboxEvent {
  const OutboxEvent(
      {required this.id,
      required this.operation,
      required this.payload,
      required this.idempotencyKey,
      required this.attemptCount});
  final String id;
  final String operation;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final int attemptCount;
  factory OutboxEvent.fromRow(Map<String, Object?> row) => OutboxEvent(
      id: row['id']! as String,
      operation: row['operation']! as String,
      payload:
          jsonDecode(row['payload_json']! as String) as Map<String, dynamic>,
      idempotencyKey: row['idempotency_key']! as String,
      attemptCount: row['attempt_count']! as int);
}

abstract class OutboxRemoteWriter {
  Future<void> write(
      {required OutboxEvent event, required AuthenticatedIdentity identity});
}

class UnconfiguredOutboxRemoteWriter implements OutboxRemoteWriter {
  const UnconfiguredOutboxRemoteWriter();

  @override
  Future<void> write(
          {required OutboxEvent event,
          required AuthenticatedIdentity identity}) async =>
      throw const RemoteSyncException(
          SyncFailureKind.permanent, 'firebase_not_configured');
}

class FirestoreOutboxRemoteWriter implements OutboxRemoteWriter {
  FirestoreOutboxRemoteWriter(this._firestore,
      {FirestoreEventContract? contract})
      : _contract = contract ?? const FirestoreEventContract();
  final FirebaseFirestore _firestore;
  final FirestoreEventContract _contract;
  @override
  Future<void> write(
      {required OutboxEvent event,
      required AuthenticatedIdentity identity}) async {
    try {
      final mutation = _contract.businessMutation(
          operation: event.operation,
          payload: event.payload,
          identity: identity,
          idempotencyKey: event.idempotencyKey);
      final batch = _firestore.batch();
      batch.set(
          _firestore.doc(mutation.path),
          {...mutation.data, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      for (final write in mutation.additionalWrites) {
        batch.set(
            _firestore.doc(write.path),
            {...write.data, 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      }
      if (event.operation == 'family.created') {
        final familyId = event.payload['familyId'] as String;
        batch.set(
            _firestore.doc(FirestorePaths.member(familyId, identity.uid)),
            {
              'familyId': familyId,
              'memberId': event.payload['primaryParentId'],
              'memberUid': identity.uid,
              'displayName': event.payload['primaryParentName'],
              'role': 'primaryParent',
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
              'idempotencyKey': event.idempotencyKey
            },
            SetOptions(merge: true));
      }
      await batch.commit();
      try {
        await _firestore
            .waitForPendingWrites()
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        throw const RemoteSyncException(
            SyncFailureKind.retryable, 'remote_ack_timeout');
      }
    } on FirebaseException catch (error) {
      throw RemoteSyncException(_classify(error.code), error.code);
    } on FormatException catch (error) {
      throw RemoteSyncException(SyncFailureKind.malformed, error.message);
    }
  }

  SyncFailureKind _classify(String code) => switch (code) {
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' =>
          SyncFailureKind.retryable,
        'permission-denied' ||
        'unauthenticated' ||
        'invalid-argument' ||
        'not-found' =>
          SyncFailureKind.permanent,
        _ => SyncFailureKind.retryable
      };
}

class OutboxSyncReport {
  const OutboxSyncReport(
      {required this.processed,
      required this.synced,
      required this.retryScheduled,
      required this.blocked,
      required this.reason});
  final int processed;
  final int synced;
  final int retryScheduled;
  final int blocked;
  final String reason;
}

class OutboxSyncExecutor {
  OutboxSyncExecutor(this._database, this._auth, this._writer,
      {OutboxRetryPolicy? retryPolicy, DateTime Function()? clock})
      : _retry = retryPolicy ?? const OutboxRetryPolicy(),
        _clock = clock ?? DateTime.now;
  final GuardianDatabase _database;
  final AuthContext _auth;
  final OutboxRemoteWriter _writer;
  final OutboxRetryPolicy _retry;
  final DateTime Function() _clock;

  Future<OutboxSyncReport> executeDue({int limit = 25}) async {
    final session = _auth.currentSession;
    if (!session.isAuthenticated) {
      return OutboxSyncReport(
          processed: 0,
          synced: 0,
          retryScheduled: 0,
          blocked: 0,
          reason: session.reason ?? 'authenticated_identity_required');
    }
    final now = _clock().toUtc();
    final db = await _database.database;
    final rows = await db.query('outbox',
        where: "state IN ('queued','failed') AND next_attempt_at <= ?",
        whereArgs: [now.toIso8601String()],
        orderBy: 'created_at ASC',
        limit: limit);
    var synced = 0;
    var retried = 0;
    var blocked = 0;
    for (final row in rows) {
      final claimed = await db.update('outbox', {'state': 'syncing'},
          where: "id = ? AND state IN ('queued','failed')",
          whereArgs: [row['id']]);
      if (claimed == 0) continue;
      final event = OutboxEvent.fromRow(row);
      try {
        await _writer.write(event: event, identity: session.identity!);
        await db.update('outbox', {'state': 'synced', 'last_error': null},
            where: 'id = ?', whereArgs: [event.id]);
        synced++;
      } on RemoteSyncException catch (failure) {
        final attempts = event.attemptCount + 1;
        if (failure.kind != SyncFailureKind.retryable ||
            !_retry.canRetry(attempts)) {
          await db.update(
              'outbox',
              {
                'state': 'blocked',
                'attempt_count': attempts,
                'last_error': failure.reason
              },
              where: 'id = ?',
              whereArgs: [event.id]);
          blocked++;
        } else {
          await db.update(
              'outbox',
              {
                'state': 'failed',
                'attempt_count': attempts,
                'next_attempt_at':
                    _retry.nextAttemptAt(now, attempts).toIso8601String(),
                'last_error': failure.reason
              },
              where: 'id = ?',
              whereArgs: [event.id]);
          retried++;
        }
      } catch (error) {
        final attempts = event.attemptCount + 1;
        await db.update(
            'outbox',
            {
              'state': 'failed',
              'attempt_count': attempts,
              'next_attempt_at':
                  _retry.nextAttemptAt(now, attempts).toIso8601String(),
              'last_error': 'unexpected:${error.runtimeType}'
            },
            where: 'id = ?',
            whereArgs: [event.id]);
        retried++;
      }
    }
    return OutboxSyncReport(
        processed: rows.length,
        synced: synced,
        retryScheduled: retried,
        blocked: blocked,
        reason: rows.isEmpty ? 'queue_empty' : 'processed');
  }
}
