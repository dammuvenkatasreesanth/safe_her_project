import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class LiveSession {
  LiveSession({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.startTime,
    required this.status,
    required this.destinationLabel,
    required this.destinationLatLng,
    this.vehicleNumber,
    this.etaMinutes,
    this.lastLocation,
    this.sharedWithUserIds = const [],
    this.arrivedSafely = false,
    this.sharingPaused = false,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final DateTime startTime;
  final String status; // 'active' | 'ended'
  final String destinationLabel;
  final LatLng destinationLatLng;
  final String? vehicleNumber;
  final int? etaMinutes;
  final SessionLocation? lastLocation;
  final List<String> sharedWithUserIds;

  /// True only when the session was ended by SafeHer's own arrival
  /// detection (see LiveTrackingTabState._handleArrival) — distinct from
  /// a plain manual "Stop Sharing," so a contact watching the trip can
  /// tell "she made it" from "she stopped sharing" at a glance.
  final bool arrivedSafely;

  /// True while the traveler has toggled off live-location sharing
  /// mid-journey without ending it — see
  /// LiveTrackingTabState._toggleSharing. The viewer screen uses this to
  /// tell a contact "still on her way, just not sharing live position
  /// right now" instead of implying the last-known point is current.
  final bool sharingPaused;

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'startTime': Timestamp.fromDate(startTime),
      'status': status,
      'destinationLabel': destinationLabel,
      'destinationLatLng': {
        'lat': destinationLatLng.latitude,
        'lng': destinationLatLng.longitude,
      },
      'vehicleNumber': vehicleNumber,
      'etaMinutes': etaMinutes,
      if (lastLocation != null) 'lastLocation': lastLocation!.toMap(),
      'sharedWithUserIds': sharedWithUserIds,
      'arrivedSafely': arrivedSafely,
      'sharingPaused': sharingPaused,
    };
  }

  factory LiveSession.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw StateError('Session ${doc.id} does not exist or was removed.');
    }
    final data = doc.data() as Map<String, dynamic>;
    final dest = data['destinationLatLng'] as Map<String, dynamic>?;
    final last = data['lastLocation'] as Map<String, dynamic>?;
    final startTimestamp = data['startTime'] as Timestamp?;

    return LiveSession(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      startTime: startTimestamp?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
      destinationLabel: data['destinationLabel'] ?? '',
      destinationLatLng: LatLng(dest?['lat'] ?? 0, dest?['lng'] ?? 0),
      vehicleNumber: data['vehicleNumber'],
      etaMinutes: data['etaMinutes'],
      lastLocation: last != null ? SessionLocation.fromMap(last) : null,
      sharedWithUserIds: List<String>.from(data['sharedWithUserIds'] ?? []),
      arrivedSafely: data['arrivedSafely'] ?? false,
      sharingPaused: data['sharingPaused'] ?? false,
    );
  }
}

class SessionLocation {
  SessionLocation({
    required this.lat,
    required this.lng,
    required this.updatedAt,
  });

  final double lat;
  final double lng;
  final DateTime updatedAt;

  LatLng get toLatLng => LatLng(lat, lng);

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory SessionLocation.fromMap(Map<String, dynamic> map) {
    final timestamp = map['updatedAt'] as Timestamp?;
    return SessionLocation(
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      updatedAt: timestamp?.toDate() ?? DateTime.now(),
    );
  }
}