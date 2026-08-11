import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_her/services/encryption_service.dart';

void main() {
  group('EncryptionService byte round trip', () {
    test('decrypting with the same key returns the original bytes', () {
      final key = enc.Key.fromSecureRandom(32);
      final original = Uint8List.fromList(utf8.encode('SafeHer evidence — do not tamper.'));

      final encrypted = EncryptionService.encryptBytes(original, key);
      final decrypted = EncryptionService.decryptBytes(encrypted, key);

      expect(decrypted, equals(original));
    });

    test('encrypted output is not the plaintext and is not empty', () {
      final key = enc.Key.fromSecureRandom(32);
      final original = Uint8List.fromList(List.generate(500, (i) => i % 256));

      final encrypted = EncryptionService.encryptBytes(original, key);

      expect(encrypted, isNot(equals(original)));
      expect(encrypted.length, greaterThan(original.length)); // nonce + auth tag overhead
    });

    test('two encryptions of the same bytes produce different ciphertext (random nonce)', () {
      final key = enc.Key.fromSecureRandom(32);
      final original = Uint8List.fromList(utf8.encode('same input twice'));

      final first = EncryptionService.encryptBytes(original, key);
      final second = EncryptionService.encryptBytes(original, key);

      expect(first, isNot(equals(second)));
    });

    test('decrypting with the wrong key throws rather than returning silently-wrong bytes', () {
      final key = enc.Key.fromSecureRandom(32);
      final wrongKey = enc.Key.fromSecureRandom(32);
      final original = Uint8List.fromList(utf8.encode('sensitive evidence bytes'));

      final encrypted = EncryptionService.encryptBytes(original, key);

      expect(() => EncryptionService.decryptBytes(encrypted, wrongKey), throwsA(anything));
    });

    test('a tampered ciphertext fails to decrypt instead of returning corrupted bytes', () {
      final key = enc.Key.fromSecureRandom(32);
      final original = Uint8List.fromList(utf8.encode('tamper-evident evidence'));

      final encrypted = EncryptionService.encryptBytes(original, key);
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF; // flip the last byte (inside the auth tag)

      expect(() => EncryptionService.decryptBytes(tampered, key), throwsA(anything));
    });

    test('round trip works for binary (non-UTF8) data like a real photo/audio file', () {
      final key = enc.Key.fromSecureRandom(32);
      // Bytes that would be invalid UTF-8 — stands in for real media bytes.
      final original = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x00, 0x80, 0x81]);

      final encrypted = EncryptionService.encryptBytes(original, key);
      final decrypted = EncryptionService.decryptBytes(encrypted, key);

      expect(decrypted, equals(original));
    });
  });
}
