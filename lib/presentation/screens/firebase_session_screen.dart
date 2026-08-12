import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
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
      setState(() => _error = 'authentication_failed');
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
      setState(() => _error = 'anonymous_authentication_failed');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(firebaseAuthSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('حساب Firebase')),
      body: SafeArea(
        child: session.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _SessionMessage(
              title: 'تعذر قراءة حالة المصادقة',
              body: 'حاول مرة أخرى بعد التحقق من إعداد Firebase.'),
          data: (value) => _body(value),
        ),
      ),
    );
  }

  Widget _body(AuthSession session) {
    if (session.status == AuthSessionStatus.unconfigured) {
      return const _SessionMessage(
          title: 'Firebase غير مهيأ',
          body:
              'يبقى التطبيق محليًا دون اتصال. لا يمكن تسجيل الدخول أو مزامنة أي بيانات حتى يضيف مالك المشروع إعداد Firebase المعتمد.');
    }
    if (session.isAuthenticated) {
      final isAnonymous = session.identity!.isAnonymous;
      return Padding(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(
              isAnonymous
                  ? Icons.person_outline
                  : Icons.verified_user_outlined,
              size: 48),
          const SizedBox(height: 16),
          Text(isAnonymous ? 'جلسة مؤقتة' : 'تمت المصادقة',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
              isAnonymous
                  ? 'هذه الجلسة المجهولة لا تمنح دور والد أو صلاحيات عائلية تلقائيًا.'
                  : (session.identity!.email ?? 'حساب بلا بريد'),
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
              label: const Text('تسجيل الخروج')),
          if (_error != null) _ErrorText(value: _error!),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_createAccount ? 'إنشاء حساب' : 'تسجيل الدخول',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('يُستخدم هذا التدفق فقط مع Firebase الذي يملكه المشروع.'),
        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: _working ? null : _signInAnonymously,
            icon: const Icon(Icons.person_outline),
            label: const Text('المتابعة بجلسة مؤقتة')),
        const SizedBox(height: 8),
        const Text(
            'الجلسة المؤقتة لا تمثل حساب والد ولا تمنح عضوية أو صلاحيات عائلية.'),
        const SizedBox(height: 24),
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
        const SizedBox(height: 12),
        TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'كلمة المرور')),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _working ? null : _submit,
            child: Text(_working
                ? 'جارٍ التحقق…'
                : (_createAccount ? 'إنشاء الحساب' : 'تسجيل الدخول'))),
        TextButton(
            onPressed: _working
                ? null
                : () => setState(() => _createAccount = !_createAccount),
            child:
                Text(_createAccount ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد')),
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
