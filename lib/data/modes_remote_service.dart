import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import '../domain/mode_config.dart';
import 'mode_config_repository.dart';

/// FS-005 — remote bridge for special & custom modes.
///
/// Honesty contract: a mode's delivery to a child device is only "applied"
/// when the child device agent confirms it. This reader pulls remote mode
/// configuration and activation state delivered by agents; when Firebase is
/// not initialised, every read returns "nothing is available" instead of
/// pretending remote data exists.
class FlutterModesRemoteReader {
  FlutterModesRemoteReader(this._repository);

  /// Stand-in used while the remote backend is not configured. It answers
  /// with empty results and never claims remote data exists.
  FlutterModesRemoteReader.unavailable() : _repository = null;

  final ModeConfigRepository? _repository;

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

  /// Pulls pending mode configs and activations delivered remotely and
  /// applies them locally. Returns the total rows applied, or null when
  /// the remote backend is genuinely not available.
  Future<int?> pullPending(
      Map<String, List<Map<String, Object?>>> batch) async {
    if (_isUnavailable || !await _ready) return null;
    var applied = 0;
    final modes = batch['modes'] ?? const <Map<String, Object?>>[];
    final activations =
        batch['activations'] ?? const <Map<String, Object?>>[];
    for (final raw in modes) {
      final row = Map<String, Object?>.from(raw);
      if (row['mode_id'] == null || row['family_id'] == null) continue;
      await _repository!.saveMode(ModeConfig.fromMap(row));
      applied += 1;
    }
    for (final raw in activations) {
      final row = Map<String, Object?>.from(raw);
      if (row['activation_id'] == null) continue;
      await _repository!.saveActivation(ModeActivation.fromMap(row));
      applied += 1;
    }
    return applied;
  }
}
