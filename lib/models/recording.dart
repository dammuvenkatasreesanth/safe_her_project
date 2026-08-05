import 'package:cloud_firestore/cloud_firestore.dart';

enum RecordingType { audio, video, photo }

/// Metadata for a file stored under `evidence/{ownerId}/...` in Firebase
/// Storage (see storage.rules) — Module 7's shared schema.
class Recording {
  Recording({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.storagePath,
    required this.downloadUrl,
    required this.createdAt,
    this.durationSeconds,
    this.incidentId,
  });

  final String id;
  final String ownerId;
  final RecordingType type;
  final String title;
  final String storagePath;
  final String downloadUrl;
  final DateTime createdAt;
  final int? durationSeconds;

  /// Links back to the `incidents` doc (Module 9) this evidence belongs
  /// to, if it was captured during an SOS alert or report.
  final String? incidentId;

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'type': type.name,
        'title': title,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (incidentId != null) 'incidentId': incidentId,
      };

  factory Recording.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final createdTimestamp = data['createdAt'] as Timestamp?;
    return Recording(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      type: RecordingType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => RecordingType.audio,
      ),
      title: data['title'] ?? 'Recording',
      storagePath: data['storagePath'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      durationSeconds: data['durationSeconds'] as int?,
      incidentId: data['incidentId'] as String?,
    );
  }
}
