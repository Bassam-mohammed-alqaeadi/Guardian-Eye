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
  // FS-006 — SOS readiness roster. Each family owns its recipient list;
  // the documents mirror the local sos_recipients table.
  static String sosRecipient(String familyId, String recipientId) =>
      '${family(familyId)}/sos/recipients/$recipientId';
  static String location(String familyId, String locationId) =>
      '${family(familyId)}/locations/$locationId';
  static String geofence(String familyId, String geofenceId) =>
      '${family(familyId)}/geofences/$geofenceId';
  static String favoritePlace(String familyId, String placeKey) =>
      '${family(familyId)}/favorite_places/$placeKey';
  static String locationSetting(String familyId, String key) =>
      '${family(familyId)}/location_settings/$key';
  static String notification(String familyId, String notificationId) =>
      '${family(familyId)}/notification_events/$notificationId';
  static String syncMetadata(String familyId, String eventId) =>
      '${family(familyId)}/sync_metadata/$eventId';
  // FS-002 — Web Filtering. Real Firestore documents the parent app
  // writes through the outbox and the child app reads for enforcement.
  static String webHit(String familyId, String hitId) =>
      '${family(familyId)}/web_hits/$hitId';
  static String webDomain(String familyId, String domainId) =>
      '${family(familyId)}/web_domains/$domainId';
  static String webCategoryRule(String familyId, String ruleId) =>
      '${family(familyId)}/web_category_rules/$ruleId';
  static String webSetting(String familyId, String key) =>
      '${family(familyId)}/web_settings/$key';
  // FS-003 — Application Control. Per-app policies are parent-written;
  // child device agents read them for on-device enforcement and report
  // block history back. Allowlist entries and usage alert settings follow
  // the same document shape discipline as web domains and settings.
  static String appPolicy(String familyId, String policyId) =>
      '${family(familyId)}/app_policies/$policyId';
  static String appAllowlist(String familyId, String allowlistId) =>
      '${family(familyId)}/app_allowlist/$allowlistId';
  static String appBlockEvent(String familyId, String eventId) =>
      '${family(familyId)}/app_block_history/$eventId';
  static String usageAlertSetting(String familyId, String settingId) =>
      '${family(familyId)}/usage_alert_settings/$settingId';
  // FS-004 — Screenshot & Camera Control. Parent devices request captures;
  // child device agents deliver shots back to these collections. Every row
  // stays honest: a shot exists only after the agent ships it.
  static String monitoringShot(String familyId, String shotId) =>
      '${family(familyId)}/monitoring_shots/$shotId';
  static String monitoringSession(String familyId, String sessionId) =>
      '${family(familyId)}/monitoring_sessions/$sessionId';
  static String monitoringRequest(String familyId, String requestId) =>
      '${family(familyId)}/monitoring_requests/$requestId';
  static String monitoringSchedule(String familyId, String scheduleId) =>
      '${family(familyId)}/monitoring_schedules/$scheduleId';
  static String monitoringEvidence(String familyId, String evidenceId) =>
      '${family(familyId)}/monitoring_evidence/$evidenceId';
  // FS-005 — Special & Custom Modes.
  static String modeConfig(String familyId, String modeId) =>
      '${family(familyId)}/mode_configs/$modeId';
  static String modeActivation(String familyId, String activationId) =>
      '${family(familyId)}/mode_activations/$activationId';
  // FS-011 — Family Rules & Policy Engine. Parent-authored rules travel
  // through the outbox to Firestore; sibling devices read them through
  // the same collection so the policy stays family-wide.
  static String familyRule(String familyId, String ruleId) =>
      '${family(familyId)}/family_rules/$ruleId';
  // FS-007 — Family Tasks & Daily Schedules. Parent-authored tasks and
  // their append-only completion logs travel through the outbox.
  static String familyTask(String familyId, String taskId) =>
      '${family(familyId)}/tasks/$taskId';
  static String taskCompletion(String familyId, String logId) =>
      '${family(familyId)}/task_completions/$logId';
  // FS-008 — Points & Rewards. The catalog, pending claims and the
  // append-only ledger are family-scoped collections.
  static String familyReward(String familyId, String rewardId) =>
      '${family(familyId)}/rewards/$rewardId';
  static String rewardClaim(String familyId, String claimId) =>
      '${family(familyId)}/reward_claims/$claimId';
  static String rewardLedgerRow(String familyId, String ledgerId) =>
      '${family(familyId)}/reward_ledger/$ledgerId';
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
    // FS-007/FS-008 — tasks and rewards write through the same outbox
    // channel; the aggregate type travels inside the payload so the
    // switch below can discriminate subsystems without widening the
    // on-device contract signature.
    final aggregateType = payload['aggregate_type'] as String?;
    final aggregateId = payload['aggregate_id'] as String?;
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
      case 'device.transferred':
        // FS-015 DL-011 — the trusted backend treats the transfer as the
        // new device taking over the child's enrollment under its uid; the
        // old device row is server-revoked inside the same trusted callable,
        // so the client only asserts the new device identity here.
        final newDeviceId = payload['newDeviceId'] as String?;
        final memberId = payload['memberId'] as String?;
        if (newDeviceId == null || memberId == null) {
          throw const FormatException('device.transferred payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.device(familyId, newDeviceId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'deviceId': newDeviceId,
              'memberId': memberId,
              'memberUid': payload['memberUid'],
              'ownerUid': identity.uid,
              'role': payload['role'] ?? 'child',
              'status': 'active',
              'transferredAtClient': payload['transferredAt'],
              'oldDeviceId': payload['oldDeviceId']
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
              // deviceId — required by Firestore activeOwnedDevice rule.
              // actorUid — identifies the authenticated writer for audit.
              if (payload['deviceId'] != null) 'deviceId': payload['deviceId'],
              if (payload['actorUid'] != null) 'actorUid': payload['actorUid'],
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
              'actorUid': payload['actorUid'],
              'status': 'queued',
              'latitude': payload['latitude'],
              'longitude': payload['longitude'],
              'accuracyMeters': payload['accuracyMeters'],
              'createdAtClient': payload['createdAt']
            });
      case 'notification.requested':
        final notificationId = payload['notificationId'] as String?;
        if (notificationId == null) {
          throw const FormatException('notification.requested payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.notification(familyId, notificationId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'notificationId': notificationId,
              'kind': payload['kind'],
              'sosId': payload['sosId'],
              'incidentId': payload['incidentId'],
              'recipientId': payload['recipientId'],
              'requestedAtClient':
                  payload['requestedAt'] ?? DateTime.now().toUtc().toIso8601String(),
              'status': 'pending',
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
            path:
                FirestorePaths.deviceUsageSummary(familyId, deviceId, usageId),
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
          throw const FormatException(
              'child exception request payload incomplete.');
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
        if (invitationId == null ||
            inviterMemberId == null ||
            targetEmail == null ||
            role == null ||
            !['parent', 'coParent'].contains(role) ||
            expiresAt == null) {
          throw const FormatException('family invitation payload incomplete.');
        }
        return FirestoreMutation(
            path:
                '${FirestorePaths.family(familyId)}/invitations/$invitationId',
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
          throw const FormatException(
              'family invitation cancellation incomplete.');
        }
        return FirestoreMutation(
            path:
                '${FirestorePaths.family(familyId)}/invitations/$invitationId',
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'status': 'cancelled',
              'cancelledAtClient': payload['cancelledAt']
            });
      case 'family.member.accepted':
        final invitationId = payload['invitationId'] as String?;
        final memberId = payload['memberId'] as String?;
        final accountUid = payload['accountUid'] as String?;
        final displayName = payload['displayName'] as String?;
        final role = payload['role'] as String?;
        if (invitationId == null ||
            memberId == null ||
            accountUid == null ||
            identity.uid != accountUid ||
            displayName == null ||
            role == null ||
            !['parent', 'coParent'].contains(role)) {
          throw const FormatException(
              'family invitation acceptance incomplete.');
        }
        return FirestoreMutation(
            path:
                '${FirestorePaths.family(familyId)}/invitations/$invitationId',
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'status': 'accepted',
              'acceptedAtClient': payload['acceptedAt'],
              'acceptedAccountUid': accountUid,
              'acceptedMemberId': memberId
            },
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
          throw const FormatException(
              'family member remote payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.member(familyId, accountUid),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'memberId': memberId,
              if (operation == 'family.member.revoked') 'status': 'revoked',
              if (operation == 'family.member.revoked')
                'revokedAtClient': payload['revokedAt'],
              if (operation == 'family.member.role.updated')
                'role': payload['role'],
              if (operation == 'family.member.role.updated')
                'roleUpdatedAtClient': payload['updatedAt'],
            });
      // FS-001-adjacent — Safety incidents. `incident.created` seeds the
      // document; `incident.acknowledged` merges the acknowledged status on
      // the same document. Without this case the ack fell through to
      // `syncMetadata`, a path no deployed rule permits (the same failure
      // mode the M8 `child.enforcement.applied` fix closed).
      case 'incident.acknowledged':
        final ackIncidentId = payload['incidentId'] as String?;
        if (ackIncidentId == null) {
          throw const FormatException(
              'incident.acknowledged payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.incident(familyId, ackIncidentId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'familyId': familyId,
              'incidentId': ackIncidentId,
              'status': 'acknowledged',
              'acknowledgedAtClient': payload['acknowledgedAt'] ??
                  DateTime.now().toUtc().toIso8601String(),
            });
      // FS-002 — Web Filtering. These operations reach real Firestore
      // documents under the family (web_hits, web_domains, web_category_rules,
      // web_settings). The same idempotency discipline as every other
      // operation: a repeated key is a harmless merge, never a duplicate.
      case 'web.hit':
        final hitId = payload['hitId'] as String?;
        final hitChildId = payload['childId'] as String?;
        final hitDomain = payload['domain'] as String?;
        if (hitId == null || hitChildId == null || hitDomain == null) {
          throw const FormatException('web.hit payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webHit(familyId, hitId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'hitId': hitId,
              'childId': hitChildId,
              'childDisplayName': payload['childDisplayName'],
              'domain': hitDomain,
              'category': payload['category'],
              'blockedAt': payload['blockedAt'],
              'decision': payload['decision'] ?? 'blocked',
              'overriddenBy': payload['overriddenBy'],
              'recordedAtClient': payload['recordedAt']
            });
      case 'web.domain':
        final domainId = payload['domainId'] as String?;
        final domainKind = payload['kind'] as String?;
        if (domainId == null || domainKind == null) {
          throw const FormatException('web.domain payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webDomain(familyId, domainId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'domainId': domainId,
              'domain': payload['domain'],
              'kind': domainKind,
              'reason': payload['reason'],
              'enabled': true,
              'createdAtClient': payload['createdAt']
            });
      case 'web.domain.updated':
        final updDomainId = payload['domainId'] as String?;
        if (updDomainId == null) {
          throw const FormatException('web.domain.updated payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webDomain(familyId, updDomainId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'domainId': updDomainId,
              'enabled': payload['enabled'],
              'updatedAtClient': payload['updatedAt']
            });
      case 'web.domain.removal':
        final remDomainId = payload['domainId'] as String?;
        if (remDomainId == null) {
          throw const FormatException('web.domain.removal payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webDomain(familyId, remDomainId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'domainId': remDomainId,
              'removed': true,
              'removedAtClient': payload['removedAt']
            });
      case 'web.category':
        final catRuleId = payload['ruleId'] as String?;
        final catChildId = payload['childId'] as String?;
        final catCategory = payload['category'] as String?;
        if (catRuleId == null || catChildId == null || catCategory == null) {
          throw const FormatException('web.category payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webCategoryRule(familyId, catRuleId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'ruleId': catRuleId,
              'childId': catChildId,
              'childDisplayName': payload['childDisplayName'],
              'category': catCategory,
              'enabled': payload['enabled'],
              'updatedAtClient': payload['updatedAt']
            });
      case 'web.setting':
        final settingKey = payload['key'] as String?;
        if (settingKey == null) {
          throw const FormatException('web.setting payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webSetting(familyId, settingKey),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'key': settingKey,
              'value': payload['value'],
              'updatedAtClient': payload['updatedAt']
            });
      case 'web.hit.overridden':
        final ovHitId = payload['hitId'] as String?;
        if (ovHitId == null) {
          throw const FormatException('web.hit.overridden payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.webHit(familyId, ovHitId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'hitId': ovHitId,
              'overriddenBy': payload['overriddenBy'],
              'overriddenAtClient': payload['overriddenAt']
            });
      // FS-001 — Location & Geofencing. Consent-gated location updates land
      // on `locations/{locationId}` (device-written, parent-read); geofence
      // configuration lands on `geofences/{geofenceId}` (parent-written);
      // favorite places anchor geofences to named family places. The same
      // idempotency discipline as every other operation applies: a repeated
      // key is a harmless merge, never a duplicate.
      case 'location.updated':
        final locId = payload['locationId'] as String?;
        final locLatitude = payload['latitude'] as num?;
        final locLongitude = payload['longitude'] as num?;
        if (locId == null || locLatitude == null || locLongitude == null) {
          throw const FormatException('location.updated payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.location(familyId, locId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'locationId': locId,
              'deviceId': payload['deviceId'],
              'memberId': payload['memberId'],
              'latitude': locLatitude.toDouble(),
              'longitude': locLongitude.toDouble(),
              'accuracyMeters': payload['accuracyMeters'] ?? 100,
              'capturedAt': payload['capturedAt'],
              'batteryLevel': payload['batteryLevel'],
              'source': payload['source'] ?? 'device',
              'recordedAtClient': payload['capturedAt']
            });
      case 'geofence.created':
        final gfId = payload['geofenceId'] as String?;
        final gfName = payload['name'] as String?;
        final gfRadius = payload['radiusMeters'] as num?;
        if (gfId == null || gfName == null || gfRadius == null) {
          throw const FormatException('geofence.created payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.geofence(familyId, gfId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'geofenceId': gfId,
              'name': gfName,
              'boundary': {
                'latitude': (payload['latitude'] as num).toDouble(),
                'longitude': (payload['longitude'] as num).toDouble(),
                'radiusMeters': gfRadius.toDouble()
              },
              'alertOnEntry': payload['alertOnEntry'] ?? true,
              'alertOnExit': payload['alertOnExit'] ?? true,
              'memberIds': payload['memberIds'] ?? const <String>[],
              'placeKey': payload['placeKey'],
              'status': 'active',
              'version': payload['version'] ?? 1,
              'createdAtClient': payload['createdAt']
            });
      case 'geofence.updated':
        final updGfId = payload['geofenceId'] as String?;
        if (updGfId == null) {
          throw const FormatException('geofence.updated payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.geofence(familyId, updGfId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'geofenceId': updGfId,
              'name': payload['name'],
              'boundary': {
                'latitude': (payload['latitude'] as num).toDouble(),
                'longitude': (payload['longitude'] as num).toDouble(),
                'radiusMeters': (payload['radiusMeters'] as num).toDouble()
              },
              'alertOnEntry': payload['alertOnEntry'],
              'alertOnExit': payload['alertOnExit'],
              'memberIds': payload['memberIds'],
              'placeKey': payload['placeKey'],
              'version': (payload['version'] ?? 1) + 1,
              'updatedAtClient': payload['updatedAt']
            });
      case 'geofence.disabled':
        final disGfId = payload['geofenceId'] as String?;
        if (disGfId == null) {
          throw const FormatException('geofence.disabled payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.geofence(familyId, disGfId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'geofenceId': disGfId,
              'status': 'disabled',
              'disabledAtClient': payload['updatedAt'] ??
                  DateTime.now().toUtc().toIso8601String()
            });
      case 'favorite.place':
        final placeKey = payload['placeKey'] as String?;
        if (placeKey == null) {
          throw const FormatException('favorite.place payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.favoritePlace(familyId, placeKey),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'placeKey': placeKey,
              'name': payload['name'],
              'updatedAtClient': payload['updatedAt']
            });
      case 'location.setting':
        final locSettingKey = payload['key'] as String?;
        if (locSettingKey == null) {
          throw const FormatException('location.setting payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.locationSetting(familyId, locSettingKey),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'key': locSettingKey,
              'value': payload['value'],
              'updatedAtClient': payload['updatedAt']
            });
      // FS-003 — Application Control. Per-app block/allow/limit policies,
      // the trusted-app allowlist, the honest audit log of enforcement
      // events, and per-app usage alert thresholds. Child devices read
      // `app_policies` to enforce on-device and write `app_block_history`
      // back; only the owning device may write its own block history.
      case 'app.policy':
        final appPolicyId = payload['policyId'] as String?;
        final appPolicyTarget = payload['target'] as String?;
        final appPolicyAction = payload['action'] as String?;
        if (appPolicyId == null ||
            appPolicyTarget == null ||
            appPolicyAction == null) {
          throw const FormatException('app.policy payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.appPolicy(familyId, appPolicyId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'policyId': appPolicyId,
              'childId': payload['childId'],
              'target': appPolicyTarget,
              'action': appPolicyAction,
              'limitMilliseconds': payload['limitMilliseconds'],
              'ratingMax': payload['ratingMax'] ?? 'all',
              'syncState': payload['syncState'] ?? 'queued',
              'updatedByUid': identity.uid,
              'updatedAtClient': payload['updatedAt']
            });
      case 'app.policy.removed':
        final remPolicyId = payload['policyId'] as String?;
        if (remPolicyId == null) {
          throw const FormatException('app.policy.removed payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.appPolicy(familyId, remPolicyId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'policyId': remPolicyId,
              'removed': true,
              'removedAtClient': payload['removedAt']
            });
      case 'app.allowlist':
        final wlId = payload['allowlistId'] as String?;
        final wlTarget = payload['target'] as String?;
        if (wlId == null || wlTarget == null) {
          throw const FormatException('app.allowlist payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.appAllowlist(familyId, wlId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'allowlistId': wlId,
              'target': wlTarget,
              'reason': payload['reason'],
              'addedByUid': identity.uid,
              'createdAtClient': payload['createdAt']
            });
      case 'app.allowlist.removed':
        final remWlId = payload['allowlistId'] as String?;
        if (remWlId == null) {
          throw const FormatException(
              'app.allowlist.removed payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.appAllowlist(familyId, remWlId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'allowlistId': remWlId,
              'removed': true,
              'removedAtClient': payload['removedAt']
            });
      case 'app.block.history':
        final bhId = payload['eventId'] as String?;
        final bhTarget = payload['target'] as String?;
        if (bhId == null || bhTarget == null) {
          throw const FormatException('app.block.history payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.appBlockEvent(familyId, bhId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventId': bhId,
              'deviceId': payload['deviceId'],
              'childId': payload['childId'],
              'target': bhTarget,
              'eventType': payload['eventType'],
              'reason': payload['reason'],
              'createdAtClient': payload['createdAt']
            });
      case 'app.alert.setting':
        final asId = payload['settingId'] as String?;
        final asTarget = payload['target'] as String?;
        if (asId == null || asTarget == null) {
          throw const FormatException('app.alert.setting payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.usageAlertSetting(familyId, asId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'settingId': asId,
              'childId': payload['childId'],
              'target': asTarget,
              'thresholdMilliseconds': payload['thresholdMilliseconds'],
              'enabled': payload['enabled'] ?? true,
              'updatedAtClient': payload['updatedAt']
            });
      case 'monitoring.shot':
        final mShotId = payload['shotId'] as String?;
        if (mShotId == null) {
          throw const FormatException('monitoring.shot payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.monitoringShot(familyId, mShotId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'shotId': mShotId,
              'deviceId': payload['deviceId'],
              'childId': payload['childId'],
              'capturedAt': payload['capturedAt'],
              'bytesLength': payload['bytesLength'],
              'mimeType': payload['mimeType'] ?? 'image/png',
              'requestId': payload['requestId'],
              'scheduleId': payload['scheduleId'],
              'isEvidence': payload['isEvidence'] ?? false
            });
      case 'monitoring.session':
        final mSessionId = payload['sessionId'] as String?;
        if (mSessionId == null) {
          throw const FormatException('monitoring.session payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.monitoringSession(familyId, mSessionId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'sessionId': mSessionId,
              'deviceId': payload['deviceId'],
              'childId': payload['childId'],
              'kind': payload['kind'] ?? 'live',
              'state': payload['state'] ?? 'pending',
              'startedAt': payload['startedAt'],
              'endedAt': payload['endedAt']
            });
      case 'monitoring.request':
        final mRequestId = payload['requestId'] as String?;
        if (mRequestId == null) {
          throw const FormatException('monitoring.request payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.monitoringRequest(familyId, mRequestId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'requestId': mRequestId,
              'deviceId': payload['deviceId'],
              'childId': payload['childId'],
              'kind': payload['kind'] ?? 'shot',
              'state': payload['state'] ?? 'queued',
              'reason': payload['reason'],
              'createdAt': payload['createdAt'],
              'deliveredAt': payload['deliveredAt']
            });
      case 'monitoring.schedule':
        final mScheduleId = payload['scheduleId'] as String?;
        if (mScheduleId == null) {
          throw const FormatException(
              'monitoring.schedule payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.monitoringSchedule(familyId, mScheduleId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'scheduleId': mScheduleId,
              'deviceId': payload['deviceId'],
              'childId': payload['childId'],
              'startHour': payload['startHour'],
              'endHour': payload['endHour'],
              'intervalMinutes': payload['intervalMinutes'] ?? 30,
              'enabled': payload['enabled'] ?? true,
              'updatedAt': payload['updatedAt']
            });
      case 'monitoring.evidence':
        final mEvidenceId = payload['evidenceId'] as String?;
        if (mEvidenceId == null) {
          throw const FormatException(
              'monitoring.evidence payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.monitoringEvidence(familyId, mEvidenceId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'evidenceId': mEvidenceId,
              'shotId': payload['shotId'],
              'deviceId': payload['deviceId'],
              'childId': payload['childId'],
              'flagReason': payload['flagReason'] ?? 'parent_review',
              'state': payload['state'] ?? 'queued',
              'decidedBy': payload['decidedBy'],
              'decidedAt': payload['decidedAt']
            });
      // FS-005 — Special & Custom Modes. Modes are parent-authored; the
      // activation log stays honest because a child device agent decides
      // whether a requested mode is actually applied on-device.
      case 'mode.config':
        final mModeId = payload['modeId'] as String?;
        if (mModeId == null) {
          throw const FormatException('mode.config payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.modeConfig(familyId, mModeId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'modeId': mModeId,
              'name': payload['name'],
              'kind': payload['kind'] ?? 'custom',
              'action': payload['action'] ?? 'slowDown',
              'enabled': payload['enabled'] ?? true,
              'startMinute': payload['startMinute'] ?? 0,
              'endMinute': payload['endMinute'] ?? 0,
              'scheduleKind': payload['scheduleKind'] ?? 'daily',
              'weekdays': payload['weekdays'] ?? '',
              'oneshotAt': payload['oneshotAt'],
              'assignedChildIds': payload['assignedChildIds'] ?? '',
              'categoryRestrictions': payload['categoryRestrictions'] ?? '',
              'appRestrictions': payload['appRestrictions'] ?? '',
              'priority': payload['priority'] ?? 50,
              'note': payload['note'],
              'updatedAt': payload['updatedAt']
            });
      case 'mode.activation':
        final mActivationId = payload['activationId'] as String?;
        if (mActivationId == null) {
          throw const FormatException('mode.activation payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.modeActivation(familyId, mActivationId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'activationId': mActivationId,
              'modeId': payload['modeId'],
              'childId': payload['childId'],
              'state': payload['state'] ?? 'requested',
              'startedAt': payload['startedAt'],
              'endsAt': payload['endsAt'],
              'decidedBy': payload['decidedBy']
            });
      // FS-011 — Family Rules & Policy Engine. Parent-authored rules
      // travel through the outbox to Firestore; sibling devices read the
      // same collection so the policy stays family-wide. This must sit
      // AFTER the FS-007/FS-008 aggregate-gated cases below: its loose
      // 'create'|'update'|'delete' arm would otherwise swallow task and
      // reward rows before they are dispatched.
      case ('family.rule.created' ||
              'family.rule.updated' ||
              'family.rule.deleted' ||
              'family.rule.toggled' ||
              'create' ||
              'update' ||
              'delete')
          when aggregateType != 'family_task' &&
              aggregateType != 'family_reward' &&
              aggregateType != 'family_claim':
        // FS-011 outbox rows dispatch with operation 'create'|'update'|
        // 'delete' (aggregate_type 'family_rule'); the writer tags the
        // aggregate through the idempotencyKey family_rule:op:family:rule.
        final dispatchedEventType = operation == 'delete'
            ? 'family.rule.deleted'
            : 'family.rule.updated';
        final rRuleId = payload['ruleId'] as String?;
        if (rRuleId == null) {
          throw const FormatException('family.rule payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.familyRule(familyId, rRuleId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventType': dispatchedEventType,
              'ruleId': rRuleId,
              'kind': payload['kind'],
              'name': payload['name'],
              'summary': payload['summary'],
              'enabled': payload['enabled'] ?? true,
              'startMinute': payload['startMinute'] ?? 0,
              'endMinute': payload['endMinute'] ?? 0,
              'scheduleKind': payload['scheduleKind'] ?? 'daily',
              'weekdays': payload['weekdays'] ?? '',
              'oneshotAt': payload['oneshotAt'],
              'assignedChildIds': payload['assignedChildIds'] ?? '',
              'categoryTargets': payload['categoryTargets'] ?? '',
              'appTargets': payload['appTargets'] ?? '',
              'priority': payload['priority'] ?? 50,
              'action': payload['action'],
              'geofenceIds': payload['geofenceIds'] ?? '',
              'geofenceTrigger': payload['geofenceTrigger'] ?? 'entering',
              'linkedTaskId': payload['linkedTaskId'] ?? '',
              'createdAt': payload['createdAt'],
              'updatedAt': payload['updatedAt'],
              'syncState': payload['syncState']
            });
      case 'sos.recipient':
        final sRecipientId = payload['recipientId'] as String?;
        if (sRecipientId == null) {
          throw const FormatException('sos.recipient payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.sosRecipient(familyId, sRecipientId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'recipientId': sRecipientId,
              'role': payload['role'] ?? 'responder',
              'ordering': payload['ordering'] ?? 0,
              'addedAt': payload['addedAt']
            });
      case 'notification.acknowledged':
        final sNotificationId = payload['notificationId'] as String?;
        if (sNotificationId == null) {
          throw const FormatException(
              'notification.acknowledged payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.notification(familyId, sNotificationId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'notificationId': sNotificationId,
              'sosId': payload['sosId'],
              'recipientId': payload['recipientId'],
              'status': 'acknowledged',
              'acknowledgedAt': payload['acknowledgedAt']
            });
      // FS-007 — Family Tasks & Daily Schedules. Parent-authored tasks
      // and honest completion actions travel through the outbox.
      case ('create' || 'update' || 'cancel')
          when aggregateType == 'family_task':
        final tTaskId =
            payload['taskId'] as String? ?? payload['task_id'] as String?;
        if (tTaskId == null) {
          throw const FormatException('family.task payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.familyTask(familyId, tTaskId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventType': 'family.task.$operation',
              'taskId': tTaskId,
              'title': payload['title'] ?? payload['title'],
              'description': payload['description'],
              'dueMinute': payload['due_minute'] ?? payload['dueMinute'] ?? 0,
              'dueDate': payload['due_date'] ?? payload['dueDate'],
              'recurrence': payload['recurrence'] ?? 'none',
              'weekdays': payload['weekdays'] ?? '',
              'assignedChildIds': payload['assigned_child_ids'] ?? '',
              'linkedRuleId':
                  payload['linked_rule_id'] ?? payload['linkedRuleId'],
              'status': payload['status'] ?? 'scheduled',
              'createdByMemberId': payload['created_by_member_id'] ??
                  payload['createdByMemberId'],
              'createdAt': payload['created_at'] ?? payload['createdAt'],
              'updatedAt': payload['updated_at'] ?? payload['updatedAt'],
              'syncState': payload['sync_state'] ?? payload['syncState']
            });
      case ('completion-requested' || 'completed' || 'completion-declined')
          when aggregateType == 'family_task':
        final tChildId =
            payload['childId'] as String? ?? payload['child_id'] as String?;
        if (tChildId == null) {
          throw const FormatException(
              'family.task completion payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.taskCompletion(
                familyId, '$idempotencyKey-${payload['child_id'] ?? tChildId}'),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventType': 'family.task.completion',
              'familyId': familyId,
              'taskId': payload['taskId'] ?? payload['task_id'],
              'childId': tChildId,
              'action': payload['action'] ?? 'requested',
              'actorMemberId':
                  payload['actor_member_id'] ?? payload['actorMemberId'],
              'requestedAt': payload['requested_at'] ?? payload['requestedAt'],
              'completedAt': payload['completed_at'] ?? payload['completedAt'],
              'declinedAt': payload['declined_at'] ?? payload['declinedAt'],
              'note': payload['note']
            });
      // FS-008 — Points & Rewards. Catalog edits, pending claims and
      // the append-only ledger travel through the outbox; no silent
      // balance mutation ever leaves the device.
      case ('create' || 'update') when aggregateType == 'family_reward':
        final rRewardId =
            payload['rewardId'] as String? ?? payload['reward_id'] as String?;
        if (rRewardId == null) {
          throw const FormatException('family.reward payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.familyReward(familyId, rRewardId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventType': 'family.reward.catalog.updated',
              'rewardId': rRewardId,
              'name': payload['name'],
              'description': payload['description'],
              'costPoints':
                  payload['cost_points'] ?? payload['costPoints'] ?? 0,
              'expiryDays': payload['expiry_days'] ?? payload['expiryDays'],
              'enabled': payload['enabled'] ?? true,
              'createdByMemberId': payload['created_by_member_id'] ??
                  payload['createdByMemberId'],
              'createdAt': payload['created_at'] ?? payload['createdAt'],
              'updatedAt': payload['updated_at'] ?? payload['updatedAt'],
              'syncState': payload['sync_state'] ?? payload['syncState']
            });
      case ('requested' || 'decided') when aggregateType == 'family_claim':
        final cClaimId =
            payload['aggregateId'] as String? ?? aggregateId ?? idempotencyKey;
        return FirestoreMutation(
            path: FirestorePaths.rewardClaim(familyId, cClaimId),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventType': 'family.claim.$operation',
              'claimId': cClaimId,
              'rewardId': payload['reward_id'] ?? payload['rewardId'],
              'childId': payload['child_id'] ?? payload['childId'],
              'costPoints': payload['cost_points'] ?? payload['costPoints'],
              'decision': payload['decision'],
              'decidedBy': payload['decided_by'] ?? payload['decidedBy'],
              'requestedAt': payload['requested_at'] ?? payload['requestedAt'],
              'decidedAt': payload['decided_at'] ?? payload['decidedAt'],
              'note': payload['note']
            });
      case ('earned' || 'spent') when aggregateType == 'family_reward':
        final lChildId =
            payload['childId'] as String? ?? payload['child_id'] as String?;
        if (lChildId == null) {
          throw const FormatException(
              'family.reward ledger payload incomplete.');
        }
        return FirestoreMutation(
            path: FirestorePaths.rewardLedgerRow(
                familyId, '$lChildId-${payload['balance_after']}'),
            idempotencyKey: idempotencyKey,
            data: {
              ...common,
              'eventType': 'family.reward.$operation',
              'childId': lChildId,
              'delta': payload['delta'] ?? 0,
              'reason': payload['reason'] ?? 'manualGrant',
              'referenceId': payload['reference_id'] ?? payload['referenceId'],
              'balanceAfter':
                  payload['balance_after'] ?? payload['balanceAfter'] ?? 0,
              'actedBy': payload['acted_by'] ?? payload['actedBy'],
              'actedAt': payload['acted_at'] ?? payload['actedAt']
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
