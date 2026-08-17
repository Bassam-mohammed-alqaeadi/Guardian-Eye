import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';
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
    final syncStates = ref.watch(familyMemberSyncStatesProvider(familyId));
    // M9 E3: family-level pending sync derived from the REAL outbox state
    // (including `family.created`). A queued family mutation must never be
    // presented as fully synchronized.
    final familyPendingSync =
        ref.watch(familyPendingSyncProvider(familyId)).valueOrNull ?? false;
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
                    onPressed: () => _showInviteSheet(context, actor!),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(l10n.t('inviteMember')),
                  );
          },
        ),
        body: members.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => GuardianStateView(
              state: GuardianViewState.error,
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
                  ..._familyOverviewSection(context, items, deviceCounts.valueOrNull ?? const {}, syncStates.valueOrNull ?? const {}, actor, familyPendingSync),
                  if (actor == null)
                    ..._unauthorizedSection(context),
                  if (items.isEmpty)
                    GuardianStateView(
                        state: GuardianViewState.empty,
                        message: l10n.t('noMembers'))
                  else
                    ...items.map((member) => _MemberTile(
                        member: member,
                        deviceCount: deviceCounts.valueOrNull?[member.id] ?? 0,
                        syncState: syncStates.valueOrNull?[member.id] ??
                            SyncState.localOnly.name,
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
                        ? GuardianStateView(
                            state: GuardianViewState.empty,
                            message: l10n.t('pendingInvitations'))
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
                  const SizedBox(height: 24),
                  _InvitationHistorySection(
                      invitations: invitations.valueOrNull ?? const [],
                      onCancel: (invitation) =>
                          !_can(actor, FamilyPermission.inviteMembers) ||
                                  invitation.status !=
                                      FamilyInvitationStatus.pending
                              ? null
                              : () => _cancelInvitation(
                                  context, ref, actor!, invitation)),
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
      BuildContext context, FamilyMember owner) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(familyId: familyId, owner: owner),
    );
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
}class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.familyId, required this.owner});

  final String familyId;
  final FamilyMember owner;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final TextEditingController _email = TextEditingController();
  FamilyRole _role = FamilyRole.coParent;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(familyMembershipRepositoryProvider)
          .inviteAdult(
              familyId: widget.familyId,
              actorMemberId: widget.owner.id,
              targetEmail: _email.text,
              proposedRole: _role);
      ref.invalidate(familyInvitationsProvider(widget.familyId));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('invitationCreated'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.t('inviteAdult'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l10n.t('targetEmail')),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<FamilyRole>(
          initialValue: _role,
          decoration: InputDecoration(labelText: l10n.t('proposedRole')),
          items: [
            DropdownMenuItem(
                value: FamilyRole.parent,
                child: Text(l10n.t('roleParent'))),
            DropdownMenuItem(
                value: FamilyRole.coParent,
                child: Text(l10n.t('roleCoParent'))),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _role = value ?? _role),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CircularProgressIndicator()
              : Text(l10n.t('sendInvitation')),
        ),
      ]),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
      required this.deviceCount,
      this.syncState = 'localOnly',
      this.onChangeRole,
      this.onRevoke});

  final FamilyMember member;
  final int deviceCount;
  final String syncState;
  final VoidCallback? onChangeRole;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      child: ListTile(
        leading: GuardianIconBadge(
            icon: _memberIcon(member.role),
            background: GuardianTokens.guardianNavy),
        title: Text(member.displayName),
        subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text('${_roleLabel(l10n, member.role)} · '
                '${_statusLabel(l10n, member.status)} · '
                '${_syncStateLabel(l10n, syncState)}')),
            const SizedBox(width: 4),
            Flexible(child: Text(
                deviceCount == 0 ? l10n.t('notConnected') : '$deviceCount ${l10n.t('memberDevices')}')),
          ],),
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
    return GuardianCard(
      child: ListTile(
        leading: GuardianIconBadge(
            icon: Icons.mark_email_unread_outlined,
            background: GuardianTokens.statusWatch),
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

/// M5 honest per-member synchronization label derived from the outbox state.
/// Never claims remote completion without proof: `queued` and `failed` are
/// surfaced explicitly, and absence of an outbox entry is reported as the
/// local-only reference state.
String _syncStateLabel(AppLocalizations l10n, String syncState) {
  switch (syncState) {
    case 'synced':
      return l10n.t('memberSynced');
    case 'queued':
      return l10n.t('memberPendingSync');
    case 'failed':
    case 'blocked':
      return l10n.t('memberSyncFailed');
    default:
      return l10n.t('memberSavedLocal');
  }
}

// — M5 Family Management helpers —

/// M5 family overview — honest reference counts (members, children, devices)
/// computed from the local canonical data, never invented.
List<Widget> _familyOverviewSection(
    BuildContext context,
    List<FamilyMember> members,
    Map<String, int> deviceCounts,
    Map<String, String> syncStates,
    FamilyMember? actor,
    bool familyPendingSync) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final children = members
      .where((m) => m.role == FamilyRole.child)
      .length;
  final adultMembers = members.length - children;
  final totalDevices = deviceCounts.values.fold(0, (sum, c) => sum + c);
  final memberPending = syncStates.values
      .where((s) =>
          s == SyncState.queued.name ||
          s == SyncState.failed.name ||
          s == SyncState.blocked.name)
      .isNotEmpty;
  // E3 honesty: the family is presented as synchronized ONLY when no member
  // mutation and no family-level mutation (e.g. `family.created`) is still
  // pending in the outbox.
  final pendingSync = familyPendingSync || memberPending;
  return [
    GuardianCard(
      child: Semantics(
        label: l10n.t('familyOverview'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GuardianIconBadge(
                icon: Icons.group_outlined,
                background: GuardianTokens.guardianNavy,
                size: 36),
            const SizedBox(width: 10),
            Text(l10n.t('familyOverview'),
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          Text(l10n.t('familyOverview')),
          Row(children: [
            Icon(Icons.people_outline, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text('${l10n.t('memberCount')}: $adultMembers · '
                    '${l10n.t('childCount')}: $children')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.devices_outlined, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text('${l10n.t('deviceCount')}: $totalDevices')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            GuardianStatusChip(
                label: pendingSync
                    ? l10n.t('memberPendingSync')
                    : l10n.t('memberSynced'),
                kind: pendingSync
                    ? GuardianStatusKind.watch
                    : GuardianStatusKind.safe),
          ]),
        ]),
      ),
    ),
    const SizedBox(height: 16),
  ];
}

/// M5 unauthorized state — the verified actor could not be bound, so no
/// administrative action is exposed (fail-closed, consistent with the UX
/// constitution's honesty requirement).
List<Widget> _unauthorizedSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    GuardianCard(
      color: GuardianTokens.statusAlertSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GuardianIconBadge(
              icon: Icons.person_off_outlined,
              background: GuardianTokens.statusAlert,
              size: 36),
          const SizedBox(width: 8),
          Text(l10n.t('unauthorizedActor'),
              style: Theme.of(context).textTheme.titleSmall),
        ]),
        const SizedBox(height: 8),
        Text(l10n.t('actorVerificationRequired'),
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
    const SizedBox(height: 16),
  ];
}

/// M5 invitation history — read-only view of accepted, cancelled, and expired
/// invitations. Pending invitations are managed in the section above.
/// Cancelling a closed invitation is deliberately not offered.
class _InvitationHistorySection extends StatefulWidget {
  const _InvitationHistorySection(
      {required this.invitations, required this.onCancel});
  final List<FamilyInvitation> invitations;
  final VoidCallback? Function(FamilyInvitation) onCancel;

  @override
  State<_InvitationHistorySection> createState() =>
      _InvitationHistorySectionState();
}

class _InvitationHistorySectionState extends State<_InvitationHistorySection> {
  FamilyInvitationStatus? _filter;

  List<FamilyInvitation> get _filtered =>
      _filter == null
          ? widget.invitations
          : widget.invitations
              .where((i) => i.status == _filter)
              .toList(growable: false);

  bool get _isClosed =>
      widget.invitations.every((i) => i.status == FamilyInvitationStatus.pending);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nonPending = widget.invitations
        .where((i) => i.status != FamilyInvitationStatus.pending)
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('invitationHistory'), style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      if (nonPending == 0 && _isClosed)
        GuardianStateView(
            state: GuardianViewState.empty,
            message: l10n.t('invitationHistoryEmpty'))
      else
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HistoryChip(
                    label: l10n.t('invitationAll'),
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null)),
                _HistoryChip(
                    label: l10n.t('invitationAccepted'),
                    selected: _filter == FamilyInvitationStatus.accepted,
                    onTap: () => setState(
                        () => _filter = FamilyInvitationStatus.accepted)),
                _HistoryChip(
                    label: l10n.t('invitationCancelled'),
                    selected: _filter == FamilyInvitationStatus.cancelled,
                    onTap: () => setState(
                        () => _filter = FamilyInvitationStatus.cancelled)),
                _HistoryChip(
                    label: l10n.t('invitationExpired'),
                    selected: _filter == FamilyInvitationStatus.expired,
                    onTap: () => setState(
                        () => _filter = FamilyInvitationStatus.expired)),
              ],
            ),
            const SizedBox(height: 12),
            ..._filtered.map(
                (invitation) => _InvitationTile(invitation: invitation,
                    onCancel: widget.onCancel(invitation))),
          ],
        ),
    ]);
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.secondaryContainer,
      checkmarkColor: theme.colorScheme.onSecondaryContainer,
    );
  }
}
