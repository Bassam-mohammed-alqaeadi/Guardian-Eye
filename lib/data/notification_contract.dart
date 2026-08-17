import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationDispatchResult {
  const NotificationDispatchResult(
      {required this.accepted, required this.reason});
  final bool accepted;
  final String reason;
}

/// A request to deliver a push notification to the family's parent devices
/// through the trusted Guardian Backend (`POST /api/notify`).
class NotificationDispatchRequest {
  const NotificationDispatchRequest({
    required this.familyId,
    required this.kind,
    required this.title,
    required this.body,
    this.incidentId,
    this.sosId,
  });
  final String familyId;

  /// `incident` or `sos`.
  final String kind;
  final String title;
  final String body;
  final String? incidentId;
  final String? sosId;
}

abstract class ParentNotificationGateway {
  Future<NotificationDispatchResult> requestServerDispatch(
      NotificationDispatchRequest request);
}

/// Fire-and-forget guard used when Firebase / the Render backend is not
/// available (emulator-only runs, unconfigured builds). Never claims delivery.
class GuardedFcmNotificationGateway implements ParentNotificationGateway {
  const GuardedFcmNotificationGateway();
  @override
  Future<NotificationDispatchResult> requestServerDispatch(
      NotificationDispatchRequest request) async {
    if (!const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED') ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'firebase_or_auth_unavailable');
    }
    return const NotificationDispatchResult(
        accepted: false, reason: 'server_side_notification_producer_required');
  }
}

/// Production FCM delivery path: posts the request to the Guardian Backend
/// (`POST /api/notify`) using the current Firebase ID token. The backend
/// verifies the caller is an active family member, reads the family's
/// parent-role device FCM tokens from Firestore, and sends via Firebase
/// Admin Messaging — the same trusted architecture as child provisioning.
class RenderNotificationGateway implements ParentNotificationGateway {
  const RenderNotificationGateway({
    Dio? client,
    Future<String> Function()? idToken,
    String? baseUrl,
    bool? available,
  })  : _client = client,
        _idToken = idToken,
        _baseUrl = baseUrl,
        _availableOverride = available;

  final Dio? _client;
  final Future<String> Function()? _idToken;
  final String? _baseUrl;
  final bool? _availableOverride;

  static const String defaultBaseUrl = String.fromEnvironment(
    'GUARDIAN_BACKEND_URL',
    defaultValue: 'https://guardian-eye-djg8.onrender.com',
  );

  String get _url => _baseUrl ?? defaultBaseUrl;

  bool get _available =>
      _availableOverride ??
      (Firebase.apps.isNotEmpty &&
          const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED'));

  Dio get _dio =>
      _client ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
      ));

  Future<String> _token() async {
    final provider = _idToken;
    if (provider != null) return provider();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('authenticated_identity_required');
    final token = await user.getIdToken();
    if (token == null) throw StateError('authenticated_identity_required');
    return token;
  }

  @override
  Future<NotificationDispatchResult> requestServerDispatch(
      NotificationDispatchRequest request) async {
    if (!_available) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'firebase_or_auth_unavailable');
    }
    final String token;
    try {
      token = await _token();
    } catch (_) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'authenticated_identity_required');
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_url/api/notify',
        data: <String, dynamic>{
          'familyId': request.familyId,
          'kind': request.kind,
          'title': request.title,
          'body': request.body,
          if (request.incidentId != null) 'incidentId': request.incidentId,
          if (request.sosId != null) 'sosId': request.sosId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final sent = data?['sent'] as int? ?? 0;
      final failed = data?['failed'] as int? ?? 0;
      final removed = data?['invalidTokensRemoved'] as int? ?? 0;
      if (sent > 0 || data?['reason'] == 'no_tokens') {
        return NotificationDispatchResult(
            accepted: true,
            reason: 'sent:$sent failed:$failed invalidRemoved:$removed');
      }
      return NotificationDispatchResult(
          accepted: sent > 0, reason: 'sent:$sent failed:$failed');
    } on DioException catch (error) {
      return NotificationDispatchResult(
          accepted: false,
          reason: _mapError(error) ?? 'server_unreachable');
    } catch (_) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'server_unreachable');
    }
  }

  String? _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'server_unreachable';
    }
    final status = error.response?.statusCode;
    if (status == 401) return 'unauthenticated';
    if (status == 403) return 'not_a_member';
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String) return message;
    }
    return 'server_error';
  }
}
