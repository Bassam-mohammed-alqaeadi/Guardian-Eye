import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;

import 'monitoring_repository.dart';

/// FS-004 — remote bridge for screen/camera monitoring.
///
/// Honesty contract: the parent platform never fabricates a screenshot.
/// Shots, sessions and evidence arrive through [FlutterMonitoringRemoteReader]
/// from a pull sync that reads documents the child device agent delivered.
/// When Firebase is not initialised (parent has not configured auth), every
/// read returns "nothing is available" instead of pretending data exists.
class FlutterMonitoringRemoteReader {
  FlutterMonitoringRemoteReader(this._repository);

  /// Stand-in used while the remote backend is not configured. It answers
  /// with empty results and never claims remote data exists.
  FlutterMonitoringRemoteReader.unavailable() : _repository = null;

  final MonitoringRepository? _repository;

  bool get _isUnavailable => _repository == null;

  Future<bool> get _ready async {
    try {
      final initialized = firebase_core.Firebase.apps.isNotEmpty;
      if (!initialized) return false;
      final auth = firebase_auth.FirebaseAuth.instance;
      if (auth.currentUser == null) return false;
      return true;
    } on Exception {
      return false;
    }
  }

  /// Pulls pending shot/session/evidence documents delivered by the child
  /// agent and applies them locally. Returns the total rows applied, or null
  /// when the remote backend is genuinely not available.
  Future<int?> pullPending(Map<String, List<Map<String, Object?>>> batch) async {
    if (_isUnavailable || !await _ready) return null;
    var applied = 0;
    final shots = batch['shots'] ?? const <Map<String, Object?>>[];
    final sessions = batch['sessions'] ?? const <Map<String, Object?>>[];
    final evidence = batch['evidence'] ?? const <Map<String, Object?>>[];
    if (shots.isNotEmpty) {
      applied += await _repository!.upsertShots(shots);
    }
    if (sessions.isNotEmpty) {
      applied += await _repository!.upsertSessions(sessions);
    }
    if (evidence.isNotEmpty) {
      applied += await _repository!.upsertEvidence(evidence);
    }
    return applied;
  }
}
