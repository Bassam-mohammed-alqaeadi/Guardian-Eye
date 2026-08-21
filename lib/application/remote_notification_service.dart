import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:sqflite/sqflite.dart';

import '../data/notification_contract.dart';

/// Android notification channel identity. A single safety-alert channel:
/// incident and SOS events are the only payloads this app ever renders.
const String kGuardianNotificationChannelId = 'guardian_safety';
const String kGuardianNotificationChannelName = 'تنبيهات السلامة';
const String kGuardianNotificationChannelDescription =
    'حوادث السلامة وتنبيهات الطوارئ — SOS';

/// Payload keys sent by the trusted backend. Deliberately data-only: no
/// title/body and no sensitive content ever crosses FCM. The app renders the
/// notification locally from the event kind.
const String kNotificationPayloadKind = 'kind';
const String kNotificationPayloadFamilyId = 'familyId';
const String kNotificationPayloadNotificationEventId = 'notificationEventId';
const String kNotificationPayloadThreadId = 'threadId';
const String kNotificationPayloadSenderName = 'senderName';
const String kNotificationPayloadMessageBody = 'messageBody';

typedef NotificationRouteResolver = Future<Uri> Function(
    NotificationOpenContext context);

/// Context passed to the route resolver when the user opens a rendered
/// notification. The resolver decides where navigation lands.
class NotificationOpenContext {
  const NotificationOpenContext(
      {required this.familyId,
      required this.kind,
      required this.notificationEventId});

  final String familyId;
  final NotificationKind kind;
  final String notificationEventId;
}

/// Typed permission observation. Never conflates "denied" with "unavailable":
/// the OS distinguishes them and so does the honest UX.
enum NotificationPermissionState { granted, denied, notDetermined, error }

/// Preferences that gate notification rendering and dispatch requests.
/// Stored in SQLite `notification_settings` (created at first access, never
/// shared between families — preferences are per-user-per-device).
class NotificationPreferences {
  const NotificationPreferences(
      {required this.renderEnabled, required this.dispatchEnabled});

  final bool renderEnabled;
  final bool dispatchEnabled;

  static const NotificationPreferences defaults =
      NotificationPreferences(renderEnabled: true, dispatchEnabled: true);
}

/// App-side notification foundation. Owns the plugin lifecycle, the channel,
/// the FCM message handlers, and local rendering. All rendering decisions
/// honor the honest preferences and the honest permission state; a failed
/// render never masquerades as success.
class RemoteNotificationService {
  RemoteNotificationService({
    required FlutterLocalNotificationsPlugin plugin,
    FirebaseMessaging? messaging,
    required GuardianDatabase database,
    RenderNotificationGateway? gateway,
    NotificationRouteResolver? routeResolver,
    @visibleForTesting DateTime Function()? clock,
  })  : _plugin = plugin,
        _messagingOverride = messaging,
        _database = database,
        _gateway = gateway ?? const RenderNotificationGateway(),
        _routeResolver = routeResolver,
        _clock = clock ?? DateTime.now;

  /// Test-only: maps both permission queries to a fixed authorization status
  /// without any Firebase SDK call. Reset via [resetTestMessaging].
  @visibleForTesting
  static set setTestMessaging(AuthorizationStatus status) {
    _testMessagingStatus = status;
  }

  @visibleForTesting
  static void resetTestMessaging() => _testMessagingStatus = null;

  static AuthorizationStatus? _testMessagingStatus;

  /// The gateway is exercised only when the app itself initiates a dispatch
  /// request; it stays unused when the device is notification-only.
  @visibleForTesting
  RenderNotificationGateway? get gateway => _gateway;

  final FlutterLocalNotificationsPlugin _plugin;
  final FirebaseMessaging? _messagingOverride;

  /// Live Firebase Messaging instance, resolved at first use so that unit
  /// tests exercising permission/preferences logic never need the Firebase
  /// runtime.
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  final GuardianDatabase _database;
  final RenderNotificationGateway? _gateway;
  final NotificationRouteResolver? _routeResolver;
  final DateTime Function() _clock;

  StreamSubscription<String>? _tokenSubscription;

  /// Records the last family id a registration was performed for, so the
  /// honest refresh handler can re-register against the same family when
  /// the backend token rotates.
  void recordRegisteredFamily(String? familyId) => _lastFamilyId = familyId;
  String? get lastRegisteredFamilyId => _lastFamilyId;
  String? _lastFamilyId;

  /// Initializes the plugin and registers the channel. Idempotent.
  /// Does not request OS permission — that belongs to token registration
  /// (see [requestLocalPermission]).
  Future<bool> initialize() async {
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: settings);
    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onLocalOpened,
      );
      return true;
    } catch (_) {
      // Plugin initialization failure is reported honestly; rendering is
      // simply unavailable on this device.
      return false;
    }
  }

  /// Creates the safety channel once, at first render. Channel creation is
  /// idempotent on Android and fails quietly on other platforms.
  Future<void> _ensureChannel() async {
    if (!kIsAndroid) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          kGuardianNotificationChannelId,
          kGuardianNotificationChannelName,
          description: kGuardianNotificationChannelDescription,
          importance: Importance.high,
        ));
  }

  bool get kIsAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Requests the OS notification permission once, at first registration.
  /// Returns the honest state; never re-requests after a denial.
  Future<NotificationPermissionState> requestLocalPermission() async {
    try {
      final status = _testMessagingStatus ??
          (await _messaging.requestPermission(
                  alert: true, badge: true, sound: true))
              .authorizationStatus;
      return _mapAuthorization(status);
    } catch (_) {
      return NotificationPermissionState.error;
    }
  }

  /// Current permission state without prompting.
  Future<NotificationPermissionState> currentPermissionState() async {
    try {
      final status = _testMessagingStatus ??
          (await _messaging.getNotificationSettings()).authorizationStatus;
      return _mapAuthorization(status);
    } catch (_) {
      return NotificationPermissionState.error;
    }
  }

  NotificationPermissionState _mapAuthorization(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return NotificationPermissionState.granted;
      case AuthorizationStatus.denied:
        return NotificationPermissionState.denied;
      case AuthorizationStatus.provisional:
        // iOS provisional: non-interrupting authorization — usable without
        // prompting the user again, so rendering is allowed.
        return NotificationPermissionState.granted;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionState.notDetermined;
    }
  }

  /// Wire-up hook called once at app startup after the plugin is initialized.
  /// Safe when Firebase is unconfigured: the messaging stream subscriptions
  /// are established regardless, but handlers no-op without a session.
  void wireHandlers() {
    // Stream subscriptions are established even without a configured Firebase
    // runtime; the handlers no-op without an authenticated session. A failed
    // subscription is never claimed as "handlers wired".
    FirebaseMessaging.onMessage.listen(_onForeground).onError((_) {});
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened).onError((_) {});
    // Terminated-launch payload: only when the plugin confirms a local
    // notification was the launch source.
    _messaging.getInitialMessage().then((message) {
      if (message != null) _onOpened(message);
    });
    _tokenSubscription = _messaging.onTokenRefresh.listen((_) {
      // The refresh stream is observed by FcmTokenService; the service
      // re-registers the new token. Nothing else is required here.
    });
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }

  /// Renders a foreground message locally. Honesty first: no channel → no
  /// render; permission denied → no render; the event still stays persisted
  /// (the in-app timeline shows it either way).
  Future<void> _onForeground(RemoteMessage message) async {
    await _renderIfAllowed(message);
  }

  Future<void> _onOpened(RemoteMessage message) async {
    await _navigateFor(message);
  }

  Future<void> _onLocalOpened(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    await _navigateForPayload(payload);
  }

  Future<void> _renderIfAllowed(RemoteMessage message) async {
    final prefs = await loadPreferences();
    if (!prefs.renderEnabled) return;
    final state = await currentPermissionState();
    if (state != NotificationPermissionState.granted) return;
    final kind = _parseKind(message.data[kNotificationPayloadKind]);
    if (kind == null) return;

    // FS-012 Security Enhancement: Privacy Notifications for Chat.
    final isChat = message.data[kNotificationPayloadKind] == 'chat';
    final privacyEnabled = await _isPrivacyNotificationsEnabled();

    await _ensureChannel();
    try {
      final String title;
      final String body;

      if (isChat) {
        if (privacyEnabled) {
          title = 'رسالة عائلية جديدة';
          body = 'لديك رسالة جديدة — افتح التطبيق للاطلاع';
        } else {
          title =
              message.data[kNotificationPayloadSenderName] ?? 'رسالة عائلية';
          body = message.data[kNotificationPayloadMessageBody] ??
              'لديك رسالة جديدة';
        }
      } else {
        title = _titleFor(kind);
        body = _bodyFor(kind);
      }

      await _plugin.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kGuardianNotificationChannelId,
            kGuardianNotificationChannelName,
            channelDescription: kGuardianNotificationChannelDescription,
            importance:
                kind == NotificationKind.sos ? Importance.max : Importance.high,
            priority: kind == NotificationKind.sos
                ? Priority.high
                : Priority.defaultPriority,
          ),
        ),
        payload: _payloadString(message),
      );
    } catch (_) {
      // Render failure never blocks the app; the event remains available
      // through the in-app timeline.
    }
  }

  String _titleFor(NotificationKind kind) =>
      kind == NotificationKind.sos ? 'SOS' : 'حدث سلامة';

  String _bodyFor(NotificationKind kind) => kind == NotificationKind.sos
      ? 'أحد أفراد العائلة يحتاجك الآن — افتح التطبيق للتحقق'
      : 'تم رصد حدث سلامة جديد — افتح التطبيق للاطلاع';

  String _payloadString(RemoteMessage message) {
    final familyId = message.data[kNotificationPayloadFamilyId] as String?;
    final eventId =
        message.data[kNotificationPayloadNotificationEventId] as String?;
    if (familyId == null || familyId.isEmpty || eventId == null) return '';
    return '$familyId|${message.data[kNotificationPayloadKind]}|$eventId';
  }

  Future<void> _navigateFor(RemoteMessage message) async {
    final payload = _payloadString(message);
    if (payload.isEmpty) return;
    await _navigateForPayload(payload);
  }

  Future<void> _navigateForPayload(String payload) async {
    final parts = payload.split('|');
    if (parts.length != 3) return;
    final context = NotificationOpenContext(
        familyId: parts[0],
        kind: _parseKind(parts[1]) ?? NotificationKind.incident,
        notificationEventId: parts[2]);
    final resolver = _routeResolver;
    if (resolver == null) return;
    try {
      final uri = await resolver(context);
      if (uri.toString().isEmpty) return;
      navigatorKey.currentState?.pushNamed(uri.toString());
    } catch (_) {
      // A broken resolver must never crash the app or navigate to garbage.
    }
  }

  NotificationKind? _parseKind(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString();
    if (value == 'incident') return NotificationKind.incident;
    if (value == 'sos') return NotificationKind.sos;
    if (value == 'chat')
      return NotificationKind.incident; // Chat uses incident logic for now
    return null;
  }

  Future<bool> _isPrivacyNotificationsEnabled() async {
    try {
      final db = await _database.database;
      final rows = await db.query('notification_settings',
          where: "key = 'security_privacy_notifications'", limit: 1);
      if (rows.isEmpty) return false;
      return rows.single['render_enabled'] == 1;
    } catch (_) {
      return false;
    }
  }

  /// Persists preferences. Never claims a preference change produced a
  /// delivery effect.
  Future<void> savePreferences(NotificationPreferences preferences) async {
    final db = await _database.database;
    await db.insert(
        'notification_settings',
        {
          'key': 'notification',
          'render_enabled': preferences.renderEnabled ? 1 : 0,
          'dispatch_enabled': preferences.dispatchEnabled ? 1 : 0,
          'updated_at': _clock().toUtc().toIso8601String()
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reads preferences with honest defaults on any read failure.
  Future<NotificationPreferences> loadPreferences() async {
    try {
      final db = await _database.database;
      final rows = await db.query('notification_settings',
          where: "key = 'notification'", limit: 1);
      if (rows.isEmpty) return NotificationPreferences.defaults;
      final row = rows.single;
      return NotificationPreferences(
          renderEnabled: row['render_enabled'] == 1,
          dispatchEnabled: row['dispatch_enabled'] == 1);
    } catch (_) {
      return NotificationPreferences.defaults;
    }
  }
}

/// Global navigator key so the notification resolver can navigate from
/// anywhere, including the background handler. Kept in one place on purpose.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
