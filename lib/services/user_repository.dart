import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

/// CRUD for the shared `users/{uid}` document. See [UserProfile] for the
/// schema every module should read from.
class UserRepository {
  UserRepository._();

  static final CollectionReference<Map<String, dynamic>> _users = FirebaseFirestore.instance.collection('users');

  static Future<void> createIfMissing({required String uid, required String email}) async {
    final doc = _users.doc(uid);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await doc.set(UserProfile(uid: uid, email: email, createdAt: DateTime.now()).toMap());
    }
  }

  static Future<void> saveProfile(UserProfile profile) {
    return _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  static Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  static Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((s) {
      final data = s.data();
      return data == null ? null : UserProfile.fromMap(data);
    });
  }
}
