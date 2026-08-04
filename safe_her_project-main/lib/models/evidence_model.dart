import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported evidence media types.
///
/// Kept as a plain enum (matches the style of other simple enums in this
/// codebase, e.g. journey/geofence status flags) rather than pulling in a
/// code-gen package — no new dev-dependency needed for this.
enum EvidenceType { photo, video, audio, note }

/// Lifecycle status of a single evidence item.
///
/// - [pending]   : metadata written, file upload not yet confirmed complete
/// - [uploaded]  : file + metadata both confirmed in Storage/Firestore
/// - [failed]    : upload failed (network, validation) — safe to retry/delete
/// - [reported]  : attached to a submitted incident report — READ-ONLY from
///                 this point on (Requirement #11). Delete/edit must be
///                 blocked both client-side (see [EvidenceService]) and at
///                 the Firestore rules layer (see firestore.rules additions).
enum EvidenceStatus { pending, uploaded, failed, reported }

EvidenceType evidenceTypeFromString(String value) {
  return EvidenceType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EvidenceType.note,
  );
}

EvidenceStatus evidenceStatusFromString(String value) {
  return EvidenceStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => EvidenceStatus.pending,
  );
}

/// Represents one piece of evidence: a photo, video, audio clip, or text
/// note captured by the user, plus the location/time/device context that
/// makes it useful during an emergency.
///
/// Firestore collection: `recordings` (per the shared schema in the repo
/// README's "Suggested shared backend schema" section — this is the
/// collection name Module 7 owns; Module 9's `incidents` collection stores
/// only the `incidentId` reference, never a copy of the evidence itself).
///
/// Document path: `recordings/{evidenceId}`
class EvidenceModel {
  final String id;
  final String userId;

  /// Null until the user submits an emergency report that includes this
  /// item. Once set, [status] becomes [EvidenceStatus.reported] and the
  /// item becomes read-only (Requirement #11).
  final String? incidentId;

  final String fileName;

  /// Download URL in Firebase Storage. Null for text-only notes
  /// ([EvidenceType.note]), which have no backing file.
  final String? storageUrl;

  /// Storage path (e.g. `evidence/{userId}/{evidenceId}.jpg`) — kept
  /// separately from [storageUrl] so we can re-derive a fresh signed URL
  /// or delete the object without re-parsing the URL.
  final String? storagePath;

  final EvidenceType fileType;

  /// Size in bytes. 0 for text notes.
  final int fileSize;

  final double? latitude;
  final double? longitude;

  /// Optional free-text note. Either accompanies a media file, or — for
  /// [EvidenceType.note] — is the evidence itself.
  final String? textNote;

  final EvidenceStatus status;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EvidenceModel({
    required this.id,
    required this.userId,
    this.incidentId,
    required this.fileName,
    this.storageUrl,
    this.storagePath,
    required this.fileType,
    required this.fileSize,
    this.latitude,
    this.longitude,
    this.textNote,
    required this.status,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLocked => status == EvidenceStatus.reported;
  bool get hasLocation => latitude != null && longitude != null;

  factory EvidenceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return EvidenceModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      incidentId: data['incidentId'] as String?,
      fileName: data['fileName'] as String? ?? '',
      storageUrl: data['storageUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      fileType: evidenceTypeFromString(data['fileType'] as String? ?? 'note'),
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      textNote: data['textNote'] as String?,
      status: evidenceStatusFromString(data['status'] as String? ?? 'pending'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'incidentId': incidentId,
      'fileName': fileName,
      'storageUrl': storageUrl,
      'storagePath': storagePath,
      'fileType': fileType.name,
      'fileSize': fileSize,
      'latitude': latitude,
      'longitude': longitude,
      'textNote': textNote,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EvidenceModel copyWith({
    String? incidentId,
    String? storageUrl,
    String? storagePath,
    EvidenceStatus? status,
    DateTime? updatedAt,
  }) {
    return EvidenceModel(
      id: id,
      userId: userId,
      incidentId: incidentId ?? this.incidentId,
      fileName: fileName,
      storageUrl: storageUrl ?? this.storageUrl,
      storagePath: storagePath ?? this.storagePath,
      fileType: fileType,
      fileSize: fileSize,
      latitude: latitude,
      longitude: longitude,
      textNote: textNote,
      status: status ?? this.status,
      timestamp: timestamp,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
