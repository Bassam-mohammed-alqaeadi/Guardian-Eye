import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/database/guardian_database.dart';
import '../data/fcm_token_repository.dart';
import '../data/notification_contract.dart';
import 'guardian_providers.dart';
import 'remote_notification_service.dart';

/// The shared plugin instance. One process, one plugin; providers compose
/// it rather than recreating it per widget.
final notificationPluginProvider = Provider<FlutterLocalNotificationsPlugin>(
    (ref) => FlutterLocalNotificationsPlugin());

/// Messaging instance is provided separately so tests can swap it out.
final notificationMessagingProvider =
    Provider((ref) => throw UnimplementedError('messaging not overridden'));

/// The trusted-backend gateway used for dispatch requests.
final notificationGatewayProvider = Provider<RenderNotificationGateway>(
    (ref) => const RenderNotificationGateway());

/// The app-side notification service: plugin lifecycle, handlers, local
/// rendering, preferences.
final remoteNotificationServiceProvider = Provider<RemoteNotificationService>(
    (ref) => RemoteNotificationService(
        plugin: ref.watch(notificationPluginProvider),
        messaging: ref.watch(notificationMessagingProvider),
        database: GuardianDatabase.instance,
        gateway: ref.watch(notificationGatewayProvider)));

/// Device token repository (SQLite + outbox envelope).
final fcmTokenRepositoryProvider =
    Provider((ref) => DeviceTokenRepository(GuardianDatabase.instance));

/// Registration service (permission request + first token registration).
final fcmTokenServiceProvider = Provider((ref) => FcmTokenService(
    ref.watch(firebaseAuthContextProvider),
    ref.watch(fcmTokenRepositoryProvider)));

/// Refresh handler (re-registers on backend token rotation).
final fcmRefreshHandlerProvider = Provider((ref) => FcmTokenRefreshHandler(
    ref.watch(firebaseAuthContextProvider),
    ref.watch(fcmTokenRepositoryProvider)));

/// Revocation service (logout / app-level opt-out).
final tokenRevocationServiceProvider =
    Provider((ref) => TokenRevocationService(GuardianDatabase.instance));

/// Device-identity service: one stable UUID persisted in `app_identity`.
/// Generated lazily on first registration; never re-generated unless the
/// local row is gone (app reinstall), which is the honest behavior for a
/// per-install FCM identity.
final appDeviceIdentityProvider = Provider<AppDeviceIdentityService>(
    (ref) => AppDeviceIdentityService(GuardianDatabase.instance));

/// Loads-or-creates the stable device identifier used by FCM registration.
/// Safe under any DB state: a read failure surfaces as a future error the
/// caller must handle honestly (no silent fake id).
class AppDeviceIdentityService {
  AppDeviceIdentityService(this._database, {Uuid? uuid, this.clock})
      : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final Uuid _uuid;
  final DateTime Function()? clock;
  static const String _deviceKey = 'device_id';

  Future<String> deviceId() async {
    final db = await _database.database;
    final rows =
        await db.query('app_identity', where: "key = '$_deviceKey'", limit: 1);
    if (rows.isNotEmpty) {
      final value = rows.single['value'] as String?;
      if (value != null && value.isNotEmpty) return value;
    }
    final id = _uuid.v4();
    await db.insert('app_identity', {
      'key': _deviceKey,
      'value': id,
      'created_at': (clock ?? DateTime.now)().toUtc().toIso8601String()
    });
    return id;
  }
}
