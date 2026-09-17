import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the mobile app's `live_sessions` collection (written by
/// lib/services/tracking_service.dart in the safe_her project).
class LiveSession {
  const LiveSession({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.status,
    this.destinationLabel,
    this.vehicleNumber,
    this.startTime,
    this.lastLat,
    this.lastLng,
    this.lastUpdatedAt,
    this.sharedWithCount = 0,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String status; // 'active' | 'ended'
  final String? destinationLabel;
  final String? vehicleNumber;
  final DateTime? startTime;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastUpdatedAt;
  final int sharedWithCount;

  bool get isActive => status == 'active';

  factory LiveSession.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final last = data['lastLocation'] as Map<String, dynamic>?;
    final start = data['startTime'] as Timestamp?;
    final lastUpdated = last?['updatedAt'] as Timestamp?;
    final shared = data['sharedWithUserIds'] as List?;
    return LiveSession(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Unknown',
      status: data['status'] as String? ?? 'active',
      destinationLabel: data['destinationLabel'] as String?,
      vehicleNumber: data['vehicleNumber'] as String?,
      startTime: start?.toDate(),
      lastLat: (last?['lat'] as num?)?.toDouble(),
      lastLng: (last?['lng'] as num?)?.toDouble(),
      lastUpdatedAt: lastUpdated?.toDate(),
      sharedWithCount: shared?.length ?? 0,
    );
  }
}
