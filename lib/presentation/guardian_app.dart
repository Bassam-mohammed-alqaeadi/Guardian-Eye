import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/guardian_providers.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

/// Guardian Eye Pro application shell.
///
/// ONE visual language: the canonical `AppTheme` design system
/// (Cairo + Material3) — no inline `ThemeData` in the shell.
///
/// ONE navigation truth: `GoRouter` via [appRouterProvider]. All live
/// screens are reached through canonical routes; settings, language
/// and session controls live on the Settings surface, never in the
/// family-home app bar.
class GuardianApp extends ConsumerWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Locale(ref.watch(localeProvider));
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Guardian Eye Pro',
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
