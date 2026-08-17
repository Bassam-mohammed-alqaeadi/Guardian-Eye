import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';

/// Reusable Guardian Eye Pro UI primitives.
///
/// Every screen builds on these — never on ad-hoc `Card`/`Chip`/`Row`
/// compositions. Primitives are pure presentation: they take strings,
/// icons, and callbacks, never providers. This keeps them trivially
/// testable and reusable by both the parent and child experiences.
///
/// Honest-state rule: status visuals describe real, observed state.
/// A primitive never renders a color that implies a state the app has
/// not actually measured.

// ── Section ──────────────────────────────────────────────────────────────────

/// A labeled content section. The label answers "what is this for?"
/// in one product sentence — the label, not the contents, carries the
/// hierarchy.
class GuardianSection extends StatelessWidget {
  const GuardianSection({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
    this.spacing = 12,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        ..._withSpacing(children),
      ],
    );
  }

  List<Widget> _withSpacing(List<Widget> children) =>
      [for (final child in children) ...[child, SizedBox(height: spacing)]];
}

// ── Card variants ────────────────────────────────────────────────────────────

/// Standard content card: flat, hairline-bordered, 16-radius — the
/// platform's workhorse surface.
class GuardianCard extends StatelessWidget {
  const GuardianCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.onTap,
    this.color,
  });

  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GuardianTokens.radiusCard),
      child: card,
    );
  }
}

/// A brand-gradient hero card (safety score, family identity, first-run
/// value proposition). White text, no border.
class GuardianHeroCard extends StatelessWidget {
  const GuardianHeroCard({
    super.key,
    required this.child,
    this.gradient,
    this.radius = GuardianTokens.radiusCardLarge,
  });

  final Widget child;
  final Gradient? gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient ?? GuardianTokens.guardianGradient,
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontFamily: GuardianTokens.fontFamily),
        child: child,
      ),
    );
  }
}

// ── Status chip ──────────────────────────────────────────────────────────────

/// An honest state pill. The color is chosen from the measured status,
/// never picked ad-hoc. `live` adds the breathing dot for live data.
class GuardianStatusChip extends StatelessWidget {
  const GuardianStatusChip({
    super.key,
    required this.label,
    required this.kind,
    this.live = false,
    this.icon,
  });

  final String label;
  final GuardianStatusKind kind;
  final bool live;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = kind.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(GuardianTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            const _PulseDot(color: GuardianTokens.statusSafe),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: palette.text),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.text,
              fontFamily: GuardianTokens.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilderCompat(
      listenable: _controller,
      builder: (opacity) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.55 * opacity + 0.45),
        ),
      ),
    );
  }
}

/// Simple opacity-driven animation wrapper (keeps primitives dependency-
/// free of animation-kit imports beyond flutter/material).
class AnimatedBuilderCompat extends AnimatedWidget {
  const AnimatedBuilderCompat({
    super.key,
    required super.listenable,
    required this.builder,
  });

  final Widget Function(double) builder;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    return builder(animation.value);
  }
}

/// The honest status taxonomy — every measurable state in the platform
/// maps to exactly one of these. Adding a new status is a documented
/// decision, not a color choice in a screen.
enum GuardianStatusKind {
  safe,
  watch,
  alert,
  offline,
  sos,
  neutral,
  pro;

  GuardianStatusPalette get palette {
    switch (this) {
      case GuardianStatusKind.safe:
        return const GuardianStatusPalette(
            GuardianTokens.statusSafe, GuardianTokens.statusSafeSoft);
      case GuardianStatusKind.watch:
        return const GuardianStatusPalette(
            GuardianTokens.statusWatch, GuardianTokens.statusWatchSoft);
      case GuardianStatusKind.alert:
        return const GuardianStatusPalette(
            GuardianTokens.statusAlert, GuardianTokens.statusAlertSoft);
      case GuardianStatusKind.offline:
        return const GuardianStatusPalette(
            GuardianTokens.statusOffline, GuardianTokens.statusOfflineSoft);
      case GuardianStatusKind.sos:
        return const GuardianStatusPalette(
            GuardianTokens.statusSOS, GuardianTokens.statusAlertSoft);
      case GuardianStatusKind.pro:
        return const GuardianStatusPalette(
            GuardianTokens.statusPro, GuardianTokens.statusProSoft);
      case GuardianStatusKind.neutral:
        return const GuardianStatusPalette(
            Color(0xFF4A5A78), Color(0xFFEDF2F9));
    }
  }
}

class GuardianStatusPalette {
  const GuardianStatusPalette(this.text, this.soft);
  final Color text;
  final Color soft;
}

// ── Global states ────────────────────────────────────────────────────────────

/// The honest state view: loading / empty / error / offline with retry.
/// Used by every list and detail surface so the product language for
/// "nothing here yet" and "this failed" stays identical everywhere.
class GuardianStateView extends StatelessWidget {
  const GuardianStateView({
    super.key,
    required this.state,
    this.message,
    this.onRetry,
    this.onPrimaryAction,
    this.primaryActionLabel,
  });

  final GuardianViewState state;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    switch (state) {
      case GuardianViewState.loading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 14),
                Text(
                  message ?? l10n.t('loading'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      case GuardianViewState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 44, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  message ?? l10n.t('nothingHereYet'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (onPrimaryAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onPrimaryAction,
                    child: Text(primaryActionLabel ?? l10n.t('continue')),
                  ),
                ],
              ],
            ),
          ),
        );
      case GuardianViewState.error:
      case GuardianViewState.offline:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state == GuardianViewState.offline
                      ? Icons.wifi_off_outlined
                      : Icons.cloud_off_outlined,
                  size: 44,
                  color: GuardianTokens.statusOffline,
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      (state == GuardianViewState.offline
                          ? l10n.t('offlineMode')
                          : l10n.t('somethingWentWrong')),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (state == GuardianViewState.offline) ...[
                  const SizedBox(height: 6),
                  Text(l10n.t('offlineChangesSaved'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(l10n.t('retry')),
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }
}

enum GuardianViewState { loading, empty, error, offline }

// ── Small helpers ────────────────────────────────────────────────────────────

/// A circular icon badge used by cards and lists (member icons, feature
/// marks, category icons).
class GuardianIconBadge extends StatelessWidget {
  const GuardianIconBadge({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.size = 44,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? cs.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: foreground ?? Colors.white,
        size: size * 0.5,
      ),
    );
  }
}

/// A two-line stat tile (value + label) used in dashboards.
class GuardianStatTile extends StatelessWidget {
  const GuardianStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.kind,
  });

  final IconData icon;
  final String value;
  final String label;
  final GuardianStatusKind? kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = kind?.palette.text ?? theme.colorScheme.primary;
    return GuardianCard(
      padding: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: theme.textTheme.titleLarge),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal offline banner — the honest network-state reminder that
/// sits above the bottom navigation.
class GuardianOfflineBanner extends StatelessWidget {
  const GuardianOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: GuardianTokens.statusOfflineSoft,
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 16, color: GuardianTokens.statusOffline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('offlineChangesSaved'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: GuardianTokens.statusOffline,
                fontFamily: GuardianTokens.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
