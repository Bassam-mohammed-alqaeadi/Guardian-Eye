import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/guardian_database.dart';
import 'core/firebase/guardian_firebase_bootstrap.dart';
import 'presentation/guardian_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GuardianDatabase.instance.initialize();
  await GuardianFirebaseBootstrap.initialize();
  runApp(const ProviderScope(child: GuardianApp()));
}
