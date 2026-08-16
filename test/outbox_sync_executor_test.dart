import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/outbox_sync_executor.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'test_database.dart';

class _Auth implements AuthContext {
  const _Auth(this.session);
  final AuthSession session;
  @override
  AuthSession get currentSession => session;
  @override
  Stream<AuthSession> get changes => Stream.value(session);
}

class _Writer implements OutboxRemoteWriter {
  _Writer({this.failure});
  final RemoteSyncException? failure;
  final List<String> idempotencyKeys = [];
  @override
  Future<void> write(
      {required OutboxEvent event,
      required AuthenticatedIdentity identity}) async {
    idempotencyKeys.add(event.idempotencyKey);
    if (failure != null) throw failure!;
  }
}

void main() {
  const identity = AuthenticatedIdentity(
      uid: 'parent-auth', email: 'p@example.test', isAnonymous: false);
  test('executor rejects unauthenticated sync without mutating outbox',
      () async {
    final database = await openTestDatabase();
    final family = await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final writer = _Writer();
    final report = await OutboxSyncExecutor(
            database,
            const _Auth(AuthSession(status: AuthSessionStatus.unauthenticated)),
            writer)
        .executeDue();
    expect(report.reason, 'authenticated_identity_required');
    expect((await (await database.database).query('outbox')).single['state'],
        'queued');
    expect(family.name, 'Family');
    await database.close();
  });
  test(
      'executor marks a successful event synced and preserves its idempotency key',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final writer = _Writer();
    final executor = OutboxSyncExecutor(
        database,
        const _Auth(AuthSession(
            status: AuthSessionStatus.authenticated, identity: identity)),
        writer);
    expect((await executor.executeDue()).synced, 1);
    expect((await executor.executeDue()).processed, 0);
    expect(writer.idempotencyKeys.length, 1);
    expect((await (await database.database).query('outbox')).single['state'],
        'synced');
    await database.close();
  });
  test(
      'executor retries transient failure and blocks permanent authorization failure',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final now = DateTime.now().toUtc();
    final transient = OutboxSyncExecutor(
        database,
        const _Auth(AuthSession(
            status: AuthSessionStatus.authenticated, identity: identity)),
        _Writer(
            failure: const RemoteSyncException(
                SyncFailureKind.retryable, 'unavailable')),
        clock: () => now);
    expect((await transient.executeDue()).retryScheduled, 1);
    final db = await database.database;
    await db.update('outbox',
        {'state': 'queued', 'next_attempt_at': now.toIso8601String()});
    final permanent = OutboxSyncExecutor(
        database,
        const _Auth(AuthSession(
            status: AuthSessionStatus.authenticated, identity: identity)),
        _Writer(
            failure: const RemoteSyncException(
                SyncFailureKind.permanent, 'permission-denied')),
        clock: () => now);
    expect((await permanent.executeDue()).blocked, 1);
    expect((await db.query('outbox')).single['state'], 'blocked');
    await database.close();
  });
  test('unconfigured remote writer blocks an authenticated outbox event',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final report = await OutboxSyncExecutor(
            database,
            const _Auth(AuthSession(
                status: AuthSessionStatus.authenticated, identity: identity)),
            const UnconfiguredOutboxRemoteWriter())
        .executeDue();
    expect(report.blocked, 1);
    final row = (await (await database.database).query('outbox')).single;
    expect(row['state'], 'blocked');
    expect(row['last_error'], 'firebase_not_configured');
    await database.close();
  });
  test(
      'executor recovers a stale syncing claim (killed run) and delivers it',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final db = await database.database;
    final now = DateTime.now().toUtc();
    // Simulate a run that claimed the row (state=syncing) then died before
    // completing the write, 10 minutes ago. next_attempt_at is the enqueue
    // time and is well past the staleness watermark.
    await db.update('outbox',
        {'state': 'syncing', 'next_attempt_at': now
            .subtract(const Duration(minutes: 10))
            .toIso8601String()});
    final writer = _Writer();
    final executor = OutboxSyncExecutor(
        database,
        const _Auth(AuthSession(
            status: AuthSessionStatus.authenticated, identity: identity)),
        writer);
    final report = await executor.executeDue();
    expect(report.synced, 1);
    expect(writer.idempotencyKeys.length, 1);
    final row = (await db.query('outbox')).single;
    expect(row['state'], 'synced');
    expect(row['last_error'], isNull);
    await database.close();
  });
  test('executor does not steal a fresh in-flight syncing claim', () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final db = await database.database;
    final now = DateTime.now().toUtc();
    await db.update('outbox',
        {'state': 'syncing', 'next_attempt_at': now.toIso8601String()});
    final writer = _Writer();
    final executor = OutboxSyncExecutor(
        database,
        const _Auth(AuthSession(
            status: AuthSessionStatus.authenticated, identity: identity)),
        writer);
    final report = await executor.executeDue();
    expect(report.processed, 0);
    expect(writer.idempotencyKeys, isEmpty);
    expect((await db.query('outbox')).single['state'], 'syncing');
    await database.close();
  });
}
