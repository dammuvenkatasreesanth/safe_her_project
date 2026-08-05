import 'package:firebase_auth/firebase_auth.dart';

/// Real phone-number sign-in (Module 1), merged with Module 2's
/// forward-compatible anonymous-auth bridge.
///
/// Prerequisites in the Firebase Console (Module 1 owner — do this once):
///  1. Authentication -> Sign-in method -> enable "Phone".
///  2. Android: register your debug/release SHA-1 + SHA-256 fingerprints
///     under Project settings -> your Android app, or verification will
///     silently fall back to a (slower) reCAPTCHA flow.
///  3. For development without burning real SMS: Authentication -> Sign-in
///     method -> Phone -> "Phone numbers for testing" — add a fake number
///     (e.g. +91 99999 99999) with a fixed code (e.g. 123456).
///
/// [verifyOtp]/the auto-verified path link the phone credential onto an
/// existing anonymous session (from [ensureSignedIn]) instead of minting a
/// fresh UID, so any data written anonymously before sign-in — e.g.
/// Module 2 contacts added before the user finished onboarding — carries
/// over unchanged rather than being orphaned under a UID nobody can reach
/// again.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// Current UID if already signed in (anonymous or real), else null.
  static String? get currentUidOrNull => _auth.currentUser?.uid;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the current UID, signing in anonymously first if nobody is
  /// signed in yet. Safe to call repeatedly — Firebase caches the session.
  /// Modules that only need *a* stable UID (not necessarily a
  /// phone-verified one) should use this rather than assuming
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

  /// Starts phone verification. [onCodeSent] fires once Firebase has sent
  /// the SMS — hand its `verificationId` to [verifyOtp] afterwards.
  /// [onAutoVerified] can fire first on some Android devices that detect
  /// the SMS automatically, skipping manual code entry entirely.
  static Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function(UserCredential credential) onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          onAutoVerified(await _signInOrLink(credential));
        } on FirebaseAuthException catch (e) {
          onError(_friendlyError(e));
        }
      },
      verificationFailed: (e) => onError(_friendlyError(e)),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  static Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    return _signInOrLink(credential);
  }

  /// Links onto the current anonymous session if there is one, otherwise
  /// signs in fresh. Falls back to a plain sign-in if the phone number
  /// turns out to already belong to a different (real) account.
  static Future<UserCredential> _signInOrLink(PhoneAuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'provider-already-linked') {
          return _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }
    return _auth.signInWithCredential(credential);
  }

  static Future<void> signOut() => _auth.signOut();

  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-verification-code':
        return 'Incorrect code. Please try again.';
      case 'session-expired':
        return 'This code expired. Request a new one.';
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
