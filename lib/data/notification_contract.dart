import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/firebase/guardian_firebase_bootstrap.dart';

/// Result of asking the trusted backend to dispatch a push notification to a
/// family's active parent devices. Honest by construction: the contract never
/// claims delivery was achieved — it only reports what the backend observed
/// (tokens accepted for sending, failures reported back, and the reason a
/// request could not be processed at all).
class NotificationDispatchResult {
  const NotificationDispatchResult(
      {required this.accepted,
      required this.reason,
      this.sent = 0,
      this.failed = 0,
      this.noTokens = false});

  /// Whether the backend accepted and attempted the dispatch.
  final bool accepted;

  /// Machine-readable reason. Stable values the UI may switch on:
  /// `accepted`, `no_tokens`, `not_authenticated`, `not_a_member`,
  /// `invalid_kind`, `server_unreachable`, `backend_unavailable`,
  /// `unexpected_error`, plus any raw backend code.
  final String reason;

  /// Tokens Firebase accepted the message for (evidence, not proof of device
  /// display — Android may still drop it under Doze / battery restrictions).
  final int sent;

  /// Tokens Firebase reported as failures (evidence).
  final int failed;

  /// The backend found no active parent token; nobody will receive this.
  final bool noTokens;
}

enum NotificationKind { incident, sos }

/// Transport errors mapped from backend responses. `retryable` failures get
/// re-attempted by the honest retry policy; `permanent` ones surface once.
enum NotificationTransportFailureKind { retryable, permanent }

class NotificationTransportException implements Exception {
  const NotificationTransportException(this.kind, this.reason);
  final NotificationTransportFailureKind kind;
  final String reason;
}

/// Asks the trusted Render backend (`POST /api/notify`) to push a safety
/// event to the family's active parent devices.
///
/// Security contract (architecture report Phase B, kept for reference):
/// - The caller never supplies recipient identities; only `familyId`, `kind`
///   and optional event references travel.
/// - The request is authenticated with the current user's Firebase ID token
///   (Bearer) — the backend re-derives the caller's UID and verifies family
///   membership itself.
/// - The backend is the only entity that can read FCM tokens and send
///   through the Admin SDK.
class RenderNotificationGateway {
  const RenderNotificationGateway({
    Dio? client,
    Future<String> Function()? idToken,
    String? baseUrl,
    DateTime Function()? clock,
  })  : _client = client,
        _idToken = idToken,
        _baseUrl = baseUrl,
        _clock = clock ?? DateTime.now;

  final Dio? _client;
  final Future<String> Function()? _idToken;
  final String? _baseUrl;
  final DateTime Function() _clock;

  /// Production Guardian Backend. Overridable at build time with
  /// `--dart-define=GUARDIAN_BACKEND_URL=...`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'GUARDIAN_BACKEND_URL',
    defaultValue: 'https://guardian-eye-djg8.onrender.com',
  );

  static const Set<String> _allowedKinds = {'incident', 'sos'};

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
      throw const NotificationTransportException(
          NotificationTransportFailureKind.permanent, 'not_authenticated');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const NotificationTransportException(
          NotificationTransportFailureKind.permanent, 'not_authenticated');
    }
    return token;
  }

  /// Requests dispatch for a safety event the device has just created or
  /// observed locally. `kind` is strictly validated before anything leaves
  /// the device. The backend is the event's only legitimate producer: it
  /// verifies the event exists, derives the family, selects tokens, sends a
  /// data-only message, and records delivery evidence.
  Future<NotificationDispatchResult> requestServerDispatch({
    required String familyId,
    required NotificationKind kind,
    String? incidentId,
    String? sosId,
  }) async {
    if (!_isConfigured) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'backend_unavailable');
    }
    // In test mode (client + idToken both injected — production never does
    // this) the caller asserts its own auth posture through the request;
    // the Firebase session check only applies to production paths.
    if (!_isTestMode) {
      final session = _currentIdentity();
      if (session == null) {
        return const NotificationDispatchResult(
            accepted: false, reason: 'not_authenticated');
      }
    }
    if (!_allowedKinds.contains(kind.name)) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'invalid_kind');
    }
    if (familyId.isEmpty) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'invalid_family');
    }
    final token = await _token();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_url/api/notify',
        data: {
          'familyId': familyId,
          'kind': kind.name,
          if (incidentId != null && incidentId.isNotEmpty)
            'incidentId': incidentId,
          if (sosId != null && sosId.isNotEmpty) 'sosId': sosId,
          'requestedAt': _clock().toUtc().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final statusCode = response.statusCode ?? 200;
      if (statusCode < 200 || statusCode >= 300) {
        return _mapStatusCode(statusCode);
      }
      final data = response.data;
      final sent = (data?['sent'] as int?) ?? 0;
      final failed = (data?['failed'] as int?) ?? 0;
      final reason = (data?['reason'] as String?) ?? 'accepted';
      final noTokens = reason == 'no_tokens';
      return NotificationDispatchResult(
          accepted: true,
          reason: noTokens ? 'no_tokens' : 'accepted',
          sent: sent,
          failed: failed,
          noTokens: noTokens);
    } on DioException catch (error) {
      return _mapTransportError(error);
    } on NotificationTransportException catch (error) {
      return NotificationDispatchResult(
          accepted: false, reason: error.reason);
    } catch (error) {
      return NotificationDispatchResult(
          accepted: false, reason: 'unexpected:${error.runtimeType}');
    }
  }

  /// Production path needs a configured Firebase runtime; the test-only path
  /// (both `idToken` provider and `client` injected together — production
  /// never does this) runs without any Firebase runtime.
  bool get _isConfigured => (_idToken != null && _client != null) ||
      (const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED') &&
          Firebase.apps.isNotEmpty &&
          GuardianFirebaseBootstrap.current.isReady);

  bool get _isTestMode => _idToken != null && _client != null;

  User? _currentUser() => _isTestMode ? null : FirebaseAuth.instance.currentUser;

  AuthenticatedIdentity? _currentIdentity() {
    final user = _currentUser();
    return user == null
        ? null
        : AuthenticatedIdentity(
            uid: user.uid, email: user.email, isAnonymous: user.isAnonymous);
  }

  NotificationDispatchResult _mapStatusCode(int statusCode) {
    if (statusCode == 401) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'not_authenticated');
    }
    if (statusCode == 403) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'not_a_member');
    }
    if (statusCode == 400) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'invalid_request');
    }
    return const NotificationDispatchResult(
        accepted: false, reason: 'server_unreachable');
  }

  NotificationDispatchResult _mapTransportError(DioException error) {
    final status = error.response?.statusCode;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'server_unreachable');
    }
    if (status == 401) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'not_authenticated');
    }
    if (status == 403) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'not_a_member');
    }
    if (status == 400) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'invalid_request');
    }
    if (status != null && status >= 500) {
      return const NotificationDispatchResult(
          accepted: false, reason: 'server_unreachable');
    }
    return const NotificationDispatchResult(
        accepted: false, reason: 'server_unreachable');
  }
}

/// Typed identity view used inside this file only; kept decoupled from the
/// auth context module so the gateway remains independently testable.
class AuthenticatedIdentity {
  const AuthenticatedIdentity(
      {required this.uid, required this.email, required this.isAnonymous});
  final String uid;
  final String? email;
  final bool isAnonymous;
}
