import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident.dart';

/// Module 9 — Incident Reporting, Timeline & Admin Dashboard.
///
/// Reads/writes the shared `incidents` collection (also written to by
/// Module 3's SOS trigger once that's wired up). The web Admin Dashboard
/// is a separate app reading this same collection.
class IncidentService {
  IncidentService._();

  static final _db = FirebaseFirestore.instance;
  static final _collection = _db.collection('incidents');

  /// TODO(module-1): swap for FirebaseAuth.instance.currentUser!.uid once
  /// real auth lands. Kept as a single constant so it's a one-line change.
  static const currentUserId = 'demo_user';

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