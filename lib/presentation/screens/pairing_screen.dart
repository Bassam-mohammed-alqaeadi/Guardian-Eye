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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('pairDevice'))),
      body: contextAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorBody(message: l10n.t('unknownRedeemError')),
        data: (runtimeContext) {
          if (!runtimeContext.can(FamilyPermission.manageDevices)) {
            return _UnauthorizedBody(
                title: l10n.t('unauthorizedActor'),
                message: l10n.t('unauthorizedActorBody'));
          }
          final children = runtimeContext.children;
          if (children.isEmpty) {
            return _ErrorBody(message: l10n.t('noChildToPair'));
          }

          _targetMemberId ??= children.first.id;

          return Center(
            child: Padding(
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
          );
        },
      ),
    );
  }
}

class _IssuanceForm extends StatelessWidget {
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
      Text('${l10n.t('pairForChild')}: $childName',
          style: Theme.of(context).textTheme.titleMedium),
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
      const SizedBox(height: 8),
      Text(expiryText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 20),
      FilledButton(onPressed: onRedeem, child: Text(l10n.t('redeemDevice'))),
    ]);
  }
}

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
