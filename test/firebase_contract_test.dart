import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/firestore_contracts.dart';

class _Auth implements AuthContext {
  const _Auth(this.value);
  final AuthSession value;
  @override
  AuthSession get currentSession => value;
  @override
  Stream<AuthSession> get changes => Stream.value(value);
}

void main() {
  test('Firestore gate rejects unconfigured and unauthenticated sessions', () {
    expect(
        () => const FirestoreAuthorizationGate(
                _Auth(AuthSession(status: AuthSessionStatus.unconfigured)))
            .requireIdentity(),
        throwsA(isA<AuthUnavailableException>()));
    expect(
        () => const FirestoreAuthorizationGate(
                _Auth(AuthSession(status: AuthSessionStatus.unauthenticated)))
            .requireIdentity(),
        throwsA(isA<AuthUnavailableException>()));
  });
  test(
      'Firestore contract uses family-scoped deterministic metadata path and identity',
      () {
    const identity = AuthenticatedIdentity(
        uid: 'parent-auth-uid',
        email: 'parent@example.test',
        isAnonymous: false);
    final mutation = const FirestoreEventContract().syncMetadata(
        familyId: 'family-a',
        eventId: 'event-a',
        operation: 'family.created',
        payload: {'familyId': 'family-a'},
        identity: identity,
        idempotencyKey: 'idem-a');
    expect(mutation.path, 'families/family-a/sync_metadata/event-a');
    expect(mutation.data['authorUid'], identity.uid);
    expect(mutation.idempotencyKey, 'idem-a');
  });
  test(
      'device enrollment does not infer a child Firebase identity from parent auth',
      () {
    const identity = AuthenticatedIdentity(
        uid: 'parent-auth-uid',
        email: 'parent@example.test',
        isAnonymous: false);
    final mutation = const FirestoreEventContract().businessMutation(
        operation: 'device.enrolled',
        payload: {
          'familyId': 'family-a',
          'deviceId': 'device-a',
          'memberId': 'child-a',
          'role': 'childDevice'
        },
        identity: identity,
        idempotencyKey: 'idem-device-a');
    expect(mutation.data['ownerUid'], 'parent-auth-uid');
    expect(mutation.data['memberUid'], isNull);
  });
  test('child telemetry is scoped to the active child identity and device path',
      () {
    final mutation = const FirestoreEventContract().businessMutation(
        operation: 'child.policy.delivered',
        payload: {
          'familyId': 'family-1',
          'deviceId': 'device-1',
          'lifecycle': 'active',
          'requiredPolicyVersion': 3,
          'lastValidPolicyAt': '2026-08-12T22:00:00.000Z',
          'updatedAt': '2026-08-12T22:00:00.000Z',
          'policyId': 'policy-1',
          'policyVersion': 3,
        },
        identity: const AuthenticatedIdentity(
            uid: 'child-uid', email: 'child@example.test', isAnonymous: false),
        idempotencyKey: 'event-1');
    expect(mutation.path,
        'families/family-1/devices/device-1/enforcement_status/current');
    expect(mutation.data['memberUid'], 'child-uid');
    expect(mutation.data['deliveryState'], 'local_persisted');
  });
  test('daily policy and usage telemetry preserve the scoped limit contract',
      () {
    const identity = AuthenticatedIdentity(
        uid: 'child-uid', email: 'child@example.test', isAnonymous: false);
    final policy = const FirestoreEventContract().businessMutation(
        operation: 'policy.updated',
        payload: {
          'familyId': 'family-1',
          'policyId': 'limit-1',
          'name': 'YouTube',
          'priority': 50,
          'enabled': true,
          'startMinute': 0,
          'endMinute': 0,
          'restrictedTargets': ['com.google.android.youtube'],
          'dailyLimitMinutes': 60,
          'version': 2,
        },
        identity: identity,
        idempotencyKey: 'policy-event');
    expect(policy.data['dailyLimitMinutes'], 60);
    final usage = const FirestoreEventContract().businessMutation(
        operation: 'child.usage.observed',
        payload: {
          'familyId': 'family-1',
          'deviceId': 'device-1',
          'usageId': 'usage-1',
          'target': 'com.google.android.youtube',
          'dayStart': '2026-08-12T00:00:00.000Z',
          'totalMilliseconds': 3600000,
          'capturedAt': '2026-08-12T12:00:00.000Z',
        },
        identity: identity,
        idempotencyKey: 'usage-event');
    expect(usage.path,
        'families/family-1/devices/device-1/usage_summaries/usage-1');
    expect(usage.data['memberUid'], 'child-uid');
    expect(usage.data['totalMilliseconds'], 3600000);
  });
  test('child.enforcement.applied writes to the rules-allowed enforcement_status path',
      () {
    final mutation = const FirestoreEventContract().businessMutation(
        operation: 'child.enforcement.applied',
        payload: {
          'familyId': 'family-1',
          'deviceId': 'device-1',
          'state': 'policyStale',
          'outcome': 'policyStale',
          'reason': 'policy_requires_fresh_delivery',
          'decidedAt': '2026-08-16T18:41:09.555659Z',
          'appliedAt': null,
          'policyVersion': null,
        },
        identity: const AuthenticatedIdentity(
            uid: 'child-uid', email: 'child@example.test', isAnonymous: false),
        idempotencyKey: 'enforcement-event');
    // The deployed rules allow create/update ONLY on
    // /devices/{deviceId}/enforcement_status/current and ONLY for the
    // device's own memberUid. Previously this operation fell through to
    // sync_metadata, which no rule permits — every write was permanently
    // permission-denied.
    expect(mutation.path,
        'families/family-1/devices/device-1/enforcement_status/current');
    expect(mutation.data['memberUid'], 'child-uid');
    expect(mutation.data['lastEnforcementState'], 'policyStale');
    expect(mutation.data['lastOutcome'], 'policyStale');
    expect(mutation.data['lastAppliedReason'], 'policy_requires_fresh_delivery');
    expect(mutation.data['evaluatedAtClient'], '2026-08-16T18:41:09.555659Z');
  });
  test('exception request and approved override retain child identity and device scope',
      () {
    const child = AuthenticatedIdentity(
        uid: 'child-uid', email: 'child@example.test', isAnonymous: false);
    final requested = const FirestoreEventContract().businessMutation(
        operation: 'child.exception.requested',
        payload: {
          'familyId': 'family-1',
          'requestId': 'request-1',
          'childDeviceId': 'device-1',
          'childMemberId': 'child-1',
          'childUid': 'child-uid',
          'target': 'com.google.android.youtube',
          'requestedDurationMinutes': 15,
          'reason': 'homework',
          'createdAt': '2026-08-12T12:00:00.000Z',
          'requestExpiresAt': '2026-08-13T12:00:00.000Z',
          'status': 'pending',
        },
        identity: child,
        idempotencyKey: 'request-event');
    expect(requested.path, 'families/family-1/exception_requests/request-1');
    expect(requested.data['childUid'], 'child-uid');
    expect(requested.data['requestedDurationMinutes'], 15);
    final override = const FirestoreEventContract().businessMutation(
        operation: 'policy.override.created',
        payload: {
          'familyId': 'family-1',
          'overrideId': 'override-1',
          'target': 'com.google.android.youtube',
          'allowed': true,
          'expiresAt': '2026-08-12T12:15:00.000Z',
          'createdByMemberId': 'parent-1',
          'childDeviceId': 'device-1',
        },
        identity: const AuthenticatedIdentity(
            uid: 'parent-uid', email: 'parent@example.test', isAnonymous: false),
        idempotencyKey: 'override-event');
    expect(override.data['childDeviceId'], 'device-1');
  });
  test('adult invitation contract creates a family-scoped invitation and atomic account-keyed membership',
      () {
    const owner = AuthenticatedIdentity(
        uid: 'owner-uid', email: 'owner@example.test', isAnonymous: false);
    const recipient = AuthenticatedIdentity(
        uid: 'adult-uid', email: 'adult@example.test', isAnonymous: false);
    const contract = FirestoreEventContract();
    final invited = contract.businessMutation(
        operation: 'family.member.invited',
        payload: {
          'familyId': 'family-1',
          'invitationId': 'invite-1',
          'inviterMemberId': 'owner-local-1',
          'targetEmail': 'adult@example.test',
          'proposedRole': 'coParent',
          'createdAt': '2026-08-12T12:00:00.000Z',
          'expiresAt': '2026-08-19T12:00:00.000Z',
        },
        identity: owner,
        idempotencyKey: 'invite-event-1');
    expect(invited.path, 'families/family-1/invitations/invite-1');
    expect(invited.data['status'], 'pending');
    expect(invited.data['inviterMemberId'], 'owner-local-1');

    final accepted = contract.businessMutation(
        operation: 'family.member.accepted',
        payload: {
          'familyId': 'family-1',
          'invitationId': 'invite-1',
          'memberId': 'adult-local-1',
          'accountUid': 'adult-uid',
          'displayName': 'Adult',
          'role': 'coParent',
          'acceptedAt': '2026-08-12T12:05:00.000Z',
        },
        identity: recipient,
        idempotencyKey: 'accept-event-1');
    expect(accepted.path, 'families/family-1/invitations/invite-1');
    expect(accepted.data['acceptedAccountUid'], 'adult-uid');
    expect(accepted.data['acceptedMemberId'], 'adult-local-1');
    expect(accepted.additionalWrites, hasLength(1));
    expect(accepted.additionalWrites.single.path,
        'families/family-1/members/adult-uid');
    expect(accepted.additionalWrites.single.data['memberId'], 'adult-local-1');
    expect(accepted.additionalWrites.single.data['memberUid'], 'adult-uid');
    expect(accepted.additionalWrites.single.data['role'], 'coParent');
    expect(
        () => contract.businessMutation(
            operation: 'family.member.accepted',
            payload: {
              'familyId': 'family-1',
              'invitationId': 'invite-1',
              'memberId': 'adult-local-1',
              'accountUid': 'another-account',
              'displayName': 'Adult',
              'role': 'coParent',
            },
            identity: recipient,
            idempotencyKey: 'accept-event-invalid'),
        throwsA(isA<FormatException>()));
  });
}
