import '../data/fcm_token_repository.dart';
import '../data/family_actor_binding_service.dart';
import '../data/guardian_repositories.dart';
import '../domain/guardian_models.dart';

/// M9/FCM — app-side registration of THIS device as a parent-role device so
/// the trusted Guardian Backend (`POST /api/notify`) can deliver push
/// notifications to the parent.
///
/// The chain is fully rules-valid but was previously unwired in the app:
///  1. [PairingRepository.enrollParentDevice] creates the local `devices`
///     row (role `parentDevice`, `memberUid == null`) and enqueues
///     `device.enrolled` through the durable outbox.
///  2. [FcmTokenService.register] obtains the platform FCM token and enqueues
///     `notification.token.registered`, which writes it under
///     `devices/{deviceId}/notification_tokens/{id}` (rules `activeTokenDevice`).
///  3. The normal SyncCoordinator pushes both ops; the backend then finds the
///     token when a parent notification is requested.
///
/// This service is idempotent and safe when logged out, unconfigured, or
/// without a family: it resolves through the same fail-closed actor binding
/// as every other surface and returns `null` without claiming anything.
class ParentNotificationRegistration {
  const ParentNotificationRegistration({
    required FamilyRepository families,
    required PairingRepository pairing,
    required FamilyActorBindingService binding,
    required FcmTokenService fcm,
    required String platform,
  })  : _families = families,
        _pairing = pairing,
        _binding = binding,
        _fcm = fcm,
        _platform = platform;

  final FamilyRepository _families;
  final PairingRepository _pairing;
  final FamilyActorBindingService _binding;
  final FcmTokenService _fcm;
  final String _platform;

  /// Ensures the parent device + FCM token are registered for EVERY family
  /// this device belongs to as a verified parent. The dashboard resolves a
  /// single family, but a device can hold membership in more than one family
  /// (e.g. the M5Gate + M9Parent test families on the same phone), so the
  /// registration considers each family independently: a family where the
  /// actor is not a verified parent (or a child) is skipped without failing
  /// the others. Returns the first enrolled parent device id, or `null` when
  /// there is nothing to register (no family, no verified parent, permission
  /// denied, Firebase unconfigured).
  Future<String?> ensureRegistered() async {
    try {
      final families = await _families.allFamilies();
      if (families.isEmpty) return null;
      String? firstDeviceId;
      for (final family in families) {
        final bindingResult = await _binding.resolveForFamily(family.id);
        if (!bindingResult.isVerified) continue;
        final parent = bindingResult.binding?.member;
        if (parent == null || parent.role == FamilyRole.child) continue;
        final deviceId = await _pairing.enrollParentDevice(
          familyId: family.id,
          memberId: parent.id,
          ownerMemberId: parent.id,
        );
        await _fcm.register(
          familyId: family.id,
          deviceId: deviceId,
          platform: _platform,
        );
        firstDeviceId ??= deviceId;
      }
      return firstDeviceId;
    } catch (_) {
      // Registration is best-effort: any failure (auth unavailable, no
      // network, permission denied) must never surface as an error — the
      // outbox rows carry the honest sync state and the backend simply finds
      // no token until registration succeeds.
      return null;
    }
  }
}
