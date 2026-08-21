import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/firebase_auth_context.dart';

class FirebaseSessionScreen extends ConsumerStatefulWidget {
  const FirebaseSessionScreen({super.key});

  @override
  ConsumerState<FirebaseSessionScreen> createState() =>
      _FirebaseSessionScreenState();
}

class _FirebaseSessionScreenState extends ConsumerState<FirebaseSessionScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final auth = ref.read(firebaseAuthServiceProvider);
      if (_createAccount) {
        await auth.createAccount(email: _email.text, password: _password.text);
      } else {
        await auth.signInWithEmail(
            email: _email.text, password: _password.text);
      }
    } on AuthUnavailableException catch (error) {
      setState(() => _error = error.reason);
    } catch (_) {
      setState(
          () => _error = AppLocalizations.of(context).t('firebaseAuthFailed'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(firebaseAuthServiceProvider).signInAnonymously();
    } on AuthUnavailableException catch (error) {
      setState(() => _error = error.reason);
    } catch (_) {
      setState(() => _error =
          AppLocalizations.of(context).t('firebaseAnonymousAuthFailed'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(firebaseAuthSessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('firebaseAccountTitle'))),
      body: SafeArea(
        child: session.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _SessionMessage(
              title: l10n.t('firebaseAuthReadErrorTitle'),
              body: l10n.t('firebaseAuthReadErrorBody')),
          data: (value) => _body(l10n, value),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, AuthSession session) {
    if (session.status == AuthSessionStatus.unconfigured) {
      return _SessionMessage(
          title: l10n.t('firebaseUnconfiguredTitle'),
          body: l10n.t('firebaseUnconfiguredBody'));
    }
    if (session.isAuthenticated) {
      final isAnonymous = session.identity!.isAnonymous;
      return Padding(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(
              isAnonymous ? Icons.person_outline : Icons.verified_user_outlined,
              size: 48),
          const SizedBox(height: 16),
          Text(
              isAnonymous
                  ? l10n.t('firebaseAnonymousSession')
                  : l10n.t('firebaseAuthenticated'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
              isAnonymous
                  ? l10n.t('firebaseAnonymousNote')
                  : (session.identity!.email ??
                      l10n.t('firebaseNoEmailAccount')),
              textAlign: TextAlign.center),
          const Spacer(),
          FilledButton.tonalIcon(
              onPressed: _working
                  ? null
                  : () async {
                      setState(() => _working = true);
                      try {
                        await ref.read(firebaseAuthServiceProvider).signOut();
                      } on AuthUnavailableException catch (error) {
                        setState(() => _error = error.reason);
                      } finally {
                        if (mounted) setState(() => _working = false);
                      }
                    },
              icon: const Icon(Icons.logout),
              label: Text(l10n.t('firebaseSignOut'))),
          if (_error != null) _ErrorText(value: _error!),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.t('firebaseSignInOrCreate'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.t('firebaseProjectNote')),
        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: _working ? null : _signInAnonymously,
            icon: const Icon(Icons.person_outline),
            label: Text(l10n.t('firebaseContinueAnonymous'))),
        const SizedBox(height: 8),
        Text(l10n.t('firebaseAnonymousNote')),
        const SizedBox(height: 24),
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration:
                InputDecoration(labelText: l10n.t('firebaseEmailLabel'))),
        const SizedBox(height: 12),
        TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration:
                InputDecoration(labelText: l10n.t('firebasePasswordLabel'))),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _working ? null : _submit,
            child: Text(_working
                ? l10n.t('firebaseVerifying')
                : (_createAccount
                    ? l10n.t('firebaseCreateAccountSubmit')
                    : l10n.t('firebaseSignInSubmit')))),
        TextButton(
            onPressed: _working
                ? null
                : () => setState(() => _createAccount = !_createAccount),
            child: Text(_createAccount
                ? l10n.t('firebaseHaveAccount')
                : l10n.t('firebaseNewAccount'))),
        if (_error != null) _ErrorText(value: _error!),
      ],
    );
  }
}

class _SessionMessage extends StatelessWidget {
  const _SessionMessage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_outlined, size: 48),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
      ]));
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(value,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error)));
}
