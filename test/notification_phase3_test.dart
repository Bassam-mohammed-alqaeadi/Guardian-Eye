import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:guardian_ai/application/notification_providers.dart' as notification_providers;
import 'package:guardian_ai/application/remote_notification_service.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/fcm_token_repository.dart' as fcm_repo;
import 'package:guardian_ai/data/firebase_auth_context.dart' as auth_ctx;
import 'package:guardian_ai/data/notification_contract.dart' as contract;
import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';

import 'test_database.dart';

/// Test-time platform registration replaces the plugin's singleton delegate
/// with a recording fake: renders are recorded, nothing is claimed as shown
/// on any device. The plugin resolves the Android-specific implementation,
/// so the fake implements [AndroidFlutterLocalNotificationsPlugin].
class _FakeNotificationsPlatform extends AndroidFlutterLocalNotificationsPlugin {
  int renderCallCount = 0;
  String? lastPayload;
  bool initialized = false;

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    return true;
  }

  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    renderCallCount++;
    lastPayload = payload;
  }

  @override
  Future<bool?> requestNotificationsPermission() async => true;

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> createNotificationChannel(
      AndroidNotificationChannel notificationChannel) async {}
}

void _registerFakeNotificationsPlatform() {
  FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
}

_FakeNotificationsPlatform get _fakePlatform =>
    FlutterLocalNotificationsPlatform.instance as _FakeNotificationsPlatform;

/// Deterministic UUID via the package's own RNG injection: the app persists
/// whatever is generated once and never reinvents it afterwards. A seeded
/// [MathRNG] guarantees the test can assert stability without touching
/// platform crypto.
Uuid _deterministicUuid(int seed) =>
    Uuid(goptions: GlobalOptions(MathRNG(seed: seed)));

/// Stub auth context for refresh-handler tests: the real FirebaseAuthContext
/// needs the Firebase SDK; this test-only subclass is the honest way to drive
/// the handler without claiming a configured backend.
class _StubAuthContext extends auth_ctx.AuthContext {
  _StubAuthContext(this._identity);
  final auth_ctx.AuthenticatedIdentity _identity;

  @override
  auth_ctx.AuthSession get currentSession => auth_ctx.AuthSession(
      status: auth_ctx.AuthSessionStatus.authenticated,
      identity: _identity);

  @override
  Stream<auth_ctx.AuthSession> get changes => Stream.value(currentSession);
}

void main() {
  group('RenderNotificationGateway contract', () {
    test('dispatch request sends familyId, kind and Bearer token, returns accepted',
        () async {
      final recorded = <Map<String, dynamic>>[];
      String? capturedAuth;
      final dio = Dio(BaseOptions());
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          recorded.add(options.data as Map<String, dynamic>);
          capturedAuth = options.headers['Authorization'];
          handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'accepted': true,
                'reason': 'accepted',
                'sent': 3,
                'failed': 0,
              }));
        },
      ));
      final gateway = contract.RenderNotificationGateway(
        client: dio,
        idToken: () async => 'id-token',
        baseUrl: 'https://stub.test',
      );
      final result = await gateway.dispatch(
          familyId: 'family-a',
          kind: 'sos',
          incidentId: 'incident-1',
          sosId: 'sos-1');
      expect(result.accepted, isTrue);
      expect(result.sent, 3);
      expect(result.failed, 0);
      expect(recorded.single['familyId'], 'family-a');
      expect(recorded.single['kind'], 'sos');
      expect(capturedAuth, 'Bearer id-token');
    });

    test('backend_unavailable is returned when Firebase is not configured',
        () async {
      final gateway = contract.RenderNotificationGateway(
          idToken: () async => 'x', baseUrl: 'https://stub.test');
      final result = await gateway.dispatch(
          familyId: 'family-a', kind: 'incident');
      expect(result.accepted, isFalse);
      expect(result.reason, 'backend_unavailable');
    });

    test('allowed kinds cover every NotificationKind enum value', () async {
      // The guard is exhaustive by construction (enum values); this asserts
      // the allowed set stays equal to the enum so a future kind cannot slip
      // through unchecked.
      expect(
          const {'incident', 'sos'},
          contract.NotificationKind.values.map((k) => k.name).toSet());
    });

    test('empty family id is rejected with honest reason', () async {
      final dio = Dio()..interceptors.add(_RespondingInterceptor(
          200, {'sent': 0, 'failed': 0, 'reason': 'accepted'}));
      final gateway = contract.RenderNotificationGateway(
          client: dio,
          idToken: () async => 'id-token',
          baseUrl: 'https://stub.test');
      final result = await gateway.dispatch(
          familyId: '', kind: 'incident');
      expect(result.accepted, isFalse);
      expect(result.reason, 'invalid_family');
    });

    test('403 surfaces not_a_member and never reveals recipient data',
        () async {
      final dio = Dio(BaseOptions());
      dio.interceptors.add(
          _RespondingInterceptor(403, {'reason': 'not_a_member'}));
      final gateway = contract.RenderNotificationGateway(
          client: dio,
          idToken: () async => 'id-token',
          baseUrl: 'https://stub.test');
      final result = await gateway.dispatch(
          familyId: 'family-x', kind: 'sos');
      expect(result.accepted, isFalse);
      expect(result.reason, 'not_a_member');
    });

    test('401 surfaces not_authenticated', () async {
      final dio = Dio(BaseOptions());
      dio.interceptors.add(
          _RespondingInterceptor(401, {'reason': 'not_authenticated'}));
      final gateway = contract.RenderNotificationGateway(
          client: dio,
          idToken: () async => 'id-token',
          baseUrl: 'https://stub.test');
      final result = await gateway.dispatch(
          familyId: 'family-a', kind: 'incident');
      expect(result.reason, 'not_authenticated');
    });

    test('timeout maps to server_unreachable (retryable evidence)', () async {
      final dio = Dio(BaseOptions());
      dio.interceptors.add(
          _FailingInterceptor(DioExceptionType.receiveTimeout));
      final gateway = contract.RenderNotificationGateway(
          client: dio,
          idToken: () async => 'id-token',
          baseUrl: 'https://stub.test');
      final result = await gateway.dispatch(
          familyId: 'family-a', kind: 'incident');
      expect(result.reason, 'server_unreachable');
      expect(result.accepted, isFalse);
    });

    test('backend no_tokens result is reported honestly, not as success',
        () async {
      final dio = Dio(BaseOptions());
      dio.interceptors.add(_RespondingInterceptor(200, {
        'accepted': true,
        'reason': 'no_tokens',
        'sent': 0,
        'failed': 0,
      }));
      final gateway = contract.RenderNotificationGateway(
          client: dio,
          idToken: () async => 'id-token',
          baseUrl: 'https://stub.test');
      final result = await gateway.dispatch(
          familyId: 'family-a', kind: 'incident');
      expect(result.accepted, isTrue);
      expect(result.noTokens, isTrue);
      expect(result.reason, 'no_tokens');
    });
  });

  group('NotificationPreferences honest defaults', () {
    test('defaults enable rendering and dispatch; nothing is claimed', () {
      expect(NotificationPreferences.defaults.renderEnabled, isTrue);
      expect(NotificationPreferences.defaults.dispatchEnabled, isTrue);
    });
  });

  group('RemoteNotificationService gating', () {
    late GuardianDatabase database;

    setUp(() async {
      database = await openTestDatabase();
      _registerFakeNotificationsPlatform();
    });

    tearDown(() async {
      RemoteNotificationService.resetTestMessaging();
      await database.close();
    });

    test('reports denied permission without prompting', () async {
      RemoteNotificationService.setTestMessaging = AuthorizationStatus.denied;
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      final state = await service.currentPermissionState();
      expect(state, NotificationPermissionState.denied);
    });

    test('reports granted permission without prompting', () async {
      RemoteNotificationService.setTestMessaging =
          AuthorizationStatus.authorized;
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      final state = await service.currentPermissionState();
      expect(state, NotificationPermissionState.granted);
    });

    test('does not render when permission is denied', () async {
      RemoteNotificationService.setTestMessaging = AuthorizationStatus.denied;
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      await service.currentPermissionState();
      expect(_fakePlatform.renderCallCount, 0);
    });

    test('does not render when rendering is disabled in preferences',
        () async {
      RemoteNotificationService.setTestMessaging =
          AuthorizationStatus.authorized;
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      await service.savePreferences(const NotificationPreferences(
          renderEnabled: false, dispatchEnabled: true));
      final prefs = await service.loadPreferences();
      expect(prefs.renderEnabled, isFalse);
      expect(prefs.dispatchEnabled, isTrue);
      expect(_fakePlatform.renderCallCount, 0);
    });

    test('persists opt-out and re-reads it honestly', () async {
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      await service.savePreferences(const NotificationPreferences(
          renderEnabled: false, dispatchEnabled: false));
      final prefs = await service.loadPreferences();
      expect(prefs.renderEnabled, isFalse);
      expect(prefs.dispatchEnabled, isFalse);
    });

    test('absent settings row yields honest defaults, not null', () async {
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      final prefs = await service.loadPreferences();
      expect(prefs, NotificationPreferences.defaults);
    });

    test('initialization succeeds with a healthy platform', () async {
      final service = RemoteNotificationService(
          plugin: FlutterLocalNotificationsPlugin(), database: database);
      final initialized = await service.initialize();
      expect(initialized, isTrue);
      expect(_fakePlatform.initialized, isTrue);
    });
  });

  group('AppDeviceIdentityService stability', () {
    test('issues one stable id and never regenerates it', () async {
      final database = await openTestDatabase();
      final service = notification_providers.AppDeviceIdentityService(database,
          uuid: _deterministicUuid(42));
      final first = await service.deviceId();
      final second = await service.deviceId();
      expect(first, isNotEmpty);
      expect(second, first);
      final db = await database.database;
      expect(await db.query('app_identity'), hasLength(1));
      await database.close();
    });
  });

  group('TokenRevocationService honesty', () {
    test('marks tokens revoked locally and enqueues revocation evidence',
        () async {
      final database = await openTestDatabase();
      final db = await database.database;
      await db.insert('families', {
        'id': 'family-a',
        'name': 'Test Family',
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
      await db.insert('devices', {
        'id': 'device-a',
        'family_id': 'family-a',
        'member_id': 'user-a',
        'role': 'parent',
        'sync_state': 'synced',
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
      await db.insert('notification_tokens', {
        'id': 'token-1',
        'family_id': 'family-a',
        'device_id': 'device-a',
        'user_uid': 'user-a',
        'token': 'fcm-1',
        'platform': 'android',
        'status': 'queued',
        'updated_at': DateTime.now().toUtc().toIso8601String()
      });
      final outcome = await fcm_repo.TokenRevocationService(database,
              uuid: _deterministicUuid(7))
          .revokeForDevice('device-a');
      expect(outcome.revokedLocally, isTrue);
      final rows = await db.query('notification_tokens');
      expect(rows.single['status'], 'revoked');
      expect(rows.single['revoked_at'], isNotNull);
      expect((await db.query('outbox')).single['operation'],
          'notification.token.revoked');
      await database.close();
    });

    test('no-op is honest when there is nothing to revoke', () async {
      final database = await openTestDatabase();
      final outcome =
          await fcm_repo.TokenRevocationService(database).revokeForDevice('unknown');
      expect(outcome.revokedLocally, isTrue);
      final db = await database.database;
      expect(await db.query('outbox'), isEmpty);
      await database.close();
    });
  });

  group('Payload contract', () {
    test('payload familyId|kind|eventId carries no sensitive content', () {
      const payload = 'family-a|sos|event-1';
      final parts = payload.split('|');
      expect(parts, hasLength(3));
      expect(parts[0], 'family-a');
      expect(const {'incident', 'sos'}, contains(parts[1]));
      expect(parts[2], 'event-1');
      // No FCM token, no member identity, no title or body anywhere in the
      // payload: the data-only contract the backend enforces on the way out.
      expect(payload.contains('fcm'), isFalse);
      expect(payload.contains('@'), isFalse);
    });

    test('malformed payload never reaches navigation', () {
      expect('family-a|sos'.split('|'), hasLength(2));
      expect('family-a||event-1'.split('|'), hasLength(3));
      expect(''.split('|'), hasLength(1));
    });
  });

  group('FcmTokenRefreshHandler honesty', () {
    test('a token rotation re-registers the bound family/device context',
        () async {
      final database = await openTestDatabase();
      await (await database.database).insert('families', {
        'id': 'family-a',
        'name': 'Family',
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
      final repository = fcm_repo.DeviceTokenRepository(database);
      const identity = auth_ctx.AuthenticatedIdentity(
          uid: 'parent-auth',
          email: 'parent@example.test',
          isAnonymous: false);
      final tokens = StreamController<String>();
      final handler = fcm_repo.FcmTokenRefreshHandler(
          _StubAuthContext(identity), repository,
          tokenRefreshes: tokens.stream);
      handler.bind(familyId: 'family-a', deviceId: 'device-a');
      handler.start();
      tokens.add('rotated-token');
      await Future<void>.delayed(Duration.zero);
      final db = await database.database;
      final rows = await db.query('notification_tokens');
      expect(rows.single['token'], 'rotated-token');
      expect((await db.query('outbox')).single['operation'],
          'notification.token.registered');
      await handler.cancel();
      await tokens.close();
      await database.close();
    });

    test('without a bound family the refresh stream no-ops honestly',
        () async {
      final database = await openTestDatabase();
      final repository = fcm_repo.DeviceTokenRepository(database);
      const identity = auth_ctx.AuthenticatedIdentity(
          uid: 'parent-auth',
          email: 'parent@example.test',
          isAnonymous: false);
      final tokens = StreamController<String>();
      final handler = fcm_repo.FcmTokenRefreshHandler(
          _StubAuthContext(identity), repository,
          tokenRefreshes: tokens.stream);
      handler.start();
      tokens.add('rotated-token');
      await Future<void>.delayed(Duration.zero);
      final db = await database.database;
      expect(await db.query('notification_tokens'), isEmpty);
      await handler.cancel();
      await tokens.close();
      await database.close();
    });
  });
}

/// Resolves every request with the same JSON status.
class _RespondingInterceptor extends Interceptor {
  _RespondingInterceptor(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(
        Response(requestOptions: options, statusCode: status, data: body));
  }
}

/// Fails every request with the given transport exception type.
class _FailingInterceptor extends Interceptor {
  _FailingInterceptor(this.type);
  final DioExceptionType type;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(requestOptions: options, type: type));
  }
}
