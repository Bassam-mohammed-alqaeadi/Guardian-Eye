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
import 'parent_notification_registration.dart';
import 'remote_provisioning_service.dart';
import '../data/fcm_token_repository.dart';
import '../data/notification_contract.dart';
import '../data/child_device_repository.dart';
import '../data/child_policy_delivery_service.dart';
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
/// M6 — child-device policy delivery. Pulls the family's policy snapshot
/// from Firestore into the local child-device store so the effective policy
/// and enforcement state reflect the family's current policies (members may
/// read `/policies` per the deployed rules; parent-only overrides are never
/// read — GA-22 preserved). When Firebase is unconfigured the source is a
/// safe no-op so the service never fabricates remote state.
final childPolicyDeliveryServiceProvider =
    Provider<ChildPolicyDeliveryService>((ref) {
  final source = GuardianFirebaseBootstrap.current.isReady
      ? FirestoreChildPolicySource(FirebaseFirestore.instance)
          as ChildPolicySource
      : const _UnavailableChildPolicySource();
  return ChildPolicyDeliveryService(
      ref.watch(childDeviceRepositoryProvider), source);
});

class _UnavailableChildPolicySource implements ChildPolicySource {
  const _UnavailableChildPolicySource();
  @override
  Future<List<RemoteChildPolicyMutation>> fetchPolicies(String familyId) async =>
      const [];
}
final deviceLinkServiceProvider = Provider(
    (ref) => DeviceLinkService(ref.watch(pairingRepositoryProvider)));
/// M5 Option D — canonical remote child provisioning (Functions callables).
/// When Firebase is unconfigured the service is unavailable and the local
/// SQLite pairing flow remains the offline-first fallback.
final remoteProvisioningServiceProvider = Provider(
    (ref) => const RemoteProvisioningService());
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
/// M9 — honest pending-count read for the sync UI. `autoDispose` so the count
/// is re-derived from the real SQLite outbox every time the surface opens
/// (never a stale cached value from before a mutation was enqueued).
final pendingOutboxCountProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.watch(outboxSyncStatusProvider).pendingCount());
/// M9 E3 — family-level pending sync derived from the REAL outbox state,
/// including `family.created` (aggregate type `family`) so a queued family
/// mutation is never presented as fully synchronized. `autoDispose` keeps the
/// read fresh whenever the family screen opens.
final familyPendingSyncProvider = FutureProvider.autoDispose.family<bool, String>(
    (ref, String familyId) =>
        ref.watch(outboxSyncStatusProvider).hasPendingForFamily(familyId));
final deviceTokenRepositoryProvider =
    Provider((ref) => DeviceTokenRepository(GuardianDatabase.instance));
/// M9/FCM — canonical FCM token service. `register()` obtains the platform
/// token and enqueues `notification.token.registered` through the durable
/// outbox; the trusted backend reads it when delivering parent notifications.
final fcmTokenServiceProvider = Provider((ref) => FcmTokenService(
    ref.watch(firebaseAuthContextProvider),
    ref.watch(deviceTokenRepositoryProvider)));
/// M9/FCM — production parent-notification gateway. Calls the trusted
/// Guardian Backend `POST /api/notify` with the current Firebase ID token.
/// Falls back to the guarded stub (honest `not accepted`) when Firebase is
/// not configured so tests and unconfigured builds never fake delivery.
final parentNotificationGatewayProvider =
    Provider<ParentNotificationGateway>((ref) {
  if (!GuardianFirebaseBootstrap.current.isReady) {
    return const GuardedFcmNotificationGateway();
  }
  return const RenderNotificationGateway();
});
/// M9/FCM — app-side registration of this device as a parent-role device so
/// the backend can deliver push notifications to the parent. Safe no-op when
/// logged out / unconfigured / without a family.
final parentNotificationRegistrationProvider = Provider((ref) =>
    ParentNotificationRegistration(
        families: ref.watch(familyRepositoryProvider),
        pairing: ref.watch(pairingRepositoryProvider),
        binding: ref.watch(familyActorBindingServiceProvider),
        fcm: ref.watch(fcmTokenServiceProvider),
        platform: 'android'));
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
