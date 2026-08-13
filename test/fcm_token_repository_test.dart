import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/fcm_token_repository.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'test_database.dart';

void main() {
  test(
      'token registration is persisted locally and queued without claiming FCM delivery',
      () async {
    final database = await openTestDatabase();
    await (await database.database).insert('families', {
      'id': 'family-a',
      'name': 'Family',
      'created_at': DateTime.now().toUtc().toIso8601String()
    });
    const identity = AuthenticatedIdentity(
        uid: 'parent-auth', email: 'parent@example.test', isAnonymous: false);
    final registration = await DeviceTokenRepository(database).upsert(
        familyId: 'family-a',
        deviceId: 'device-a',
        identity: identity,
        token: 'fcm-token',
        platform: 'android');
    final db = await database.database;
    expect((await db.query('notification_tokens')).single['status'], 'queued');
    expect((await db.query('outbox')).single['operation'],
        'notification.token.registered');
    expect(registration.userUid, identity.uid);
    await database.close();
  });
}
