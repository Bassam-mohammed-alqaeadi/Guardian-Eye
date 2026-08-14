import 'dart:async';

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
class GuardianApp extends ConsumerStatefulWidget {
  const GuardianApp({super.key});

  @override
  ConsumerState<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends ConsumerState<GuardianApp> {
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    // M9 Trigger A — app startup. Fire once after the first frame so sync
    // never blocks the first paint. Safe when logged out, Firebase
    // unavailable, outbox empty, or the database is not yet reachable: the
    // coordinator contains any failure into an honest state.
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerSync());
    // M9 Trigger A (auth-aware) — after authentication state is initialized,
    // a signed-in actor's queued operations sync right away; signing out
    // produces no authenticated session, so no stale-identity write can
    // happen (the executor reads the current session on every run).
    ref.listenManual(firebaseAuthSessionProvider, (previous, next) {
      if (next.valueOrNull?.isAuthenticated ?? false) _triggerSync();
    });
    // M9 Trigger B — connectivity restoration (offline → online). The
    // service emits only genuine transitions; concurrent triggers are
    // collapsed by the single-flight coordinator.
    _connectivitySub = ref
        .read(networkConnectivityServiceProvider)
        .onlineChanges
        .listen((online) {
      if (online) _triggerSync();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _triggerSync() {
    // Fire-and-forget: triggers never await the network, and the coordinator
    // serializes executions and contains errors.
    ref.read(syncCoordinatorProvider.notifier).executeNow();
  }

  @override
  Widget build(BuildContext context) {
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
