import 'package:firebase_auth/firebase_auth.dart';

/// Bridges Module 2 to a real Firebase Auth UID.
///
/// Module 1 (Auth & Profile) is still UI-only — the OTP screen is mocked
/// and never actually calls `FirebaseAuth`, so there is currently no real
/// signed-in user anywhere in the app. Contacts/Nearby Help still need a
/// stable, real UID today to write to `users/{uid}/contacts`, so this
/// service signs the device in anonymously on first use.
///
/// This is intentionally forward-compatible: when Module 1 wires up real
/// phone verification, it can call
/// `FirebaseAuth.instance.currentUser!.linkWithCredential(phoneCredential)`
/// on this same anonymous user instead of creating a new one — the UID
/// (and every contact already saved under it) carries over unchanged.
/// No changes to this file are required for that to work.
class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;

  /// Returns the current UID, signing in anonymously first if nobody is
  /// signed in yet. Safe to call repeatedly — Firebase caches the session.
  static Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    try {
      final credential = await _auth.signInAnonymously();
      final uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'Anonymous sign-in returned no user.',
        );
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } catch (_) {
      throw const AuthException(
        'Could not connect to sign you in. Check your internet connection '
        'and try again.',
      );
    }
  }

  /// Current UID if already signed in, else null (does not trigger a
  /// sign-in — use [ensureSignedIn] when you need a guaranteed value).
  static String? get currentUidOrNull => _auth.currentUser?.uid;

  static String _messageFor(FirebaseAuthException e) {
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
