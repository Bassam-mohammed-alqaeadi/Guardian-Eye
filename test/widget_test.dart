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
              member: null,
              children: [],
              incidentsToday: 0,
              queuedOperations: 0)),
        ],
        child: const GuardianApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardian Eye Pro'), findsOneWidget);
    // FS-014: Dashboard now renders FamilySetupEntryScreen when family is null.
    // We look for the main prompt "ابدأ بإعداد عائلتك. لا تُنشأ أي بيانات تجريبية." (noFamily l10n key).
    expect(find.text('ابدأ بإعداد عائلتك. لا تُنشأ أي بيانات تجريبية.'),
        findsOneWidget);
    // And the two path cards.
    expect(find.text('إنشاء عائلة جديدة'), findsOneWidget);
    expect(find.text('الانضمام إلى عائلة موجودة'), findsOneWidget);
  });
  testWidgets(
      'Firebase account entry states that sync is unavailable when unconfigured',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) async => const GuardianDashboard(
              family: null,
              member: null,
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

  // TODO(fs012): Re-enable child dashboard widget test once async sliver layout is stable in headless tester
  // testWidgets('Child actor lands on Child Dashboard', (tester) async { ... });
}
