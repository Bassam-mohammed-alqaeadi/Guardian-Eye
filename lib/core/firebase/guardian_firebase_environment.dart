enum GuardianFirebaseEnvironment {
  development,
  test,
  realBackendValidation,
  production,
  disabled,
}

/// Compile-time Firebase environment policy.
///
/// DEVELOPMENT and TEST can only start with an explicit emulator host.
/// REAL_BACKEND_VALIDATION and PRODUCTION can only start with an explicit
/// approval define, preventing local commands from writing to manus-guardian.
class GuardianFirebaseEnvironmentConfig {
  const GuardianFirebaseEnvironmentConfig._(
      this.environment, this.emulatorHost);

  final GuardianFirebaseEnvironment environment;
  final String? emulatorHost;

  factory GuardianFirebaseEnvironmentConfig.fromValues({
    required String rawEnvironment,
    required String emulatorHost,
    required bool realBackendApproved,
    required bool productionApproved,
  }) {
    final normalized = rawEnvironment.trim().toLowerCase();
    switch (normalized) {
      case 'development':
        return emulatorHost.trim().isEmpty
            ? const GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.disabled, null)
            : GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.development, emulatorHost.trim());
      case 'test':
        return emulatorHost.trim().isEmpty
            ? const GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.disabled, null)
            : GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.test, emulatorHost.trim());
      case 'real_backend_validation':
        return realBackendApproved
            ? const GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.realBackendValidation, null)
            : const GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.disabled, null);
      case 'production':
        return productionApproved
            ? const GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.production, null)
            : const GuardianFirebaseEnvironmentConfig._(
                GuardianFirebaseEnvironment.disabled, null);
      default:
        return const GuardianFirebaseEnvironmentConfig._(
            GuardianFirebaseEnvironment.disabled, null);
    }
  }

  static GuardianFirebaseEnvironmentConfig get current =>
      GuardianFirebaseEnvironmentConfig.fromValues(
        rawEnvironment: const String.fromEnvironment('GUARDIAN_ENV'),
        emulatorHost:
            const String.fromEnvironment('GUARDIAN_FIREBASE_EMULATOR_HOST'),
        realBackendApproved:
            const bool.fromEnvironment('GUARDIAN_REAL_BACKEND_VALIDATION'),
        productionApproved:
            const bool.fromEnvironment('GUARDIAN_PRODUCTION_APPROVED'),
      );

  bool get isFirebaseEnabled =>
      environment != GuardianFirebaseEnvironment.disabled;
  bool get usesEmulator =>
      environment == GuardianFirebaseEnvironment.development ||
      environment == GuardianFirebaseEnvironment.test;

  String get disabledReason {
    switch (environment) {
      case GuardianFirebaseEnvironment.disabled:
        return 'firebase_environment_not_explicitly_approved';
      default:
        return 'firebase_not_configured';
    }
  }
}
