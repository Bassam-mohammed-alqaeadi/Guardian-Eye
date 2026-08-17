import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../screens/dashboard_screen.dart';
import '../screens/family_members_screen.dart';
import '../screens/safety_policies_screen.dart';
import '../screens/child_device_status_screen.dart';
import '../screens/child_context_screen.dart';
import '../screens/screen_time_policies_screen.dart';
import '../screens/family_safety_experience_screens.dart';
import '../screens/settings_screen.dart';
import '../screens/pairing_screen.dart';
import '../screens/child_redemption_screen.dart';
import '../screens/permissions_screen.dart';
import '../screens/firebase_session_screen.dart';
import '../widgets/guardian_bottom_nav.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../application/family_context_provider.dart';

/// One source of navigation truth for Guardian Eye Pro.
///
/// The family user thinks in product terms — Home, Family, Safety,
/// Timeline, Settings — not in module names. All routes target live
/// screens only; authorization stays delegated to
/// `FamilyRuntimeContext` → `FamilyAuthorization`, never to local
/// role checks inside the router.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      // The platform shell: five-tab navigation around the family
      // routes. The home route (family setup / dashboard) lives inside
      // the shell so the bottom nav is present from first launch.
      ShellRoute(
        builder: (context, state, child) {
          // Family id is optional at the shell level — before family
          // creation the dependent tabs disable honestly.
          final familyId = _familyIdOf(state, ref);
          return GuardianBottomNav(familyId: familyId, child: child);
        },
        routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/child/:familyId/:childId',
        name: 'childContext',
        builder: (context, state) => ChildContextScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/child/:familyId/:childId/policies',
        name: 'childPolicies',
        builder: (context, state) => ScreenTimePoliciesScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/family/:familyId',
        name: 'family',
        builder: (context, state) => FamilyMembersScreen(
            familyId: state.pathParameters['familyId']!,
            actorMemberId: state.extra as String?),
      ),
      GoRoute(
        path: '/safety/policies/:familyId',
        name: 'safetyPolicies',
        builder: (context, state) =>
            SafetyPoliciesScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/device-status/:familyId',
        name: 'safetyDeviceStatus',
        builder: (context, state) =>
            ChildDeviceStatusScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/daily/:familyId',
        name: 'safetyDaily',
        builder: (context, state) =>
            FamilyDailySafetyScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/timeline/:familyId',
        name: 'timeline',
        builder: (context, state) =>
            FamilySafetyTimelineScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/requests/:familyId',
        name: 'childRequests',
        builder: (context, state) =>
            ParentExceptionRequestsScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/firebase-session',
        name: 'firebaseSession',
        builder: (context, state) => const FirebaseSessionScreen(),
      ),
      GoRoute(
        path: '/safety/pairing/:familyId',
        name: 'safetyPairing',
        builder: (context, state) =>
            PairingScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/device-link/:familyId',
        name: 'deviceLink',
        builder: (context, state) =>
            ChildRedemptionScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/permissions',
        name: 'safetyPermissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      ],),
    ],
    errorBuilder: (context, state) => _RouterNotFoundPage(uri: state.uri),
  );
});

/// Best-effort family id resolution for the shell: deep states carry
/// the family id in their path; the root route resolves it from the
/// dashboard payload (the same single source the home screen uses).
/// When nothing resolves, the shell renders honestly disabled tabs.
String? _familyIdOf(GoRouterState state, Ref ref) {
  final fromPath = state.pathParameters['familyId'];
  if (fromPath != null) return fromPath;
  return ref.read(dashboardProvider).valueOrNull?.family?.id;
}

/// Honest, calm not-found surface. The user is told where they are
/// and offered a safe way home — predictable back behavior without
/// exposing technical routing details.
class _RouterNotFoundPage extends StatelessWidget {
  const _RouterNotFoundPage({required this.uri});
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.t('pageNotFound'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_outlined, size: 40),
                const SizedBox(height: 12),
                Text(l10n.t('pageNotFoundBody'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: Text(l10n.t('goHome')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
