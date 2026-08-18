// ────────────── FS-001 · Location & Geofencing · Child scope ──────────────
//
// Screens that render when the verified actor is a child: the child may
// only see and control their *own* location sharing (LO-015). Everything
// else is role-filtered by the same runtime context gate every parent
// screen uses — no local re-implementation of the policy.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../presentation/widgets/guardian_primitives.dart';

// ──────────────────── LO-015 Child location sharing ─────────────────────

/// `/child/:familyId/:childId/location-sharing` — LO-015 (canonical). Child
/// self-scope screen: the child may only see whether *their own* location
/// sharing is enabled, and toggle the verified `sharing_enabled:<memberId>`
/// setting row. The honest banner tells them that a parent's stop request
/// lands here only once the device reconnects. The legacy
/// `/location/sharing/self` path self-resolves the family from the verified
/// actor binding; a route that names another member than the acting child
/// fails closed to the authorization page (never another child's settings).
class ChildLocationSharingScreen extends ConsumerWidget {
  const ChildLocationSharingScreen({super.key, this.familyId, this.childId});

  /// Family/child ids carried by the canonical route; null on the legacy
  /// self-scope path, where they are resolved from the actor binding.
  final String? familyId;
  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncRuntime = ref.watch(
        familyRuntimeContextProvider(familyId ?? ''));
    final resolvedFamilyId = familyId ??
        asyncRuntime.valueOrNull?.familyId;
    final resolvedChildId = childId ??
        asyncRuntime.valueOrNull?.actor?.id;
    // Self-scope rule: the route may only address the acting child's own
    // sharing — never another member's.
    final actorId = asyncRuntime.valueOrNull?.actor?.id;
    final guardedChildId = resolvedChildId != null &&
            resolvedChildId == actorId
        ? resolvedChildId
        : null;

    return _childScaffold(
      context: context,
      l10n: l10n,
      runtime: asyncRuntime,
      childId: guardedChildId,
      familyId: resolvedFamilyId,
    );
  }
}

class _ChildLocationSharingBody extends ConsumerStatefulWidget {
  const _ChildLocationSharingBody({
    required this.familyId,
    required this.childId,
    required this.runtime,
  });
  final String familyId;
  final String childId;
  final AsyncValue<FamilyRuntimeContext> runtime;

  @override
  ConsumerState<_ChildLocationSharingBody> createState() =>
      _ChildLocationSharingBodyState();
}

class _ChildLocationSharingBodyState
    extends ConsumerState<_ChildLocationSharingBody> {
  Future<bool>? _sharingFuture;

  Future<bool> _loadSharing() async {
    final repository = ref.read(locationGeofenceRepositoryProvider);
    final sharing = await repository.setting(
        widget.familyId, 'sharing_enabled:${widget.childId}', 'on');
    return sharing != 'off';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(locationGeofenceRepositoryProvider);
    _sharingFuture ??= _loadSharing();
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: FutureBuilder<bool>(
        future: _sharingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const GuardianStateView(state: GuardianViewState.loading);
          }
          final sharingOn = snapshot.data ?? false;
          return RefreshIndicator(
            onRefresh: () async {
              _sharingFuture = null;
              setState(() {});
              try {
                await ref
                    .read(familyLocationPullProvider(widget.familyId).future);
              } catch (_) {}
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GuardianHeroCard(
                  child: Row(children: [
                    GuardianIconBadge(
                        icon: Icons.location_on_outlined,
                        background: GuardianTokens.guardianTeal
                            .withValues(alpha: 0.25),
                        foreground: GuardianTokens.guardianTeal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('locationSharing'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                GuardianCard(
                  child: SwitchListTile.adaptive(
                    title: Text(l10n.t('childSharingEnabled'),
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(l10n.t('childSharingDescription'),
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    value: sharingOn,
                    activeColor: GuardianTokens.guardianTeal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) async {
                      try {
                        await repository.setSetting(
                            familyId: widget.familyId,
                            key: 'sharing_enabled:${widget.childId}',
                            value: value ? 'on' : 'off');
                        _sharingFuture = null;
                        setState(() {});
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                                content: Text(value
                                    ? l10n.t('sharingEnabled')
                                    : l10n.t('childSharingDisabled'))));
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                                content: Text(l10n.t('somethingWentWrong'))));
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                GuardianCard(
                  child: Row(children: [
                    GuardianIconBadge(
                        icon: Icons.info_outline,
                        background: GuardianTokens.guardianTeal
                            .withValues(alpha: 0.25),
                        foreground: GuardianTokens.guardianTeal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('childSyncPending'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white54, height: 1.3)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                GuardianCard(
                  child: Row(children: [
                    GuardianIconBadge(
                        icon: Icons.privacy_tip,
                        background: GuardianTokens.guardianTeal
                            .withValues(alpha: 0.25),
                        foreground: GuardianTokens.guardianTeal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('childPrivacySeePrivacy'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white54, height: 1.3)),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _childScaffold({
  required BuildContext context,
  required AppLocalizations l10n,
  required AsyncValue<FamilyRuntimeContext> runtime,
  required String? childId,
  required String? familyId,
}) {
  if (childId == null || familyId == null) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('locationSharing')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('authorizationFailure'),
        message: l10n.t('unauthorizedActor'),
      ),
    );
  }
  return Scaffold(
    backgroundColor: GuardianTokens.guardianNavy,
    appBar: AppBar(
      title: Text(l10n.t('locationSharing')),
      backgroundColor: GuardianTokens.guardianNavy,
      foregroundColor: Colors.white,
    ),
    body: _ChildLocationSharingBody(
      familyId: familyId,
      childId: childId,
      runtime: runtime,
    ),
  );
}
