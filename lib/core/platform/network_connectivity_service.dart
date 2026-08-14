import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// M9 Trigger B — offline → online restoration monitor.
///
/// Thin, injectable seam around `connectivity_plus` so the runtime trigger
/// wiring can be unit-tested and so platform absence (widget tests,
/// unsupported hosts) degrades to "offline" instead of crashing the app.
class NetworkConnectivityService {
  NetworkConnectivityService({
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityStream,
  })  : _connectivity = connectivity ?? Connectivity(),
        _checkConnectivityOverride = checkConnectivity,
        _connectivityStreamOverride = connectivityStream;

  final Connectivity _connectivity;
  final Future<List<ConnectivityResult>> Function()? _checkConnectivityOverride;
  final Stream<List<ConnectivityResult>>? _connectivityStreamOverride;

  /// Whether any non-`none` connectivity is currently reported. Never throws:
  /// any platform failure is reported as offline (fail-closed).
  Future<bool> isOnline() async {
    try {
      final results = await (_checkConnectivityOverride?.call() ??
          _connectivity.checkConnectivity());
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Emits the current snapshot, then only on genuine offline → online
  /// transitions. Repeated online reports and noise are suppressed, which
  /// avoids duplicate sync triggers (the coordinator is single-flight anyway,
  /// but this keeps the stream itself minimal).
  Stream<bool> get onlineChanges async* {
    var previous = await isOnline();
    yield previous;
    try {
      final changes = _connectivityStreamOverride ??
          _connectivity.onConnectivityChanged;
      await for (final results in changes) {
        final online = results.any((result) => result != ConnectivityResult.none);
        if (online != previous) {
          previous = online;
          yield online;
        }
      }
    } catch (_) {
      // Platform stream unavailable: stay silent. Startup, auth, and manual
      // triggers still provide the sync path.
    }
  }
}
