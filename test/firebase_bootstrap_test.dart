import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/firebase/guardian_firebase_bootstrap.dart';
import 'package:guardian_ai/core/firebase/guardian_firebase_environment.dart';

void main() {
  test('Firebase bootstrap is disabled without an explicit environment',
      () async {
    final state = await GuardianFirebaseBootstrap.initialize();
    expect(state.status, FirebaseBootstrapStatus.failed);
    expect(state.reason, 'firebase_environment_not_explicitly_approved');
    expect(GuardianFirebaseBootstrap.current.isReady, isFalse);
  });

  test('development and test require an explicit emulator host', () {
    final blocked = GuardianFirebaseEnvironmentConfig.fromValues(
        rawEnvironment: 'development',
        emulatorHost: '',
        realBackendApproved: false,
        productionApproved: false);
    expect(blocked.isFirebaseEnabled, isFalse);

    final development = GuardianFirebaseEnvironmentConfig.fromValues(
        rawEnvironment: 'development',
        emulatorHost: '10.0.2.2',
        realBackendApproved: false,
        productionApproved: false);
    expect(development.usesEmulator, isTrue);
    expect(development.emulatorHost, '10.0.2.2');
  });

  test('real and production backends require separate explicit approvals', () {
    final realBlocked = GuardianFirebaseEnvironmentConfig.fromValues(
        rawEnvironment: 'real_backend_validation',
        emulatorHost: '',
        realBackendApproved: false,
        productionApproved: false);
    expect(realBlocked.isFirebaseEnabled, isFalse);

    final realApproved = GuardianFirebaseEnvironmentConfig.fromValues(
        rawEnvironment: 'real_backend_validation',
        emulatorHost: '',
        realBackendApproved: true,
        productionApproved: false);
    expect(realApproved.environment,
        GuardianFirebaseEnvironment.realBackendValidation);

    final productionBlocked = GuardianFirebaseEnvironmentConfig.fromValues(
        rawEnvironment: 'production',
        emulatorHost: '',
        realBackendApproved: true,
        productionApproved: false);
    expect(productionBlocked.isFirebaseEnabled, isFalse);
  });
}
