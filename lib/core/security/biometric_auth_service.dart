import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// FS-012 Security Enhancement: Biometric Chat Lock.
///
/// This service handles the biometric authentication flow for sensitive
/// surfaces like Family Chat. It manages the user preference for enabling
/// the lock and performs the actual authentication check.
/// ---------------------------------------------------------------------------

class BiometricAuthService {
  BiometricAuthService(this._auth);
  final LocalAuthentication _auth;

  static const _prefKey = 'security_chat_biometric_lock';

  /// Check if biometrics are available on this device.
  Future<bool> isAvailable() async {
    final canAuthWithBiometrics = await _auth.canCheckBiometrics;
    final canAuth = canAuthWithBiometrics || await _auth.isDeviceSupported();
    return canAuth;
  }

  /// Check if the user has enabled the chat lock.
  Future<bool> isChatLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Toggle the chat lock preference.
  Future<void> setChatLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  /// Perform biometric authentication.
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      // For local_auth 3.0.1, authenticate uses named parameters directly.
      // 'stickyAuth' is mapped to 'persistAcrossBackgrounding' in 3.0.1.
      return await _auth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
        biometricOnly: false, // Fallback to PIN/Pattern if biometric fails
      );
    } catch (e) {
      return false;
    }
  }
}

final biometricAuthProvider = Provider((ref) => LocalAuthentication());

final biometricAuthServiceProvider = Provider((ref) {
  final auth = ref.watch(biometricAuthProvider);
  return BiometricAuthService(auth);
});

/// State provider for the chat lock status.
final chatLockEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(biometricAuthServiceProvider);
  return service.isChatLockEnabled();
});
