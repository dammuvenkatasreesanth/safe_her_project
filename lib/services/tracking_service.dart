import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/live_session.dart';

class TrackingService {
  TrackingService._();

  static final _db = FirebaseFirestore.instance;

  static Future<String> startSession({
    required String ownerId,
    required String ownerName,
    required String destinationLabel,
    required LatLng destinationLatLng,
    String? vehicleNumber,
    int? etaMinutes,
  }) async {
    final docRef = await _db.collection('live_sessions').add({
      'ownerId': ownerId,
      'ownerName': ownerName,
      'startTime': FieldValue.serverTimestamp(),
      'status': 'active',
      'destinationLabel': destinationLabel,
      'destinationLatLng': {
        'lat': destinationLatLng.latitude,
        'lng': destinationLatLng.longitude,
      },
      'vehicleNumber': vehicleNumber,
      'etaMinutes': etaMinutes,
      'sharedWithUserIds': [],
    });
    return docRef.id;
  }

  static Future<void> updateLocation(String sessionId, LatLng location) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'lastLocation': {
        'lat': location.latitude,
        'lng': location.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  static Future<void> endSession(String sessionId) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'status': 'ended',
    });
  }

  /// Ends the session the same way [endSession] does, but flags it as a
  /// safe arrival rather than a plain manual stop — see
  /// [LiveSession.arrivedSafely]. Any contact with the tracking viewer
  /// open sees this the moment it's written, no action needed on their
  /// end.
  static Future<void> endSessionOnArrival(String sessionId) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'status': 'ended',
      'arrivedSafely': true,
    });
  }

  /// Toggled by "Stop/Resume Sharing Live Location" during a journey —
  /// never touches `status`, so it can't accidentally end the journey.
  /// See LiveSession.sharingPaused.
  static Future<void> setSharingPaused(String sessionId, bool paused) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'sharingPaused': paused,
    });
  }

  static Future<void> shareWithUsers(
    String sessionId,
    List<String> userIds,
  ) async {
    await _db.collection('live_sessions').doc(sessionId).update({
      'sharedWithUserIds': FieldValue.arrayUnion(userIds),
    });
  }

  static Stream<LiveSession> streamSession(String sessionId) {
    return _db
        .collection('live_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => LiveSession.fromFirestore(doc));
  }
}

class PositionUpdate {
  final LatLng point;
  final DateTime time;
  PositionUpdate(this.point, this.time);
}
