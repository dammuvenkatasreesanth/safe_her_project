import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Matches the `incidents` collection in the shared Firestore schema
/// (used by Module 3 - SOS and Module 9 - Reporting/History/Admin Dashboard).
enum IncidentType { sos, report }

enum IncidentStatus { emergency, resolved, cancelled }

class Incident {
  Incident({
    required this.id,
    required this.reporterId,
    required this.type,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.reportCategory,
    this.description,
    this.locationLabel,
    this.locationLatLng,
    this.hasPhoto = false,
  });

  final String id;
  final String reporterId;
  final IncidentType type;
  final IncidentStatus status;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  /// Only set when [type] is IncidentType.report.
  final String? reportCategory;
  final String? description;
  final String? locationLabel;
  final LatLng? locationLatLng;
  final bool hasPhoto;

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'type': type.name,
      'status': status.name,
      'title': title,
      'subtitle': subtitle,
      'createdAt': FieldValue.serverTimestamp(),
      if (reportCategory != null) 'reportCategory': reportCategory,
      if (description != null) 'description': description,
      if (locationLabel != null) 'locationLabel': locationLabel,
      if (locationLatLng != null)
        'locationLatLng': {
          'lat': locationLatLng!.latitude,
          'lng': locationLatLng!.longitude,
        },
      'hasPhoto': hasPhoto,
    };
  }

  factory Incident.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final loc = data['locationLatLng'] as Map<String, dynamic>?;
    final createdTimestamp = data['createdAt'] as Timestamp?;

    return Incident(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      type: IncidentType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => IncidentType.report,
      ),
      status: IncidentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => IncidentStatus.resolved,
      ),
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      reportCategory: data['reportCategory'],
      description: data['description'],
      locationLabel: data['locationLabel'],
      locationLatLng: loc != null
          ? LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble())
          : null,
      hasPhoto: data['hasPhoto'] ?? false,
    );
  }
}
