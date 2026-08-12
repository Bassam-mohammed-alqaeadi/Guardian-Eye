import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

enum AuthSessionStatus { unconfigured, unauthenticated, authenticated, failure }

class AuthenticatedIdentity {
  const AuthenticatedIdentity(
      {required this.uid, required this.email, required this.isAnonymous});
  final String uid;
  final String? email;
  final bool isAnonymous;
}

class AuthSession {
  const AuthSession({required this.status, this.identity, this.reason});
  final AuthSessionStatus status;
  final AuthenticatedIdentity? identity;
  final String? reason;
  bool get isAuthenticated =>
      status == AuthSessionStatus.authenticated && identity != null;
}

class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.reason);
  final String reason;
}

abstract class AuthContext {
  AuthSession get currentSession;
  Stream<AuthSession> get changes;
}

class FirebaseAuthContext implements AuthContext {
  const FirebaseAuthContext();
  bool get _configured =>
      const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED') &&
      Firebase.apps.isNotEmpty;
  AuthSession _fromUser(User? user) => user == null
      ? const AuthSession(status: AuthSessionStatus.unauthenticated)
      : AuthSession(
          status: AuthSessionStatus.authenticated,
          identity: AuthenticatedIdentity(
              uid: user.uid, email: user.email, isAnonymous: user.isAnonymous));
  @override
  AuthSession get currentSession => !_configured
      ? const AuthSession(
          status: AuthSessionStatus.unconfigured,
          reason: 'firebase_not_configured')
      : _fromUser(FirebaseAuth.instance.currentUser);
  @override
  Stream<AuthSession> get changes => !_configured
      ? Stream.value(currentSession)
      : FirebaseAuth.instance.authStateChanges().map(_fromUser).handleError(
          (_) => const AuthSession(
              status: AuthSessionStatus.failure, reason: 'auth_state_failure'));
}

class FirebaseAuthService {
  FirebaseAuthService(this._context);
  final FirebaseAuthContext _context;
  void _requireConfigured() {
    if (_context.currentSession.status == AuthSessionStatus.unconfigured) {
      throw const AuthUnavailableException('firebase_not_configured');
    }
  }

  Future<AuthSession> signInWithEmail(
      {required String email, required String password}) async {
    _requireConfigured();
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email.trim(), password: password);
    return _context.currentSession;
  }

  Future<AuthSession> createAccount(
      {required String email, required String password}) async {
    _requireConfigured();
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    return _context.currentSession;
  }

  Future<AuthSession> signInAnonymously() async {
    _requireConfigured();
    await FirebaseAuth.instance.signInAnonymously();
    return _context.currentSession;
  }

  Future<void> signOut() async {
    _requireConfigured();
    await FirebaseAuth.instance.signOut();
  }
}
