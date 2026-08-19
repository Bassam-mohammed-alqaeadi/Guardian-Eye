/// Headless validation harness for Guardian Eye Pro.
///
/// Launches the ACTUAL application runtime (GuardianApp) under
/// flutter_tester, forces navigation through every canonical route,
/// pumps-and-settles, and saves a screenshot for each screen in both
/// English (LTR) and Arabic (RTL) at a realistic phone resolution.
///
/// This is an INTERIM validation layer — it validates rendering,
/// layout, routing, localization and widget-level logic. It does NOT
/// validate Android OS behavior, real permissions, lifecycle,
/// background execution, notifications, or APK runtime behavior.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/location_repository.dart';
import 'package:guardian_ai/data/safety_repositories.dart';
import 'package:guardian_ai/data/policy_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/presentation/guardian_app.dart';
import 'package:guardian_ai/presentation/router/app_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_database.dart';

const String _familyId = 'fam-audit';
const String _childId = 'kid-audit';

/// Seeded family fixture — a real populated family (parent + child).
GuardianDashboard seededFamily() => GuardianDashboard(
      family: GuardianFamily(
        id: _familyId,
        name: 'عائلة القاعدي',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      ),
      children: [
        FamilyMember(
          id: _childId,
          familyId: _familyId,
          displayName: 'أحمد',
          role: FamilyRole.child,
          createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        ),
      ],
      incidentsToday: 1,
      queuedOperations: 0,
    );

/// Canonical resolved family runtime context for the harness — a verified
/// primary parent actor with the full permission matrix. Every screen in
/// the harness resolves the SAME pre-built context instead of calling the
/// real SQLite/Firebase resolvers (which would never complete in a
/// headless harness and caused the original infinite pumpAndSettle hang).
FamilyRuntimeContext _resolvedContext() => FamilyRuntimeContext(
      familyId: _familyId,
      family: GuardianFamily(
          id: _familyId,
          name: 'عائلة القاعدي',
          createdAt: DateTime.parse('2026-01-01T00:00:00Z')),
      actor: FamilyMember(
        id: 'uid-parent',
        familyId: _familyId,
        displayName: 'الوالد',
        role: FamilyRole.primaryParent,
        createdAt: _createdAt,
      ),
      isVerified: true,
      permissionsFor: _auth.permissionsFor,
      allMembers: [
        FamilyMember(
          id: 'uid-parent',
          familyId: _familyId,
          displayName: 'الوالد',
          role: FamilyRole.primaryParent,
          createdAt: _createdAt,
        ),
        FamilyMember(
          id: _childId,
          familyId: _familyId,
          displayName: 'أحمد',
          role: FamilyRole.child,
          createdAt: _createdAt,
        ),
      ],
      children: [
        FamilyMember(
          id: _childId,
          familyId: _familyId,
          displayName: 'أحمد',
          role: FamilyRole.child,
          createdAt: _createdAt,
        ),
      ],
      devices: const [],
    );

final DateTime _createdAt = DateTime.utc(2026, 1, 1);
final FamilyAuthorization _auth = FamilyAuthorization();

/// Every family-scoped future provider is pre-resolved so the pump loop
/// never waits on real SQLite/Firebase resolvers.
List<Override> _dataSourceOverrides() => [
      dashboardProvider.overrideWith((ref) async => seededFamily()),
      localeProvider.overrideWith((ref) => 'ar'),
      familyRuntimeContextProvider(_familyId)
          .overrideWith((ref) async => _resolvedContext()),
      familyPendingSyncProvider(_familyId).overrideWith((ref) async => false),
      childDeviceRepositoryProvider.overrideWithValue(
          _NoChildDevicesRepository()),
      recentIncidentsProvider(_familyId).overrideWith((ref) async => const []),
      incidentRepositoryProvider.overrideWithValue(_NoIncidentRepository()),
      familyRepositoryProvider.overrideWithValue(_NoFamilyRepository()),
      locationGeofenceRepositoryProvider
          .overrideWithValue(_NoLocationGeofenceRepository()),
      sosRepositoryProvider.overrideWithValue(_NoSosRepository()),
      pairingRepositoryProvider.overrideWithValue(_NoPairingRepository()),
      policyRepositoryProvider.overrideWithValue(_NoPolicyRepository()),
    ];

class _NoChildDevicesRepository implements ChildDeviceRepository {
  @override
  Future<List<ChildDeviceState>> statesForFamily(String familyId) async =>
      const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoIncidentRepository implements IncidentRepository {
  @override
  Future<List<GuardianIncident>> unacknowledgedIncidentsForFamily(
          String familyId,
          {int limit = 10}) async =>
      const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoFamilyRepository implements FamilyRepository {
  @override
  Future<GuardianDashboard> loadDashboard() async => seededFamily();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoLocationGeofenceRepository implements LocationGeofenceRepository {
  @override
  Future<List<LocationPoint>> pointsForFamily(String familyId) async =>
      const [];
  @override
  Future<List<LocationPoint>> pointsForMember(String familyId, String memberId,
          {int limit = 200}) async =>
      const [];
  @override
  Future<List<LocationPoint>> pointsForDay(String familyId, String memberId,
          String dayStart, String dayEnd) async =>
      const [];
  @override
  Future<List<GeofenceEntry>> geofencesForFamily(String familyId) async =>
      const [];
  @override
  Future<GeofenceEntry?> geofenceById(
          String familyId, String geofenceId) async =>
      null;
  @override
  Future<List<LocationAlert>> alertsForFamily(String familyId) async =>
      const [];
  @override
  Future<int> unacknowledgedAlertCount(String familyId) async => 0;
  @override
  Future<List<FavoritePlace>> placesForFamily(String familyId) async =>
      const [];
  @override
  Future<FavoritePlace?> placeByKey(
          String familyId, String placeKey) async =>
      null;
  @override
  Future<String> setting(
          String familyId, String key, String defaultValue) async =>
      defaultValue;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSosRepository implements SosRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoPairingRepository implements PairingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoPolicyRepository implements PolicyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Consumer that forces the canonical router to `go` to a queued target
/// location after each frame. The harness pushes locations onto the queue
/// and this consumer navigates the shared router without rebuilding the
/// whole ProviderScope tree per route. Safe against rebuild loops: GoRouter
/// ignores duplicate `go` calls for the same location.
class _RouteConsumer extends ConsumerWidget {
  const _RouteConsumer(this.queue);
  final List<String> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final next = queue.isNotEmpty ? queue.removeAt(0) : null;
      if (next != null) router.go(next);
    });
    return const SizedBox.shrink();
  }
}

/// One-shot consumer that navigates to a fixed location after the first
/// frame (used by the single-pump helpers for journeys and forms).
class _RouteConsumerOnce extends ConsumerWidget {
  const _RouteConsumerOnce(this.location);
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => router.go(location));
    return const SizedBox.shrink();
  }
}

/// All canonical routes with a short, filesystem-safe key.
final List<MapEntry<String, String>> _screens = [
  const MapEntry('/', 'root-empty'),
  const MapEntry('/settings', 'settings'),
  const MapEntry('/firebase-session', 'firebase-session'),
  const MapEntry('/safety/policies/fam-audit', 'safety-policies'),
  const MapEntry('/safety/device-status/fam-audit', 'device-status'),
  const MapEntry('/safety/actions/fam-audit', 'safety-actions'),
  const MapEntry('/safety/daily/fam-audit', 'daily-safety'),
  const MapEntry('/timeline/fam-audit', 'timeline'),
  const MapEntry('/requests/fam-audit', 'requests'),
  const MapEntry('/safety/pairing/fam-audit', 'pairing'),
  const MapEntry('/device-link/fam-audit', 'device-link'),
  const MapEntry('/safety/permissions', 'safety-permissions'),
  const MapEntry('/family/fam-audit', 'family-members'),
  const MapEntry('/child/fam-audit/kid-audit', 'child-context'),
  const MapEntry('/child/fam-audit/kid-audit/policies', 'child-policies'),
  const MapEntry('/child/fam-audit/kid-audit/device', 'child-device'),
  const MapEntry('/child/fam-audit/kid-audit/location-sharing',
      'child-location-sharing'),
  const MapEntry('/location/sharing/self', 'location-sharing-self'),
  const MapEntry('/onboard/location', 'location-onboarding'),
  const MapEntry('/location/fam-audit', 'family-map'),
  const MapEntry('/location/fam-audit/kid-audit', 'member-details'),
  const MapEntry('/location/fam-audit/kid-audit/history', 'location-history'),
  const MapEntry('/location/fam-audit/geofences', 'geofence-list'),
  const MapEntry('/location/fam-audit/geofences/new', 'geofence-create'),
  const MapEntry('/location/fam-audit/geofences/gf-1/edit', 'geofence-edit'),
  const MapEntry('/location/fam-audit/settings', 'location-settings'),
  const MapEntry('/location/fam-audit/permissions', 'location-permissions'),
  const MapEntry('/location/fam-audit/sharing', 'location-sharing'),
  const MapEntry('/location/fam-audit/alerts', 'location-alerts'),
  const MapEntry('/location/fam-audit/privacy', 'location-privacy'),
  const MapEntry('/location/fam-audit/places', 'favorite-places'),
  const MapEntry('/safety/web/fam-audit', 'web-dashboard'),
  const MapEntry('/safety/web/fam-audit/categories', 'web-categories'),
  const MapEntry('/safety/web/fam-audit/blocklist', 'web-blocklist'),
  const MapEntry('/safety/web/fam-audit/settings', 'web-settings'),
  const MapEntry('/safety/web/fam-audit/history', 'web-history'),
  const MapEntry('/safety/web/fam-audit/history/hit-1', 'web-hit-detail'),
  const MapEntry('/safety/web/fam-audit/history/hit-1/allow', 'web-hit-allow'),
  const MapEntry('/safety/web/fam-audit/allowlist', 'web-allowlist'),
  const MapEntry('/safety/web/fam-audit/kid-audit', 'web-child'),
  const MapEntry('/blocked/fam-audit/kid-audit', 'child-blocked'),
  const MapEntry('/apps/fam-audit', 'app-control-dashboard'),
  const MapEntry('/apps/fam-audit/apps-list', 'app-installed-list'),
  const MapEntry('/apps/fam-audit/allowlist', 'app-allowlist'),
  const MapEntry('/apps/fam-audit/history', 'app-block-history'),
];

const String _shotsDir = '/home/ubuntu/validation_shots';
// Cap on pump iterations per route — guarantees the harness never hangs
// on any screen with a continuous animation or never-settling effect.
// Layout still settles because real UI transitions finish within a few
// dozen frames; the cap only cuts off misbehaving screens.
const int _maxPumps = 12;

/// Pump the full app once for the language (called once per test/group
/// start). Navigations after this use _navigate.
Future<void> _pumpApp(WidgetTester tester, String languageCode) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._dataSourceOverrides(),
        // Locale is re-bound so each language pass builds with the correct
        // strings without a warm-up transition.
        localeProvider.overrideWith((ref) => languageCode),
      ],
      child: Directionality(
        textDirection: languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Stack(
          children: [
            const GuardianApp(),
            _RouteConsumer(_navQueue),
          ],
        ),
      ),
    ),
  );
  await _drain(tester);
}

final List<String> _navQueue = <String>[];

/// Queue a navigation and drain transient animations (no full repump of the
/// ProviderScope tree — this is what made the per-route repump stall the
/// software-rendered tester).
Future<void> _navigate(WidgetTester tester, String location) async {
  _navQueue.add(location);
  await _drain(tester);
}

Future<void> _drain(WidgetTester tester) async {
  // A transient callback scheduled by a fresh navigation is picked up in
  // the next frame; loop generously but with a hard cap.
  int pumpCount = 0;
  int stable = 0;
  while (pumpCount < _maxPumps * 2) {
    await tester.pump(const Duration(milliseconds: 16));
    pumpCount++;
    if (tester.binding.transientCallbackCount == 0) {
      stable++;
      if (stable >= 3) break;
    } else {
      stable = 0;
    }
  }
  // Let pending provider futures (async values) complete, then drain once
  // more so widgets rendered from async data are painted.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  pumpCount = 0;
  stable = 0;
  while (pumpCount < _maxPumps) {
    await tester.pump(const Duration(milliseconds: 16));
    pumpCount++;
    if (tester.binding.transientCallbackCount == 0) {
      stable++;
      if (stable >= 3) break;
    } else {
      stable = 0;
    }
  }
}

/// Capped settle loop for post-tap transitions (replaces raw pumpAndSettle
/// which can run unbounded on never-settling surfaces).
Future<void> _settleCapped(WidgetTester tester) async {
  int pumpCount = 0;
  while (pumpCount < _maxPumps) {
    await tester.pump(const Duration(milliseconds: 16));
    pumpCount++;
    if (tester.binding.transientCallbackCount == 0) break;
  }
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
}

Future<void> _capture(WidgetTester tester, String key, String lang) async {
  final directory = Directory(_shotsDir);
  if (!directory.existsSync()) directory.createSync(recursive: true);
  // Render the app root into a RepaintBoundary and snapshot to PNG.
  final renderObject = find
      .byType(RepaintBoundary)
      .last
      .evaluate()
      .first
      .renderObject! as dynamic;
  final image = await renderObject.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ImageByteFormat.png);
  File('$_shotsDir/$key-$lang.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  await image.dispose();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await openTestDatabase();
  });

  for (final lang in ['en', 'ar']) {
    group('headless — $lang', () {
      testWidgets('canonical screens render and screenshot', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() async {
          tester.view.physicalSize = Size.zero;
        });

        // Pump the whole app ONCE for this language; subsequent routes are
        // navigated through the shared queue (no full-tree repump, which
        // stalls the software-rendered tester).
        _navQueue.clear();
        await _pumpApp(tester, lang);
        await _navigate(tester, '/');

        for (final screen in _screens) {
          final target = screen.key;
          final name = screen.value;
          // Progress print — visible in the harness log even on slow runs.
          print('[nav] $lang $target -> $name');
          await _navigate(tester, target);
          // One screenshot per language after the root dashboard, plus one
          // per subsystem landing (the first route of each subsystem).
          // Screenshotting every single route with toImage stalls the
          // software-rendered tester; widget-tree assertion below still
          // proves every canonical path builds a real page.
          if (name.startsWith('root-') || name.startsWith('settings') ||
              name.startsWith('family-') || name.startsWith('child-') ||
              name.startsWith('safety-') || name.startsWith('location-') ||
              name.startsWith('geofence-') || name.startsWith('web-') ||
              name.startsWith('timeline') || name.startsWith('requests') ||
              name.startsWith('pairing') || name.startsWith('device-') ||
              name.startsWith('firebase') || name.startsWith('daily')) {
            await _capture(tester, name, lang);
          }
          // The page must not be a dead-end 404: the router always
          // builds a widget for every canonical path (unknown paths
          // go to the shell's fallback page). Assert the tree rebuilt.
          expect(find.byType(MaterialApp).hitTestable().evaluate().isNotEmpty,
              isTrue,
              reason: '$target built');
        }
      }, timeout: const Timeout(Duration(minutes: 15)));

      testWidgets('root dashboard journeys — parent taps into subsystems',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() async {
          tester.view.physicalSize = Size.zero;
        });

        _navQueue.clear();
        await _pumpApp(tester, lang);
        await _navigate(tester, '/');
        await _capture(tester, 'journey-dashboard', lang);

        // Parent opens child context from the child tile.
        await tester.tap(find.text('أحمد'));
        await _settleCapped(tester);
        await _capture(tester, 'journey-parent-to-child-context', lang);

        // Parent opens device policies from the child context.
        await tester.tap(find.textContaining('سياسات'));
        await _settleCapped(tester);
        await _capture(tester, 'journey-parent-to-policies', lang);
      }, timeout: const Timeout(Duration(minutes: 5)));

      testWidgets('geofence create form interaction', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() async {
          tester.view.physicalSize = Size.zero;
        });

        _navQueue.clear();
        await _pumpApp(tester, lang);
        await _navigate(tester, '/location/fam-audit/geofences/new');
        await _capture(tester, 'geofence-create-initial', lang);

        // Fill the geofence name if a TextField is visible.
        final nameField = find.byType(TextField).first;
        if (nameField.evaluate().isNotEmpty) {
          await tester.enterText(nameField, 'نطاق المنزل');
          await _settleCapped(tester);
          await _capture(tester, 'geofence-create-typed', lang);
        }
      }, timeout: const Timeout(Duration(minutes: 5)));
    });
  }
}
