import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the mobile app's `incidents` collection schema exactly
/// (lib/models/incident.dart in the safe_her project) — this is the same
/// shared Firestore collection, just read here instead of written.
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
    this.latitude,
    this.longitude,
    this.hasPhoto = false,
  });

  final String id;
  final String reporterId;
  final IncidentType type;
  final IncidentStatus status;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final String? reportCategory;
  final String? description;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final bool hasPhoto;

  /// SOS alerts and automatic safety events (geofence exit, safe arrival)
  /// share `type == sos`; the [title] is what actually distinguishes them
  /// ("SOS Alert", "Left Safe Zone", "Arrived Home Safely") — mirrors how
  /// the mobile app's IncidentService.submitSafetyEvent logs them.
  bool get isAutomaticSafetyEvent =>
      type == IncidentType.sos && title != 'SOS Alert' && !title.startsWith('SOS Alert');

  factory Incident.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final loc = data['locationLatLng'] as Map<String, dynamic>?;
    final createdTimestamp = data['createdAt'] as Timestamp?;
    return Incident(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      type: IncidentType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => IncidentType.report,
      ),
      status: IncidentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => IncidentStatus.resolved,
      ),
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      reportCategory: data['reportCategory'] as String?,
      description: data['description'] as String?,
      locationLabel: data['locationLabel'] as String?,
      latitude: (loc?['lat'] as num?)?.toDouble(),
      longitude: (loc?['lng'] as num?)?.toDouble(),
      hasPhoto: data['hasPhoto'] as bool? ?? false,
    );
  }
}
