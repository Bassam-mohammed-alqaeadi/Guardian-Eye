import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
export 'family_membership_providers.dart';
import '../core/database/guardian_database.dart';
import '../core/firebase/guardian_firebase_bootstrap.dart';
import '../core/platform/capability_gateway.dart';
import '../core/platform/android_enforcement_adapter.dart';
import '../core/platform/android_observation_gateway.dart';
import 'child_screen_time_coordinator.dart';
import '../data/fcm_token_repository.dart';
import '../data/child_device_repository.dart';
import '../data/child_exception_request_repository.dart';
import '../data/firebase_auth_context.dart';
import '../data/family_safety_experience_repository.dart';
import '../data/family_actor_binding_service.dart';
import '../data/family_membership_repository.dart';
import '../data/guardian_repositories.dart';
import '../data/outbox_sync_executor.dart';
import '../data/policy_repository.dart';
import '../data/safety_repositories.dart';
import '../domain/incident_engine.dart';
import '../domain/guardian_models.dart';

final localeProvider = StateProvider<String>((ref) => 'ar');
final familyRepositoryProvider =
    Provider((ref) => FamilyRepository(GuardianDatabase.instance));
final pairingRepositoryProvider =
    Provider((ref) => PairingRepository(GuardianDatabase.instance));
final policyRepositoryProvider =
    Provider((ref) => PolicyRepository(GuardianDatabase.instance));
final childDeviceRepositoryProvider =
    Provider((ref) => ChildDeviceRepository(GuardianDatabase.instance));
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
final deviceTokenRepositoryProvider =
    Provider((ref) => DeviceTokenRepository(GuardianDatabase.instance));
final capabilityGatewayProvider = Provider((ref) => const CapabilityGateway());
final androidObservationGatewayProvider =
    Provider((ref) => const AndroidObservationGateway());
final androidEnforcementAdapterProvider =
    Provider((ref) => const AndroidEnforcementAdapter());
final childScreenTimeCoordinatorProvider = Provider((ref) =>
    ChildScreenTimeCoordinator(
        ref.watch(childDeviceRepositoryProvider),
        ref.watch(androidObservationGatewayProvider),
        ref.watch(androidEnforcementAdapterProvider)));
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
