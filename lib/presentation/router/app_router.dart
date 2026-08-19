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
import '../screens/safety_actions_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pairing_screen.dart';
import '../screens/child_redemption_screen.dart';
import '../screens/permissions_screen.dart';
import '../screens/firebase_session_screen.dart';
import '../screens/web_filter_screens.dart';
import '../screens/web_filter_management_screens.dart';
import '../screens/web_filter_child_screens.dart';
import '../screens/location_screens.dart';
import '../screens/location_child_screens.dart';
import '../screens/application_screens.dart';
import '../screens/monitoring_screens.dart';
import '../screens/modes_screens.dart';
import '../screens/sos_screens.dart';
import '../screens/device_linking_screens.dart';
import '../screens/reports_screens.dart';
import '../widgets/guardian_bottom_nav.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';

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
        path: '/child/:familyId/:childId/device',
        name: 'childDeviceExperience',
        builder: (context, state) => ChildPolicyExperienceScreen(
            familyId: state.pathParameters['familyId']!,
            deviceId: state.pathParameters['childId']!,
            childUid: state.pathParameters['childId']!),
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
        path: '/safety/actions/:familyId',
        name: 'safetyActions',
        builder: (context, state) =>
            SafetyActionsScreen(familyId: state.pathParameters['familyId']!),
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
      // FS-002 Web Filtering subsystem routes (WF-001 … WF-010).
      GoRoute(
        path: '/safety/web/:familyId',
        name: 'webFiltering',
        builder: (context, state) =>
            WebFilterDashboardScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/categories',
        name: 'webCategories',
        builder: (context, state) =>
            WebFilterCategoriesScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/blocklist',
        name: 'webBlocklist',
        builder: (context, state) =>
            WebBlocklistScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/settings',
        name: 'webSettings',
        builder: (context, state) =>
            WebSettingsScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/history',
        name: 'webHistory',
        builder: (context, state) =>
            WebBlockHistoryScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/history/:hitId',
        name: 'webHitDetail',
        builder: (context, state) => WebBlockHitDetailScreen(
            familyId: state.pathParameters['familyId']!,
            hitId: state.pathParameters['hitId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/history/:hitId/allow',
        name: 'webTemporaryAllow',
        builder: (context, state) => WebTemporaryAllowScreen(
            familyId: state.pathParameters['familyId']!,
            hitId: state.pathParameters['hitId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/allowlist',
        name: 'webAllowlist',
        builder: (context, state) =>
            WebAllowlistScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/safety/web/:familyId/:childId',
        name: 'perChildWebPolicy',
        builder: (context, state) => PerChildWebPolicyScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/blocked/:familyId/:childId',
        name: 'blockedPage',
        builder: (context, state) => BlockedPageScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      // FS-001 Location & Geofencing subsystem routes (LO-001 … LO-015).
      GoRoute(
        path: '/location/:familyId',
        name: 'familyMap',
        builder: (context, state) =>
            FamilyMapScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/:memberId',
        name: 'memberLocationDetails',
        builder: (context, state) => MemberLocationDetailsScreen(
            familyId: state.pathParameters['familyId']!,
            memberId: state.pathParameters['memberId']!),
      ),
      GoRoute(
        path: '/location/:familyId/:memberId/history',
        name: 'locationHistory',
        builder: (context, state) => LocationHistoryScreen(
            familyId: state.pathParameters['familyId']!,
            memberId: state.pathParameters['memberId']!),
      ),
      GoRoute(
        path: '/location/:familyId/geofences',
        name: 'geofenceList',
        builder: (context, state) =>
            GeofenceListScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/geofences/new',
        name: 'createGeofence',
        builder: (context, state) =>
            CreateGeofenceScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/geofences/:geofenceId/edit',
        name: 'editGeofence',
        builder: (context, state) => EditGeofenceScreen(
            familyId: state.pathParameters['familyId']!,
            geofenceId: state.pathParameters['geofenceId']!),
      ),
      GoRoute(
        path: '/location/:familyId/settings',
        name: 'locationSettings',
        builder: (context, state) =>
            LocationSettingsScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/onboard/location',
        name: 'permissionOnboarding',
        builder: (context, state) =>
            PermissionOnboardingScreen(familyId: ''),
      ),
      GoRoute(
        path: '/location/:familyId/permissions',
        name: 'permissionOnboardingFamily',
        builder: (context, state) => PermissionOnboardingScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/sharing',
        name: 'sharingStatus',
        builder: (context, state) =>
            SharingStatusScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/alerts',
        name: 'locationAlerts',
        builder: (context, state) =>
            LocationAlertsScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/privacy',
        name: 'locationPrivacy',
        builder: (context, state) =>
            LocationPrivacyScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/location/:familyId/places',
        name: 'favoritePlaces',
        builder: (context, state) =>
            FavoritePlacesScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/child/:familyId/:childId/location-sharing',
        name: 'childLocationSharing',
        builder: (context, state) => ChildLocationSharingScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      // FS-003 Application Control subsystem routes (AC-001 … AC-008).
      GoRoute(
        path: '/apps/:familyId',
        name: 'appControlDashboard',
        builder: (context, state) =>
            AppControlDashboardScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/apps/:familyId/apps-list',
        name: 'installedAppsList',
        builder: (context, state) =>
            InstalledAppsListScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/apps/:familyId/details/:appId',
        name: 'appDetail',
        builder: (context, state) => AppDetailScreen(
            familyId: state.pathParameters['familyId']!,
            appTarget: state.pathParameters['appId']!),
      ),
      GoRoute(
        path: '/apps/:familyId/allowlist',
        name: 'appAllowlist',
        builder: (context, state) =>
            AppAllowlistScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/apps/:familyId/:childId/rules',
        name: 'perChildAppRules',
        builder: (context, state) => PerChildAppRulesScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/apps/:familyId/alerts',
        name: 'usageAlerts',
        builder: (context, state) =>
            UsageAlertsScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/apps/:familyId/history',
        name: 'appBlockHistory',
        builder: (context, state) =>
            AppBlockHistoryScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/child/:familyId/:childId/apps',
        name: 'childAppUsage',
        builder: (context, state) => ChildAppUsageScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      // FS-004 Screen & Camera Monitoring subsystem routes (SC-001 … SC-009).
      GoRoute(
        path: '/monitoring/:familyId',
        name: 'monitoringDashboard',
        builder: (context, state) => MonitoringDashboardScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/screenshots',
        name: 'monitoringScreenshotsTimeline',
        builder: (context, state) => MonitoringScreenshotsTimelineScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/screenshots/:shotId',
        name: 'monitoringShotViewer',
        builder: (context, state) => MonitoringShotViewerScreen(
            familyId: state.pathParameters['familyId']!,
            shotId: state.pathParameters['shotId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/live',
        name: 'monitoringLiveSession',
        builder: (context, state) => MonitoringLiveSessionScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/camera',
        name: 'monitoringCameraControl',
        builder: (context, state) => MonitoringCameraControlScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/:childId/session',
        name: 'monitoringChildSession',
        builder: (context, state) => MonitoringChildSessionScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/requests',
        name: 'monitoringRequestsHistory',
        builder: (context, state) => MonitoringRequestsHistoryScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/schedule',
        name: 'monitoringSchedules',
        builder: (context, state) => MonitoringSchedulesScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/monitoring/:familyId/evidence',
        name: 'monitoringEvidenceQueue',
        builder: (context, state) => MonitoringEvidenceQueueScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      // FS-005 Special & Custom Modes subsystem routes (MD-001 … MD-010).
      GoRoute(
        path: '/modes/:familyId',
        name: 'modesDashboard',
        builder: (context, state) =>
            ModesDashboardScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/:modeId',
        name: 'modeDetail',
        builder: (context, state) => ModeDetailScreen(
            familyId: state.pathParameters['familyId']!,
            modeId: state.pathParameters['modeId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/new',
        name: 'modeCreate',
        builder: (context, state) =>
            ModeCreateScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/:modeId/edit',
        name: 'modeEdit',
        builder: (context, state) => ModeEditScreen(
            familyId: state.pathParameters['familyId']!,
            modeId: state.pathParameters['modeId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/:modeId/schedule',
        name: 'modeSchedule',
        builder: (context, state) => ModeScheduleScreen(
            familyId: state.pathParameters['familyId']!,
            modeId: state.pathParameters['modeId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/:modeId/children',
        name: 'modeChildren',
        builder: (context, state) => ModeChildrenScreen(
            familyId: state.pathParameters['familyId']!,
            modeId: state.pathParameters['modeId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/:modeId/history',
        name: 'modeActivationHistory',
        builder: (context, state) => ModeActivationHistoryScreen(
            familyId: state.pathParameters['familyId']!,
            modeId: state.pathParameters['modeId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/conflict',
        name: 'modeConflict',
        builder: (context, state) =>
            ModeConflictScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/modes/:familyId/templates',
        name: 'modeTemplates',
        builder: (context, state) =>
            ModeTemplatesScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/child/:familyId/:childId/mode',
        name: 'childActiveMode',
        builder: (context, state) => ChildActiveModeScreen(
            familyId: state.pathParameters['familyId']!,
            childId: state.pathParameters['childId']!),
      ),
      // FS-006 SOS & Emergency subsystem routes (SO-001 … SO-008).
      GoRoute(
        path: '/sos/:familyId',
        name: 'sosDashboard',
        builder: (context, state) =>
            SosDashboardScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/activate',
        name: 'sosActivate',
        builder: (context, state) =>
            SosActivationScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/active',
        name: 'sosActive',
        builder: (context, state) =>
            ActiveSosScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/location',
        name: 'sosEmergencyLocation',
        builder: (context, state) => EmergencyLocationScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/alert/:alertId',
        name: 'sosEmergencyAlert',
        builder: (context, state) => EmergencyAlertScreen(
            familyId: state.pathParameters['familyId']!,
            alertId: state.pathParameters['alertId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/ack',
        name: 'sosAckHistory',
        builder: (context, state) =>
            SosAckHistoryScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/recipients',
        name: 'sosRecipients',
        builder: (context, state) => SosRecipientsScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/sos/:familyId/drill',
        name: 'sosDrill',
        builder: (context, state) =>
            SosDrillScreen(familyId: state.pathParameters['familyId']!),
      ),

      // FS-015 Device Linking & Enrollment subsystem routes
      // (DL-002 … DL-011). DL-001 is the existing `/safety/pairing/:familyId`
      // issuance surface in pairing_screen.dart, extended with the FS-015
      // inventory and lockout banner.
      GoRoute(
        path: '/safety/pairing/:familyId/lockout',
        name: 'deviceLinkLockout',
        builder: (context, state) => DeviceLockoutScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/enroll/:familyId/:code',
        name: 'deviceEnroll',
        builder: (context, state) => DeviceEnrollScreen(
            familyId: state.pathParameters['familyId']!,
            code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/enroll/:familyId/:code/confirm',
        name: 'deviceEnrollConfirm',
        builder: (context, state) => DeviceEnrollConfirmScreen(
            familyId: state.pathParameters['familyId']!,
            code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/couple/:familyId/link-device',
        name: 'spouseLinkDevice',
        builder: (context, state) => SpouseLinkDeviceScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/couple/:familyId/enroll',
        name: 'spouseEnroll',
        builder: (context, state) => SpouseEnrollScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/couple/:familyId/role',
        name: 'spouseRoleConfirmation',
        builder: (context, state) => SpouseRoleConfirmationScreen(
            familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/onboard/device-permissions',
        name: 'devicePermissionOnboarding',
        builder: (context, state) =>
            const DevicePermissionOnboardingScreen(),
      ),
      GoRoute(
        path: '/settings/devices',
        name: 'deviceHealthDashboard',
        builder: (context, state) =>
            const DeviceHealthDashboardScreen(familyId: 'self'),
      ),
      GoRoute(
        path: '/settings/device/:deviceId/unlink',
        name: 'deviceUnlink',
        builder: (context, state) => DeviceUnlinkScreen(
            familyId: 'self',
            deviceId: state.pathParameters['deviceId']!),
      ),
      GoRoute(
        path: '/settings/device/:deviceId/transfer',
        name: 'deviceTransfer',
        builder: (context, state) => DeviceTransferScreen(
            familyId: 'self',
            deviceId: state.pathParameters['deviceId']!),
      ),
      GoRoute(
        path: '/location/sharing/self',
        name: 'childLocationSharingLegacy',
        builder: (context, state) => const ChildLocationSharingScreen(),
      ),

      // FS-009 — Reports & Export routes (RP-001 … RP-008). Authorization
      // is delegated to FamilyPermission.viewReports inside the screens —
      // the router only registers the surfaces.
      GoRoute(
        path: ReportsDashboardScreen.route,
        name: 'reportsDashboard',
        builder: (context, state) => const ReportsDashboardScreen(),
      ),
      GoRoute(
        path: WebReportScreen.route,
        name: 'webReport',
        builder: (context, state) => const WebReportScreen(),
      ),
      GoRoute(
        path: UsageReportScreen.route,
        name: 'usageReport',
        builder: (context, state) => const UsageReportScreen(),
      ),
      GoRoute(
        path: LocationReportScreen.route,
        name: 'locationReport',
        builder: (context, state) => const LocationReportScreen(),
      ),
      GoRoute(
        path: SafetyReportScreen.route,
        name: 'safetyReport',
        builder: (context, state) => const SafetyReportScreen(),
      ),
      GoRoute(
        path: ModesReportScreen.route,
        name: 'modesReport',
        builder: (context, state) => const ModesReportScreen(),
      ),
      GoRoute(
        path: SosReportScreen.route,
        name: 'sosReport',
        builder: (context, state) => const SosReportScreen(),
      ),
      GoRoute(
        path: ReportExportScreen.route,
        name: 'reportExport',
        builder: (context, state) => const ReportExportScreen(),
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
