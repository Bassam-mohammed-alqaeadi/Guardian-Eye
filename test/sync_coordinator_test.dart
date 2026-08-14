import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/sync_coordinator.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/outbox_sync_executor.dart';

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
  _Writer({this.failure, this.delay = Duration.zero});
  final RemoteSyncException? failure;
  final Duration delay;
  int writes = 0;
  @override
  Future<void> write(
      {required OutboxEvent event,
      required AuthenticatedIdentity identity}) async {
    writes++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (failure != null) throw failure!;
  }
}

class _CountingExecutor extends OutboxSyncExecutor {
  _CountingExecutor(super.database, super.auth, super.writer);
  int runs = 0;
  @override
  Future<OutboxSyncReport> executeDue({int limit = 25}) {
    runs++;
    return super.executeDue(limit: limit);
  }
}

class _ThrowingExecutor extends OutboxSyncExecutor {
  _ThrowingExecutor(super.database, super.auth, super.writer);
  @override
  Future<OutboxSyncReport> executeDue({int limit = 25}) async =>
      throw StateError('db_down');
}

void main() {
  const identity = AuthenticatedIdentity(
      uid: 'parent-auth', email: 'p@example.test', isAnonymous: false);
  const authenticated = AuthSession(
      status: AuthSessionStatus.authenticated, identity: identity);

  test('concurrent triggers share one execution (single-flight)', () async {
    final database = await openTestDatabase();
    // Two family mutations queued so a single run delivers both.
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    await FamilyRepository(database)
        .createFamily(familyName: 'Second', parentName: 'Parent');
    final writer = _Writer(delay: const Duration(milliseconds: 20));
    final executor = _CountingExecutor(database, const _Auth(authenticated), writer);
    final core = SyncCoordinatorCore(executor);

    final results =
        await Future.wait([core.executeNow(), core.executeNow()]);

    // Exactly ONE outbox execution ran despite two simultaneous triggers,
    // and both callers observed the same truthful report (single-flight:
    // same report object, every queued operation delivered exactly once).
    expect(executor.runs, 1);
    expect(results[0].synced, 2);
    expect(results[1].synced, 2);
    expect(writer.writes, 2);
    await database.close();
  });

  test('coordinator exposes honest idle -> syncing -> synced transitions',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final writer = _Writer(delay: const Duration(milliseconds: 10));
    final executor = _CountingExecutor(database, const _Auth(authenticated), writer);
    final fixedNow = DateTime.utc(2026, 8, 14, 12);
    final coordinator =
        SyncCoordinator(SyncCoordinatorCore(executor), clock: () => fixedNow);

    expect(coordinator.state.isSyncing, isFalse);
    final future = coordinator.executeNow();
    expect(coordinator.state.isSyncing, isTrue);

    final report = await future;
    expect(coordinator.state.isSyncing, isFalse);
    expect(report.synced, 1);
    expect(coordinator.state.lastReport?.synced, 1);
    expect(coordinator.state.lastReport?.processed, 1);
    expect(coordinator.state.lastError, isNull);
    expect(coordinator.state.lastRunAt, fixedNow);
    await database.close();
  });

  test('coordinator contains pipeline failures into an honest failed state',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final coordinator = SyncCoordinator(
        SyncCoordinatorCore(_ThrowingExecutor(
            database, const _Auth(authenticated), _Writer())));

    // The trigger never throws — errors surface as honest state.
    final report = await coordinator.executeNow();
    expect(coordinator.state.isSyncing, isFalse);
    expect(coordinator.state.lastError, 'sync_failed:StateError');
    expect(report.reason, startsWith('sync_failed:'));
    expect(coordinator.state.hasOutstanding, isFalse);
    await database.close();
  });

  test('unauthenticated coordinator run is a clean no-op with an honest reason',
      () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final writer = _Writer();
    final coordinator = SyncCoordinator(SyncCoordinatorCore(OutboxSyncExecutor(
        database,
        const _Auth(AuthSession(status: AuthSessionStatus.unauthenticated)),
        writer)));

    final report = await coordinator.executeNow();
    expect(report.reason, 'authenticated_identity_required');
    expect(writer.writes, 0);
    expect(coordinator.state.lastError, isNull);
    // The queued operation remains queued — never optimistically synced.
    final row = (await (await database.database).query('outbox')).single;
    expect(row['state'], 'queued');
    await database.close();
  });

  test('failed run sets hasOutstanding from the executor report', () async {
    final database = await openTestDatabase();
    await FamilyRepository(database)
        .createFamily(familyName: 'Family', parentName: 'Parent');
    final now = DateTime.now().toUtc();
    final coordinator = SyncCoordinator(
      SyncCoordinatorCore(OutboxSyncExecutor(
        database,
        const _Auth(authenticated),
        _Writer(
            failure: const RemoteSyncException(
                SyncFailureKind.retryable, 'unavailable')),
        clock: () => now,
      )),
    );

    final report = await coordinator.executeNow();
    expect(report.retryScheduled, 1);
    expect(report.synced, 0);
    expect(coordinator.state.lastReport?.retryScheduled, 1);
    expect(coordinator.state.hasOutstanding, isTrue);
    await database.close();
  });
}
