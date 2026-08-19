import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'safety_repositories.dart';

/// FS-006 — remote bridge for the SOS readiness roster.
///
/// Honesty contract: recipient documents arrive through
/// [FlutterSosRemoteReader] from a pull sync that reads documents the
/// notification pipeline delivered. When Firebase is not initialised
/// (parent has not configured auth), every read returns "nothing is
/// available" instead of pretending data exists.
class FlutterSosRemoteReader {
  FlutterSosRemoteReader(this._repository);

  /// Stand-in used while the remote backend is not configured. It answers
  /// with empty results and never claims remote data exists.
  FlutterSosRemoteReader.unavailable() : _repository = null;

  final SosRepository? _repository;

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

  /// Pulls pending recipient documents delivered by the notification
  /// pipeline and applies them locally. Returns the rows applied, or null
  /// when the remote backend is genuinely not available.
  Future<int?> pullPending(
      Map<String, List<Map<String, Object?>>> batch) async {
    if (_isUnavailable || !await _ready) return null;
    var applied = 0;
    final recipients =
        batch['recipients'] ?? const <Map<String, Object?>>[];
    if (recipients.isNotEmpty && _repository != null) {
      applied += await _repository!.upsertRecipients(recipients);
    }
    return applied;
  }
}

// upsertRecipients lives on SosRepository itself (see
// safety_repositories.dart) — the remote reader calls it through the
// injected repository, keeping this file focused on the bridge.
