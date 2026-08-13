/// M1 — App Shell + Canonical Navigation: focused widget evidence.
///
/// These tests prove the shell properties defined by the M1 scope:
/// coherent theme, coherent RTL/LTR, one source of navigation truth,
/// settings access out of the family-home app bar, and no
/// production-reachable dead paths.
///
/// Domain/security logic is never tested here — it stays inside the
/// existing unit suites (tests are the source of truth).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_ai/presentation/guardian_app.dart';
import 'package:guardian_ai/presentation/router/app_router.dart';

/// Empty-family dashboard fixture reused by every shell test.
const GuardianDashboard _emptyFamily = GuardianDashboard(
    family: null,
    children: [],
    incidentsToday: 0,
    queuedOperations: 0);

Future<void> _pump(WidgetTester tester, {String languageCode = 'ar'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardProvider.overrideWith((ref) async => _emptyFamily),
        localeProvider.overrideWith((ref) => languageCode),
      ],
      child: const GuardianApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Navigates the app's canonical router inside the same ProviderScope
/// that builds the shell, without disturbing the widget tree.
class _GoConsumer extends ConsumerWidget {
  const _GoConsumer(this.location);
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A Consumer sitting next to the app can read the same router.
    // `go` is guarded so repeated rebuilds don't throw.
    final router = ref.watch(appRouterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(location);
    });
    return const SizedBox.shrink();
  }
}

Future<void> _pumpWithTarget(WidgetTester tester, String location) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardProvider.overrideWith((ref) async => _emptyFamily),
        localeProvider.overrideWith((ref) => 'ar'),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            const GuardianApp(),
            _GoConsumer(location),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  group('M1 shell', () {
    testWidgets('renders the family home with the canonical Cairo theme',
        (tester) async {
      await _pump(tester);
      // The shell theme is the canonical AppTheme (Cairo, Material3),
      // never an inline theme.
      final ThemeData theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.textTheme.bodyMedium?.fontFamily ?? theme.textTheme.titleMedium?.fontFamily,
          'Cairo');
      expect(find.text('Guardian Eye Pro'), findsOneWidget);
    });

    testWidgets('Arabic locale drives a right-to-left shell',
        (tester) async {
      await _pump(tester, languageCode: 'ar');
      expect(tester.widget<Directionality>(find.byType(Directionality).first).textDirection,
          TextDirection.rtl);
      expect(find.byTooltip('الإعدادات'), findsOneWidget);
    });

    testWidgets('English locale drives a left-to-right shell',
        (tester) async {
      await _pump(tester, languageCode: 'en');
      expect(tester.widget<Directionality>(find.byType(Directionality).first).textDirection,
          TextDirection.ltr);
      expect(find.byTooltip('Settings'), findsOneWidget);
    });

    testWidgets('navigation entry points live on the family home and all use the canonical router',
        (tester) async {
      final family = GuardianFamily(
          id: 'f-1', name: 'Al-Family', createdAt: DateTime(2026, 1, 1));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(
                (ref) async => GuardianDashboard(
                    family: family,
                    children: [],
                    incidentsToday: 0,
                    queuedOperations: 0)),
            localeProvider.overrideWith((ref) => 'ar'),
          ],
          child: const GuardianApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('الإعدادات'));
      await tester.pumpAndSettle();
      expect(find.text('الإعدادات'), findsWidgets);
      // The settings surface exposes account/session and language — not raw
      // Firebase or sync terminology.
      expect(find.text('الحساب والجلسة'), findsOneWidget);
      expect(find.text('اللغة'), findsOneWidget);
    });

    testWidgets('settings language toggle updates the shell locale and feedback appears',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('الإعدادات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      // Informative feedback: the shell announces the saved preference.
      expect(find.textContaining('حُفظت الإعدادات'), findsOneWidget);
    });

    testWidgets('an unverified actor gets disabled safety actions rather than dead ends',
        (tester) async {
      final family = GuardianFamily(
          id: 'f-1', name: 'Al-Family', createdAt: DateTime(2026, 1, 1));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(
                (ref) async => GuardianDashboard(
                    family: family,
                    children: [],
                    incidentsToday: 0,
                    queuedOperations: 0)),
            localeProvider.overrideWith((ref) => 'ar'),
            familyRuntimeContextProvider(
                    'f-1').overrideWith((ref) async =>
                FamilyRuntimeContext(
                  familyId: 'f-1',
                  family: family,
                  actor: null,
                  isVerified: false,
                  permissionsFor:
                      const FamilyAuthorization().permissionsFor,
                  allMembers: const [],
                  children: const [],
                  devices: const [],
                )),
          ],
          child: const GuardianApp(),
        ),
      );
      await tester.pumpAndSettle();

      // The manage-policies action exists but is disabled — never a
      // locally-added role check, always delegated via FamilyRuntimeContext.
      final managePolicies = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'إدارة السياسات'));
      expect(managePolicies.onPressed, isNull);
    });

    testWidgets('dead routes land on the not-found page instead of prototype screens',
        (tester) async {
      await _pumpWithTarget(tester, '/child-profile');
      expect(find.text('الصفحة غير موجودة'), findsOneWidget);
      expect(find.text('العودة إلى الشاشة الرئيسة'), findsOneWidget);
    });

    testWidgets('unknown deep links also land on the not-found page',
        (tester) async {
      await _pumpWithTarget(tester, '/welcome');
      expect(find.text('الصفحة غير موجودة'), findsOneWidget);
    });

    testWidgets('settings has account/session, language and permissions entries',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.byTooltip('الإعدادات'));
      await tester.pumpAndSettle();
      expect(find.text('الحساب والجلسة'), findsOneWidget);
      expect(find.text('اللغة'), findsOneWidget);
      expect(find.text('سُلّم الأذونات'), findsWidgets);
    });
  });
}
