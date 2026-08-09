import 'package:cloud_firestore/cloud_firestore.dart';

/// The shared `users/{uid}` Firestore document every module reads from —
/// Module 1 owns writes to this; other modules should treat it read-only
/// (add your own subcollections under `users/{uid}/...` instead of bolting
/// fields onto this doc).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    this.fullName = '',
    this.bloodGroup,
    this.medicalNotes,
    this.photoUrl,
    this.profileComplete = false,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String fullName;
  final String? bloodGroup;
  final String? medicalNotes;
  final String? photoUrl;
  final bool profileComplete;
  final DateTime? createdAt;

  UserProfile copyWith({
    String? fullName,
    String? bloodGroup,
    String? medicalNotes,
    String? photoUrl,
    bool? profileComplete,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      photoUrl: photoUrl ?? this.photoUrl,
      profileComplete: profileComplete ?? this.profileComplete,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'bloodGroup': bloodGroup,
      'medicalNotes': medicalNotes,
      'photoUrl': photoUrl,
      'profileComplete': profileComplete,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    return UserProfile(
      uid: map['uid'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      bloodGroup: map['bloodGroup'] as String?,
      medicalNotes: map['medicalNotes'] as String?,
      photoUrl: map['photoUrl'] as String?,
      profileComplete: map['profileComplete'] as bool? ?? false,
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : null,
    );
  }
}
