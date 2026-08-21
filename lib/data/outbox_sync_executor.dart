import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/guardian_database.dart';
import 'firebase_auth_context.dart';
import 'firestore_contracts.dart';
import 'notification_contract.dart' hide AuthenticatedIdentity;
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
  FirestoreOutboxRemoteWriter(this._firestoreOverride,
      {FirestoreEventContract? contract})
      : _contract = contract ?? const FirestoreEventContract();
  final FirebaseFirestore? _firestoreOverride;
  final FirestoreEventContract _contract;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

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
      // Bounded commit: a hung network must never leave the row stuck in
      // 'syncing' forever. On timeout the op is re-scheduled (retryable);
      // the write is idempotent (idempotencyKey), so a retry is safe.
      await batch
          .commit()
          .timeout(const Duration(seconds: 20));
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
      {OutboxRetryPolicy? retryPolicy,
      DateTime Function()? clock,
      NotificationGateway? notificationGateway})
      : _retry = retryPolicy ?? const OutboxRetryPolicy(),
        _clock = clock ?? DateTime.now,
        _notificationGateway = notificationGateway;
  final GuardianDatabase _database;
  final AuthContext _auth;
  final OutboxRemoteWriter _writer;
  final OutboxRetryPolicy _retry;
  final DateTime Function() _clock;
  final NotificationGateway? _notificationGateway;

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
    // Recover stale 'syncing' claims left behind by a run that died mid-write
    // (process kill, force-stop, network hang, crash). Without this, such rows
    // are never re-claimed and stay 'syncing' forever, poisoning the pending
    // count and silently blocking retry. Re-queueing is safe because every
    // remote write is idempotent (idempotencyKey) and the claim is atomic.
    // A healthy write completes in well under a minute (commit 20s + ack
    // 15s timeouts), so 3 minutes is a conservative staleness watermark.
    await db.rawUpdate(
        "UPDATE outbox SET state = 'queued', last_error = 'stale_syncing_recovered' "
        "WHERE state = 'syncing' AND next_attempt_at <= ?",
        [now.subtract(const Duration(minutes: 3)).toIso8601String()]);
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

        // FS-006 / FS-001 — Notification Dispatch. When an incident, SOS, or
        // alert is synced to Firestore, we immediately attempt to trigger the
        // remote notification dispatch through the Render backend. This ensures
        // that safety events aren't just recorded, but actively announced.
        if (event.operation == 'notification.requested' &&
            _notificationGateway != null) {
          final kind = event.payload['kind'] as String?;
          final familyId = event.payload['familyId'] as String?;
          final incidentId = event.payload['incidentId'] as String?;
          final sosId = event.payload['sosId'] as String?;

          if (kind != null && familyId != null) {
            await _notificationGateway!.dispatch(
              familyId: familyId,
              kind: kind,
              incidentId: incidentId,
              sosId: sosId,
            );
          }
        }

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
