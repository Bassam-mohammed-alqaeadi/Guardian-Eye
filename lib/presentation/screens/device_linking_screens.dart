import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../application/family_context_provider.dart';
import '../../application/family_membership_providers.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/device_linking.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

/// FS-015 — Device Linking & Enrollment screens (DL-002 … DL-011).
/// DL-001 is the extended `/safety/pairing/:familyId` pairing surface.
///
/// Honesty contract: a device is "healthy" only when its real
/// `last_synced_at` timestamp proves freshness; a pairing code is shown
/// only while the session is genuinely pending and unexpired; a transfer
/// only claims success when the new device row and its queued outbox
/// operation exist. Device linking never says "connected" unless the
/// enrollment evidence is on disk.
///
/// Shared authorization + loading guard for all DL-* screens, matching the
/// FS-001/FS-004/FS-006 pattern exactly: loading while the runtime
/// resolves, honest error for unbound actors, `roleNotAllowed` for missing
/// role permission.
Widget _guardedScaffold({
  required BuildContext context,
  required AppLocalizations l10n,
  required AsyncValue<FamilyRuntimeContext> runtime,
  required FamilyPermission requiredPermission,
  required Widget child,
}) {
  final contextValue = runtime.valueOrNull;
  if (contextValue == null || runtime.isLoading) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const GuardianStateView(state: GuardianViewState.loading),
      ),
    );
  }
  if (!contextValue.isVerified || contextValue.actor == null) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.error,
          title: l10n.t('roleNotAllowed'),
          message: l10n.t('authorizationFailure'),
        ),
      ),
    );
  }
  if (!contextValue.can(requiredPermission)) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.error,
          title: l10n.t('roleNotAllowed'),
          message: l10n.t('dlPermissionDenied'),
        ),
      ),
    );
  }
  return child;
}

String _roleLabel(AppLocalizations l10n, String role) {
  final DeviceRole? parsed =
      DeviceRole.values.where((r) => r.storageKey == role).firstOrNull;
  return switch (parsed) {
    DeviceRole.parentDevice => l10n.t('dlRoleParent'),
    DeviceRole.coParentDevice => l10n.t('dlRoleCoParent'),
    DeviceRole.spouseDevice => l10n.t('dlRoleSpouse'),
    DeviceRole.childDevice => l10n.t('dlRoleChild'),
    null => l10n.t('dlRoleUnknown'),
  };
}

Color _healthColor(DeviceHealthKind kind) => switch (kind) {
      DeviceHealthKind.healthy => GuardianTokens.statusSafe,
      DeviceHealthKind.stale => GuardianTokens.statusAlert,
      DeviceHealthKind.offline => GuardianTokens.statusSOS,
      DeviceHealthKind.revoked => Colors.grey,
    };

String _healthLabel(AppLocalizations l10n, DeviceHealthKind kind) =>
    switch (kind) {
      DeviceHealthKind.healthy => l10n.t('dlHealthHealthy'),
      DeviceHealthKind.stale => l10n.t('dlHealthStale'),
      DeviceHealthKind.offline => l10n.t('dlHealthOffline'),
      DeviceHealthKind.revoked => l10n.t('dlHealthRevoked'),
    };

// ──────────────────────── DL-002 lockout screen ────────────────────────
/// `/safety/pairing/:familyId/lockout` — DL-002. The honest 5-attempt
/// lockout view: the failed-attempt count comes straight from the pairing
/// session row, and the unlock path is a real counter reset (the session
/// rows are kept for audit — never deleted).
class DeviceLockoutScreen extends ConsumerStatefulWidget {
  const DeviceLockoutScreen({required this.familyId, super.key});
  final String familyId;
  @override
  ConsumerState<DeviceLockoutScreen> createState() =>
      _DeviceLockoutScreenState();
}

class _DeviceLockoutScreenState extends ConsumerState<DeviceLockoutScreen> {
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final latestSession =
        ref.watch(latestPairingSessionProvider(widget.familyId));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageDevices,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlLockoutTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (latestSession.valueOrNull == null)
                GuardianCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 36, color: GuardianTokens.guardianTeal),
                        const SizedBox(height: 12),
                        Text(l10n.t('dlNoLockout'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(l10n.t('dlNoLockoutMessage'),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13.5)),
                      ],
                    ),
                  ),
                )
              else ...[
                GuardianCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.block,
                            size: 34, color: GuardianTokens.statusSOS),
                        const SizedBox(height: 10),
                        Text(l10n.t('dlLockoutTitle'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.t('dlAttempts')}: '
                          '${latestSession.valueOrNull!['failure_count'] ?? 0} / 5',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13.5),
                        ),
                        const SizedBox(height: 6),
                        Text(l10n.t('dlLockoutHint'),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12.5)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _resetting
                              ? null
                              : () async {
                                  if (_resetting) return;
                                  setState(() => _resetting = true);
                                  try {
                                    final ok = await ref
                                        .read(pairingRepositoryProvider)
                                        .resetFailedAttempts(widget.familyId);
                                    if (mounted) {
                                      ref.invalidate(
                                          latestPairingSessionProvider(
                                              widget.familyId));
                                      if (ok) {
                                        context.pop();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    l10n.t('dlResetFailed'))));
                                      }
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() => _resetting = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  l10n.t('dlResetFailed'))));
                                    }
                                  }
                                },
                          icon: _resetting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.lock_reset),
                          label: Text(_resetting
                              ? l10n.t('loading')
                              : l10n.t('dlResetLockout')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (latestSession.hasError)
                GuardianStateView(
                  state: GuardianViewState.error,
                  title: l10n.t('loadingFailed'),
                  message: l10n.t('retryHint'),
                  onRetry: () => ref.invalidate(
                      latestPairingSessionProvider(widget.familyId)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────── DL-003 device enrollment ──────────────────────
/// `/enroll/:familyId/:code` — DL-003. The device enters the six-digit code
/// issued by the parent. Every character of state is derived from the real
/// session: an unknown code yields a real `dlCodeInvalid` reason, an
/// expired session yields `dlCodeExpired`, and only a live session moves to
/// the confirmation step. This screen is read-only on the session — no
/// failure counters are touched until the confirmation.
class DeviceEnrollScreen extends ConsumerStatefulWidget {
  const DeviceEnrollScreen({
    required this.familyId,
    required this.code,
    this.requestId,
    super.key,
  });
  final String familyId;
  final String code;
  final String? requestId;

  @override
  ConsumerState<DeviceEnrollScreen> createState() => _DeviceEnrollScreenState();
}

class _DeviceEnrollScreenState extends ConsumerState<DeviceEnrollScreen> {
  final _controller = TextEditingController();
  String? _errorKey;
  bool _submitting = false;
  bool _showScanner = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('guardian-eye://pair?')) {
        final uri = Uri.parse(rawValue);
        final code = uri.queryParameters['code'];
        if (code != null && code.length == 6) {
          setState(() {
            _controller.text = code;
            _showScanner = false;
          });
          _verify();
          return;
        }
      }
    }
  }

  Future<void> _verify() async {
    final value = _controller.text.replaceAll(' ', '').trim();
    if (value.length != 6) {
      setState(() => _errorKey = 'dlCodeTooShort');
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorKey = null;
    });
    try {
      final session = widget.requestId != null
          ? await ref
              .read(pairingRepositoryProvider)
              .sessionById(widget.requestId!)
          : await ref
              .read(pairingRepositoryProvider)
              .sessionForCode(widget.familyId, value);

      if (!mounted) return;
      if (session == null) {
        setState(() => _errorKey = 'dlCodeInvalid');
        return;
      }
      final state = PairingState.values.byName(session['status'] as String);
      final expired = DateTime.parse(session['expires_at'] as String)
          .isBefore(DateTime.now().toUtc());
      if (expired) {
        setState(() => _errorKey = 'dlCodeExpired');
        return;
      }
      switch (state) {
        case PairingState.pending || PairingState.verified:
          context.pushReplacement('/enroll/${widget.familyId}/$value/confirm');
          return;
        case PairingState.enrolled:
          context.go(
              '/child/${widget.familyId}/${session['target_member_id']}/dashboard');
          return;
        case PairingState.expired:
          setState(() => _errorKey = 'dlCodeExpired');
          return;
        case PairingState.rejected:
          setState(() => _errorKey = 'dlCodeRejected');
          return;
        case PairingState.revoked:
          setState(() => _errorKey = 'dlCodeRevoked');
          return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'dlCodeInvalid');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('dlEnrollTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: _showScanner
            ? Stack(
                children: [
                  MobileScanner(
                    onDetect: _onDetect,
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 30),
                      onPressed: () => setState(() => _showScanner = false),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: GuardianTokens.guardianTeal, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  GuardianCard(
                    child: Padding(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.devices_outlined,
                              size: 38, color: GuardianTokens.guardianTeal),
                          const SizedBox(height: 12),
                          Text(l10n.t('dlEnrollSubtitle'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13.5)),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showScanner = true),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(l10n.t('dlScanQr')),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(l10n.t('or'),
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _controller,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                                fontSize: 26,
                                letterSpacing: 8,
                                fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              hintText: '• • • • • •',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.4)),
                              counterText: '',
                            ),
                          ),
                          if (_errorKey != null) ...[
                            const SizedBox(height: 10),
                            Text(l10n.t(_errorKey!),
                                style: const TextStyle(
                                    color: GuardianTokens.statusSOS,
                                    fontSize: 13)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _verify,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check),
                            label: Text(_submitting
                                ? l10n.t('loading')
                                : l10n.t('dlVerifyCode')),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ──────────────────────── DL-004 enrollment confirmation ────────────────
/// `/enroll/:familyId/:code/confirm` — DL-004. The device actor selects
/// which family member this device will represent, then completes
/// verification-and-enrollment. Success is claimed only when the real
/// device row, lifecycle row and outbox operation exist (i.e. the result
/// returned by the repository is `enrolled`).
class DeviceEnrollConfirmScreen extends ConsumerStatefulWidget {
  const DeviceEnrollConfirmScreen({
    required this.familyId,
    required this.code,
    this.requestId,
    super.key,
  });
  final String familyId;
  final String code;
  final String? requestId;

  @override
  ConsumerState<DeviceEnrollConfirmScreen> createState() =>
      _DeviceEnrollConfirmScreenState();
}

class _DeviceEnrollConfirmScreenState
    extends ConsumerState<DeviceEnrollConfirmScreen> {
  String? _selectedMemberId;
  String? _selectedRole;
  bool _enrolling = false;
  String? _enrollErrorKey;

  Future<void> _enroll() async {
    if (_selectedMemberId == null || _selectedRole == null) return;
    if (_enrolling) return;
    setState(() {
      _enrolling = true;
      _enrollErrorKey = null;
    });
    try {
      final repo = ref.read(pairingRepositoryProvider);
      final session = widget.requestId != null
          ? await repo.sessionById(widget.requestId!)
          : await repo.sessionForCode(widget.familyId, widget.code);
      if (session == null) {
        if (!mounted) return;
        setState(() => _enrollErrorKey = 'dlCodeInvalid');
        return;
      }
      final runtime = ref.read(familyRuntimeContextProvider(widget.familyId));
      final ownerId = runtime.value?.actor?.id ?? '';
      final result = await repo.verifyAndEnroll(
          requestId: session['id'] as String,
          code: widget.code,
          memberId: _selectedMemberId!,
          ownerMemberId: ownerId);
      if (!mounted) return;
      if (result.succeeded) {
        // Real rows exist — safe to claim completion.
        context.go('/enroll/${widget.familyId}/success');
      } else {
        switch (result.reason) {
          case 'request_expired':
            setState(() => _enrollErrorKey = 'dlCodeExpired');
            return;
          case 'code_mismatch':
            setState(() => _enrollErrorKey = 'dlCodeInvalid');
            return;
          case 'too_many_attempts':
            setState(() => _enrollErrorKey = 'dlCodeRejected');
            return;
          case 'active_device_already_linked':
            setState(() => _enrollErrorKey = 'dlDeviceAlreadyLinked');
            return;
          default:
            setState(() => _enrollErrorKey = 'dlEnrollFailed');
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _enrollErrorKey = 'dlEnrollFailed');
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(familyMembersProvider(widget.familyId));
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('dlConfirmTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 36, color: GuardianTokens.guardianTeal),
                    const SizedBox(height: 10),
                    Text(l10n.t('dlConfirmSubtitle'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13.5)),
                    const SizedBox(height: 14),
                    if (membersAsync.valueOrNull == null &&
                        membersAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (membersAsync.valueOrNull == null)
                      Text(l10n.t('loadingFailed'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13))
                    else
                      ...membersAsync.valueOrNull!.map((m) {
                        final roles = _rolesForMember(m.role);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(m.displayName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            if (roles.length > 1) ...[
                              ...roles.map((role) => RadioListTile<String>(
                                    value: role,
                                    groupValue: _selectedMemberId == m.id
                                        ? _selectedRole
                                        : null,
                                    activeColor: GuardianTokens.guardianTeal,
                                    title: Text(_roleLabel(l10n, role),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13)),
                                    onChanged: (v) => setState(() {
                                      _selectedMemberId = m.id;
                                      _selectedRole = v;
                                    }),
                                  )),
                            ] else if (roles.isNotEmpty) ...[
                              RadioListTile<String>(
                                value: roles.first,
                                groupValue: _selectedMemberId == m.id
                                    ? _selectedRole
                                    : null,
                                activeColor: GuardianTokens.guardianTeal,
                                title: Text(_roleLabel(l10n, roles.first),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                onChanged: (v) => setState(() {
                                  _selectedMemberId = m.id;
                                  _selectedRole = v;
                                }),
                              ),
                            ],
                          ],
                        );
                      }).toList(),
                    if (_enrollErrorKey != null) ...[
                      const SizedBox(height: 10),
                      Text(l10n.t(_enrollErrorKey!),
                          style: const TextStyle(
                              color: GuardianTokens.statusSOS, fontSize: 13)),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: (_selectedMemberId == null ||
                              _selectedRole == null ||
                              _enrolling)
                          ? null
                          : _enroll,
                      icon: _enrolling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.link),
                      label: Text(_enrolling
                          ? l10n.t('loading')
                          : l10n.t('dlCompleteEnrollment')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A member may appear under the device roles that match their family
  /// role: parents under parent/spouse/parentDevice roles, children only
  /// under the child device role.
  List<String> _rolesForMember(FamilyRole role) => switch (role) {
        FamilyRole.primaryParent || FamilyRole.parent => [
            DeviceRole.parentDevice.storageKey,
            DeviceRole.coParentDevice.storageKey,
          ],
        FamilyRole.coParent => [
            DeviceRole.coParentDevice.storageKey,
          ],
        FamilyRole.spouse => [
            DeviceRole.spouseDevice.storageKey,
          ],
        FamilyRole.child => [
            DeviceRole.childDevice.storageKey,
          ],
      };
}

// ────────────────────── DL-005 spouse device link ───────────────────────
/// `/couple/:familyId/link-device` — DL-005. The primary parent issues a
/// six-digit code for a spouse's device (requested role
/// `spouseDevice`). The plain-text code lives only in this screen's memory
/// — exactly like the parent issuance flow — and is handed to DL-006.
class SpouseLinkDeviceScreen extends ConsumerStatefulWidget {
  const SpouseLinkDeviceScreen({required this.familyId, super.key});
  final String familyId;
  @override
  ConsumerState<SpouseLinkDeviceScreen> createState() =>
      _SpouseLinkDeviceScreenState();
}

class _SpouseLinkDeviceScreenState
    extends ConsumerState<SpouseLinkDeviceScreen> {
  PairingRequest? _request;
  String? _errorKey;
  bool _issuing = false;

  Future<void> _create() async {
    if (_issuing) return;
    setState(() {
      _issuing = true;
      _errorKey = null;
    });
    try {
      final request = await ref
          .read(pairingRepositoryProvider)
          .createParentAuthorizedRequest(
              familyId: widget.familyId,
              requestedRole: DeviceRole.spouseDevice);
      if (!mounted) return;
      setState(() {
        _request = request;
        _errorKey = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'dlIssueFailed');
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  String _expiryText(AppLocalizations l10n, DateTime expiresAt) {
    final minutes = expiresAt.difference(DateTime.now().toUtc()).inMinutes;
    if (minutes <= 0) return l10n.t('dlCodeExpired');
    return l10n.t('dlExpiryMinutes').replaceAll('{minutes}', '$minutes');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageDevices,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlSpouseLinkTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 38, color: GuardianTokens.guardianTeal),
                      const SizedBox(height: 12),
                      Text(l10n.t('dlSpouseLinkTitle'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(l10n.t('dlSpouseLinkSubtitle'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13.5)),
                      const SizedBox(height: 18),
                      if (_request == null) ...[
                        FilledButton.icon(
                          onPressed: _issuing ? null : _create,
                          icon: _issuing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.qr_code_2),
                          label: Text(_issuing
                              ? l10n.t('loading')
                              : l10n.t('dlGenerateSpouseCode')),
                        ),
                      ] else ...[
                        Text(l10n.t('dlYourCode'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final ch in _request!.code.characters)
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: GuardianTokens.guardianTealSoft,
                                  borderRadius: BorderRadius.circular(
                                      GuardianTokens.radiusChip),
                                ),
                                child: Text(ch,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: GuardianTokens.guardianNavy)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_expiryText(l10n, _request!.expiresAt),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12.5)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _request!.code));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(l10n.t('dlCodeCopied'))));
                          },
                          icon: const Icon(Icons.copy),
                          label: Text(l10n.t('dlCopyCode')),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.pushReplacement(
                              '/couple/${widget.familyId}/enroll'),
                          child: Text(l10n.t('dlAlreadyHaveCode')),
                        ),
                      ],
                      if (_errorKey != null) ...[
                        const SizedBox(height: 12),
                        Text(l10n.t(_errorKey!),
                            style: const TextStyle(
                                color: GuardianTokens.statusAlert,
                                fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────── DL-006 spouse enrollment ────────────────────────
/// `/couple/:familyId/enroll` — DL-006. The spouse device completes
/// enrollment with a shared six-digit code: first the live session is
/// looked up without touching any counters, then confirmation performs the
/// actual verification-and-enrollment on the `spouseDevice` role.
class SpouseEnrollScreen extends ConsumerStatefulWidget {
  const SpouseEnrollScreen({required this.familyId, super.key});
  final String familyId;
  @override
  ConsumerState<SpouseEnrollScreen> createState() => _SpouseEnrollScreenState();
}

class _SpouseEnrollScreenState extends ConsumerState<SpouseEnrollScreen> {
  final _controller = TextEditingController();
  String? _sessionRequestId;
  String? _errorKey;
  bool _verifying = false;
  bool _enrolling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final value = _controller.text.replaceAll(' ', '').trim();
    if (value.length != 6) {
      setState(() => _errorKey = 'dlCodeTooShort');
      return;
    }
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _errorKey = null;
    });
    try {
      final session = await ref
          .read(pairingRepositoryProvider)
          .sessionForCode(widget.familyId, value);
      if (!mounted) return;
      if (session == null) {
        setState(() => _errorKey = 'dlCodeInvalid');
        return;
      }
      final expired = DateTime.parse(session['expires_at'] as String)
          .isBefore(DateTime.now().toUtc());
      if (expired) {
        setState(() => _errorKey = 'dlCodeExpired');
        return;
      }
      if (session['requested_role'] != DeviceRole.spouseDevice.storageKey) {
        setState(() => _errorKey = 'dlWrongCodeRole');
        return;
      }
      setState(() => _sessionRequestId = session['id'] as String);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'dlCodeInvalid');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _enroll() async {
    if (_sessionRequestId == null) return;
    if (_enrolling) return;
    final code = _controller.text.replaceAll(' ', '').trim();
    setState(() {
      _enrolling = true;
      _errorKey = null;
    });
    try {
      final ownerId = ref
              .read(familyRuntimeContextProvider(widget.familyId))
              .value
              ?.actor
              ?.id ??
          '';
      final result = await ref.read(pairingRepositoryProvider).verifyAndEnroll(
          requestId: _sessionRequestId!,
          code: code,
          memberId: ownerId,
          ownerMemberId: ownerId);
      if (!mounted) return;
      if (result.succeeded) {
        context.go('/couple/${widget.familyId}/role');
      } else if (result.reason == 'too_many_attempts') {
        setState(() => _errorKey = 'dlCodeRejected');
      } else if (result.reason == 'active_device_already_linked') {
        setState(() => _errorKey = 'dlDeviceAlreadyLinked');
      } else {
        setState(() => _errorKey = 'dlEnrollFailed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'dlEnrollFailed');
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('dlSpouseEnrollTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.wc_outlined,
                        size: 36, color: GuardianTokens.guardianTeal),
                    const SizedBox(height: 10),
                    Text(l10n.t('dlSpouseEnrollSubtitle'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13.5)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _controller,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      enabled: _sessionRequestId == null,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                          fontSize: 26,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '• • • • • •',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.4)),
                        counterText: '',
                      ),
                    ),
                    if (_errorKey != null) ...[
                      const SizedBox(height: 10),
                      Text(l10n.t(_errorKey!),
                          style: const TextStyle(
                              color: GuardianTokens.statusAlert, fontSize: 13)),
                    ],
                    const SizedBox(height: 14),
                    if (_sessionRequestId == null)
                      FilledButton.icon(
                        onPressed: _verifying ? null : _verify,
                        icon: _verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check),
                        label: Text(_verifying
                            ? l10n.t('loading')
                            : l10n.t('dlVerifyCode')),
                      )
                    else ...[
                      Text(l10n.t('dlCodeValid'),
                          style: const TextStyle(
                              color: GuardianTokens.statusSafe,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _enrolling ? null : _enroll,
                        icon: _enrolling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.link),
                        label: Text(_enrolling
                            ? l10n.t('loading')
                            : l10n.t('dlCompleteSpouseEnrollment')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── DL-007 spouse role confirmation ───────────────────
/// `/couple/:familyId/role` — DL-007. An honest read-only confirmation of
/// the linked spouse role: it lists the real device rows of the family,
/// never a synthesized role description. The spouse role is fixed at
/// enrollment time; this screen makes that truth visible to both partners.
class SpouseRoleConfirmationScreen extends ConsumerWidget {
  const SpouseRoleConfirmationScreen({required this.familyId, super.key});
  final String familyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final devicesAsync = ref.watch(familyDevicesProvider(familyId));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageDevices,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlSpouseRoleTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: devicesAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (_, __) => GuardianStateView(
                state: GuardianViewState.error,
                message: l10n.t('retryHint'),
                onRetry: () => ref.invalidate(familyDevicesProvider(familyId))),
            data: (rows) {
              final spouseDevices = rows
                  .where((r) => r['role'] == DeviceRole.spouseDevice.storageKey)
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GuardianCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.verified_outlined,
                              size: 36, color: GuardianTokens.guardianTeal),
                          const SizedBox(height: 10),
                          Text(l10n.t('dlSpouseRoleTitle'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(l10n.t('dlSpouseRoleSubtitle'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13.5)),
                          const SizedBox(height: 14),
                          if (spouseDevices.isEmpty)
                            Text(l10n.t('dlNoSpouseDevice'),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13.5))
                          else
                            ...spouseDevices.map((d) {
                              final revoked = d['revoked_at'] != null;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                        revoked
                                            ? Icons.device_unknown
                                            : Icons.devices,
                                        color: revoked
                                            ? Colors.grey
                                            : GuardianTokens.guardianTeal),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${l10n.t('dlRoleSpouse')} — '
                                        '${revoked ? l10n.t('dlHealthRevoked') : l10n.t('dlActive')}',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.85),
                                            fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────── DL-007 pairing success ──────────────────────────
/// `/enroll/:familyId/success` — DL-007. A simple, celebratory landing for
/// the newly linked device before they proceed to permission onboarding.
class PairingSuccessScreen extends StatelessWidget {
  const PairingSuccessScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 80, color: GuardianTokens.guardianTeal),
                const SizedBox(height: 24),
                Text(l10n.t('dlSuccessTitle'),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Text(l10n.t('dlSuccessSubtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () =>
                      context.go('/safety/permissions', extra: familyId),
                  child: Text(l10n.t('dlContinueToPermissions')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────── DL-008 permission onboarding ──────────────────────
/// `/onboard/permissions` — DL-008. The honest Android permission ladder:
/// each step reports its REAL state. On this environment the Android
/// permission channels are unavailable, so every step honestly renders as
/// `requiresSettings` with a truthful explanation — never a fabricated
/// "granted".
class DevicePermissionOnboardingScreen extends ConsumerStatefulWidget {
  final String familyId;
  const DevicePermissionOnboardingScreen({super.key, required this.familyId});
  @override
  ConsumerState<DevicePermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<DevicePermissionOnboardingScreen> {
  late final List<PermissionLadderRow> _rows = _buildHonestRows();
  final Set<PermissionLadderStep> _deferred = {};

  /// Honest deterministic ladder: without an Android device the real
  /// permission channels cannot be probed, so the truthful state is
  /// `requiresSettings` — the app never pretends a permission is granted.
  static List<PermissionLadderRow> _buildHonestRows() => [
        const PermissionLadderRow(
            step: PermissionLadderStep.location,
            state: LadderStepState.requiresSettings,
            detail: 'needsSettingsExplanation'),
        const PermissionLadderRow(
            step: PermissionLadderStep.notificationAccess,
            state: LadderStepState.requiresSettings,
            detail: 'needsSettingsExplanation'),
        const PermissionLadderRow(
            step: PermissionLadderStep.usageStats,
            state: LadderStepState.requiresSettings,
            detail: 'needsSettingsExplanation'),
        const PermissionLadderRow(
            step: PermissionLadderStep.backgroundService,
            state: LadderStepState.requiresSettings,
            detail: 'needsSettingsExplanation'),
      ];

  String _stepTitle(AppLocalizations l10n, PermissionLadderStep step) =>
      switch (step) {
        PermissionLadderStep.location => l10n.t('dlPermLocation'),
        PermissionLadderStep.notificationAccess => l10n.t('dlPermNotification'),
        PermissionLadderStep.usageStats => l10n.t('dlPermUsage'),
        PermissionLadderStep.backgroundService => l10n.t('dlPermBackground'),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider('self'));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewOwnPermissions,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlPermissionOnboardingTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.tune,
                          size: 36, color: GuardianTokens.guardianTeal),
                      const SizedBox(height: 10),
                      Text(l10n.t('dlPermissionOnboardingTitle'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(l10n.t('dlPermissionOnboardingSubtitle'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13.5)),
                      const SizedBox(height: 14),
                      ..._rows.map((row) {
                        final deferred = _deferred.contains(row.step);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: GuardianTokens.guardianNavySoft,
                            borderRadius: BorderRadius.circular(
                                GuardianTokens.radiusCard),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(
                                    deferred
                                        ? Icons.timelapse
                                        : Icons.settings_outlined,
                                    color: deferred
                                        ? GuardianTokens.statusWatch
                                        : GuardianTokens.guardianTeal,
                                    size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_stepTitle(l10n, row.step),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5)),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Text(l10n.t('dlPermSettingsHint'),
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12.5)),
                              const SizedBox(height: 8),
                              if (!deferred)
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => setState(
                                          () => _deferred.add(row.step)),
                                      child: Text(l10n.t('dlPermDefer'),
                                          style:
                                              const TextStyle(fontSize: 12.5)),
                                    ),
                                  ),
                                ])
                              else
                                Text(l10n.t('dlPermDeferred'),
                                    style: TextStyle(
                                        color: GuardianTokens.statusWatch,
                                        fontSize: 12.5)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────── DL-009 device unlinking ─────────────────────────
/// `/settings/device/:deviceId/unlink` — DL-009. Honest device unlinking:
/// the device row is marked revoked (record kept, never deleted), a
/// `device.revoked` outbox operation is queued, and the child lifecycle is
/// moved to `revoked`. Success is claimed only when the repository returns
/// `true` for the real update.
class DeviceUnlinkScreen extends ConsumerStatefulWidget {
  const DeviceUnlinkScreen(
      {required this.familyId, required this.deviceId, super.key});
  final String familyId;
  final String deviceId;
  @override
  ConsumerState<DeviceUnlinkScreen> createState() => _DeviceUnlinkScreenState();
}

class _DeviceUnlinkScreenState extends ConsumerState<DeviceUnlinkScreen> {
  bool _revoking = false;
  String? _errorKey;

  Future<void> _revoke() async {
    if (_revoking) return;
    setState(() {
      _revoking = true;
      _errorKey = null;
    });
    try {
      final ownerId = ref
              .read(familyRuntimeContextProvider(widget.familyId))
              .value
              ?.actor
              ?.id ??
          '';
      final ok = await ref
          .read(pairingRepositoryProvider)
          .revokeDevice(deviceId: widget.deviceId, ownerMemberId: ownerId);
      if (!mounted) return;
      if (ok) {
        context.go('/settings/devices');
      } else {
        setState(() => _errorKey = 'dlUnlinkFailed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'dlUnlinkFailed');
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deviceAsync = ref.watch(deviceByIdProvider(widget.deviceId));
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageDevices,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlUnlinkTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: deviceAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (_, __) => GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('loadingFailed'),
                message: l10n.t('retryHint'),
                onRetry: () =>
                    ref.invalidate(deviceByIdProvider(widget.deviceId))),
            data: (row) {
              if (row == null) {
                return GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('loadingFailed'),
                  message: l10n.t('dlDeviceMissing'),
                );
              }
              final revoked = row['revoked_at'] != null;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GuardianCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                              revoked
                                  ? Icons.device_unknown
                                  : Icons.phonelink_off,
                              size: 36,
                              color: revoked
                                  ? Colors.grey
                                  : GuardianTokens.statusAlert),
                          const SizedBox(height: 10),
                          Text(l10n.t('dlUnlinkTitle'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(l10n.t('dlRevokeWarning'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13.5)),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.t('dlRoleLabel')}: '
                            '${_roleLabel(l10n, row['role'] as String)}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12.5),
                          ),
                          const SizedBox(height: 14),
                          if (revoked)
                            Text(l10n.t('dlHealthRevoked'),
                                style: const TextStyle(
                                    color: GuardianTokens.statusWatch,
                                    fontSize: 13))
                          else
                            FilledButton.icon(
                              onPressed: _revoking ? null : _revoke,
                              icon: _revoking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.link_off),
                              label: Text(_revoking
                                  ? l10n.t('loading')
                                  : l10n.t('dlConfirmUnlink')),
                              style: FilledButton.styleFrom(
                                  backgroundColor: GuardianTokens.statusAlert),
                            ),
                          if (_errorKey != null) ...[
                            const SizedBox(height: 10),
                            Text(l10n.t(_errorKey!),
                                style: const TextStyle(
                                    color: GuardianTokens.statusAlert,
                                    fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ──────────────────── DL-010 device health dashboard ────────────────────
/// `/settings/devices` — DL-010. The honest device health roster: each row
/// derives its verdict from the real `last_synced_at` timestamp plus the
/// real lifecycle row. Sync is a real outbox-triggered marker
/// (`markDeviceSynced`) — never a fake button that flips the label.
class DeviceHealthDashboardScreen extends ConsumerWidget {
  const DeviceHealthDashboardScreen({required this.familyId, super.key});
  final String familyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final healthAsync = ref.watch(familyDeviceHealthProvider(familyId));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageDevices,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlDevicesTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: healthAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (_, __) => GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('loadingFailed'),
                message: l10n.t('retryHint'),
                onRetry: () =>
                    ref.invalidate(familyDeviceHealthProvider(familyId))),
            data: (healths) {
              if (healths.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          const Icon(Icons.devices_other,
                              size: 38, color: GuardianTokens.guardianTeal),
                          const SizedBox(height: 10),
                          Text(l10n.t('dlNoDevices'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13.5)),
                        ]),
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...healths.map((health) {
                    final memberName =
                        health.memberId == runtime.value?.actor?.id
                            ? l10n.t('dlThisDevice')
                            : health.memberId;
                    return GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Icon(Icons.devices,
                                  size: 26, color: _healthColor(health.health)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(memberName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_roleLabel(l10n, health.role)} — '
                                      '${_healthLabel(l10n, health.health)}',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _healthColor(health.health)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(
                                      GuardianTokens.radiusChip),
                                ),
                                child: Text(
                                    health.freshnessMinutes == null
                                        ? l10n.t('dlNeverSynced')
                                        : l10n.t('dlMinutesAgo').replaceAll(
                                            '{minutes}',
                                            '${health.freshnessMinutes!}'),
                                    style: TextStyle(
                                        color: _healthColor(health.health),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              if (health.health != DeviceHealthKind.revoked)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await ref
                                          .read(pairingRepositoryProvider)
                                          .markDeviceSynced(health.deviceId);
                                      if (context.mounted) {
                                        ref.invalidate(
                                            familyDeviceHealthProvider(
                                                familyId));
                                      }
                                    },
                                    icon: const Icon(Icons.sync, size: 16),
                                    label: Text(l10n.t('dlSyncNow'),
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push(
                                      '/settings/device/${health.deviceId}/transfer'),
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: Text(l10n.t('dlTransferDevice'),
                                      style: const TextStyle(fontSize: 12.5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push(
                                      '/settings/device/${health.deviceId}/unlink'),
                                  icon: const Icon(Icons.link_off, size: 16),
                                  label: Text(l10n.t('dlRevokeDevice'),
                                      style: const TextStyle(fontSize: 12.5)),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────── DL-011 device transfer ──────────────────────────
/// `/settings/device/:deviceId/transfer` — DL-011. Honest device transfer:
/// the old device row is revoked (record kept), a fresh device row and
/// lifecycle row are created, and a `device.transferred` outbox operation
/// carries the migration. Success is claimed only when the repository
/// returns the real new device id.
class DeviceTransferScreen extends ConsumerStatefulWidget {
  const DeviceTransferScreen(
      {required this.familyId, required this.deviceId, super.key});
  final String familyId;
  final String deviceId;
  @override
  ConsumerState<DeviceTransferScreen> createState() =>
      _DeviceTransferScreenState();
}

class _DeviceTransferScreenState extends ConsumerState<DeviceTransferScreen> {
  bool _transferring = false;
  String? _newDeviceId;
  String? _errorKey;

  Future<void> _transfer() async {
    if (_transferring) return;
    setState(() {
      _transferring = true;
      _errorKey = null;
    });
    try {
      final runtime = ref.read(familyRuntimeContextProvider(widget.familyId));
      final actor = runtime.value?.actor;
      if (actor == null) {
        if (!mounted) return;
        setState(() => _errorKey = 'dlTransferFailed');
        return;
      }
      final deviceRow =
          await ref.read(pairingRepositoryProvider).deviceById(widget.deviceId);
      if (deviceRow == null) {
        if (!mounted) return;
        setState(() => _errorKey = 'dlDeviceMissing');
        return;
      }
      setDeviceTransferScope(ref,
          familyId: widget.familyId,
          memberId: deviceRow['member_id'] as String,
          ownerMemberId: actor.id);
      final result =
          await ref.read(deviceTransferProvider(widget.deviceId).future);
      if (!mounted) return;
      if (result.succeeded && result.newDeviceId != null) {
        setState(() => _newDeviceId = result.newDeviceId);
      } else {
        setState(() => _errorKey = 'dlTransferFailed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'dlTransferFailed');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final deviceAsync = ref.watch(deviceByIdProvider(widget.deviceId));
    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageDevices,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('dlTransferTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: deviceAsync.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())),
            error: (_, __) => GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('loadingFailed'),
                message: l10n.t('retryHint'),
                onRetry: () =>
                    ref.invalidate(deviceByIdProvider(widget.deviceId))),
            data: (row) {
              if (row == null) {
                return GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('loadingFailed'),
                  message: l10n.t('dlDeviceMissing'),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GuardianCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.swap_horiz,
                              size: 36, color: GuardianTokens.guardianTeal),
                          const SizedBox(height: 10),
                          Text(l10n.t('dlTransferTitle'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(l10n.t('dlTransferSubtitle'),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13.5)),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.t('dlRoleLabel')}: '
                            '${_roleLabel(l10n, row['role'] as String)}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12.5),
                          ),
                          const SizedBox(height: 14),
                          if (_newDeviceId != null) ...[
                            const Icon(Icons.check_circle_outline,
                                size: 40, color: GuardianTokens.statusSafe),
                            const SizedBox(height: 10),
                            Text(l10n.t('dlTransferSuccess'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(l10n.t('dlTransferOldRevoked'),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12.5)),
                          ] else ...[
                            FilledButton.icon(
                              onPressed: _transferring ? null : _transfer,
                              icon: _transferring
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.swap_horiz),
                              label: Text(_transferring
                                  ? l10n.t('loading')
                                  : l10n.t('dlConfirmTransfer')),
                            ),
                            if (_errorKey != null) ...[
                              const SizedBox(height: 10),
                              Text(l10n.t(_errorKey!),
                                  style: const TextStyle(
                                      color: GuardianTokens.statusAlert,
                                      fontSize: 13)),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
