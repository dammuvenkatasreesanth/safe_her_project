import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth's phone-number sign-in flow.
///
/// Prerequisites in the Firebase Console (Module 1 owner — do this once):
///  1. Authentication -> Sign-in method -> enable "Phone".
///  2. Android: register your debug/release SHA-1 + SHA-256 fingerprints
///     under Project settings -> your Android app, or verification will
///     silently fall back to a (slower) reCAPTCHA flow.
///  3. For development without burning real SMS: Authentication -> Sign-in
///     method -> Phone -> "Phone numbers for testing" — add a fake number
///     (e.g. +91 99999 99999) with a fixed code (e.g. 123456).
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

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
          final result = await _auth.signInWithCredential(credential);
          onAutoVerified(result);
        } on FirebaseAuthException catch (e) {
          onError(e.message ?? 'Automatic verification failed');
        }
      },
      verificationFailed: (e) {
        onError(_friendlyError(e));
      },
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  static Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
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
}
