import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firebase/guardian_firebase_bootstrap.dart';

/// M5 — canonical remote child provisioning path via the Guardian Backend.
///
/// The parent issues a trusted provisioning session through
/// `POST /api/provision-child`; the child device redeems it through
/// `POST /api/redeem-child`. The trusted backend (Firebase Admin SDK) creates
/// the UID-keyed `members/{childUid}` and `devices/{deviceId}` documents inside
/// a single atomic redemption transaction. This service is a thin, honest
/// client over those endpoints; it never performs Firestore writes itself and
/// it never creates a child member document from the parent client.
///
/// Authentication uses the Firebase ID token of the CURRENT authenticated
/// session (`Authorization: Bearer <idToken>`). The backend derives every
/// identity (parentUid / childUid) from that verified token — never from the
/// request payload.
///
/// When Firebase is not configured the service is unavailable and the local
/// SQLite pairing machinery remains the offline-first fallback path.
class RemoteProvisioningService {
  const RemoteProvisioningService({
    Dio? client,
    Future<String> Function()? idToken,
    bool? available,
    String? baseUrl,
  })  : _client = client,
        _idToken = idToken,
        _availableOverride = available,
        _baseUrl = baseUrl;

  final Dio? _client;
  final Future<String> Function()? _idToken;
  final bool? _availableOverride;
  final String? _baseUrl;

  /// Production Guardian Backend. Overridable at build time with
  /// `--dart-define=GUARDIAN_BACKEND_URL=...`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'GUARDIAN_BACKEND_URL',
    defaultValue: 'https://guardian-eye-djg8.onrender.com',
  );

  bool get _available =>
      _availableOverride ?? GuardianFirebaseBootstrap.current.isReady;

  String get _url => _baseUrl ?? defaultBaseUrl;

  Dio get _dio =>
      _client ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ));

  /// Resolves the Firebase ID token of the currently authenticated actor.
  Future<String> _token() async {
    final provider = _idToken;
    if (provider != null) return provider();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const RemoteProvisioningUnavailableException();
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const RemoteProvisioningUnavailableException();
    }
    return token;
  }

  Future<RemoteProvisioningIssue> issue({
    required String familyId,
    required String targetMemberId,
    required String displayName,
  }) async {
    if (!_available) {
      throw const RemoteProvisioningUnavailableException();
    }
    final token = await _token();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_url/api/provision-child',
        data: {
          'familyId': familyId,
          'targetMemberId': targetMemberId,
          'displayName': displayName,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final pairingId = data?['pairingId'] as String?;
      final code = data?['provisioningCode'] as String?;
      final expiresAt = data?['expiresAt'] as String?;
      if (pairingId == null || code == null || expiresAt == null) {
        throw const RemoteProvisioningException('issue_incomplete_result');
      }
      return RemoteProvisioningIssue(
          pairingId: pairingId,
          code: code,
          expiresAt: DateTime.parse(expiresAt).toUtc());
    } on DioException catch (error) {
      throw _mapIssueError(error);
    }
  }

  RemoteProvisioningException _mapIssueError(DioException error) {
    if (_isNetworkFailure(error)) {
      return const RemoteProvisioningException('server_unreachable');
    }
    final code = _errorCode(error);
    switch (code) {
      case 'family_not_found':
        return const RemoteProvisioningException('family_not_found');
      case 'parent_not_member':
      case 'parent_not_authorized':
        return const RemoteProvisioningException('parent_not_authorized');
      case 'unauthenticated':
      case 'invalid_token':
        return const RemoteProvisioningException('unauthenticated');
      default:
        return const RemoteProvisioningException('server_error');
    }
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
    final token = await _token();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_url/api/redeem-child',
        data: {
          'provisioningCode': code,
          'deviceId': deviceId,
          if (pairingId.isNotEmpty) 'pairingId': pairingId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final state = data?['state'] as String?;
      if (state == 'enrolled') {
        return RemoteRedeemResult.enrolled(
            deviceId: data?['deviceId'] as String?,
            targetMemberId: data?['targetMemberId'] as String?);
      }
      return const RemoteRedeemResult.rejected();
    } on DioException catch (error) {
      return _mapRedeemError(error);
    }
  }

  bool _isNetworkFailure(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError;

  String? _errorCode(DioException error) {
    final data = error.response?.data;
    if (data is Map) return data['error'] as String?;
    return null;
  }

  RemoteRedeemResult _mapRedeemError(DioException error) {
    if (_isNetworkFailure(error)) {
      return const RemoteRedeemResult.networkUnavailable();
    }
    final code = _errorCode(error);
    switch (code) {
      case 'invalid_code':
        return const RemoteRedeemResult.invalidCode();
      case 'expired':
        return const RemoteRedeemResult.expired();
      case 'locked':
        return const RemoteRedeemResult.locked();
      case 'already_used':
        return const RemoteRedeemResult.alreadyUsed();
      case 'device_conflict':
        return const RemoteRedeemResult.deviceConflict();
      case 'member_conflict':
        return const RemoteRedeemResult.memberConflict();
      case 'unauthenticated':
      case 'invalid_token':
        return const RemoteRedeemResult.unauthenticated();
      case 'parent_not_authorized':
      case 'parent_not_member':
      case 'family_not_found':
        return const RemoteRedeemResult.unauthorized();
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
  networkUnavailable,
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

  const RemoteRedeemResult.networkUnavailable()
      : this._(RemoteRedeemState.networkUnavailable);

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
