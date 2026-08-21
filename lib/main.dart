import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'application/sync_coordinator.dart';
import 'core/database/guardian_database.dart';
import 'core/firebase/guardian_firebase_bootstrap.dart';
import 'data/outbox_sync_executor.dart';
import 'data/sync_services.dart';
import 'data/firebase_auth_context.dart';
import 'presentation/guardian_app.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Background sync worker: honest single-flight execution over the
    // same outbox used by the foreground.
    try {
      await GuardianDatabase.instance.initialize();
      final executor = OutboxSyncExecutor(
        GuardianDatabase.instance,
        const FirebaseAuthContext(),
        FirestoreOutboxRemoteWriter(null), // Null firestore resolved by bootstrap
      );
      final core = SyncCoordinatorCore(executor);
      await core.executeNow();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GuardianDatabase.instance.initialize();
  await GuardianFirebaseBootstrap.initialize();

  // Initialize background sync worker (M9)
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'guardian_sync_periodic',
    'syncTask',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );

  runApp(const ProviderScope(child: GuardianApp()));
}
