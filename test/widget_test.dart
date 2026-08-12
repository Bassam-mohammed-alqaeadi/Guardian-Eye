import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/presentation/guardian_app.dart';

void main() {
  testWidgets(
      'Guardian Eye Pro opens an empty family setup rather than sample data',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) async => const GuardianDashboard(
              family: null,
              children: [],
              incidentsToday: 0,
              queuedOperations: 0)),
        ],
        child: const GuardianApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardian Eye Pro'), findsOneWidget);
    expect(find.text('إنشاء عائلة'), findsOneWidget);
  });
  testWidgets(
      'Firebase account entry states that sync is unavailable when unconfigured',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) async => const GuardianDashboard(
              family: null,
              children: [],
              incidentsToday: 0,
              queuedOperations: 0)),
        ],
        child: const GuardianApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Firebase'));
    await tester.pumpAndSettle();
    expect(find.text('Firebase غير مهيأ'), findsOneWidget);
    expect(find.textContaining('يبقى التطبيق محليًا'), findsOneWidget);
  });
}
