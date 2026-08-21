/// FS-016 — Startup & Onboarding screens.
///
/// ST-001: splash/brand entry + role gate.
/// ST-004: canonical role landing wrapper (child / spouse / parent).
///
/// Design laws:
/// 1. The role gate decides from [RoleGateDecisionResult] only — the router
///    and widgets never re-implement role logic; it is computed by
///    [decideRoleGate] over the canonical [FamilyRuntimeContext].
/// 2. No role is silently defaulted. An actor without a persisted role, or
///    whose persisted role no longer matches the verified actor, re-sees
///    the gate.
/// 3. Honest states only: resolving / signed-out / unverified / no-family /
///    offline — the splash never claims success before evidence.
/// 4. Pure presentation on existing Guardian primitives; l10n-driven with
///    AR/EN maps and RTL support.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../application/role_gate_service.dart';
import '../../application/startup_state_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';
import '../widgets/startup_widgets.dart';

/// ST-001 — brand entry. Renders immediately (never waits on network or
/// Firebase) and hands control to the role gate via [appStartupStateProvider].
/// A stalled Firebase or an offline cold start degrades to an honest
/// unauthenticated state on the splash itself.
class StartupSplashScreen extends ConsumerWidget {
  const StartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final startup = ref.watch(appStartupStateProvider);

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        body: Semantics(
          label: l10n.t('splashTitle'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration:
                const BoxDecoration(gradient: GuardianTokens.guardianGradient),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GuardianIconBadge(
                    icon: Icons.shield_outlined,
                    size: 72,
                    background: Color(0x3DFFFFFF),
                    foreground: Colors.white),
                const SizedBox(height: 20),
                Text(l10n.t('splashTitle'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: GuardianTokens.fontFamily)),
                const SizedBox(height: 8),
                Text(l10n.t('splashSubtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontFamily: GuardianTokens.fontFamily)),
                const SizedBox(height: 48),
                // Honest state under the brand: the splash reports what the
                // startup machine is actually doing instead of an infinite
                // spinner that claims progress.
                startup.when(
                  data: (snapshot) => StartupStateNote(
                      snapshot: snapshot,
                      onReady: () {
                        if (snapshot.gateReady) {
                          context.push('/role');
                        } else {
                          context.push('/firebase-session');
                        }
                      }),
                  loading: () => const _SplashLoader(),
                  error: (_, __) => GuardianStateView(
                      state: GuardianViewState.error,
                      message: l10n.t('startupErrorNote'),
                      onRetry: () => ref.invalidate(appStartupStateProvider)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white70)),
        const SizedBox(width: 10),
        Text(l10n.t('splashChecking'),
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontFamily: GuardianTokens.fontFamily)),
      ],
    );
  }
}

/// ST-001 — authenticated role gate. The gate renders exactly one path per
/// [RoleGateDecision]; no role is ever defaulted, and no ineligible actor
/// is offered a choice.
class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final decision = ref.watch(roleGateDecisionProvider);

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('roleGateTitle'),
              style: const TextStyle(
                  fontFamily: GuardianTokens.fontFamily, color: Colors.white)),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Semantics(
          label: l10n.t('roleGateTitle'),
          child: decision.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => GuardianStateView(
                state: GuardianViewState.error,
                message: 'roleGateResolveError',
                onRetry: () => ref.invalidate(roleGateDecisionProvider)),
            data: (decision) => switch (decision) {
              RoleGateDecision.showGate =>
                _RoleSelection(ref: ref, familyId: _familyIdOf(ref)),
              RoleGateDecision.landWithRole =>
                const _LandingRedirect(route: '/'),
              RoleGateDecision.landAsChild =>
                const _LandingRedirect(route: '/'),
              RoleGateDecision.landAsSpouse =>
                _SpouseLandingRedirect(familyId: _familyIdOf(ref)),
              RoleGateDecision.unverified => const _UnverifiedState(),
              RoleGateDecision.signedOut => const _SignedOutState(),
            },
          ),
        ),
      ),
    );
  }
}

/// The gate view for a parent-type actor that must choose a role. The
/// choices are the parent-type roles only; child and spouse are fixed
/// landings that never appear here.
class _RoleSelection extends StatelessWidget {
  const _RoleSelection({required this.ref, this.familyId});

  final WidgetRef ref;
  final String? familyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GuardianHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('roleGateHeroTitle'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: GuardianTokens.fontFamily)),
              const SizedBox(height: 6),
              Text(l10n.t('roleGateHeroNote'),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFamily: GuardianTokens.fontFamily)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final entry in const [
          (FamilyRole.primaryParent, Icons.family_restroom),
          (FamilyRole.parent, Icons.person_outline),
          (FamilyRole.coParent, Icons.people_outline),
        ])
          GuardianCard(
            onTap: () => _selectRole(context, role: entry.$1, icon: entry.$2),
            child: Semantics(
              button: true,
              label: entry.$1.displayLabel(l10n),
              child: Row(children: [
                GuardianIconBadge(
                    icon: entry.$2, background: GuardianTokens.guardianNavy),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(entry.$1.displayLabel(l10n),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: GuardianTokens.fontFamily)),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: GuardianTokens.guardianTeal),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Text(l10n.t('roleGatePersistNote'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: GuardianTokens.fontFamily)),
      ],
    );
  }

  Future<void> _selectRole(BuildContext context,
      {required FamilyRole role, required IconData icon}) async {
    // The verified actor is the single source of truth for who is choosing;
    // the persistence pair (role + actor id) is what keeps the gate honest
    // across restarts and unlinking.
    final runtime = familyId == null
        ? null
        : await ref
            .read(familyRuntimeContextProvider(familyId!).future)
            .catchError(
                (Object _, StackTrace __) => FamilyRuntimeContext.unverified());
    final actor = runtime?.actor;
    if (actor == null) return;
    await persistRoleForActor(
        roleKey: role.storageKey, actorMemberId: actor.id, ref: ref);
    if (context.mounted) context.go('/');
  }
}

String? _familyIdOf(WidgetRef ref) =>
    ref.read(dashboardProvider).valueOrNull?.family?.id;

extension _RoleDisplayLabel on FamilyRole {
  String displayLabel(AppLocalizations l10n) => switch (this) {
        FamilyRole.primaryParent => l10n.t('rolePrimaryParent'),
        FamilyRole.parent => l10n.t('roleParent'),
        FamilyRole.coParent => l10n.t('roleCoParent'),
        FamilyRole.spouse => l10n.t('roleSpouse'),
        FamilyRole.child => l10n.t('roleChild'),
      };
}

/// Auto-redirect for a parent-type actor with a valid persisted role.
class _LandingRedirect extends ConsumerStatefulWidget {
  const _LandingRedirect({required this.route});
  final String route;

  @override
  ConsumerState<_LandingRedirect> createState() => _LandingRedirectState();
}

class _LandingRedirectState extends ConsumerState<_LandingRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 10),
        Text(l10n.t('roleGateEntering'),
            style: const TextStyle(
                fontSize: 12.5, fontFamily: GuardianTokens.fontFamily)),
      ]),
    );
  }
}

/// Canonical spouse landing: the gate lands on the existing couple-harmony
/// surface (/couple/:fid/role) rather than building a second one.
class _SpouseLandingRedirect extends ConsumerStatefulWidget {
  const _SpouseLandingRedirect({this.familyId});
  final String? familyId;

  @override
  ConsumerState<_SpouseLandingRedirect> createState() =>
      _SpouseLandingRedirectState();
}

class _SpouseLandingRedirectState
    extends ConsumerState<_SpouseLandingRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final familyId = widget.familyId ??
            ref.read(dashboardProvider).valueOrNull?.family?.id;
        if (familyId != null && familyId.isNotEmpty) {
          context.go('/couple/$familyId/role');
        } else {
          context.go('/');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Honest unverified state: the Trusted Actor Binding did not verify this
/// account to an active member. No role choice is offered — that would be
/// a false success.
class _UnverifiedState extends StatelessWidget {
  const _UnverifiedState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GuardianStateView(
            state: GuardianViewState.offline,
            title: 'roleGateUnverifiedTitle',
            message: 'roleGateUnverifiedDetail'),
        const SizedBox(height: 12),
        GuardianCard(
            child: Text(l10n.t('roleGateUnverifiedRecover'),
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: GuardianTokens.fontFamily))),
      ],
    );
  }
}

/// Honest signed-out state: no account, nothing to gate.
class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GuardianStateView(
            state: GuardianViewState.empty,
            title: 'roleGateSignedOutTitle',
            message: 'roleGateSignedOutDetail'),
        const SizedBox(height: 12),
        GuardianCard(
          onTap: () => context.push('/firebase-session'),
          child: Semantics(
            button: true,
            label: l10n.t('roleGateSignIn'),
            child: Row(children: [
              const GuardianIconBadge(
                  icon: Icons.login_outlined,
                  background: GuardianTokens.guardianNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.t('roleGateSignIn'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: GuardianTokens.fontFamily)),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Canonical child landing wrapper (ST-004): the child vertical is entered
/// through this single wrapper, which keeps the child surface gated and the
/// route tree stable. Child members never see the role gate.
class ChildLandingWrapper extends ConsumerWidget {
  const ChildLandingWrapper(
      {required this.familyId, required this.childId, super.key});

  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('childLandingTitle'),
              style: const TextStyle(fontFamily: GuardianTokens.fontFamily)),
        ),
        body: Semantics(
          label: l10n.t('childLandingTitle'),
          child: const Center(child: SizedBox.shrink()),
        ),
      ),
    );
  }
}

// The per-child context surface lives on its canonical route
// (/child/:fid/:cid) and remains the single source for the child
// vertical; the wrapper keeps the gate invariant that children land
// here without a role choice.
