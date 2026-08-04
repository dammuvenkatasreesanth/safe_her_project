import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/evidence_model.dart';

/// Thrown for anything the UI should surface as a friendly error/snackbar
/// rather than a stack trace. Mirrors the "don't leak exceptions to the UI"
/// pattern used by `location_service.dart` / `geocoding_service.dart`
/// (fallback-first, typed failures).
class EvidenceException implements Exception {
  final String message;
  const EvidenceException(this.message);
  @override
  String toString() => message;
}

/// Progress + terminal state for a single upload, streamed to the UI so it
/// can drive a progress bar and a success/error snackbar (Requirement #8).
class EvidenceUploadProgress {
  final double fraction; // 0.0 - 1.0
  final EvidenceModel? completedEvidence; // set only on the final event
  final String? error;

  const EvidenceUploadProgress({required this.fraction, this.completedEvidence, this.error});

  bool get isDone => completedEvidence != null || error != null;
}

/// Handles everything for Module 7 — Evidence Recording & Storage:
///   - metadata persistence in Firestore (`recordings` collection)
///   - file persistence in Firebase Storage (`evidence/{userId}/...`)
///   - format/size validation
///   - status-gated delete ("before reported" — Requirement #10/#11)
///
/// Firebase Storage encrypts all objects at rest (server-side, GCP-managed
/// keys) and in transit (TLS) by default, satisfying Requirement #12
/// without extra client-side key management. If the team later wants
/// client-side (end-to-end) encryption on top of that, that's a deliberate
/// follow-up requiring secure key storage (e.g. `flutter_secure_storage`)
/// — flagged in the module docs rather than bolted on here.
///
/// Usage pattern matches the rest of `lib/services/`: a plain class with
/// static-ish instance methods, no DI framework, instantiated where needed
/// (e.g. `final _evidenceService = EvidenceService();` in the screen's
/// State class) — same as `LocationService`/`GeocodingService`.
class EvidenceService {
  EvidenceService({FirebaseFirestore? firestore, FirebaseStorage? storage, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('recordings');

  // ---------------------------------------------------------------------
  // Validation (Requirements #13, #14)
  // ---------------------------------------------------------------------

  static const Map<EvidenceType, List<String>> allowedExtensions = {
    EvidenceType.photo: ['jpg', 'jpeg', 'png', 'heic'],
    EvidenceType.video: ['mp4', 'mov', 'm4v'],
    EvidenceType.audio: ['m4a', 'mp3', 'wav', 'aac'],
  };

  /// 50 MB per file. Generous enough for a few minutes of video while
  /// still protecting mobile data plans / Storage costs in an emergency
  /// context where uploads may be happening on a poor connection.
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  void _validateFile(File file, EvidenceType type) {
    final ext = file.path.split('.').last.toLowerCase();
    final allowed = allowedExtensions[type];
    if (allowed == null || !allowed.contains(ext)) {
      throw EvidenceException(
        'Unsupported file format ".$ext" for ${type.name}. Allowed: ${allowed?.join(', ')}',
      );
    }
    final size = file.lengthSync();
    if (size <= 0) {
      throw const EvidenceException('Selected file is empty.');
    }
    if (size > maxFileSizeBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      throw EvidenceException(
        'File is ${mb}MB — max allowed is ${maxFileSizeBytes ~/ (1024 * 1024)}MB.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Upload (Requirements #1-#8)
  // ---------------------------------------------------------------------

  /// Uploads a media file + writes its metadata, streaming progress the
  /// whole way. Call with the file returned from `camera`/`image_picker`/
  /// `record` (capture) or `file_picker`/`image_picker` (device upload) —
  /// this method doesn't care which source produced the file.
  ///
  /// [latitude]/[longitude] should come from the same `LocationService`
  /// already used by Live Tracking (Module 4) so GPS-unavailable fallback
  /// behavior stays consistent app-wide (Requirement's "GPS unavailable"
  /// error case: pass null and this still succeeds, just without location).
  Stream<EvidenceUploadProgress> uploadEvidence({
    required File file,
    required EvidenceType type,
    String? textNote,
    double? latitude,
    double? longitude,
  }) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield const EvidenceUploadProgress(fraction: 0, error: 'You must be signed in to upload evidence.');
      return;
    }

    try {
      _validateFile(file, type);
    } on EvidenceException catch (e) {
      yield EvidenceUploadProgress(fraction: 0, error: e.message);
      return;
    }

    final docRef = _collection.doc(); // pre-generate ID so Storage path is known up front
    final fileName = file.path.split('/').last;
    final storagePath = 'evidence/${user.uid}/${docRef.id}_$fileName';
    final fileSize = file.lengthSync();
    final now = DateTime.now();

    try {
      final ref = _storage.ref(storagePath);
      final uploadTask = ref.putFile(file);

      await for (final snap in uploadTask.snapshotEvents) {
        final fraction = snap.totalBytes > 0 ? snap.bytesTransferred / snap.totalBytes : 0.0;
        if (snap.state == TaskState.running || snap.state == TaskState.paused) {
          yield EvidenceUploadProgress(fraction: fraction);
        }
      }

      final downloadUrl = await ref.getDownloadURL();

      final evidence = EvidenceModel(
        id: docRef.id,
        userId: user.uid,
        fileName: fileName,
        storageUrl: downloadUrl,
        storagePath: storagePath,
        fileType: type,
        fileSize: fileSize,
        latitude: latitude,
        longitude: longitude,
        textNote: textNote,
        status: EvidenceStatus.uploaded,
        timestamp: now,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(evidence.toFirestore());
      yield EvidenceUploadProgress(fraction: 1.0, completedEvidence: evidence);
    } on FirebaseException catch (e) {
      // Network failures, storage-quota errors, permission-denied, etc.
      // land here — handled gracefully rather than crashing (Requirement #15).
      yield EvidenceUploadProgress(
        fraction: 0,
        error: e.code == 'unauthorized'
            ? 'You do not have permission to upload this file.'
            : 'Upload failed: ${e.message ?? e.code}. Please check your connection and try again.',
      );
    } catch (e) {
      yield EvidenceUploadProgress(fraction: 0, error: 'Unexpected error while uploading: $e');
    }
  }

  /// Saves a text-only note (Requirement #3's "optional text notes") —
  /// no file, no Storage write, just a Firestore doc.
  Future<EvidenceModel> saveTextNote({
    required String textNote,
    double? latitude,
    double? longitude,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EvidenceException('You must be signed in to save a note.');
    }
    if (textNote.trim().isEmpty) {
      throw const EvidenceException('Note cannot be empty.');
    }

    final docRef = _collection.doc();
    final now = DateTime.now();
    final evidence = EvidenceModel(
      id: docRef.id,
      userId: user.uid,
      fileName: 'note_${docRef.id}.txt',
      fileType: EvidenceType.note,
      fileSize: textNote.length,
      latitude: latitude,
      longitude: longitude,
      textNote: textNote.trim(),
      status: EvidenceStatus.uploaded,
      timestamp: now,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(evidence.toFirestore());
    return evidence;
  }

  // ---------------------------------------------------------------------
  // Read (Requirement #9)
  // ---------------------------------------------------------------------

  /// Live stream of the current user's evidence, newest first. Firestore
  /// security rules (see firestore.rules) enforce that a user can only
  /// ever query their own `userId` — this filter is defense-in-depth, not
  /// the actual security boundary.
  Stream<List<EvidenceModel>> watchEvidenceForCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _collection
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(EvidenceModel.fromFirestore).toList());
  }

  Future<EvidenceModel?> getById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return EvidenceModel.fromFirestore(doc);
  }

  // ---------------------------------------------------------------------
  // Delete (Requirements #10, #11)
  // ---------------------------------------------------------------------

  /// Deletes both the Storage file and the Firestore doc — but only if
  /// the evidence hasn't been attached to a submitted report yet. Once
  /// [EvidenceStatus.reported], this throws instead of silently no-op'ing,
  /// so the UI can show a clear "this evidence is locked" message.
  Future<void> deleteEvidence(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return;

    final evidence = EvidenceModel.fromFirestore(doc);
    if (evidence.isLocked) {
      throw const EvidenceException(
        'This evidence has been attached to a submitted report and can no longer be deleted.',
      );
    }

    if (evidence.storagePath != null) {
      try {
        await _storage.ref(evidence.storagePath!).delete();
      } on FirebaseException catch (e) {
        // If the file's already gone, don't block deleting the metadata.
        if (e.code != 'object-not-found') rethrow;
      }
    }
    await _collection.doc(id).delete();
  }

  // ---------------------------------------------------------------------
  // Lock on report submission (Requirement #11)
  // ---------------------------------------------------------------------

  /// Called by Module 9 (Incident Reporting) when the user submits an
  /// emergency report, passing the IDs of evidence items selected for
  /// inclusion. Flips them to read-only and links them to the incident.
  ///
  /// This is the integration point other modules should call — expose it
  /// (or a thin wrapper) so Module 9 doesn't need to know about the
  /// `recordings` collection's internal shape.
  Future<void> attachEvidenceToReport({
    required List<String> evidenceIds,
    required String incidentId,
  }) async {
    if (evidenceIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in evidenceIds) {
      batch.update(_collection.doc(id), {
        'incidentId': incidentId,
        'status': EvidenceStatus.reported.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }
}
