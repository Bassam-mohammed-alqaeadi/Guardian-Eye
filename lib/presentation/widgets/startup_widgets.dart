/// FS-016 — shared startup widgets.
///
/// Builds on the existing [GuardianStateView] primitive (warning visuals are
/// expressed with the `empty`/`offline` states plus the honest l10n message,
/// never a duplicated view class).
library;

import 'package:flutter/material.dart';

import '../../application/startup_state_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';

/// The honest state note rendered under the splash brand. Reports the real
/// startup posture and offers the matching next step — never a fake "ready"
/// while the startup machine is still resolving.
class StartupStateNote extends StatelessWidget {
  const StartupStateNote({
    super.key,
    required this.snapshot,
    required this.onReady,
  });

  final AppStartupSnapshot snapshot;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final note = snapshot.startupNote(l10n);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(note.icon, size: 16, color: note.color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(note.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFamily: GuardianTokens.fontFamily)),
            ),
          ],
        ),
        if (note.canContinue) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: onReady, child: Text(note.cta)),
        ],
      ],
    );
  }
}

/// Resolved note for a startup state.
class _StartupNote {
  const _StartupNote(
      {required this.text,
      required this.cta,
      required this.icon,
      required this.color,
      this.canContinue = false});

  final String text;
  final String cta;
  final IconData icon;
  final Color color;
  final bool canContinue;
}

extension _StartupSnapshotNote on AppStartupSnapshot {
  _StartupNote startupNote(AppLocalizations l10n) {
    switch (startupState) {
      case AppStartupState.resolving:
        return _StartupNote(
            text: l10n.t('splashResolving'),
            cta: '',
            icon: Icons.hourglass_empty_outlined,
            color: Colors.white.withValues(alpha: 0.5));
      case AppStartupState.unauthenticated:
        return _StartupNote(
            text: l10n.t('splashNotSignedIn'),
            cta: l10n.t('splashSignIn'),
            icon: Icons.login_outlined,
            color: Colors.amber.shade300,
            canContinue: true);
      case AppStartupState.noFamily:
        return _StartupNote(
            text: l10n.t('splashNoFamily'),
            cta: l10n.t('splashCreateFamily'),
            icon: Icons.family_restroom_outlined,
            color: GuardianTokens.guardianTealLight,
            canContinue: true);
      case AppStartupState.unverified:
        return _StartupNote(
            text: l10n.t('splashUnverified'),
            cta: l10n.t('splashContinue'),
            icon: Icons.shield_outlined,
            color: Colors.amber.shade300,
            canContinue: true);
      case AppStartupState.authenticatedWithFamily:
        if (firebaseState == AppFirebaseState.unconfigured) {
          return _StartupNote(
              text: l10n.t('splashFirebaseUnconfigured'),
              cta: l10n.t('splashContinueOffline'),
              icon: Icons.cloud_off_outlined,
              color: Colors.amber.shade300,
              canContinue: true);
        }
        return _StartupNote(
            text: l10n.t('splashReady'),
            cta: l10n.t('splashContinue'),
            icon: Icons.check_circle_outline,
            color: GuardianTokens.guardianTealLight,
            canContinue: true);
    }
  }
}
