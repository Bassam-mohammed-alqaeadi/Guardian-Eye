import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';

/// PD-001 — Family Setup Entry. Dual-path selection for creating or joining.
class FamilySetupEntryScreen extends ConsumerWidget {
  const FamilySetupEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('welcome'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/images/guardian_eye_icon.png',
                    width: 88, height: 88, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 32),
            Text(l10n.t('noFamily'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 48),
            _PathCard(
              title: l10n.t('familyCreatePathTitle'),
              subtitle: l10n.t('familyCreatePathNote'),
              icon: Icons.add_home_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FamilyCreateScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _PathCard(
              title: l10n.t('familyJoinPathTitle'),
              subtitle: l10n.t('familyJoinPathNote'),
              icon: Icons.group_add_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FamilyJoinScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// PD-002 — Create Family. Refactored from dashboard_screen's private widget.
class FamilyCreateScreen extends ConsumerStatefulWidget {
  const FamilyCreateScreen({super.key});

  @override
  ConsumerState<FamilyCreateScreen> createState() => _FamilyCreateScreenState();
}

class _FamilyCreateScreenState extends ConsumerState<FamilyCreateScreen> {
  final _familyController = TextEditingController();
  final _parentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _familyController.dispose();
    _parentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final familyName = _familyController.text.trim();
    final parentName = _parentController.text.trim();
    if (familyName.isEmpty || parentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('familySetupRequired'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(familyRepositoryProvider).createFamily(
            familyName: familyName,
            parentName: parentName,
          );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('familyCreatePathTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _familyController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.t('familyProfileName'),
              prefixIcon: const Icon(Icons.family_restroom_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parentController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.t('parentName'),
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.t('splashCreateFamily')),
          ),
        ],
      ),
    );
  }
}

/// PD-003 — Join Family. Code-based join flow.
class FamilyJoinScreen extends ConsumerStatefulWidget {
  const FamilyJoinScreen({super.key});

  @override
  ConsumerState<FamilyJoinScreen> createState() => _FamilyJoinScreenState();
}

class _FamilyJoinScreenState extends ConsumerState<FamilyJoinScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _verifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (code.length != 6 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('familyJoinCodeRequired'))),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      final repo = ref.read(familyMembershipRepositoryProvider);
      final invitation = await repo.lookupInvitationByCode(code);
      if (invitation == null) {
        throw StateError('familyJoinCodeInvalid');
      }

      final auth = ref.read(firebaseAuthSessionProvider).valueOrNull;
      if (auth == null || auth.identity == null) {
        throw StateError('splashNotSignedIn');
      }

      await repo.acceptInvitation(
        invitationId: invitation.id,
        accountUid: auth.identity!.uid,
        accountEmail: auth.identity!.email ?? '',
        displayName: name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('familyJoinCodeSuccess'))),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        final key = e is StateError ? e.message : 'error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t(key))),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('familyJoinPathTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _codeController,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            style: const TextStyle(letterSpacing: 8, fontSize: 24),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: l10n.t('familyJoinCodeLabel'),
              counterText: '',
              hintText: 'XXXXXX',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.t('parentName'),
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _verifying ? null : _submit,
            child: _verifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.t('familyJoinSubmit')),
          ),
        ],
      ),
    );
  }
}
