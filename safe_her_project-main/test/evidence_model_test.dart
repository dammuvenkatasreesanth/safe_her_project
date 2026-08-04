import 'package:flutter_test/flutter_test.dart';
import 'package:safe_her/models/evidence_model.dart';

void main() {
  group('EvidenceModel status logic', () {
    test('isLocked is true only when status is reported', () {
      final base = EvidenceModel(
        id: 'e1',
        userId: 'u1',
        fileName: 'photo.jpg',
        fileType: EvidenceType.photo,
        fileSize: 1024,
        status: EvidenceStatus.uploaded,
        timestamp: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(base.isLocked, isFalse);

      final reported = base.copyWith(status: EvidenceStatus.reported);
      expect(reported.isLocked, isTrue);
    });

    test('hasLocation is false when lat/lng are null', () {
      final noLocation = EvidenceModel(
        id: 'e2',
        userId: 'u1',
        fileName: 'note.txt',
        fileType: EvidenceType.note,
        fileSize: 10,
        status: EvidenceStatus.uploaded,
        timestamp: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(noLocation.hasLocation, isFalse);

      final withLocation = EvidenceModel(
        id: 'e3',
        userId: 'u1',
        fileName: 'note.txt',
        fileType: EvidenceType.note,
        fileSize: 10,
        latitude: 23.7,
        longitude: 90.4,
        status: EvidenceStatus.uploaded,
        timestamp: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(withLocation.hasLocation, isTrue);
    });
  });

  group('Enum parsing falls back safely on unknown/corrupt values', () {
    test('evidenceTypeFromString defaults to note for unrecognized input', () {
      expect(evidenceTypeFromString('photo'), EvidenceType.photo);
      expect(evidenceTypeFromString('bogus'), EvidenceType.note);
    });

    test('evidenceStatusFromString defaults to pending for unrecognized input', () {
      expect(evidenceStatusFromString('reported'), EvidenceStatus.reported);
      expect(evidenceStatusFromString('bogus'), EvidenceStatus.pending);
    });
  });

  group('toFirestore / fromFirestore field mapping', () {
    test('toFirestore includes all expected keys', () {
      final model = EvidenceModel(
        id: 'e4',
        userId: 'u1',
        fileName: 'clip.mp4',
        fileType: EvidenceType.video,
        fileSize: 2048,
        status: EvidenceStatus.uploaded,
        timestamp: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final map = model.toFirestore();
      expect(map['fileType'], 'video');
      expect(map['status'], 'uploaded');
      expect(map['fileName'], 'clip.mp4');
      expect(map.containsKey('incidentId'), isTrue); // present (null) not omitted
    });
  });
}

// -----------------------------------------------------------------------
// NOTE: EvidenceService itself (Firestore/Storage/Auth calls) needs
// fake_cloud_firestore + firebase_storage_mocks + firebase_auth_mocks as
// dev_dependencies to test without hitting real Firebase — not added yet
// since that's a dev_dependencies change I'd rather bundle with Pass 2
// once the UI's test needs are known too, to avoid two separate
// pubspec-editing round trips. Flagging here so it isn't forgotten.
// -----------------------------------------------------------------------
