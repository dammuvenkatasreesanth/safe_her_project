import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the mobile app's `users/{uid}` document (lib/models/user_profile.dart
/// in the safe_her project).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.fullName = '',
    this.bloodGroup,
    this.profileComplete = false,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String fullName;
  final String? bloodGroup;
  final bool profileComplete;
  final DateTime? createdAt;

  factory AppUser.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAtRaw = data['createdAt'];
    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      bloodGroup: data['bloodGroup'] as String?,
      profileComplete: data['profileComplete'] as bool? ?? false,
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : null,
    );
  }
}
