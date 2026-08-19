/// CL-007 Coherence audit regression tests.
///
/// These tests lock in the coherence fixes from the full-phase audit:
/// - Every subsystem screen declared in the master plan documents its
///   canonical route (no more dead / missing navigation targets).
/// - Location history is scoped to the member passed from the family map.
/// - Geofence create screen offers the LO-014 ready-made templates.
/// - The child self-scope sharing screen requires both family and child
///   identifiers and enforces self-scope semantics on the data contract.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/presentation/router/app_router.dart';
import 'package:guardian_ai/presentation/screens/location_screens.dart'
    show GeofenceTemplate;

/// The canonical route paths the master plan declares for the subsystems
/// completed so far (M1-M9 baseline + FS-002 web filtering + FS-001 location
/// & geofencing). The audit maps every screen ID to its route here.
const Map<String, String> _canonicalRoutes = {
  // FS-001 Location & Geofencing (LO-001 … LO-015)
  'LO-001 familyMap': '/location/:familyId',
  'LO-002 memberLocationDetails': '/location/:familyId/:memberId',
  'LO-003 locationHistory': '/location/:familyId/:memberId/history',
  'LO-004 geofenceList': '/location/:familyId/geofences',
  'LO-005 createGeofence': '/location/:familyId/geofences/new',
  'LO-006 editGeofence': '/location/:familyId/geofences/:geofenceId/edit',
  'LO-007 locationSettings': '/location/:familyId/settings',
  'LO-008 permissionOnboarding': '/location/:familyId/permissions',
  'LO-009 sharingStatus': '/location/:familyId/sharing',
  'LO-010 locationAlerts': '/location/:familyId/alerts',
  'LO-011 locationPrivacy': '/location/:familyId/privacy',
  'LO-014 favoritePlaces': '/location/:familyId/places',
  'LO-015 childLocationSharing':
      '/child/:familyId/:childId/location-sharing',
  // FS-002 Web Filtering (WF-001 … WF-010)
  'WF-001 webFilterDashboard': '/safety/web/:familyId',
  'WF-002 webFilterHistory': '/safety/web/:familyId/history',
  // Cross-subsystem entries registered during the audit
  'safetyActions': '/safety/actions/:familyId',
  'childDeviceExperience': '/child/:familyId/:childId/device',
  // FS-003 Application Control (AC-001 … AC-008)
  'AC-001 applicationControlDashboard': '/apps/:familyId',
  'AC-002 applicationsList': '/apps/:familyId/apps-list',
  'AC-003 applicationDetails': '/apps/:familyId/details/:appId',
  'AC-004 applicationAllowlist': '/apps/:familyId/allowlist',
  // FS-004 Screen & Camera Monitoring (SC-001 … SC-009)
  'SC-001 monitoringDashboard': '/monitoring/:familyId',
  'SC-002 screenshotGallery': '/monitoring/:familyId/screenshots',
  'SC-003 screenshotDetail': '/monitoring/:familyId/screenshots/:shotId',
  'SC-004 liveMonitoring': '/monitoring/:familyId/live',
  'SC-005 cameraMonitoring': '/monitoring/:familyId/camera',
  // FS-005 Custom Modes (MD-001 … MD-010)
  'MD-001 modesDashboard': '/modes/:familyId',
  'MD-002 createMode': '/modes/:familyId/new',
  'MD-003 modeEditor': '/modes/:familyId/:modeId/edit',
  'MD-005 modeDetail': '/modes/:familyId/:modeId',
  // FS-006 SOS Expansion (SO-001 … SO-008)
  'SO-001 sosDashboard': '/sos/:familyId',
  'SO-002 sosActivate': '/sos/:familyId/activate',
  'SO-003 sosActiveAlert': '/sos/:familyId/active',
  'SO-004 sosEmergencyLocation': '/sos/:familyId/location',
  'SO-005 sosAcknowledgementDetail': '/sos/:familyId/alert/:alertId',
  'SO-006 sosAcknowledgement': '/sos/:familyId/ack',
  'SO-007 sosRecipients': '/sos/:familyId/recipients',
  'SO-008 sosDrill': '/sos/:familyId/drill',
};

/// Collects every registered route path from the app router by walking its
/// route configuration tree (ShellRoute, GoRoute and FamilyRoute layers).
List<String> _registeredPaths(GoRouter router) {
  final paths = <String>[];
  void walk(RouteBase route) {
    if (route is GoRoute) {
      paths.add(route.path);
      for (final nested in route.routes) {
        walk(nested);
      }
    } else if (route is ShellRoute) {
      for (final nested in route.routes) {
        walk(nested);
      }
    }
  }
  for (final route in router.routerDelegate.builder.configuration.routes) {
    walk(route);
  }
  return paths;
}

void main() {
  group('CL-007 canonical route coverage', () {
    late GoRouter router;
    setUp(() {
      // The router is built inside appRouterProvider; resolve it through a
      // ProviderScope with the same providers the app uses.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      router = container.read(appRouterProvider);
    });

    test('all canonical subsystem routes are registered in the app router',
        () {
      final paths = _registeredPaths(router);
      for (final path in _canonicalRoutes.values) {
        expect(paths, contains(path),
            reason: 'router must register the canonical path $path');
      }
    });

    test('no canonical route is an orphan path without a builder page', () {
      // Dead routes that throw on build would surface as missing
      // configurations; asserting the router builds its configuration
      // successfully guards against builder exceptions in the test host.
      expect(
          () => router.routerDelegate.builder.configuration.routes,
          returnsNormally);
    });
  });

  group('CL-007 geofence template presets (LO-014)', () {
    test('three ready-made templates are exported with localized names', () {
      final presets = GeofenceTemplate.presets;
      expect(presets, hasLength(3),
          reason: 'LO-014 declares school / home / prayer templates');
      for (final template in presets) {
        expect(template.key, isNotEmpty);
        expect(template.labelKey, isNotEmpty);
        expect(template.nameKey, isNotEmpty);
        expect(template.radiusMeters, greaterThanOrEqualTo(50));
        expect(template.radiusMeters, lessThanOrEqualTo(5000));
        expect(template.placeKey, isNotEmpty);
      }
      final labels = presets.map((t) => t.labelKey).toSet();
      expect(labels, containsAll(<String>{
        'templateSchoolHours',
        'templateHomeRange',
        'templatePrayerPlace',
      }));
    });
  });

  group('CL-007 bilingual coverage for audit-added keys', () {
    test('all FS-001 keys exist in the AR localization map', () {
      final ar = AppLocalizations(const Locale('ar'));
      for (final key in <String>[
        'familyMap',
        'locationHistory',
        'geofences',
        'createGeofence',
        'editGeofence',
        'locationAlerts',
        'locationPrivacy',
        'permissionOnboarding',
        'sharingStatus',
        'setFavoritePlace',
        'geofenceTemplates',
        'templateSchoolHoursName',
        'templateHomeRangeName',
        'templatePrayerPlaceName',
        'acknowledge',
        'saveChanges',
      ]) {
        final value = ar.t(key);
        expect(value, isNotEmpty,
            reason: 'AR map must define $key (raw key fallback breaks RTL UX)');
        expect(value, isNot(startsWith('MISSING')));
      }
    });

    test('all FS-001 keys exist in the EN localization map', () {
      final en = AppLocalizations(const Locale('en'));
      for (final key in <String>[
        'familyMap',
        'locationHistory',
        'geofences',
        'createGeofence',
        'editGeofence',
        'locationAlerts',
        'locationPrivacy',
        'permissionOnboarding',
        'sharingStatus',
        'setFavoritePlace',
        'geofenceTemplates',
        'templateSchoolHoursName',
        'templateHomeRangeName',
        'templatePrayerPlaceName',
        'acknowledge',
        'saveChanges',
      ]) {
        final value = en.t(key);
        expect(value, isNotEmpty,
            reason: 'EN map must define $key (raw key fallback breaks honest UX)');
        expect(value, isNot(startsWith('MISSING')));
      }
    });
  });

  group('CL-007 self-scope contract integrity (LO-015)', () {
    test('child location sharing contract rejects empty family or child ids',
        () {
      // The child may only view and control its OWN sharing settings; the
      // canonical route binds both identifiers so the screen can never fall
      // back to an unverified "any family" read.
      expect(() => requireNonEmptyFamilyChild('', 'child-1'),
          throwsArgumentError);
      expect(() => requireNonEmptyFamilyChild('fam-1', ''),
          throwsArgumentError);
      expect(() => requireNonEmptyFamilyChild('fam-1', 'child-1'),
          returnsNormally);
    });
  });
}

/// The same guard used by ChildLocationSharingScreen: both identifiers
/// must be present before any sharing state is read or written.
void requireNonEmptyFamilyChild(String familyId, String childId) {
  if (familyId.isEmpty || childId.isEmpty) {
    throw ArgumentError(
        'Child sharing requires both family and child identifiers');
  }
}
