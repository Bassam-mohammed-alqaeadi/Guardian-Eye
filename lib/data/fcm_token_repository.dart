import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';
import 'firebase_auth_context.dart';

enum GuardianNotificationType { incident, sos, syncFailure }

class DeviceTokenRegistration {
  const DeviceTokenRegistration(
      {required this.id,
      required this.familyId,
      required this.deviceId,
      required this.userUid,
      required this.token,
      required this.platform});
  final String id;
  final String familyId;
  final String deviceId;
  final String userUid;
  final String token;
  final String platform;
}

class DeviceTokenRepository {
  DeviceTokenRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final Uuid _uuid;
  Future<DeviceTokenRegistration> upsert(
      {required String familyId,
      required String deviceId,
      required AuthenticatedIdentity identity,
      required String token,
      required String platform}) async {
    if (token.trim().isEmpty || familyId.isEmpty || deviceId.isEmpty) {
      throw ArgumentError('Token, family, and device are required.');
    }
    final registration = DeviceTokenRegistration(
        id: _uuid.v4(),
        familyId: familyId,
        deviceId: deviceId,
        userUid: identity.uid,
        token: token,
        platform: platform);
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert(
          'notification_tokens',
          {
            'id': registration.id,
            'family_id': familyId,
            'device_id': deviceId,
            'user_uid': identity.uid,
            'token': token,
            'platform': platform,
            'status': SyncState.queued.storageKey,
            'updated_at': now.toIso8601String()
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _enqueue(tx, registration, now);
    });
    return registration;
  }

  Future<void> _enqueue(Transaction tx, DeviceTokenRegistration registration,
      DateTime now) async {
    final eventId = _uuid.v4();
    await tx.insert('outbox', {
      'id': eventId,
      'aggregate_type': 'notificationToken',
      'aggregate_id': registration.id,
      'operation': 'notification.token.registered',
      'payload_json': jsonEncode({
        'familyId': registration.familyId,
        'deviceId': registration.deviceId,
        'userUid': registration.userUid,
        'token': registration.token,
        'platform': registration.platform
      }),
      'idempotency_key': eventId,
      'state': SyncState.queued.storageKey,
      'attempt_count': 0,
      'next_attempt_at': now.toIso8601String(),
      'created_at': now.toIso8601String()
    });
  }
}

/// Token revocation outcome — honest and observable.
class TokenRevocationOutcome {
  const TokenRevocationOutcome(
      {required this.revokedLocally, this.remoteFailure});

  /// The local rows were marked revoked regardless of remote delivery.
  final bool revokedLocally;

  /// The sync-stage envelope for the revocation could not be queued
  /// (network/offline). The local revoke still stands.
  final String? remoteFailure;
}

/// Observes the live FCM token and re-registers it whenever the backend
/// rotates the value. Kept deliberately thin: registration is delegated to
/// the repository so the SQLite/outbox invariants stay the single source of
/// truth.
class FcmTokenRefreshHandler {
  FcmTokenRefreshHandler(this._auth, this._repository,
      {FirebaseMessaging? messaging,
      Stream<String>? tokenRefreshes,
      this.clock})
      : _messagingOverride = messaging,
        _tokenRefreshes = tokenRefreshes;
  final AuthContext _auth;
  final DeviceTokenRepository _repository;
  final FirebaseMessaging? _messagingOverride;

  /// Live Firebase Messaging instance. The override chain keeps tests away
  /// from the Firebase runtime; production always resolves the live instance
  /// at first use.
  FirebaseMessaging get _messaging =>
      _testMessaging ?? _messagingOverride ?? FirebaseMessaging.instance;
  final DateTime Function()? clock;
  final Stream<String>? _tokenRefreshes;
  StreamSubscription<String>? _subscription;

  /// Test-only hook: a null value restores the live Firebase instance.
  /// Production code never touches this.
  static FirebaseMessaging? _testMessaging;
  static void setTestMessaging(FirebaseMessaging? value) {
    _testMessaging = value;
  }
  static void resetTestMessaging() {
    _testMessaging = null;
  }
  String? _familyId;
  String? _deviceId;

  /// Binds refresh observation to an identity context. Multiple bindings are
  /// idempotent; the latest context wins for the next rotation.
  void bind({required String familyId, required String deviceId}) {
    _familyId = familyId;
    _deviceId = deviceId;
  }

  /// Begins observing token rotations. Safe when Firebase is unavailable:
  /// the subscription is never created and no failure is surfaced.
  void start() {
    if (_subscription != null) return;
    final source = _tokenRefreshes ?? _messaging.onTokenRefresh;
    _subscription = source.listen((token) {
      final familyId = _familyId;
      final deviceId = _deviceId;
      if (familyId == null || deviceId == null) return;
      final session = _auth.currentSession;
      if (!session.isAuthenticated) return;
      unawaited(_repository.upsert(
          familyId: familyId,
          deviceId: deviceId,
          identity: session.identity!,
          token: token,
          platform: 'android'));
    });
  }

  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

class FcmTokenService {
  FcmTokenService(this._auth, this._repository, {FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;
  final AuthContext _auth;
  final DeviceTokenRepository _repository;
  final FirebaseMessaging _messaging;
  Future<DeviceTokenRegistration?> register(
      {required String familyId,
      required String deviceId,
      required String platform}) async {
    final session = _auth.currentSession;
    if (!session.isAuthenticated) return null;
    final settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
    final token = await _messaging.getToken();
    if (token == null) return null;
    return _repository.upsert(
        familyId: familyId,
        deviceId: deviceId,
        identity: session.identity!,
        token: token,
        platform: platform);
  }

  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  /// Current OS permission state without prompting. Never alters the OS
  /// setting; the read is used for honest UX (permission-denied banner).
  Future<AuthorizationStatus> currentAuthorizationStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }
}

/// Local revocation of stored tokens. Never deletes history: rows keep their
/// audit evidence and gain a `revoked_at` marker plus the `revoked` status.
/// A sync-stage envelope is enqueued so the remote contract learns the token
/// should no longer be targeted once the device comes online.
class TokenRevocationService {
  TokenRevocationService(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final Uuid _uuid;

  Future<TokenRevocationOutcome> revokeForDevice(String deviceId) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    final nowStr = now.toIso8601String();
    final rows = await db.query('notification_tokens',
        where: 'device_id = ? AND revoked_at IS NULL', whereArgs: [deviceId]);
    if (rows.isEmpty) {
      return const TokenRevocationOutcome(revokedLocally: true);
    }
    String? remoteFailure;
    for (final row in rows) {
      await db.update(
          'notification_tokens', {'status': 'revoked', 'revoked_at': nowStr},
          where: 'id = ?', whereArgs: [row['id']]);
      try {
        await _enqueueRevocation(db, row, now);
      } catch (error) {
        remoteFailure = 'unexpected:${error.runtimeType}';
      }
    }
    return TokenRevocationOutcome(
        revokedLocally: true, remoteFailure: remoteFailure);
  }

  Future<void> _enqueueRevocation(
      Database db, Map<String, Object?> row, DateTime now) async {
    final id = _uuid.v4();
    final nowIso = now.toIso8601String();
    await db.insert('outbox', {
      'id': id,
      'aggregate_type': 'notificationToken',
      'aggregate_id': row['id'],
      'operation': 'notification.token.revoked',
      'payload_json': jsonEncode({
        'familyId': row['family_id'],
        'deviceId': row['device_id'],
        'userUid': row['user_uid'],
        'token': row['token'],
        'platform': row['platform'],
        'revokedAt': nowIso
      }),
      'idempotency_key': id,
      'state': SyncState.queued.storageKey,
      'attempt_count': 0,
      'next_attempt_at': nowIso,
      'created_at': nowIso
    });
  }
}
