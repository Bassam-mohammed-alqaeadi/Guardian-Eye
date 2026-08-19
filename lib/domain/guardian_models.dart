enum FamilyRole { primaryParent, parent, coParent, spouse, child }

enum FamilyMemberStatus { invited, active, revoked, expired }

enum FamilyInvitationStatus { pending, accepted, cancelled, expired }

enum FamilyPermission {
  viewFamily,
  viewMembers,
  viewChildren,
  manageChildren,
  viewPolicies,
  managePolicies,
  reviewExceptionRequests,
  viewSafetyTimeline,
  manageMembers,
  inviteMembers,
  revokeMembers,
  manageRoles,
  manageDevices,
  viewUsage,
  viewChildStatus,
  requestOwnException,
  viewOwnPolicy,
  viewOwnUsage,
  viewOwnStatus,
  viewDeviceLinking,
  viewOwnPermissions,

  // FS-009 — Reports & Export. Adult roles may generate family reports;
  // a child may view its own activity within the exported report data.
  viewReports,
  viewOwnReport,

  // FS-011 — Family Rules & Policy Engine. Parents author and edit the
  // unified rule book; a spouse observes it read-only; a child sees only
  // the rules that apply to them (honest, read-only view).
  viewFamilyRules,
  manageFamilyRules,
  viewOwnRules,
}

enum DeviceRole { parentDevice, childDevice, spouseDevice, coParentDevice }

enum PairingState { pending, verified, enrolled, expired, rejected, revoked }

enum SyncState { localOnly, queued, synced, blocked, failed }

enum IncidentSeverity { low, medium, high, critical }

enum IncidentState {
  detected,
  localPending,
  synced,
  delivered,
  acknowledged,
  resolved
}

enum SafetyCategory {
  violence,
  adultContent,
  dangerousContent,
  bullying,
  suspiciousLanguage
}

extension EnumStorage on Enum {
  String get storageKey => name;
}

class GuardianFamily {
  const GuardianFamily(
      {required this.id, required this.name, required this.createdAt});
  final String id;
  final String name;
  final DateTime createdAt;
  factory GuardianFamily.fromMap(Map<String, Object?> map) => GuardianFamily(
      id: map['id']! as String,
      name: map['name']! as String,
      createdAt: DateTime.parse(map['created_at']! as String));
}

class FamilyMember {
  const FamilyMember(
      {required this.id,
      required this.familyId,
      required this.displayName,
      required this.role,
      required this.createdAt,
      this.status = FamilyMemberStatus.active,
      this.accountUid,
      this.invitationId,
      this.invitedAt,
      this.joinedAt,
      this.revokedAt,
      this.updatedAt});
  final String id;
  final String familyId;
  final String displayName;
  final FamilyRole role;
  final DateTime createdAt;
  final FamilyMemberStatus status;
  final String? accountUid;
  final String? invitationId;
  final DateTime? invitedAt;
  final DateTime? joinedAt;
  final DateTime? revokedAt;
  final DateTime? updatedAt;
  bool get isActive => status == FamilyMemberStatus.active;
  factory FamilyMember.fromMap(Map<String, Object?> map) => FamilyMember(
      id: map['id']! as String,
      familyId: map['family_id']! as String,
      displayName: map['display_name']! as String,
      role: FamilyRole.values.byName(map['role']! as String),
      createdAt: DateTime.parse(map['created_at']! as String),
      status: map['status'] == null
          ? FamilyMemberStatus.active
          : FamilyMemberStatus.values.byName(map['status']! as String),
      accountUid: map['account_uid'] as String?,
      invitationId: map['invitation_id'] as String?,
      invitedAt: map['invited_at'] == null
          ? null
          : DateTime.parse(map['invited_at']! as String),
      joinedAt: map['joined_at'] == null
          ? null
          : DateTime.parse(map['joined_at']! as String),
      revokedAt: map['revoked_at'] == null
          ? null
          : DateTime.parse(map['revoked_at']! as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at']! as String));
}

class FamilyInvitation {
  const FamilyInvitation(
      {required this.id,
      required this.familyId,
      required this.inviterMemberId,
      required this.targetEmail,
      required this.proposedRole,
      required this.status,
      required this.createdAt,
      required this.expiresAt,
      this.acceptedAt,
      this.acceptedAccountUid,
      this.acceptedMemberId,
      this.cancelledAt});
  final String id;
  final String familyId;
  final String inviterMemberId;
  final String targetEmail;
  final FamilyRole proposedRole;
  final FamilyInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedAccountUid;
  final String? acceptedMemberId;
  final DateTime? cancelledAt;
  bool isExpiredAt(DateTime now) =>
      status == FamilyInvitationStatus.pending && !expiresAt.isAfter(now.toUtc());
  factory FamilyInvitation.fromMap(Map<String, Object?> map) => FamilyInvitation(
      id: map['id']! as String,
      familyId: map['family_id']! as String,
      inviterMemberId: map['inviter_member_id']! as String,
      targetEmail: map['target_email']! as String,
      proposedRole: FamilyRole.values.byName(map['proposed_role']! as String),
      status: FamilyInvitationStatus.values.byName(map['status']! as String),
      createdAt: DateTime.parse(map['created_at']! as String),
      expiresAt: DateTime.parse(map['expires_at']! as String),
      acceptedAt: map['accepted_at'] == null ? null : DateTime.parse(map['accepted_at']! as String),
      acceptedAccountUid: map['accepted_account_uid'] as String?,
      acceptedMemberId: map['accepted_member_id'] as String?,
      cancelledAt: map['cancelled_at'] == null ? null : DateTime.parse(map['cancelled_at']! as String));
}

class GuardianDevice {
  const GuardianDevice(
      {required this.id,
      required this.familyId,
      required this.memberId,
      required this.role,
      required this.syncState,
      this.lastSyncedAt});
  final String id;
  final String familyId;
  final String memberId;
  final DeviceRole role;
  final SyncState syncState;
  final DateTime? lastSyncedAt;
}

class GuardianIncident {
  const GuardianIncident(
      {required this.id,
      required this.familyId,
      required this.category,
      required this.severity,
      required this.confidence,
      required this.status,
      required this.observedAt,
      required this.modelVersion,
      this.deviceId,
      this.actorUid});
  final String id;
  final String familyId;
  final SafetyCategory category;
  final IncidentSeverity severity;
  final double confidence;
  final IncidentState status;
  final DateTime observedAt;
  final String modelVersion;
  /// Local SQLite device UUID that produced this incident.
  /// Required by Firestore security rules for activeOwnedDevice authorization.
  final String? deviceId;
  /// Firebase Auth UID of the actor writing the incident to Firestore.
  final String? actorUid;
  factory GuardianIncident.fromMap(Map<String, Object?> map) =>
      GuardianIncident(
          id: map['id']! as String,
          familyId: map['family_id']! as String,
          category: SafetyCategory.values.byName(map['category']! as String),
          severity: IncidentSeverity.values.byName(map['severity']! as String),
          confidence: (map['confidence']! as num).toDouble(),
          status: IncidentState.values.byName(map['status']! as String),
          observedAt: DateTime.parse(map['observed_at']! as String),
          modelVersion: map['model_version']! as String,
          deviceId: map['device_id'] as String?,
          actorUid: map['actor_uid'] as String?);
}

class PairingRequest {
  const PairingRequest(
      {required this.id,
      required this.code,
      required this.expiresAt,
      this.targetMemberId});
  final String id;
  final String code;
  final DateTime expiresAt;
  final String? targetMemberId;
}

class PairingEnrollmentResult {
  const PairingEnrollmentResult(
      {required this.state, this.deviceId, this.reason});
  final PairingState state;
  final String? deviceId;
  final String? reason;
  bool get succeeded => state == PairingState.enrolled;
}

class PairingLifecycle {
  static bool canTransition(PairingState from, PairingState to) =>
      switch (from) {
        PairingState.pending => {
            PairingState.verified,
            PairingState.expired,
            PairingState.rejected,
            PairingState.revoked
          }.contains(to),
        PairingState.verified => {
            PairingState.enrolled,
            PairingState.expired,
            PairingState.rejected,
            PairingState.revoked
          }.contains(to),
        PairingState.enrolled => to == PairingState.revoked,
        PairingState.expired ||
        PairingState.rejected ||
        PairingState.revoked =>
          false,
      };
}

class GuardianDashboard {
  const GuardianDashboard(
      {required this.family,
      required this.children,
      required this.incidentsToday,
      required this.queuedOperations});
  final GuardianFamily? family;
  final List<FamilyMember> children;
  final int incidentsToday;
  final int queuedOperations;
}

class SafetyObservation {
  const SafetyObservation(
      {required this.category,
      required this.confidence,
      required this.source,
      required this.observedAt,
      required this.modelVersion,
      this.deviceId,
      this.actorUid});
  final SafetyCategory category;
  final double confidence;
  final String source;
  final DateTime observedAt;
  final String modelVersion;
  /// SQLite device UUID of the child device producing this observation.
  /// Required for Firestore activeOwnedDevice authorization.
  final String? deviceId;
  /// Firebase Auth UID of the actor submitting this observation to Firestore.
  final String? actorUid;
}
