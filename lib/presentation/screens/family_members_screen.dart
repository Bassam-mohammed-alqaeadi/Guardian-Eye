import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/family_membership_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/family_authorization.dart';
import '../../domain/guardian_models.dart';

class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key, required this.familyId, this.actorMemberId});

  final String familyId;
  final String? actorMemberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(familyMembersProvider(familyId));
    final invitations = ref.watch(familyInvitationsProvider(familyId));
    final deviceCounts = ref.watch(familyMemberDeviceCountsProvider(familyId));
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.t('familyMembers'))),
        floatingActionButton: members.when(
          loading: () => null,
          error: (_, __) => null,
          data: (items) {
            final actor = _activeActor(items);
            return !_can(actor, FamilyPermission.inviteMembers)
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _showInviteSheet(context, ref, actor!),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(l10n.t('inviteMember')),
                  );
          },
        ),
        body: members.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Failure(
              onRetry: () => ref.invalidate(familyMembersProvider(familyId))),
          data: (items) {
            final actor = _activeActor(items);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(familyMembersProvider(familyId));
                ref.invalidate(familyInvitationsProvider(familyId));
                ref.invalidate(familyMemberDeviceCountsProvider(familyId));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (items.isEmpty)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(l10n.t('noMembers'))))
                  else
                    ...items.map((member) => _MemberTile(
                        member: member,
                        deviceCount: deviceCounts.valueOrNull?[member.id] ?? 0,
                        onChangeRole: !_can(actor, FamilyPermission.manageRoles) ||
                                member.id == actor!.id
                            ? null
                            : () => _showRoleSheet(context, ref, actor, member),
                        onRevoke: !_can(actor, FamilyPermission.revokeMembers) ||
                                member.id == actor!.id
                            ? null
                            : () => _confirmRevoke(context, ref, actor, member))),
                  const SizedBox(height: 24),
                  Text(l10n.t('pendingInvitations'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  invitations.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Text(l10n.t('error')),
                    data: (items) => items.isEmpty
                        ? Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(l10n.t('pendingInvitations'))))
                        : Column(
                            children: items
                                .map((invitation) => _InvitationTile(
                                    invitation: invitation,
                                    onCancel: !_can(actor, FamilyPermission.inviteMembers) ||
                                            invitation.status !=
                                                FamilyInvitationStatus.pending
                                        ? null
                                        : () => _cancelInvitation(
                                            context, ref, actor!, invitation)))
                                .toList(growable: false)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  FamilyMember? _activeActor(List<FamilyMember> members) {
    if (actorMemberId == null) return null;
    for (final member in members) {
      if (member.id == actorMemberId && member.isActive) {
        return member;
      }
    }
    return null;
  }

  bool _can(FamilyMember? actor, FamilyPermission permission) =>
      actor != null && const FamilyAuthorization().hasPermission(actor, permission);

  Future<void> _showInviteSheet(
      BuildContext context, WidgetRef ref, FamilyMember owner) async {
    final l10n = AppLocalizations.of(context);
    final email = TextEditingController();
    var role = FamilyRole.coParent;
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.t('inviteAdult'),
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.t('targetEmail')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FamilyRole>(
              initialValue: role,
              decoration: InputDecoration(labelText: l10n.t('proposedRole')),
              items: [
                DropdownMenuItem(
                    value: FamilyRole.parent,
                    child: Text(l10n.t('roleParent'))),
                DropdownMenuItem(
                    value: FamilyRole.coParent,
                    child: Text(l10n.t('roleCoParent'))),
              ],
              onChanged: saving
                  ? null
                  : (value) => setSheetState(() => role = value ?? role),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setSheetState(() => saving = true);
                      try {
                        await ref
                            .read(familyMembershipRepositoryProvider)
                            .inviteAdult(
                                familyId: familyId,
                                actorMemberId: owner.id,
                                targetEmail: email.text,
                                proposedRole: role);
                        ref.invalidate(familyInvitationsProvider(familyId));
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.t('invitationCreated'))));
                        }
                      } catch (_) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(l10n.t('error'))));
                        }
                        if (sheetContext.mounted) setSheetState(() => saving = false);
                      }
                    },
              child: saving
                  ? const CircularProgressIndicator()
                  : Text(l10n.t('sendInvitation')),
            ),
          ]),
        ),
      ),
    );
    email.dispose();
  }

  Future<void> _showRoleSheet(BuildContext context, WidgetRef ref,
      FamilyMember owner, FamilyMember member) async {
    final l10n = AppLocalizations.of(context);
    var role = member.role;
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.t('changeRole'),
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<FamilyRole>(
              initialValue: role,
              items: [
                DropdownMenuItem(
                    value: FamilyRole.parent,
                    child: Text(l10n.t('roleParent'))),
                DropdownMenuItem(
                    value: FamilyRole.coParent,
                    child: Text(l10n.t('roleCoParent'))),
              ],
              onChanged: saving
                  ? null
                  : (value) => setSheetState(() => role = value ?? role),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setSheetState(() => saving = true);
                      try {
                        await ref
                            .read(familyMembershipRepositoryProvider)
                            .updateAdultRole(
                                familyId: familyId,
                                actorMemberId: owner.id,
                                targetMemberId: member.id,
                                role: role);
                        ref.invalidate(familyMembersProvider(familyId));
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (_) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(l10n.t('error'))));
                          setSheetState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const CircularProgressIndicator()
                  : Text(l10n.t('changeRole')),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref,
      FamilyMember owner, FamilyMember member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(l10n.t('revokeAccess')),
              content: Text(l10n.t('confirmRevoke')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.t('cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(l10n.t('confirm'))),
              ],
            ));
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(familyMembershipRepositoryProvider).revokeMember(
          familyId: familyId,
          actorMemberId: owner.id,
          targetMemberId: member.id);
      ref.invalidate(familyMembersProvider(familyId));
      ref.invalidate(familyMemberDeviceCountsProvider(familyId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
      }
    }
  }

  Future<void> _cancelInvitation(BuildContext context, WidgetRef ref,
      FamilyMember owner, FamilyInvitation invitation) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(familyMembershipRepositoryProvider).cancelInvitation(
          familyId: familyId,
          invitationId: invitation.id,
          actorMemberId: owner.id);
      ref.invalidate(familyInvitationsProvider(familyId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
      }
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile(
      {required this.member,
      required this.deviceCount,
      this.onChangeRole,
      this.onRevoke});

  final FamilyMember member;
  final int deviceCount;
  final VoidCallback? onChangeRole;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_memberIcon(member.role))),
        title: Text(member.displayName),
        subtitle: Text('${_roleLabel(l10n, member.role)} · '
            '${_statusLabel(l10n, member.status)}\n'
            '${deviceCount == 0 ? l10n.t('notConnected') : '$deviceCount ${l10n.t('memberDevices')}'}'),
        isThreeLine: true,
        trailing: onChangeRole == null && onRevoke == null
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'role') onChangeRole?.call();
                  if (value == 'revoke') onRevoke?.call();
                },
                itemBuilder: (_) => [
                  if (onChangeRole != null)
                    PopupMenuItem(value: 'role', child: Text(l10n.t('changeRole'))),
                  if (onRevoke != null)
                    PopupMenuItem(value: 'revoke', child: Text(l10n.t('revokeAccess'))),
                ],
              ),
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({required this.invitation, this.onCancel});

  final FamilyInvitation invitation;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mark_email_unread_outlined),
        title: Text(invitation.targetEmail),
        subtitle: Text('${_roleLabel(l10n, invitation.proposedRole)} · '
            '${_invitationStatusLabel(l10n, invitation.status)}\n'
            '${l10n.t('invitationExpiry')}: ${MaterialLocalizations.of(context).formatShortDate(invitation.expiresAt.toLocal())}'),
        isThreeLine: true,
        trailing: onCancel == null
            ? null
            : TextButton(onPressed: onCancel, child: Text(l10n.t('cancelInvitation'))),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
      child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context).t('retry'))));
}

IconData _memberIcon(FamilyRole role) => switch (role) {
      FamilyRole.primaryParent => Icons.admin_panel_settings_outlined,
      FamilyRole.parent || FamilyRole.coParent => Icons.person_outline,
      FamilyRole.spouse => Icons.people_outline,
      FamilyRole.child => Icons.child_care_outlined,
    };

String _roleLabel(AppLocalizations l10n, FamilyRole role) => switch (role) {
      FamilyRole.primaryParent => l10n.t('roleOwner'),
      FamilyRole.parent => l10n.t('roleParent'),
      FamilyRole.coParent => l10n.t('roleCoParent'),
      FamilyRole.spouse => l10n.t('roleSpouse'),
      FamilyRole.child => l10n.t('roleChild'),
    };

String _statusLabel(AppLocalizations l10n, FamilyMemberStatus status) =>
    switch (status) {
      FamilyMemberStatus.active => l10n.t('statusActive'),
      FamilyMemberStatus.invited => l10n.t('statusInvited'),
      FamilyMemberStatus.revoked => l10n.t('statusRevoked'),
      FamilyMemberStatus.expired => l10n.t('invitationExpired'),
    };

String _invitationStatusLabel(
        AppLocalizations l10n, FamilyInvitationStatus status) =>
    switch (status) {
      FamilyInvitationStatus.pending => l10n.t('invitationPending'),
      FamilyInvitationStatus.accepted => l10n.t('invitationAccepted'),
      FamilyInvitationStatus.cancelled => l10n.t('invitationCancelled'),
      FamilyInvitationStatus.expired => l10n.t('invitationExpired'),
    };
