import 'package:firebase_auth/firebase_auth.dart';

/// Email/password sign-in (Module 1), merged with Module 2's forward-
/// compatible anonymous-auth bridge.
///
/// Switched from phone/OTP because Firebase phone auth's Play Integrity
/// verification path kept failing (CONFIGURATION_NOT_FOUND / cert trust
/// errors) and Firebase Storage — used elsewhere in the app — now requires
/// the paid Blaze plan, which isn't an option for this project. Email/
/// password needs no billing and no SMS quota.
///
/// Prerequisite in the Firebase Console (Module 1 owner — do this once):
///  Authentication -> Sign-in method -> enable "Email/Password".
///
/// [signUp] links the email credential onto an existing anonymous session
/// (from [ensureSignedIn]) instead of minting a fresh UID, so any data
/// written anonymously before sign-up — e.g. Module 2 contacts added
/// before the user finished onboarding — carries over unchanged rather
/// than being orphaned under a UID nobody can reach again.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// Current UID if already signed in (anonymous or real), else null.
  static String? get currentUidOrNull => _auth.currentUser?.uid;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the current UID, signing in anonymously first if nobody is
  /// signed in yet. Safe to call repeatedly — Firebase caches the session.
  /// Modules that only need *a* stable UID (not necessarily an
  /// email-verified one) should use this rather than assuming
  /// [currentUser] is non-null.
  static Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    try {
      final credential = await _auth.signInAnonymously();
      final uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'Anonymous sign-in returned no user.');
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_anonMessageFor(e));
    } catch (_) {
      throw const AuthException('Could not connect to sign you in. Check your internet connection and try again.');
    }
  }

  /// Creates a new account. Links onto the current anonymous session if
  /// there is one, otherwise signs up fresh. Falls back to a plain sign-in
  /// if the email turns out to already belong to an existing account.
  static Future<UserCredential> signUp({required String email, required String password}) async {
    try {
      final credential = EmailAuthProvider.credential(email: email, password: password);
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          return await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use' || e.code == 'provider-already-linked') {
            return await _auth.signInWithCredential(credential);
          }
          rethrow;
        }
      }
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyError(e));
    }
  }

  static Future<UserCredential> signIn({required String email, required String password}) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyError(e));
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyError(e));
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with that email. Try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found with that email and password.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  static String _anonMessageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'operation-not-allowed':
        return 'Sign-in is temporarily unavailable. Please try again later.';
      default:
        return e.message ?? 'Could not sign you in. Please try again.';
    }
  }
}

/// Thrown by [AuthService] with a message safe to show directly to users.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
