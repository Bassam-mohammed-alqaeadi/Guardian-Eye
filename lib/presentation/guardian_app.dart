import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/guardian_providers.dart';
import '../core/localization/app_localizations.dart';
import 'screens/dashboard_screen.dart';

class GuardianApp extends ConsumerWidget {
  const GuardianApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
      title: 'Guardian Eye Pro',
      debugShowCheckedModeBanner: false,
      locale: Locale(ref.watch(localeProvider)),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF173B7A)),
          scaffoldBackgroundColor: const Color(0xFFF6F8FC)),
      home: const DashboardScreen());
}
