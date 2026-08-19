import 'guardian_models.dart';

class FamilyDraft {
  const FamilyDraft(
      {required this.familyName, required this.primaryParentName});
  final String familyName;
  final String primaryParentName;
  bool get isValid =>
      familyName.trim().isNotEmpty && primaryParentName.trim().isNotEmpty;
}

class ChildDraft {
  const ChildDraft({required this.displayName});
  final String displayName;
  bool get isValid => displayName.trim().isNotEmpty;
}

class FamilyAuthorization {
  const FamilyAuthorization();
  Set<FamilyPermission> permissionsFor(FamilyRole role) => switch (role) {
        FamilyRole.primaryParent => Set<FamilyPermission>.from(FamilyPermission.values),
        FamilyRole.parent || FamilyRole.coParent => {
            FamilyPermission.viewFamily,
            FamilyPermission.viewMembers,
            FamilyPermission.viewChildren,
            FamilyPermission.manageChildren,
            FamilyPermission.viewPolicies,
            FamilyPermission.managePolicies,
            FamilyPermission.reviewExceptionRequests,
            FamilyPermission.viewSafetyTimeline,
            FamilyPermission.viewUsage,
            FamilyPermission.viewChildStatus,
            FamilyPermission.manageDevices,
            // FS-015 — Device Linking & Enrollment. All adult actors may
            // observe the family's linking inventory and health verdicts.
            FamilyPermission.viewDeviceLinking,
            // FS-009 — adult actors may generate family reports and export
            // them (PDF / CSV). A co-parent reads, the primary parent manages.
            FamilyPermission.viewReports,
          },
        FamilyRole.child => {
            FamilyPermission.viewFamily,
            FamilyPermission.requestOwnException,
            FamilyPermission.viewOwnPolicy,
            FamilyPermission.viewOwnUsage,
            FamilyPermission.viewOwnStatus,
            // FS-015 DL-008 — the child device actor may view its own
            // permission ladder (honest, read-only).
            FamilyPermission.viewOwnPermissions,
            // FS-009 — a child may only see its own activity inside the
            // family report (honest, read-only view).
            FamilyPermission.viewOwnReport,
          },
        FamilyRole.spouse => {
            FamilyPermission.viewFamily,
            FamilyPermission.viewMembers,
            // FS-015 — a spouse observes the linking inventory but never
            // mutates device state.
            FamilyPermission.viewDeviceLinking,
            // FS-009 — a spouse observes reports but never mutates them.
            FamilyPermission.viewReports,
          },
      };
  bool hasPermission(FamilyMember member, FamilyPermission permission) =>
      member.isActive && permissionsFor(member.role).contains(permission);
  void require(FamilyMember member, FamilyPermission permission) {
    if (!hasPermission(member, permission)) {
      throw StateError('family_permission_denied:${permission.name}');
    }
  }
  bool canManageFamily(FamilyRole role) =>
      permissionsFor(role).contains(FamilyPermission.manageMembers);
  bool canViewSafetyEvents(FamilyRole role) => role != FamilyRole.child;
  bool canManageDevice(
          {required FamilyRole actorRole,
          required String actorMemberId,
          required String ownerMemberId}) =>
      actorMemberId == ownerMemberId || actorRole == FamilyRole.primaryParent;
  bool canAcknowledgeIncident(FamilyRole role) => role != FamilyRole.child;
}
