import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';

/// Guardian Eye Pro five-tab navigation shell.
///
/// One shell per role experience — the tab set is the product map the
/// user lives in. Tabs that need a family context are honest about it:
/// they render disabled with the "setup first" affordance rather than
/// pretending the content exists.
///
/// Wired as a `ShellRoute` in `app_router.dart`.
class GuardianBottomNav extends StatelessWidget {
  const GuardianBottomNav({
    super.key,
    required this.child,
    this.familyId,
  });

  final Widget child;

  /// Optional family identifier. When absent, tabs that require family
  /// context disable themselves rather than crashing or showing empty
  /// shells.
  final String? familyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).uri.path;

    final items = [
      _Tab(icon: Icons.home_outlined, active: Icons.home, path: '/',
          label: l10n.t('navDashboard')),
      _Tab(icon: Icons.family_restroom_outlined, active: Icons.family_restroom,
          path: '/family/$familyId', label: l10n.t('navChildren'),
          requiresFamily: true),
      _Tab(icon: Icons.shield_outlined, active: Icons.shield,
          path: '/safety/daily/$familyId', label: l10n.t('navSafety'),
          requiresFamily: true),
      _Tab(icon: Icons.timeline_outlined, active: Icons.timeline,
          path: '/timeline/$familyId', label: l10n.t('navTimeline'),
          requiresFamily: true),
      _Tab(icon: Icons.settings_outlined, active: Icons.settings,
          path: '/settings', label: l10n.t('navSettings')),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: GuardianTokens.guardianNavy,
          boxShadow: [
            BoxShadow(
              color: GuardianTokens.guardianNavy.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final tab in items)
                  Expanded(
                    child: _NavItem(
                      tab: tab,
                      active: tab.resolvedPath == location,
                      enabled: !tab.requiresFamily || familyId != null,
                      onTap: () {
                        final target = tab.requiresFamily
                            ? '/${tab.path.startsWith('/') ? tab.path.substring(1) : tab.path}'
                            : tab.path;
                        if (familyId == null && tab.requiresFamily) {
                          context.push('/');
                          return;
                        }
                        if (target != location) context.go(target);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.icon,
    required this.active,
    required this.path,
    required this.label,
    this.requiresFamily = false,
  });

  final IconData icon;
  final IconData active;
  final String path;
  final String label;
  final bool requiresFamily;

  String get resolvedPath {
    if (!requiresFamily) return path;
    // '/family/$familyId' is a template — match anything under it.
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    return '/${segments.first}';
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tab.label,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(GuardianTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? tab.active : tab.icon,
                color: enabled
                    ? (active
                        ? GuardianTokens.guardianTealLight
                        : Colors.white70)
                    : Colors.white24,
                size: 23,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: enabled
                        ? (active ? Colors.white : Colors.white60)
                        : Colors.white24,
                    fontFamily: GuardianTokens.fontFamily,
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
