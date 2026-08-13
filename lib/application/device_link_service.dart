import 'dart:io';
import '../data/guardian_repositories.dart';

/// Explicit user-facing outcome of a redemption attempt.
///
/// Never collapses into a generic error: each variant maps to a distinct
/// localized message and UI state on the child redemption surface.
enum RedeemOutcome {
  validating,
  success,
  pendingSync,
  codeInvalid,
  codeExpired,
  codeLocked,
  codeAlreadyUsed,
  alreadyEnrolled,
  unauthorized,
  networkUnavailable,
  unknownError,
}

/// Maps the repository reason taxonomy to explicit [RedeemOutcome] values.
RedeemOutcome outcomeForReason(String? reason) {
  switch (reason) {
    case 'code_mismatch':
      return RedeemOutcome.codeInvalid;
    case 'request_expired':
      return RedeemOutcome.codeExpired;
    case 'too_many_attempts':
      return RedeemOutcome.codeLocked;
    case 'request_already_used':
    case 'request_revoked':
      return RedeemOutcome.codeAlreadyUsed;
    case 'active_device_already_linked':
      return RedeemOutcome.alreadyEnrolled;
    case 'request_not_found':
    default:
      return RedeemOutcome.codeInvalid;
  }
}

/// Canonical device-linking service for M4 child redemption.
///
/// Authority model (verified from the repository's own tests):
/// `owner_member_id` on the enrolled device row identifies the member the
/// device belongs to — the same member id as `member_id` for child devices.
/// The pairing core's transactional gates (expiry, attempts, single use,
/// single active device per member, owner-only revocation) are the sole
/// authority boundary; this service does not re-implement or weaken them.
///
/// Redemption happens BEFORE the device is an established actor: no actor
/// binding is required (or even possible) at redemption time, so this service
/// never consults `FamilyRuntimeContext`. The device only becomes part of the
/// family after the enrollment transaction; trust is then granted through
/// the trusted actor binding like every other member.
///
/// Identity invariant preserved: `accountUid != memberId != deviceId`.
class DeviceLinkService {
  const DeviceLinkService(this._pairing);
  final PairingRepository _pairing;

  /// Redeems a pairing code for this device.
  ///
  /// [requestId] identifies the parent-issued session; [code] is verified
  /// against the stored SHA-256 hash inside the repository; [targetMemberId]
  /// is the child member the device binds to (matching the session's
  /// `target_member_id` binding intent). Returns the explicit outcome and, on
  /// success, the enrolled device id.
  ///
  /// Offline honesty: network-dependent verification cannot be simulated
  /// locally, so transient `SocketException`/`HttpException` surfaces as
  /// [RedeemOutcome.networkUnavailable] rather than a fabricated success or
  /// a technical exception string. Local SQLite success is honest local
  /// success; remote synchronization is reflected by the outbox queue state.
  Future<({RedeemOutcome outcome, String? deviceId})> redeem({
    required String requestId,
    required String code,
    required String targetMemberId,
  }) async {
    if (code.trim().length != 6 || !RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return (outcome: RedeemOutcome.codeInvalid, deviceId: null);
    }
    try {
      final result = await _pairing.verifyAndEnroll(
        requestId: requestId,
        code: code.trim(),
        memberId: targetMemberId,
        ownerMemberId: targetMemberId,
      );
      if (result.succeeded) {
        // The outbox holds the remote reconciliation mutation; local state is
        // honest but remote trust is pending synchronization.
        return (outcome: RedeemOutcome.pendingSync, deviceId: result.deviceId);
      }
      return (outcome: outcomeForReason(result.reason), deviceId: null);
    } on SocketException {
      return (outcome: RedeemOutcome.networkUnavailable, deviceId: null);
    } on HttpException {
      return (outcome: RedeemOutcome.networkUnavailable, deviceId: null);
    } catch (_) {
      return (outcome: RedeemOutcome.unknownError, deviceId: null);
    }
  }
}
