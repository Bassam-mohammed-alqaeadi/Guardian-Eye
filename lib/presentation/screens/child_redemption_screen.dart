import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../application/device_link_service.dart';
import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../application/remote_provisioning_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/guardian_models.dart';

/// Canonical child-device redemption screen (M4).
///
/// States are never collapsed: loading / success / invalid / expired /
/// locked / already used / unauthorized / offline / unknown error each render
/// an explicit localized explanation with a safe recovery path.
class ChildRedemptionScreen extends ConsumerStatefulWidget {
  const ChildRedemptionScreen({super.key, required this.familyId});
  final String familyId;

  @override
  ConsumerState<ChildRedemptionScreen> createState() =>
      _ChildRedemptionScreenState();
}

class _ChildRedemptionScreenState extends ConsumerState<ChildRedemptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  RedeemOutcome _outcome = RedeemOutcome.validating;
  String? _enrolledDeviceId;
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem(String targetMemberId) async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _outcome = RedeemOutcome.validating;
    });
    // M5 Option D: the canonical redemption path calls the trusted Guardian
    // Backend (`POST /api/redeem-child`), which creates `members/{childUid}` +
    // `devices/{deviceId}` in one atomic server transaction and binds the
    // child's own authenticated UID. When Firebase is unconfigured, the local
    // SQLite pairing flow remains the offline-first fallback.
    final pairingId = _pendingRequestId();
    RemoteRedeemResult? remote;
    try {
      remote = await ref.read(remoteProvisioningServiceProvider).redeem(
            familyId: widget.familyId,
            pairingId: pairingId ?? '',
            code: _codeController.text,
            deviceId: _deviceId,
          );
    } on RemoteProvisioningUnavailableException {
      remote = null;
    }
    if (!mounted) return;
    if (remote != null) {
      final result = remote;
      setState(() {
        _submitting = false;
        _outcome = _remoteOutcome(result.state);
        _enrolledDeviceId = result.deviceId;
      });
      if (result.succeeded && result.deviceId != null) {
        await ref.read(pairingRepositoryProvider).recordRemoteEnrollment(
              familyId: widget.familyId,
              deviceId: result.deviceId!,
              memberId: targetMemberId,
              ownerMemberId: targetMemberId,
              role: DeviceRole.childDevice.storageKey,
            );
      }
      return;
    }
    final result = await ref.read(deviceLinkServiceProvider).redeem(
        requestId: pairingId ?? '',
        code: _codeController.text,
        targetMemberId: targetMemberId,
      );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _outcome = result.outcome;
      _enrolledDeviceId = result.deviceId;
    });
  }

  /// Stable per-screen device identity used for remote redemption, so retries
  /// on the same screen reuse the same device id (idempotent enrollment).
  String get _deviceId => _screenDeviceId ??= const Uuid().v4();
  String? _screenDeviceId;

  RedeemOutcome _remoteOutcome(RemoteRedeemState state) => switch (state) {
        RemoteRedeemState.enrolled => RedeemOutcome.success,
        RemoteRedeemState.invalidCode => RedeemOutcome.codeInvalid,
        RemoteRedeemState.expired => RedeemOutcome.codeExpired,
        RemoteRedeemState.locked => RedeemOutcome.codeLocked,
        RemoteRedeemState.alreadyUsed ||
        RemoteRedeemState.deviceConflict ||
        RemoteRedeemState.memberConflict =>
          RedeemOutcome.codeAlreadyUsed,
        RemoteRedeemState.unauthorized ||
        RemoteRedeemState.unauthenticated =>
          RedeemOutcome.unauthorized,
        RemoteRedeemState.networkUnavailable =>
          RedeemOutcome.networkUnavailable,
        RemoteRedeemState.rejected || RemoteRedeemState.unknown =>
          RedeemOutcome.unknownError,
      };

  /// QR deep links (`guardian-eye://pair?request=...&code=...`) prefill the
  /// pending request id and code so the child can redeem by scanning without
  /// typing the code from memory. Route extras come from the issuer screen
  /// and are accessed through the canonical [GoRouterState] of this route.
  Map? _routeExtras() {
    try {
      final state = GoRouterState.of(context);
      return state.extra is Map ? state.extra as Map : null;
    } catch (_) {
      return null;
    }
  }

  String? _pendingRequestId() => _routeExtras()?['requestId'] as String?;

  String? _pendingCode() => _routeExtras()?['code'] as String?;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _codeController.text.isEmpty) {
        final prefilled = _pendingCode();
        if (prefilled != null) {
          _codeController.text = prefilled;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contextAsync = ref.watch(familyRuntimeContextProvider(widget.familyId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('redeemDevice'))),
      body: contextAsync.when(
        loading: () => _StateView(
          icon: Icons.hourglass_top,
          title: l10n.t('redeemValidating'),
          message: '',
        ),
        error: (_, __) => _OutcomeView(
          icon: Icons.cloud_off,
          title: l10n.t('unknownRedeemError'),
          message: l10n.t('unknownRedeemErrorBody'),
              primaryLabel: l10n.t('retryRedeemLater'),
              onPrimary: () => ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId)),
          secondaryLabel: l10n.t('goHome'),
          onSecondary: () => context.go('/'),
        ),
        data: (runtimeContext) {
          final targetChild = runtimeContext.children.isEmpty
              ? null
              : runtimeContext.children.first;
          if (targetChild == null) {
            return _OutcomeView(
              icon: Icons.info_outline,
              title: l10n.t('noChildToPair'),
              message: l10n.t('unauthorizedRedeemBody'),
              primaryLabel: l10n.t('goHome'),
              onPrimary: () => context.go('/'),
            );
          }
          return _OutcomeSurface(
            outcome: _outcome,
            enrolledDeviceId: _enrolledDeviceId,
            form: _RedeemForm(
              formKey: _formKey,
              controller: _codeController,
              submitting: _submitting,
              onSubmit: () => _redeem(targetChild.id),
            ),
            onRetry: () => setState(() {
              _outcome = RedeemOutcome.validating;
              _codeController.clear();
              _submitting = false;
            }),
            onGoHome: () => context.go('/'),
          );
        },
      ),
    );
  }
}

class _RedeemForm extends StatelessWidget {
  const _RedeemForm({
    required this.formKey,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.t('redeemTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(labelText: l10n.t('enterPairingCode')),
          validator: (value) {
            if (value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())) {
              return l10n.t('codeInvalid');
            }
            return null;
          },
          enabled: !submitting,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: submitting ? null : onSubmit,
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.t('redeemConfirm')),
        ),
      ]),
    );
  }
}

class _OutcomeSurface extends StatelessWidget {
  const _OutcomeSurface({
    required this.outcome,
    required this.enrolledDeviceId,
    required this.form,
    required this.onRetry,
    required this.onGoHome,
  });

  final RedeemOutcome outcome;
  final String? enrolledDeviceId;
  final Widget form;
  final VoidCallback onRetry;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    switch (outcome) {
      case RedeemOutcome.validating:
        return Center(child: form);
      case RedeemOutcome.success:
      case RedeemOutcome.pendingSync:
        final pending = outcome == RedeemOutcome.pendingSync;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                pending ? Icons.cloud_queue : Icons.check_circle_outline,
                size: 48,
                color: pending
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(l10n.t('redeemSuccess'),
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (enrolledDeviceId != null)
                Text('${l10n.t('linkedDevice')}: ${enrolledDeviceId!.substring(0, 8)}',
                    style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(pending
                      ? l10n.t('redemptionPendingHint')
                      : l10n.t('redeemSuccessBody'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              if (pending) ...[
                const SizedBox(height: 8),
                Text(l10n.t('pendingSync'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: onGoHome, child: Text(l10n.t('goHome'))),
            ]),
          ),
        );
      case RedeemOutcome.codeInvalid:
        return _OutcomeView(
          icon: Icons.cancel_outlined,
          title: l10n.t('codeInvalid'),
          message: l10n.t('codeInvalidBody'),
          primaryLabel: l10n.t('retry'),
          onPrimary: onRetry,
          secondaryLabel: l10n.t('goHome'),
          onSecondary: onGoHome,
        );
      case RedeemOutcome.codeExpired:
        return _OutcomeView(
          icon: Icons.schedule,
          title: l10n.t('codeExpired'),
          message: l10n.t('codeExpiredBody'),
          primaryLabel: l10n.t('retry'),
          onPrimary: onRetry,
          secondaryLabel: l10n.t('goHome'),
          onSecondary: onGoHome,
        );
      case RedeemOutcome.codeLocked:
        return _OutcomeView(
          icon: Icons.lock_outline,
          title: l10n.t('codeLocked'),
          message: l10n.t('codeLockedBody'),
          primaryLabel: l10n.t('goHome'),
          onPrimary: onGoHome,
        );
      case RedeemOutcome.codeAlreadyUsed:
      case RedeemOutcome.alreadyEnrolled:
        return _OutcomeView(
          icon: Icons.check_box_outline_blank,
          title: l10n.t('codeAlreadyUsed'),
          message: l10n.t('codeAlreadyUsedBody'),
          primaryLabel: l10n.t('goHome'),
          onPrimary: onGoHome,
        );
      case RedeemOutcome.unauthorized:
        return _OutcomeView(
          icon: Icons.block,
          title: l10n.t('unauthorizedRedeem'),
          message: l10n.t('unauthorizedRedeemBody'),
          primaryLabel: l10n.t('goHome'),
          onPrimary: onGoHome,
        );
      case RedeemOutcome.networkUnavailable:
        return _OutcomeView(
          icon: Icons.cloud_off,
          title: l10n.t('networkUnavailable'),
          message: l10n.t('networkUnavailableBody'),
          primaryLabel: l10n.t('retryRedeemLater'),
          onPrimary: onRetry,
          secondaryLabel: l10n.t('goHome'),
          onSecondary: onGoHome,
        );
      case RedeemOutcome.unknownError:
        return _OutcomeView(
          icon: Icons.error_outline,
          title: l10n.t('unknownRedeemError'),
          message: l10n.t('unknownRedeemErrorBody'),
          primaryLabel: l10n.t('retry'),
          onPrimary: onRetry,
          secondaryLabel: l10n.t('goHome'),
          onSecondary: onGoHome,
        );
    }
  }
}

class _OutcomeView extends StatelessWidget {
  const _OutcomeView({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ]),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}
