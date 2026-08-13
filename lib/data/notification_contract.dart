import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationDispatchResult {
  const NotificationDispatchResult(
      {required this.accepted, required this.reason});
  final bool accepted;
  final String reason;
}

abstract class ParentNotificationGateway {
  Future<NotificationDispatchResult> requestServerDispatch(
      {required String notificationEventId});
}

class GuardedFcmNotificationGateway implements ParentNotificationGateway {
  const GuardedFcmNotificationGateway();
  @override
  Future<NotificationDispatchResult> requestServerDispatch(
      {required String notificationEventId}) async {
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
