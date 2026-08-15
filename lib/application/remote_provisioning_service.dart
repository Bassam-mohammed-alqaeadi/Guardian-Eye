import 'package:cloud_functions/cloud_functions.dart';

import '../core/firebase/guardian_firebase_bootstrap.dart';

/// M5 Option D — canonical remote child provisioning path.
///
/// The parent issues a trusted provisioning session through
/// `createChildDeviceProvisioning`; the child device redeems it through
/// `redeemChildDeviceProvisioning`. The trusted backend creates the
/// UID-keyed `members/{childUid}` and `devices/{deviceId}` documents inside a
/// single atomic redemption transaction. This service is a thin, honest client
/// over those two callables; it never performs Firestore writes itself and it
/// never creates a child member document from the parent client.
///
/// When Firebase is not configured the callables are unavailable and the local
/// SQLite pairing machinery remains the offline-first fallback path.
class RemoteProvisioningService {
  const RemoteProvisioningService({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  bool get _available => GuardianFirebaseBootstrap.current.isReady;

  FirebaseFunctions get _instance =>
      _functions ?? FirebaseFunctions.instance;

  Future<RemoteProvisioningIssue> issue({
    required String familyId,
    required String targetMemberId,
    required String displayName,
  }) async {
    if (!_available) {
      throw const RemoteProvisioningUnavailableException();
    }
    final callable = _instance.httpsCallable('createChildDeviceProvisioning');
    final result = await callable.call({
      'familyId': familyId,
      'targetMemberId': targetMemberId,
      'displayName': displayName,
    });
    final data = result.data as Map<dynamic, dynamic>;
    final pairingId = data['pairingId'] as String?;
    final code = data['code'] as String?;
    final expiresAt = data['expiresAt'] as String?;
    if (pairingId == null || code == null || expiresAt == null) {
      throw const RemoteProvisioningException('issue_incomplete_result');
    }
    return RemoteProvisioningIssue(
        pairingId: pairingId,
        code: code,
        expiresAt: DateTime.parse(expiresAt).toUtc());
  }

  Future<RemoteRedeemResult> redeem({
    required String familyId,
    required String pairingId,
    required String code,
    required String deviceId,
  }) async {
    if (!_available) {
      throw const RemoteProvisioningUnavailableException();
    }
    final callable = _instance.httpsCallable('redeemChildDeviceProvisioning');
    try {
      final result = await callable.call({
        'familyId': familyId,
        'pairingId': pairingId,
        'code': code,
        'deviceId': deviceId,
      });
      final data = result.data as Map<dynamic, dynamic>;
      final state = data['state'] as String?;
      if (state == 'enrolled') {
        return RemoteRedeemResult.enrolled(
            deviceId: data['deviceId'] as String?,
            targetMemberId: data['targetMemberId'] as String?);
      }
      return RemoteRedeemResult.rejected(state: state ?? 'rejected');
    } on FirebaseFunctionsException catch (error) {
      return _mapError(error);
    }
  }

  RemoteRedeemResult _mapError(FirebaseFunctionsException error) {
    final code = error.code;
    final message = error.message ?? '';
    switch (code) {
      case 'unauthenticated':
        return const RemoteRedeemResult.unauthenticated();
      case 'permission-denied':
        if (message.contains('pairing_locked')) {
          return const RemoteRedeemResult.locked();
        }
        if (message.contains('pairing_invalid_code') ||
            message.contains('invalid_code')) {
          return const RemoteRedeemResult.invalidCode();
        }
        return const RemoteRedeemResult.unauthorized();
      case 'failed-precondition':
        if (message.contains('pairing_expired') ||
            message.contains('expired')) {
          return const RemoteRedeemResult.expired();
        }
        if (message.contains('pairing_rejected') ||
            message.contains('rejected')) {
          return const RemoteRedeemResult.alreadyUsed();
        }
        if (message.contains('device_conflict')) {
          return const RemoteRedeemResult.deviceConflict();
        }
        if (message.contains('member_conflict')) {
          return const RemoteRedeemResult.memberConflict();
        }
        return const RemoteRedeemResult.rejected(state: 'failed-precondition');
      case 'invalid-argument':
        return const RemoteRedeemResult.invalidCode();
      default:
        return const RemoteRedeemResult.unknown();
    }
  }
}

class RemoteProvisioningIssue {
  const RemoteProvisioningIssue({
    required this.pairingId,
    required this.code,
    required this.expiresAt,
  });

  final String pairingId;
  final String code;
  final DateTime expiresAt;
}

enum RemoteRedeemState {
  enrolled,
  invalidCode,
  expired,
  locked,
  alreadyUsed,
  deviceConflict,
  memberConflict,
  unauthorized,
  unauthenticated,
  rejected,
  unknown,
}

class RemoteRedeemResult {
  const RemoteRedeemResult._(this.state, {this.deviceId, this.targetMemberId});

  const RemoteRedeemResult.enrolled({this.deviceId, this.targetMemberId})
      : state = RemoteRedeemState.enrolled;

  const RemoteRedeemResult.invalidCode()
      : this._(RemoteRedeemState.invalidCode);

  const RemoteRedeemResult.expired() : this._(RemoteRedeemState.expired);

  const RemoteRedeemResult.locked() : this._(RemoteRedeemState.locked);

  const RemoteRedeemResult.alreadyUsed()
      : this._(RemoteRedeemState.alreadyUsed);

  const RemoteRedeemResult.deviceConflict()
      : this._(RemoteRedeemState.deviceConflict);

  const RemoteRedeemResult.memberConflict()
      : this._(RemoteRedeemState.memberConflict);

  const RemoteRedeemResult.unauthorized()
      : this._(RemoteRedeemState.unauthorized);

  const RemoteRedeemResult.unauthenticated()
      : this._(RemoteRedeemState.unauthenticated);

  const RemoteRedeemResult.rejected({String? state})
      : this._(RemoteRedeemState.rejected);

  const RemoteRedeemResult.unknown() : this._(RemoteRedeemState.unknown);

  final RemoteRedeemState state;
  final String? deviceId;
  final String? targetMemberId;

  bool get succeeded => state == RemoteRedeemState.enrolled;
}

class RemoteProvisioningUnavailableException implements Exception {
  const RemoteProvisioningUnavailableException();
}

class RemoteProvisioningException implements Exception {
  const RemoteProvisioningException(this.reason);
  final String reason;
}
