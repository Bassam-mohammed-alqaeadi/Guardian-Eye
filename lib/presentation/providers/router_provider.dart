import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:guardian_ai/presentation/screens/welcome_screen.dart';
import 'package:guardian_ai/presentation/screens/parent_dashboard_screen.dart';
import 'package:guardian_ai/presentation/screens/child_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: '/child-profile',
        name: 'child_profile',
        builder: (context, state) => const ChildProfileScreen(),
      ),
    ],
  );
});
