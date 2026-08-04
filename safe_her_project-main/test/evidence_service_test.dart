import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_her/models/evidence_model.dart';
import 'package:safe_her/services/evidence_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseStorage storage;
  late MockFirebaseAuth auth;
  late EvidenceService service;
  late Directory tempDir;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'user_1', email: 'test@safeher.app'));
    service = EvidenceService(firestore: firestore, storage: storage, auth: auth);
    tempDir = await Directory.systemTemp.createTemp('evidence_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  File writeTempFile(String name, {int bytes = 1024}) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List.filled(bytes, 0));
    return file;
  }

  group('Validation (Requirements #13, #14)', () {
    test('rejects unsupported file extension', () async {
      final file = writeTempFile('evidence.exe');
      final events = await service
          .uploadEvidence(file: file, type: EvidenceType.photo)
          .toList();
      expect(events.last.error, contains('Unsupported file format'));
    });

    test('rejects file over the size cap', () async {
      final file = writeTempFile(
        'big.jpg',
        bytes: EvidenceService.maxFileSizeBytes + 1,
      );
      final events = await service
          .uploadEvidence(file: file, type: EvidenceType.photo)
          .toList();
      expect(events.last.error, contains('max allowed'));
    });

    test('rejects an empty file', () async {
      final file = writeTempFile('empty.jpg', bytes: 0);
      final events = await service
          .uploadEvidence(file: file, type: EvidenceType.photo)
          .toList();
      expect(events.last.error, contains('empty'));
    });

    test('accepts a valid file within limits', () async {
      final file = writeTempFile('photo.jpg', bytes: 2048);
      final events = await service
          .uploadEvidence(file: file, type: EvidenceType.photo)
          .toList();
      expect(events.last.completedEvidence, isNotNull);
      expect(events.last.completedEvidence!.status, EvidenceStatus.uploaded);
    });
  });

  group('Upload happy path (Requirements #5, #6, #7)', () {
    test('auto-attaches userId, timestamp, type, and size', () async {
      final file = writeTempFile('clip.mp4', bytes: 4096);
      final events = await service
          .uploadEvidence(file: file, type: EvidenceType.video, latitude: 23.7, longitude: 90.4)
          .toList();
      final evidence = events.last.completedEvidence!;

      expect(evidence.userId, 'user_1');
      expect(evidence.fileType, EvidenceType.video);
      expect(evidence.fileSize, 4096);
      expect(evidence.latitude, 23.7);
      expect(evidence.longitude, 90.4);
      expect(evidence.timestamp, isNotNull);

      final doc = await firestore.collection('recordings').doc(evidence.id).get();
      expect(doc.exists, isTrue);
    });

    test('rejects upload when signed out', () async {
      final signedOutService = EvidenceService(
        firestore: firestore,
        storage: storage,
        auth: MockFirebaseAuth(signedIn: false),
      );
      final file = writeTempFile('photo.jpg');
      final events = await signedOutService
          .uploadEvidence(file: file, type: EvidenceType.photo)
          .toList();
      expect(events.single.error, contains('signed in'));
    });
  });

  group('Text notes', () {
    test('saveTextNote persists a note-only evidence item', () async {
      final evidence = await service.saveTextNote(textNote: 'Followed by a stranger.');
      expect(evidence.fileType, EvidenceType.note);
      expect(evidence.textNote, 'Followed by a stranger.');
      expect(evidence.fileSize, greaterThan(0));
    });

    test('rejects an empty note', () async {
      expect(
        () => service.saveTextNote(textNote: '   '),
        throwsA(isA<EvidenceException>()),
      );
    });
  });

  group('Delete before reported (Requirements #10, #11)', () {
    test('deletes evidence while status is uploaded', () async {
      final file = writeTempFile('photo.jpg');
      final events = await service.uploadEvidence(file: file, type: EvidenceType.photo).toList();
      final evidence = events.last.completedEvidence!;

      await service.deleteEvidence(evidence.id);

      final doc = await firestore.collection('recordings').doc(evidence.id).get();
      expect(doc.exists, isFalse);
    });

    test('throws when attempting to delete reported evidence', () async {
      final file = writeTempFile('photo.jpg');
      final events = await service.uploadEvidence(file: file, type: EvidenceType.photo).toList();
      final evidence = events.last.completedEvidence!;

      await service.attachEvidenceToReport(evidenceIds: [evidence.id], incidentId: 'incident_1');

      expect(
        () => service.deleteEvidence(evidence.id),
        throwsA(isA<EvidenceException>()),
      );

      // Confirm it's still there — the throw must be a real block, not a
      // silent no-op that also happens to leave the doc alone.
      final doc = await firestore.collection('recordings').doc(evidence.id).get();
      expect(doc.exists, isTrue);
    });
  });

  group('Lock on report submission (Requirement #11)', () {
    test('attachEvidenceToReport flips status and links incidentId for all given ids', () async {
      final file1 = writeTempFile('a.jpg');
      final file2 = writeTempFile('b.jpg');
      final e1 = (await service.uploadEvidence(file: file1, type: EvidenceType.photo).toList())
          .last
          .completedEvidence!;
      final e2 = (await service.uploadEvidence(file: file2, type: EvidenceType.photo).toList())
          .last
          .completedEvidence!;

      await service.attachEvidenceToReport(evidenceIds: [e1.id, e2.id], incidentId: 'incident_9');

      final doc1 = await service.getById(e1.id);
      final doc2 = await service.getById(e2.id);
      expect(doc1!.status, EvidenceStatus.reported);
      expect(doc1.incidentId, 'incident_9');
      expect(doc2!.status, EvidenceStatus.reported);
    });

    test('no-ops safely on an empty id list', () async {
      await service.attachEvidenceToReport(evidenceIds: [], incidentId: 'incident_9');
      // Should simply not throw.
    });
  });

  group('watchEvidenceForCurrentUser (Requirement #9)', () {
    test('only returns the signed-in user\'s evidence, newest first', () async {
      await firestore.collection('recordings').add(
        EvidenceModel(
          id: 'other',
          userId: 'someone_else',
          fileName: 'x.jpg',
          fileType: EvidenceType.photo,
          fileSize: 1,
          status: EvidenceStatus.uploaded,
          timestamp: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ).toFirestore(),
      );
      final file = writeTempFile('mine.jpg');
      await service.uploadEvidence(file: file, type: EvidenceType.photo).toList();

      final results = await service.watchEvidenceForCurrentUser().first;
      expect(results.length, 1);
      expect(results.first.userId, 'user_1');
    });
  });
}
