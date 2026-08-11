enum RecordingType { audio, video, photo }

/// Metadata for an evidence file stored locally on the device (see
/// EvidenceService) — no cloud upload, per the "your recordings stay on
/// your device" design decision for Module 7.
class Recording {
  Recording({
    required this.id,
    required this.type,
    required this.title,
    required this.localPath,
    required this.createdAt,
    this.durationSeconds,
    this.incidentId,
  });

  final String id;
  final RecordingType type;
  final String title;

  /// Absolute path to the file on this device's own storage.
  final String localPath;
  final DateTime createdAt;
  final int? durationSeconds;

  /// Links back to the `incidents` doc (Module 9) this evidence belongs
  /// to, if it was captured during an SOS alert or report.
  final String? incidentId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'localPath': localPath,
    'createdAt': createdAt.toIso8601String(),
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (incidentId != null) 'incidentId': incidentId,
  };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
    id: json['id'] as String,
    type: RecordingType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => RecordingType.audio,
    ),
    title: json['title'] as String? ?? 'Recording',
    localPath: json['localPath'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    durationSeconds: json['durationSeconds'] as int?,
    incidentId: json['incidentId'] as String?,
  );
}
