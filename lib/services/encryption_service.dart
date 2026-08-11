import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption for evidence files at rest (Module 7). The key
/// is generated once on first use and stored in the OS keystore (Android
/// Keystore / iOS Keychain via flutter_secure_storage) — it never leaves
/// the device and isn't visible to the app's own Firestore/backup data.
///
/// GCM (not plain CBC) so tampering with an encrypted file is detected —
/// decryption fails loudly instead of silently returning corrupted bytes.
///
/// The pure [encryptBytes]/[decryptBytes] pair take the key as a plain
/// argument so the actual crypto round trip is unit-testable without a
/// real device/keystore; [encryptFile]/[decryptToFile] are the file-system
/// glue EvidenceService actually calls.
class EncryptionService {
  EncryptionService._();

  static const _storage = FlutterSecureStorage();
  static const _keyStorageKey = 'evidence_encryption_key_v1';
  static const _nonceBytes = 12; // standard GCM nonce size
  static enc.Key? _cachedKey;

  static Future<enc.Key> _getOrCreateKey() async {
    final cached = _cachedKey;
    if (cached != null) return cached;
    var stored = await _storage.read(key: _keyStorageKey);
    if (stored == null) {
      stored = enc.Key.fromSecureRandom(32).base64; // AES-256
      await _storage.write(key: _keyStorageKey, value: stored);
    }
    final key = enc.Key.fromBase64(stored);
    _cachedKey = key;
    return key;
  }

  /// Encrypts [bytes] with a fresh random nonce, prepended to the output
  /// (the nonce isn't secret — carrying it alongside the ciphertext is
  /// the standard approach so decryption doesn't need it stored separately).
  static Uint8List encryptBytes(Uint8List bytes, enc.Key key) {
    final iv = enc.IV.fromSecureRandom(_nonceBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
  }

  /// Reverses [encryptBytes]. Throws if [data] was tampered with or
  /// encrypted under a different key — GCM's auth tag makes that a hard
  /// failure rather than silently-wrong output.
  static Uint8List decryptBytes(Uint8List data, enc.Key key) {
    final iv = enc.IV(data.sublist(0, _nonceBytes));
    final cipherBytes = data.sublist(_nonceBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// Encrypts [plainFile] in place: writes an encrypted sibling
  /// (`<path>.enc`) then deletes the original plaintext. Returns the
  /// encrypted file's path.
  static Future<String> encryptFile(File plainFile) async {
    final key = await _getOrCreateKey();
    final bytes = await plainFile.readAsBytes();
    final encryptedBytes = encryptBytes(bytes, key);
    final encryptedPath = '${plainFile.path}.enc';
    await File(encryptedPath).writeAsBytes(encryptedBytes, flush: true);
    await plainFile.delete();
    return encryptedPath;
  }

  /// Decrypts the file at [encryptedPath] into [destination] — used
  /// transiently for viewing. Callers own cleaning up [destination]
  /// afterwards (see EvidenceService.cleanupDecrypted); this never leaves
  /// a plaintext copy anywhere except that explicit, caller-managed file.
  static Future<File> decryptToFile(String encryptedPath, File destination) async {
    final key = await _getOrCreateKey();
    final bytes = await File(encryptedPath).readAsBytes();
    final decryptedBytes = decryptBytes(bytes, key);
    await destination.writeAsBytes(decryptedBytes, flush: true);
    return destination;
  }
}
