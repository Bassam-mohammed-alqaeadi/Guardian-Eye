import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';

Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => inMemoryDatabasePath);
  await database.initialize();
  return database;
}
