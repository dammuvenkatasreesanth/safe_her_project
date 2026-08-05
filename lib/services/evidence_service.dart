import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/recording.dart';
import 'auth_service.dart';

/// Module 7 — Audio/Video Recording & Cloud Evidence Storage.
///
/// Storage layout: `evidence/{uid}/{recordingId}_{fileName}` (see
/// storage.rules — owner-only read/write, 50MB cap enforced server-side
/// too). Metadata lives in the `recordings` Firestore collection so the
/// Evidence screen can list everything without downloading files.
///
/// Capture itself (camera/mic) isn't wired up yet — this is the
/// upload/list backend for whoever adds that with the `camera`/`record`
/// packages. Call [uploadRecording] with the captured file when that
/// lands; listing, sync status, and the SOS/incident link already work.
class EvidenceService {
  EvidenceService._();

  static final _db = FirebaseFirestore.instance;
  static final _collection = _db.collection('recordings');
  static final _storage = FirebaseStorage.instance;

  static const maxFileSizeBytes = 50 * 1024 * 1024;

  static Future<Recording> uploadRecording({
    required File file,
    required RecordingType type,
    required String title,
    String? incidentId,
    int? durationSeconds,
  }) async {
    final size = await file.length();
    if (size > maxFileSizeBytes) {
      throw Exception('File is too large (max 50MB).');
    }

    final uid = AuthService.currentUser!.uid;
    final docRef = _collection.doc();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final storagePath = 'evidence/$uid/${docRef.id}_$fileName';
    final ref = _storage.ref(storagePath);

    await ref.putFile(file);
    final downloadUrl = await ref.getDownloadURL();

    final recording = Recording(
      id: docRef.id,
      ownerId: uid,
      type: type,
      title: title,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      createdAt: DateTime.now(),
      durationSeconds: durationSeconds,
      incidentId: incidentId,
    );
    await docRef.set(recording.toMap());
    return recording;
  }

  static Stream<List<Recording>> streamRecordings() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _collection
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Recording.fromFirestore).toList());
  }

  static Future<void> deleteRecording(Recording recording) async {
    await _storage.ref(recording.storagePath).delete();
    await _collection.doc(recording.id).delete();
  }
}
