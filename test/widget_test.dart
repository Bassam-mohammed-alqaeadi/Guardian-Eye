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
    // The shell no longer exposes a raw "Firebase" icon in the app bar;
    // account/session entry now lives on the settings surface.
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('الحساب والجلسة'), findsOneWidget);
    // The account/session card (showing "Not signed in") is the entry
    // point to the Firebase session screen.
    await tester.tap(find.text('غير مسجّل الدخول'));
    await tester.pumpAndSettle();
    expect(find.text('Firebase غير مهيأ'), findsOneWidget);
    expect(find.textContaining('يبقى التطبيق محليًا'), findsOneWidget);
  });
}
