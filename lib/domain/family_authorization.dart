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
        FamilyRole.primaryParent =>
          Set<FamilyPermission>.from(FamilyPermission.values),
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
            // FS-011 — a co-parent observes and amends the rule book.
            FamilyPermission.viewFamilyRules,
            FamilyPermission.manageFamilyRules,
            // FS-007 — a co-parent authors tasks and verifies completions.
            FamilyPermission.viewTasks,
            FamilyPermission.manageTasks,
            // FS-008 — a co-parent authors rewards and approves spends.
            FamilyPermission.viewRewards,
            FamilyPermission.manageRewards,
            // Guardian AI — a co-parent observes the intelligence hub,
            // views insights and proposals, and manages consent scopes.
            FamilyPermission.viewAiInsights,
            FamilyPermission.manageAiConsent,
            // FS-013 — a co-parent authors decisions and manages routines.
            FamilyPermission.viewCoupleHarmony,
            FamilyPermission.manageCoupleDecisions,
            // FS-010 — Ephemeral Family Chat. Adult actors read and send
            // within role-scoped threads (family / per-member / spouse);
            // children are granted nothing and are fail-closed below.
            FamilyPermission.viewChat,
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
            // FS-011 — a child sees only the rules applied to them
            // (honest, read-only view).
            FamilyPermission.viewOwnRules,
            // FS-007 — a child self-reports completion of their own
            // tasks and sees only their own assignments (honest view).
            FamilyPermission.viewOwnTasks,
            FamilyPermission.requestOwnTaskCompletion,
            // FS-008 — a child sees only their own balance and ledger
            // and may request redemptions (parent decides, no silent
            // deduction).
            FamilyPermission.viewOwnRewards,
            FamilyPermission.requestOwnRedemption,
          },
        FamilyRole.spouse => {
            FamilyPermission.viewFamily,
            FamilyPermission.viewMembers,
            // FS-015 — a spouse observes the linking inventory but never
            // mutates device state.
            FamilyPermission.viewDeviceLinking,
            // FS-009 — a spouse observes reports but never mutates them.
            FamilyPermission.viewReports,
            // FS-011 — a spouse observes the rule book but never amends it.
            FamilyPermission.viewFamilyRules,
            // FS-007 — a spouse observes tasks and may verify a
            // self-report; the family author remains the primary parent.
            FamilyPermission.viewTasks,
            FamilyPermission.manageTasks,
            // FS-008 — a spouse observes the ledger but never mutates
            // balances or the catalog.
            FamilyPermission.viewRewards,
            // Guardian AI — a spouse observes insights read-only.
            FamilyPermission.viewAiInsights,
            // FS-013 — a spouse views harmony screens and their own
            // linking state; decisions remain with parent roles.
            FamilyPermission.viewCoupleHarmony,
            // FS-010 — a spouse participates in role-scoped chat threads
            // (including the symmetric spouse pair) but never manages
            // thread scope.
            FamilyPermission.viewChat,
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

  /// ST-001 — only the owner may view or change the family plan.
  bool canManageSubscription(FamilyRole role) =>
      role == FamilyRole.primaryParent;
}
