/// M9 — Canonical runtime sync coordinator.
///
/// The durable outbox already owns the delivery pipeline
/// (`OutboxSyncExecutor` → `FirestoreOutboxRemoteWriter` → real Firestore).
/// What M9 adds is the missing runtime trigger chain: startup, connectivity
/// restoration, manual "sync now", and WorkManager all funnel into the same
/// coordinator so that only one execution may touch the outbox at a time.
///
/// Honesty contract (unchanged): `SyncState.synced` is only ever written by
/// `OutboxSyncExecutor` after the remote writer confirms delivery. This
/// coordinator never infers, optimistically sets, or claims `synced`; it
/// only exposes the executor's real report.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/outbox_sync_executor.dart';

/// UI-visible snapshot of the sync pipeline.
///
/// `isSyncing` mirrors an execution in flight; `lastReport` is the executor's
/// truthful result (processed/synced/retryScheduled/blocked); `lastError`
/// records a pipeline-level failure (e.g. database unavailable) that the
/// executor itself could not classify.
class SyncRunState {
  const SyncRunState({
    required this.isSyncing,
    this.lastRunAt,
    this.lastReport,
    this.lastError,
  });

  const SyncRunState.idle() : this(isSyncing: false);

  final bool isSyncing;
  final DateTime? lastRunAt;
  final OutboxSyncReport? lastReport;
  final String? lastError;

  /// True when the most recent run still left operations that were NOT
  /// confirmed delivered (retry scheduled or blocked). Honest signal for
  /// the UI: never claim "synced" while delivery is outstanding.
  bool get hasOutstanding =>
      lastReport != null &&
      (lastReport!.retryScheduled > 0 || lastReport!.blocked > 0);
}

/// Platform-free single-flight core. Used by both the Riverpod notifier
/// (foreground) and the WorkManager background worker so both paths invoke
/// the SAME coordinator logic over the SAME outbox.
class SyncCoordinatorCore {
  SyncCoordinatorCore(this._executor);

  final OutboxSyncExecutor _executor;
  Completer<OutboxSyncReport>? _inFlight;

  /// Runs the outbox sync exactly once for any number of concurrent callers.
  ///
  /// Startup + connectivity + manual + WorkManager can race freely; every
  /// caller after the first receives the same in-flight future, so no
  /// duplicate remote mutations can be produced by trigger overlap.
  Future<OutboxSyncReport> executeNow() {
    final existing = _inFlight;
    if (existing != null) return existing.future;
    final completer = Completer<OutboxSyncReport>();
    _inFlight = completer;
    _executor.executeDue().then(
          completer.complete,
          onError: (Object error, StackTrace stackTrace) =>
              completer.completeError(error, stackTrace),
        );
    return completer.future.whenComplete(() => _inFlight = null);
  }
}

/// Riverpod state notifier exposing [SyncRunState] to the UI while keeping
/// the single-flight guarantee from [SyncCoordinatorCore].
class SyncCoordinator extends StateNotifier<SyncRunState> {
  SyncCoordinator(this._core, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const SyncRunState.idle());

  final SyncCoordinatorCore _core;
  final DateTime Function() _clock;

  /// Fire-and-forget-safe sync entry point for all triggers. Errors are
  /// contained into an honest `lastError` state so a background trigger can
  /// never crash the UI, and the executor's real report is always surfaced.
  Future<OutboxSyncReport> executeNow() async {
    state = SyncRunState(
        isSyncing: true, lastRunAt: state.lastRunAt, lastReport: state.lastReport);
    try {
      final report = await _core.executeNow();
      state = SyncRunState(
          isSyncing: false, lastRunAt: _clock(), lastReport: report);
      return report;
    } catch (error) {
      final reason = 'sync_failed:${error.runtimeType}';
      state = SyncRunState(isSyncing: false, lastError: reason);
      return OutboxSyncReport(
          processed: 0,
          synced: 0,
          retryScheduled: 0,
          blocked: 0,
          reason: reason);
    }
  }
}
