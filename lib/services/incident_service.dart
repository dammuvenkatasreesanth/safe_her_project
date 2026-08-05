import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident.dart';
import 'auth_service.dart';

/// Module 9 — Incident Reporting, Timeline & Admin Dashboard.
///
/// Reads/writes the shared `incidents` collection (also written to by
/// Module 3's SOS trigger once that's wired up). The web Admin Dashboard
/// is a separate app reading this same collection.
class IncidentService {
  IncidentService._();

  static final _db = FirebaseFirestore.instance;
  static final _collection = _db.collection('incidents');

  /// Module 1 landed — real signed-in UID. Every call site already assumes
  /// the user is authenticated by the time it runs (Report/History are
  /// only reachable past the auth gate), so a null here is a genuine bug
  /// upstream rather than something to silently paper over.
  static String get currentUserId => AuthService.currentUser!.uid;

  /// Submits a new incident report from the Report screen.
  static Future<String> submitReport({
    required String category,
    required String description,
    required String locationLabel,
    LatLng? locationLatLng,
    bool hasPhoto = false,
  }) async {
    final incident = Incident(
      id: '', // assigned by Firestore
      reporterId: currentUserId,
      type: IncidentType.report,
      status: IncidentStatus.resolved,
      title: 'Incident Reported',
      subtitle: description.isEmpty ? category : description,
      createdAt: DateTime.now(),
      reportCategory: category,
      description: description,
      locationLabel: locationLabel,
      locationLatLng: locationLatLng,
      hasPhoto: hasPhoto,
    );

    final docRef = await _collection.add(incident.toMap());
    return docRef.id;
  }

  /// Real-time feed of this user's incidents (reports + past SOS alerts),
  /// newest first — backs the History tab.
  static Stream<List<Incident>> streamIncidents({int limit = 100}) {
    return _collection
        .where('reporterId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Incident.fromFirestore).toList());
  }
}