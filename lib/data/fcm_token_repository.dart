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
}
