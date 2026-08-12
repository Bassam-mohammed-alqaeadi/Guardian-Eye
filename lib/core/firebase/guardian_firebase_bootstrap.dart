import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'guardian_firebase_environment.dart';

enum FirebaseBootstrapStatus { disabled, ready, failed }

class FirebaseBootstrapState {
  const FirebaseBootstrapState._(this.status, this.reason);
  const FirebaseBootstrapState.disabled()
      : this._(FirebaseBootstrapStatus.disabled, 'firebase_not_configured');
  const FirebaseBootstrapState.ready()
      : this._(FirebaseBootstrapStatus.ready, null);
  const FirebaseBootstrapState.failed(String reason)
      : this._(FirebaseBootstrapStatus.failed, reason);

  final FirebaseBootstrapStatus status;
  final String? reason;
  bool get isReady => status == FirebaseBootstrapStatus.ready;
}

/// Initializes only an explicitly configured Firebase runtime.
///
/// Android/iOS platform files supplied through FlutterFire provide the default
/// options. Without the explicit build flag, local-first operation remains
/// intact and no Firebase API is touched.
class GuardianFirebaseBootstrap {
  GuardianFirebaseBootstrap._();
  static FirebaseBootstrapState _current =
      const FirebaseBootstrapState.disabled();

  static FirebaseBootstrapState get current => _current;
  static GuardianFirebaseEnvironmentConfig get environment =>
      GuardianFirebaseEnvironmentConfig.current;
  static bool get isEnabled => environment.isFirebaseEnabled;

  static Future<FirebaseBootstrapState> initialize() async {
    final config = environment;
    if (!config.isFirebaseEnabled) {
      return _current = FirebaseBootstrapState.failed(config.disabledReason);
    }
    if (_current.isReady) return _current;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      if (config.usesEmulator) {
        final host = config.emulatorHost!;
        FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      }
      return _current = const FirebaseBootstrapState.ready();
    } on FirebaseException catch (error) {
      return _current = FirebaseBootstrapState.failed(error.code);
    } catch (_) {
      return _current =
          const FirebaseBootstrapState.failed('firebase_initialization_failed');
    }
  }
}
