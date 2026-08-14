import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'family_membership_providers.dart';
import '../core/database/guardian_database.dart';
import '../core/firebase/guardian_firebase_bootstrap.dart';
import '../core/platform/capability_gateway.dart';
import '../core/platform/android_enforcement_adapter.dart';
import '../core/platform/enforcement_platform_channel.dart';
import '../core/platform/android_observation_gateway.dart';
import 'child_screen_time_coordinator.dart';
import 'child_usage_measurement_provider.dart';
import 'child_enforcement_coordinator.dart';
import 'device_link_service.dart';
import '../data/fcm_token_repository.dart';
import '../data/child_device_repository.dart';
import '../data/child_exception_request_repository.dart';
import '../data/firebase_auth_context.dart';
import '../data/family_safety_experience_repository.dart';
import '../data/family_actor_binding_service.dart';
import '../data/family_membership_repository.dart';
import '../data/guardian_repositories.dart';
import '../data/outbox_sync_executor.dart';
import '../data/outbox_sync_status.dart';
import '../data/policy_repository.dart';
import '../data/safety_repositories.dart';
import 'sync_coordinator.dart';
import '../core/platform/network_connectivity_service.dart';
import '../domain/incident_engine.dart';
import '../domain/guardian_models.dart';

final localeProvider = StateProvider<String>((ref) => 'ar');
final familyRepositoryProvider =
    Provider((ref) => FamilyRepository(GuardianDatabase.instance));
final pairingRepositoryProvider =
    Provider((ref) => PairingRepository(GuardianDatabase.instance));
final policyRepositoryProvider =
    Provider((ref) => PolicyRepository(GuardianDatabase.instance));

/// M6 — Screen-Time Administration. The policy list a parent sees for a
/// child's family. Local first; each policy carries its honest
/// [SyncState] so the UI never claims server delivery without evidence.
final childPoliciesProvider =
    FutureProvider.family((ref, String familyId) =>
        ref.watch(policyRepositoryProvider).forFamily(familyId));

/// M6 — Screen-Time Administration. Active temporary allowances for a
/// family. The engine applies these on top of policies; every allowance
/// is bounded by expiry and the UI displays that expiry plainly.
final childOverridesProvider =
    FutureProvider.family((ref, String familyId) => ref
        .watch(policyRepositoryProvider)
        .overridesForFamily(familyId));

final childDeviceRepositoryProvider =
    Provider((ref) => ChildDeviceRepository(GuardianDatabase.instance));
final deviceLinkServiceProvider = Provider(
    (ref) => DeviceLinkService(ref.watch(pairingRepositoryProvider)));
final childExceptionRequestRepositoryProvider = Provider((ref) =>
    ChildExceptionRequestRepository(GuardianDatabase.instance,
        ref.watch(policyRepositoryProvider)));
final familySafetyExperienceRepositoryProvider = Provider((ref) =>
    FamilySafetyExperienceRepository(
        GuardianDatabase.instance,
        ref.watch(policyRepositoryProvider),
        ref.watch(childExceptionRequestRepositoryProvider)));
final childDeviceStatesProvider = FutureProvider.family(
    (ref, String familyId) =>
        ref.watch(childDeviceRepositoryProvider).statesForFamily(familyId));
final childUsageForTodayProvider = FutureProvider.family((ref, String deviceId) =>
    ref.watch(childDeviceRepositoryProvider).usageForDeviceDay(
        deviceId: deviceId, day: DateTime.now()));
final deliveredChildPoliciesProvider = FutureProvider.family((ref, String deviceId) =>
    ref.watch(childDeviceRepositoryProvider).deliveredPolicies(deviceId));
final familyDailySafetyProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familySafetyExperienceRepositoryProvider).childrenForFamily(familyId));
final familySafetyTimelineProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familySafetyExperienceRepositoryProvider).timelineForFamily(familyId));
final familyExceptionRequestsProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(childExceptionRequestRepositoryProvider).forFamily(familyId));
typedef ChildRequestScope = ({String familyId, String deviceId, String childUid});
final childExceptionRequestsProvider = FutureProvider.family(
    (ref, ChildRequestScope scope) => ref
        .watch(childExceptionRequestRepositoryProvider)
        .forChild(
            familyId: scope.familyId,
            childDeviceId: scope.deviceId,
            childUid: scope.childUid));
final sosRepositoryProvider =
    Provider((ref) => SosRepository(GuardianDatabase.instance));
final incidentRepositoryProvider = Provider(
    (ref) => IncidentRepository(GuardianDatabase.instance, const RiskEngine()));
/// Unacknowledged incidents for the family — drives the dashboard safety
/// signal. A pure local read; never called directly from a widget.
final recentIncidentsProvider = FutureProvider.family<List<GuardianIncident>, String>(
    (ref, String familyId) => ref
        .watch(incidentRepositoryProvider)
        .unacknowledgedIncidentsForFamily(familyId));
final firebaseAuthContextProvider =
    Provider<FirebaseAuthContext>((ref) => const FirebaseAuthContext());
final firebaseAuthServiceProvider = Provider(
    (ref) => FirebaseAuthService(ref.watch(firebaseAuthContextProvider)));
final firebaseAuthSessionProvider = StreamProvider<AuthSession>(
    (ref) => ref.watch(firebaseAuthContextProvider).changes);
final familyMembershipRemoteReaderProvider =
    Provider<FamilyMembershipRemoteReader>((ref) {
  if (!GuardianFirebaseBootstrap.current.isReady) {
    return _UnavailableFamilyMembershipRemoteReader();
  }
  return FirestoreFamilyMembershipRemoteReader(FirebaseFirestore.instance);
});
final familyActorBindingServiceProvider = Provider((ref) =>
    FamilyActorBindingService(
        ref.watch(firebaseAuthContextProvider),
        FamilyMembershipRepository(GuardianDatabase.instance),
        ref.watch(familyMembershipRemoteReaderProvider)));
final familyActorBindingProvider =
    FutureProvider.family<FamilyActorBindingResult, String>((ref, familyId) =>
        ref.watch(familyActorBindingServiceProvider).resolveForFamily(familyId));
final outboxRemoteWriterProvider = Provider<OutboxRemoteWriter>((ref) {
  if (!GuardianFirebaseBootstrap.current.isReady) {
    return const UnconfiguredOutboxRemoteWriter();
  }
  return FirestoreOutboxRemoteWriter(FirebaseFirestore.instance);
});
final outboxSyncExecutorProvider = Provider((ref) => OutboxSyncExecutor(
    GuardianDatabase.instance,
    ref.watch(firebaseAuthContextProvider),
    ref.watch(outboxRemoteWriterProvider)));
/// M9 — canonical runtime sync coordinator. All triggers (startup,
/// connectivity restoration, manual sync, WorkManager) funnel through this
/// single-flight coordinator so only one execution may operate on the outbox
/// at a time. UI watches [syncCoordinatorProvider] for the honest state.
final syncCoordinatorCoreProvider = Provider(
    (ref) => SyncCoordinatorCore(ref.watch(outboxSyncExecutorProvider)));
final syncCoordinatorProvider = StateNotifierProvider<SyncCoordinator, SyncRunState>(
    (ref) => SyncCoordinator(ref.watch(syncCoordinatorCoreProvider)));
/// M9 Trigger B — network restoration monitor (offline → online).
final networkConnectivityServiceProvider =
    Provider((ref) => NetworkConnectivityService());
/// M9 — honest outbox status queries for the UI (pending count, family-level
/// pending state). Never claims synced without real outbox evidence.
final outboxSyncStatusProvider =
    Provider((ref) => OutboxSyncStatus(GuardianDatabase.instance));
final pendingOutboxCountProvider = FutureProvider<int>(
    (ref) => ref.watch(outboxSyncStatusProvider).pendingCount());
/// M9 E3 — family-level pending sync derived from the REAL outbox state,
/// including `family.created` (aggregate type `family`) so a queued family
/// mutation is never presented as fully synchronized.
final familyPendingSyncProvider = FutureProvider.family<bool, String>(
    (ref, String familyId) =>
        ref.watch(outboxSyncStatusProvider).hasPendingForFamily(familyId));
final deviceTokenRepositoryProvider =
    Provider((ref) => DeviceTokenRepository(GuardianDatabase.instance));
final capabilityGatewayProvider = Provider((ref) => const CapabilityGateway());
final androidObservationGatewayProvider =
    Provider((ref) => const AndroidObservationGateway());
final androidEnforcementAdapterProvider =
    Provider((ref) => AndroidEnforcementAdapter(platform: EnforcementPlatformChannel()));
final childScreenTimeCoordinatorProvider = Provider((ref) =>
    ChildScreenTimeCoordinator(
        ref.watch(childDeviceRepositoryProvider),
        ref.watch(androidObservationGatewayProvider),
        ref.watch(androidEnforcementAdapterProvider)));

/// M7 — Screen-Time Measurement. On-demand, consent-gated measurement
/// snapshot for a child device's current local day: usage totals,
/// per-target breakdown, honest observation state, freshness, and sync
/// evidence derived only from the actual outbox row state.
final childUsageMeasurementProvider =
    FutureProvider.family((ref, String deviceId) =>
        buildUsageMeasurementSnapshot(
            coordinator: ref.watch(childScreenTimeCoordinatorProvider),
            repository: ref.watch(childDeviceRepositoryProvider),
            deviceId: deviceId,
            now: DateTime.now()));
/// M8 — Screen-Time Enforcement. On-demand, consent-gated enforcement
/// evaluation for a child device: honest enforcement state, application
/// evidence, policy freshness, and sync evidence derived only from the
/// actual outbox row state. Offline-safe: all inputs are local.
final childEnforcementCoordinatorProvider = Provider<ChildEnforcementCoordinator>(
    (ref) => ChildEnforcementCoordinator(
        ref.watch(childDeviceRepositoryProvider),
        ref.watch(androidEnforcementAdapterProvider)));
final enforcementStateProvider =
    FutureProvider.family((ref, String deviceId) =>
        ref.watch(childEnforcementCoordinatorProvider).evaluate(deviceId,
            moment: DateTime.now().toUtc()));
final dashboardProvider = FutureProvider<GuardianDashboard>(
    (ref) => ref.watch(familyRepositoryProvider).loadDashboard());
final capabilityStatusProvider = FutureProvider<List<CapabilityStatus>>(
    (ref) => ref.watch(capabilityGatewayProvider).inspectAll());

class _UnavailableFamilyMembershipRemoteReader
    implements FamilyMembershipRemoteReader {
  @override
  Future<RemoteFamilyMembership?> readMembership(
          {required String familyId, required String accountUid}) =>
      Future<RemoteFamilyMembership?>.error(
          StateError('firebase_membership_reader_unavailable'));
}
