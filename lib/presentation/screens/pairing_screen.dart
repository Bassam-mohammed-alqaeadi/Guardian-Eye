import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../application/remote_provisioning_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/family_authorization.dart';
import '../../domain/guardian_models.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';

/// Canonical parent pairing issuance screen.
///
/// Extends the M3-era pairing screen only as needed for M4:
/// target-child selection (child members only), an expiry derived from the
/// actual `expiresAt` timestamp (no fabricated countdown), and an explicit
/// entry point to the child redemption surface. Authorization is delegated
/// verbatim to [FamilyRuntimeContext.can] / [FamilyAuthorization.permissionsFor]
/// (`manageDevices`) — never local role checks.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, required this.familyId});
  final String familyId;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  PairingRequest? _request;
  String? _targetMemberId;
  bool _issuing = false;
  String? _issueErrorKey;

  Future<void> _create() async {
    if (_targetMemberId == null) return;
    if (_issuing) return;
    setState(() => _issuing = true);
    try {
      // M5 Option D: the canonical production path issues through the trusted
      // Guardian Backend (`POST /api/provision-child`), which no longer
      // requires a remote child member to pre-exist. When Firebase is
      // unconfigured, the local SQLite pairing flow remains the offline-first
      // fallback. A reachable-but-failing backend is reported honestly — never
      // silently downgraded to a local code.
      final members = await ref
          .read(familyMembershipRepositoryProvider)
          .membersForFamily(widget.familyId);
      final displayName =
          members.firstWhere((m) => m.id == _targetMemberId).displayName;
      try {
        final issue = await ref
            .read(remoteProvisioningServiceProvider)
            .issue(
                familyId: widget.familyId,
                targetMemberId: _targetMemberId!,
                displayName: displayName);
        if (mounted) {
          setState(() {
            _request = PairingRequest(
                id: issue.pairingId,
                code: issue.code,
                expiresAt: issue.expiresAt,
                targetMemberId: _targetMemberId);
            _issueErrorKey = null;
          });
        }
      } on RemoteProvisioningUnavailableException {
        final request = await ref
            .read(pairingRepositoryProvider)
            .createParentAuthorizedRequest(
                familyId: widget.familyId,
                requestedRole: DeviceRole.childDevice,
                targetMemberId: _targetMemberId);
        if (mounted) {
          setState(() {
            _request = request;
            _issueErrorKey = null;
          });
        }
      } on RemoteProvisioningException catch (error) {
        if (mounted) {
          setState(() => _issueErrorKey = _errorKeyFor(error.reason));
        }
      } catch (_) {
        if (mounted) setState(() => _issueErrorKey = 'unknownRedeemError');
      }
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  String _errorKeyFor(String reason) {
    switch (reason) {
      case 'server_unreachable':
        return 'networkUnavailable';
      case 'parent_not_authorized':
      case 'unauthenticated':
        return 'unauthorizedActorBody';
      default:
        return 'provisioningServerError';
    }
  }

  /// Remaining whole minutes derived from the real expiry timestamp.
  String _expiryText(AppLocalizations l10n, DateTime expiresAt) {
    final now = DateTime.now().toUtc();
    final minutes = expiresAt.difference(now).inMinutes;
    if (minutes <= 0) return l10n.t('codeExpired');
    return l10n.t('pairingExpiryExpiresAt').replaceAll('{minutes}', '$minutes');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contextAsync = ref.watch(familyRuntimeContextProvider(widget.familyId));
    // DL-001: live inventory from the real pairing_sessions table.
    final sessionsAsync =
        ref.watch(pendingPairingRequestsProvider(widget.familyId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('pairDevice'))),
      body: contextAsync.when(
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator())),
        error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            message: l10n.t('unknownRedeemError'),
            onRetry: () =>
                ref.invalidate(familyRuntimeContextProvider(widget.familyId))),
        data: (runtimeContext) {
          if (!runtimeContext.can(FamilyPermission.manageDevices)) {
            return GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('unauthorizedActor'),
                message: l10n.t('unauthorizedActorBody'),
                onPrimaryAction: () =>
                    ref.invalidate(familyRuntimeContextProvider(widget.familyId)),
                primaryActionLabel: l10n.t('retry'));
          }
          final children = runtimeContext.children;
          if (children.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/device_pairing.png',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GuardianStateView(
                    state: GuardianViewState.empty,
                    message: l10n.t('noChildToPair'),
                  ),
                ],
              ),
            );
          }

          _targetMemberId ??= children.first.id;

          return Center(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _LockoutBanner(
                    sessionsAsync: sessionsAsync, familyId: widget.familyId),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _request == null
                  ? _IssuanceForm(
                      children: children,
                      selectedId: _targetMemberId!,
                      onChildChanged: (id) =>
                          setState(() => _targetMemberId = id),
                      issuing: _issuing,
                      errorKey: _issueErrorKey,
                      onCreate: _create,
                    )
                  : _IssuedView(
                      request: _request!,
                      familyId: widget.familyId,
                      childName: children
                          .firstWhere((c) => c.id == _targetMemberId)
                          .displayName,
                      expiryText: _expiryText(l10n, _request!.expiresAt),
                      onRedeem: () =>
                          context.pushNamed('deviceLink', extra: {
                        'familyId': widget.familyId,
                        'requestId': _request!.id,
                        'code': _request!.code,
                      }),
                    ),
                ),
                const SizedBox(height: 20),
                _InventoryCard(
                    sessionsAsync: sessionsAsync, familyId: widget.familyId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LockoutBanner extends ConsumerWidget {
  const _LockoutBanner(
      {required this.sessionsAsync, required this.familyId});
  final AsyncValue<List<Map<String, Object?>>> sessionsAsync;
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = sessionsAsync.valueOrNull ?? const [];
    final blocked =
        sessions.any((s) => (s['attempts'] as int? ?? 0) >= _maxAttempts);
    if (!blocked) return const SizedBox.shrink();
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.lock_outline,
              color: GuardianTokens.statusAlert, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l10n.t('dlLockoutActive'),
                style: const TextStyle(fontSize: 13.5)),
          ),
          TextButton(
            onPressed: () =>
                context.push('/safety/pairing/$familyId/lockout'),
            child: Text(l10n.t('dlReview'),
                style: const TextStyle(fontSize: 12.5)),
          ),
        ]),
      ),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard(
      {required this.sessionsAsync, required this.familyId});
  final AsyncValue<List<Map<String, Object?>>> sessionsAsync;
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 20, color: GuardianTokens.guardianTeal),
              const SizedBox(width: 8),
              Text(l10n.t('dlPendingSessions'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5)),
            ]),
            const SizedBox(height: 8),
            sessionsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => Text(l10n.t('retryHint'),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5)),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Text(l10n.t('dlNoPendingSessions'),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12.5));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sessions
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '• ${s['code'] ?? ''} — '
                              '${s['requested_role'] ?? ''} '
                              '(${(s['attempts'] as int? ?? 0)} '
                              '${l10n.t('dlAttemptsLabel')})',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12.5,
                                  fontFamily: GuardianTokens.fontFamily),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

const int _maxAttempts = 5;

class _IssuanceForm extends StatelessWidget {
  // DL-001 continuation: the issuance surface is wrapped by the FS-015
  // lockout + inventory state machine. Pending sessions are listed from
  // the real SQLite table so the parent sees exact real codes.
  const _IssuanceForm({
    required this.children,
    required this.selectedId,
    required this.onChildChanged,
    required this.issuing,
    required this.onCreate,
    this.errorKey,
  });

  final List<FamilyMember> children;
  final String selectedId;
  final ValueChanged<String> onChildChanged;
  final bool issuing;
  final VoidCallback onCreate;
  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l10n.t('pairForChild'),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<String?>(
        initialValue: selectedId,
        decoration: InputDecoration(labelText: l10n.t('selectChild')),
        items: children
            .map((c) =>
                DropdownMenuItem(value: c.id, child: Text(c.displayName)))
            .toList(),
        onChanged: issuing ? null : (id) {
          if (id != null) onChildChanged(id);
        },
      ),
      const SizedBox(height: 24),
      if (errorKey != null) ...[
        Text(AppLocalizations.of(context).t(errorKey!),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
      ],
      FilledButton(
        onPressed: issuing ? null : onCreate,
        child: issuing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l10n.t('generatePairing')),
      ),
    ]);
  }
}

class _IssuedView extends StatelessWidget {
  // DL-001 continuation: the issued view carries the FS-015 inventory
  // link — pending sessions for this family are fetched from the real
  // pairing_sessions table and rendered beside the QR code.
  const _IssuedView({
    required this.request,
    required this.familyId,
    required this.childName,
    required this.expiryText,
    required this.onRedeem,
  });

  final PairingRequest request;
  final String familyId;
  final String childName;
  final String expiryText;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GuardianCard(
        child: Column(children: [
          Row(children: [
            GuardianIconBadge(
                icon: Icons.qr_code_2_outlined,
                background: GuardianTokens.guardianNavy),
            const SizedBox(width: 14),
            Expanded(
              child: Text('${l10n.t('pairForChild')}: $childName',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ]),
          const SizedBox(height: 8),
          GuardianStatusChip(label: expiryText, kind: GuardianStatusKind.watch),
          const SizedBox(height: 16),
          QrImageView(
              data:
                  'guardian-eye://pair?request=${request.id}&code=${request.code}',
              size: 210),
          const SizedBox(height: 16),
          SelectableText(request.code,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 12),
          Text(l10n.t('pairingRedeemHint'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRedeem, child: Text(l10n.t('redeemDevice'))),
        ]),
      ),
    ]);
  }
}


// ignore: unused_element — FS-015 building block for future linking flows.
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.info_outline, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ignore: unused_element — FS-015 building block for future linking flows.
class _UnauthorizedBody extends StatelessWidget {
  const _UnauthorizedBody({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 32),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
