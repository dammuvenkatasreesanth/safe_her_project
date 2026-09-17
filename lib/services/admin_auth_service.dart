import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Signs an admin in with the *same* SafeHer Firebase project's
/// email/password auth the mobile app uses, then checks the
/// `admins/{uid}` allowlist collection to decide whether they're actually
/// allowed to see this dashboard.
///
/// This client-side check is only for UX (redirecting a non-admin back to
/// the login screen with a clear message) — the real enforcement is
/// firestore.rules' `isAdmin()` check, which every query in
/// AdminDataService is subject to regardless of what this class decides.
/// See README.md for how to add the first admin.
class AdminAuthService {
  AdminAuthService._();

  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<bool> isCurrentUserAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _db.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      // Firestore rules will reject this read outright for a non-admin —
      // that "permission-denied" is itself proof they're not an admin.
      return false;
    }
  }

  /// Signs in, then verifies admin status. Throws [AdminAuthException]
  /// with a message safe to show directly if either step fails — signs
  /// the user back out again if they authenticated but aren't an admin,
  /// so a non-admin SafeHer account can't linger half-signed-in here.
  static Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_friendlyError(e));
    }

    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) {
      await _auth.signOut();
      throw const AdminAuthException(
        'This account is not an admin. Ask an existing admin to add your '
        'user ID to the "admins" collection in Firestore.',
      );
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found with that email and password.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Could not sign in. Please try again.';
    }
  }
}

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
