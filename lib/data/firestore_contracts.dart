import 'firebase_auth_context.dart';

class FirestorePaths {
  static String user(String uid) => 'users/$uid';
  static String family(String familyId) => 'families/$familyId';
  static String member(String familyId, String memberId) =>
      '${family(familyId)}/members/$memberId';
  static String child(String familyId, String childId) =>
      '${family(familyId)}/children/$childId';
  static String device(String familyId, String deviceId) =>
      '${family(familyId)}/devices/$deviceId';
  static String pairing(String familyId, String pairingId) =>
      '${family(familyId)}/device_pairings/$pairingId';
  static String policy(String familyId, String policyId) =>
      '${family(familyId)}/policies/$policyId';
  static String policyOverride(String familyId, String overrideId) =>
      '${family(familyId)}/policy_overrides/$overrideId';
  static String deviceEnforcementStatus(String familyId, String deviceId) =>
      '${device(familyId, deviceId)}/enforcement_status/current';
  static String deviceUsageSummary(
          String familyId, String deviceId, String usageId) =>
      '${device(familyId, deviceId)}/usage_summaries/$usageId';
  static String exceptionRequest(String familyId, String requestId) =>
      '${family(familyId)}/exception_requests/$requestId';
  static String incident(String familyId, String incidentId) =>
      '${family(familyId)}/incidents/$incidentId';
  static String sos(String familyId, String sosId) =>
      '${family(familyId)}/sos/$sosId';
  static String location(String familyId, String locationId) =>
      '${family(familyId)}/locations/$locationId';
  static String geofence(String familyId, String geofenceId) =>
      '${family(familyId)}/geofences/$geofenceId';
  static String notification(String familyId, String notificationId) =>
      '${family(familyId)}/notification_events/$notificationId';
  static String syncMetadata(String familyId, String eventId) =>
      '${family(familyId)}/sync_metadata/$eventId';
}

class FirestoreMutation {
  const FirestoreMutation(
      {required this.path,
      required this.data,
      required this.idempotencyKey,
      this.additionalWrites = const []});
  final String path;
  final Map<String, Object?> data;
  final String idempotencyKey;
  final List<FirestoreAdditionalWrite> additionalWrites;
}

class FirestoreAdditionalWrite {
  const FirestoreAdditionalWrite({required this.path, required this.data});
  final String path;
  final Map<String, Object?> data;
}

class FirestoreAuthorizationGate {
  const FirestoreAuthorizationGate(this._auth);
  final AuthContext _auth;
  AuthenticatedIdentity requireIdentity() {
    final session = _auth.currentSession;
    if (!session.isAuthenticated) {
      throw AuthUnavailableException(
          session.reason ?? 'authenticated_identity_required');
    }
    return session.identity!;
  }
}

class FirestoreEventContract {
  const FirestoreEventContract();
  FirestoreMutation syncMetadata(
          {required String familyId,
          required String eventId,
          required String operation,
          required Map<String, Object?> payload,
          required AuthenticatedIdentity identity,
          required String idempotencyKey}) =>
      FirestoreMutation(
          path: FirestorePaths.syncMetadata(familyId, eventId),
          idempotencyKey: idempotencyKey,
          data: {
            'familyId': familyId,
            'eventId': eventId,
            'operation': operation,
            'payload': payload,
            'authorUid': identity.uid,
            'idempotencyKey': idempotencyKey,
            'status': 'accepted'
          });

  FirestoreMutation businessMutation(
      {required String operation,
      required Map<String, dynamic> payload,
      required AuthenticatedIdentity identity,
      required String idempotencyKey}) {
    final familyId = payload['familyId'] as String?;
    if (familyId == null || familyId.isEmpty) {
      throw const FormatException('familyId is required for remote sync.');
    }
    final common = <String, Object?>{
      'familyId': familyId,
      'idempotencyKey': idempotencyKey,
      'updatedByUid': identity.uid,
      'syncStatus': 'client_submitted'
    };
    switch (operation) {
      case 'family.created':
        final name = payload['name'] as String?;
        final parentId = payload['primaryParentId'] as String?;
        final parentName = payload['primaryParentName'] as String?;
        if (name == null || parentId == null || parentName == null) {
          throw const FormatException('family.created payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.family(familyId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'name': name,
              'ownerUid': identity.uid,
              'primaryParentId': parentId,
              'primaryParentName': parentName,
              'status': 'active'
            });
      case 'member.created':
        // M5 Option D: child membership is local-only until trusted device
        // provisioning. No `member.created` operation may ever be written
        // remotely — the UID-keyed remote member document is created by the
        // backend inside redeemChildDeviceProvisioning. A legacy row reaching
        // this point is malformed and must be blocked, never delivered.
        throw const FormatException(
            'member.created is local-only; child membership is created by trusted provisioning.');
      case 'device.enrolled':
        final deviceId = payload['deviceId'] as String?;
        final memberId = payload['memberId'] as String?;
        final role = payload['role'] as String?;
        if (deviceId == null || memberId == null || role == null) {
          throw const FormatException('device.enrolled payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.device(familyId, deviceId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'deviceId': deviceId,
              'memberId': memberId,
              'memberUid': payload['memberUid'],
              'ownerUid': identity.uid,
              'role': role,
              'status': 'active'
            });
      case 'device.revoked':
        final deviceId = payload['deviceId'] as String?;
        if (deviceId == null) {
          throw const FormatException('device.revoked payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.device(familyId, deviceId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'status': 'revoked',
              'revokedByUid': identity.uid,
              'revokedAtClient': payload['revokedAt']
            });
      case 'incident.created':
        final incidentId = payload['incidentId'] as String?;
        final category = payload['category'] as String?;
        final severity = payload['severity'] as String?;
        if (incidentId == null || category == null || severity == null) {
          throw const FormatException('incident.created payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.incident(familyId, incidentId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'incidentId': incidentId,
              'category': category,
              'severity': severity,
              'confidence': payload['confidence'],
              'source': payload['source'],
              'observedAtClient': payload['observedAt'],
              'modelVersion': payload['modelVersion'],
              'status': 'queued'
            });
      case 'sos.created':
        final sosId = payload['sosEventId'] as String?;
        if (sosId == null) {
          throw const FormatException('sos.created payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.sos(familyId, sosId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'sosId': sosId,
              'deviceId': payload['deviceId'],
              'status': 'queued',
              'latitude': payload['latitude'],
              'longitude': payload['longitude'],
              'accuracyMeters': payload['accuracyMeters'],
              'createdAtClient': payload['createdAt']
            });
      case 'notification.token.registered':
        final deviceId = payload['deviceId'] as String?;
        final token = payload['token'] as String?;
        final platform = payload['platform'] as String?;
        if (deviceId == null || token == null || platform == null) {
          throw const FormatException('notification token payload incomplete.');
        }
        return FirestoreMutation(
            path:
                '${FirestorePaths.device(familyId, deviceId)}/notification_tokens/$idempotencyKey',
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'deviceId': deviceId,
              'userUid': identity.uid,
              'token': token,
              'platform': platform,
              'status': 'active'
            });
      case 'policy.created' || 'policy.updated':
        final policyId = payload['policyId'] as String?;
        final name = payload['name'] as String?;
        final priority = payload['priority'] as int?;
        final enabled = payload['enabled'] as bool?;
        final startMinute = payload['startMinute'] as int?;
        final endMinute = payload['endMinute'] as int?;
        final targets = payload['restrictedTargets'];
        final version = payload['version'] as int?;
        if (policyId == null ||
            name == null ||
            priority == null ||
            enabled == null ||
            startMinute == null ||
            endMinute == null ||
            targets is! List ||
            version == null) {
          throw const FormatException('policy payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.policy(familyId, policyId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'policyId': policyId,
              'name': name,
              'priority': priority,
              'enabled': enabled,
              'startMinute': startMinute,
              'endMinute': endMinute,
              'restrictedTargets': targets,
              'dailyLimitMinutes': payload['dailyLimitMinutes'],
              'version': version
            });
      case 'policy.override.created':
        final overrideId = payload['overrideId'] as String?;
        final target = payload['target'] as String?;
        final allowed = payload['allowed'] as bool?;
        final expiresAt = payload['expiresAt'] as String?;
        final createdBy = payload['createdByMemberId'] as String?;
        if (overrideId == null ||
            target == null ||
            allowed == null ||
            expiresAt == null ||
            createdBy == null) {
          throw const FormatException('policy override payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.policyOverride(familyId, overrideId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'overrideId': overrideId,
              'target': target,
              'allowed': allowed,
              'expiresAtClient': expiresAt,
              'createdByMemberId': createdBy,
              'childDeviceId': payload['childDeviceId']
            });
      case 'child.device.state.updated' || 'child.policy.delivered':
        final deviceId = payload['deviceId'] as String?;
        final lifecycle = payload['lifecycle'] as String?;
        if (deviceId == null || lifecycle == null) {
          throw const FormatException(
              'child device status payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.deviceEnforcementStatus(familyId, deviceId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'deviceId': deviceId,
              'memberUid': identity.uid,
              'lifecycle': lifecycle,
              'requiredPolicyVersion': payload['requiredPolicyVersion'],
              'lastValidPolicyAtClient': payload['lastValidPolicyAt'],
              'lastDecision': payload['lastDecision'],
              'reportedAtClient': payload['updatedAt'],
              if (operation == 'child.policy.delivered')
                'deliveryState': 'local_persisted',
              if (operation == 'child.policy.delivered')
                'lastDeliveredPolicyId': payload['policyId'],
              if (operation == 'child.policy.delivered')
                'lastDeliveredPolicyVersion': payload['policyVersion']
            });
      case 'child.enforcement.applied':
        // M8 — device enforcement status. Written to the rules-authorized
        // `/devices/{deviceId}/enforcement_status/current` path (deployed
        // rules: create/update only for the device's own `memberUid`, and
        // only for `statusId == 'current'`). Previously this operation fell
        // through to `sync_metadata`, which no rule allows — every such
        // write was permanently `permission-denied`.
        final enforcementDeviceId = payload['deviceId'] as String?;
        if (enforcementDeviceId == null) {
          throw const FormatException(
              'child.enforcement.applied payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.deviceEnforcementStatus(
                familyId, enforcementDeviceId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'deviceId': enforcementDeviceId,
              'memberUid': identity.uid,
              'lastEnforcementState': payload['state'],
              'lastOutcome': payload['outcome'],
              'lastAppliedReason': payload['reason'],
              'policyVersion': payload['policyVersion'],
              'evaluatedAtClient': payload['decidedAt'],
              'appliedAtClient': payload['appliedAt']
            });
      case 'child.usage.observed':
        final deviceId = payload['deviceId'] as String?;
        final usageId = payload['usageId'] as String?;
        final target = payload['target'] as String?;
        final dayStart = payload['dayStart'] as String?;
        final totalMilliseconds = payload['totalMilliseconds'] as int?;
        final capturedAt = payload['capturedAt'] as String?;
        if (deviceId == null ||
            usageId == null ||
            target == null ||
            dayStart == null ||
            totalMilliseconds == null ||
            capturedAt == null ||
            totalMilliseconds < 0) {
          throw const FormatException('child usage payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.deviceUsageSummary(
                familyId, deviceId, usageId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'deviceId': deviceId,
              'memberUid': identity.uid,
              'usageId': usageId,
              'target': target,
              'dayStartClient': dayStart,
              'totalMilliseconds': totalMilliseconds,
              'lastUsedAtClient': payload['lastUsedAt'],
              'capturedAtClient': capturedAt
            });
      case 'child.exception.requested' ||
          'child.exception.approved' ||
          'child.exception.denied' ||
          'child.exception.cancelled':
        final requestId = payload['requestId'] as String?;
        final childDeviceId = payload['childDeviceId'] as String?;
        final childMemberId = payload['childMemberId'] as String?;
        final childUid = payload['childUid'] as String?;
        final target = payload['target'] as String?;
        final duration = payload['requestedDurationMinutes'] as int?;
        final status = payload['status'] as String?;
        final createdAt = payload['createdAt'] as String?;
        final requestExpiresAt = payload['requestExpiresAt'] as String?;
        if (requestId == null ||
            childDeviceId == null ||
            childMemberId == null ||
            childUid == null ||
            target == null ||
            duration == null ||
            duration <= 0 ||
            status == null ||
            createdAt == null ||
            requestExpiresAt == null) {
          throw const FormatException('child exception request payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.exceptionRequest(familyId, requestId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'requestId': requestId,
              'childDeviceId': childDeviceId,
              'childMemberId': childMemberId,
              'childUid': childUid,
              'target': target,
              'policyId': payload['policyId'],
              'requestedDurationMinutes': duration,
              'reason': payload['reason'],
              'reasonDetail': payload['reasonDetail'],
              'createdAtClient': createdAt,
              'requestExpiresAtClient': requestExpiresAt,
              'status': status,
              'reviewedByMemberId': payload['reviewedByMemberId'],
              'reviewedAtClient': payload['reviewedAt'],
              'overrideId': payload['overrideId'],
              'expiresAtClient': payload['expiresAt']
            });
      case 'family.member.invited':
        final invitationId = payload['invitationId'] as String?;
        final inviterMemberId = payload['inviterMemberId'] as String?;
        final targetEmail = payload['targetEmail'] as String?;
        final role = payload['proposedRole'] as String?;
        final expiresAt = payload['expiresAt'] as String?;
        if (invitationId == null || inviterMemberId == null || targetEmail == null ||
            role == null || !['parent', 'coParent'].contains(role) || expiresAt == null) {
          throw const FormatException('family invitation payload incomplete.');
        }
        return FirestoreMutation(
            path: '${FirestorePaths.family(familyId)}/invitations/$invitationId',
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'invitationId': invitationId,
              'inviterMemberId': inviterMemberId,
              'targetEmail': targetEmail,
              'proposedRole': role,
              'status': 'pending',
              'createdAtClient': payload['createdAt'],
              'expiresAt': DateTime.parse(expiresAt),
            });
      case 'family.invitation.cancelled':
        final invitationId = payload['invitationId'] as String?;
        if (invitationId == null) {
          throw const FormatException('family invitation cancellation incomplete.');
        }
        return FirestoreMutation(
            path: '${FirestorePaths.family(familyId)}/invitations/$invitationId',
            idempotencyKey: idempotencyKey,
            data: {...common, 'status': 'cancelled', 'cancelledAtClient': payload['cancelledAt']});
      case 'family.member.accepted':
        final invitationId = payload['invitationId'] as String?;
        final memberId = payload['memberId'] as String?;
        final accountUid = payload['accountUid'] as String?;
        final displayName = payload['displayName'] as String?;
        final role = payload['role'] as String?;
        if (invitationId == null || memberId == null || accountUid == null ||
            identity.uid != accountUid || displayName == null ||
            role == null || !['parent', 'coParent'].contains(role)) {
          throw const FormatException('family invitation acceptance incomplete.');
        }
        return FirestoreMutation(
            path: '${FirestorePaths.family(familyId)}/invitations/$invitationId',
            idempotencyKey: idempotencyKey,
            data: {...common, 'status': 'accepted', 'acceptedAtClient': payload['acceptedAt'], 'acceptedAccountUid': accountUid, 'acceptedMemberId': memberId},
            additionalWrites: [
              FirestoreAdditionalWrite(
                  path: FirestorePaths.member(familyId, accountUid),
                  data: {
                    'familyId': familyId,
                    'memberId': memberId,
                    'memberUid': accountUid,
                    'displayName': displayName,
                    'role': role,
                    'status': 'active',
                    'invitationId': invitationId,
                    'joinedAtClient': payload['acceptedAt'],
                    'idempotencyKey': idempotencyKey,
                  })
            ]);
      case 'family.member.revoked' || 'family.member.role.updated':
        final accountUid = payload['accountUid'] as String?;
        final memberId = payload['memberId'] as String?;
        if (accountUid == null || memberId == null) {
          throw const FormatException('family member remote payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.member(familyId, accountUid),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'memberId': memberId,
              if (operation == 'family.member.revoked') 'status': 'revoked',
              if (operation == 'family.member.revoked') 'revokedAtClient': payload['revokedAt'],
              if (operation == 'family.member.role.updated') 'role': payload['role'],
              if (operation == 'family.member.role.updated') 'roleUpdatedAtClient': payload['updatedAt'],
            });
      default:
        return syncMetadata(
            familyId: familyId,
            eventId: idempotencyKey,
            operation: operation,
            payload: payload,
            identity: identity,
            idempotencyKey: idempotencyKey);
    }
  }
}
