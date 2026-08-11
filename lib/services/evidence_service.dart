import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording.dart';
import 'encryption_service.dart';

/// Module 7 — Evidence Recording & local Storage.
///
/// Recordings never leave the device: audio/photo/video are captured
/// on-device, then immediately AES-encrypted at rest via
/// [EncryptionService] before the plaintext file is deleted — the index
/// (title/duration/timestamps) is kept in SharedPreferences alongside the
/// encrypted files. There is no cloud upload — the project deliberately
/// doesn't use Firebase Storage (it requires the paid Blaze plan), so
/// "your evidence stays on your device" is a real property here, not just
/// a UI claim. Viewing an entry requires decrypting it first — see
/// [decryptForViewing] — which callers should only do after a
/// BiometricService.authenticate() success.
class EvidenceService {
  EvidenceService._();

  static const _indexKey = 'evidence.recordings';
  static final _recorder = AudioRecorder();
  static final _picker = ImagePicker();
  static final _controller = StreamController<List<Recording>>.broadcast();
  static List<Recording>? _cache;
  static DateTime? _recordingStartedAt;
  static String? _activeIncidentId;

  static Future<Directory> _evidenceDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/evidence');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<Recording>> _loadIndex() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_indexKey) ?? [];
    final list = raw
        .map((s) => Recording.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = list;
    return list;
  }

  static Future<void> _saveIndex(List<Recording> list) async {
    _cache = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _indexKey,
      list.map((r) => jsonEncode(r.toJson())).toList(),
    );
    _controller.add(List.unmodifiable(list));
  }

  static Future<bool> get isRecording => _recorder.isRecording();

  /// Starts a real audio recording to a file on this device. Returns false
  /// (without throwing) if microphone permission isn't granted — callers
  /// should treat that as "evidence wasn't captured this time" rather than
  /// blocking whatever triggered it (e.g. an SOS alert must still go out).
  static Future<bool> startRecording({String? incidentId}) async {
    if (await _recorder.isRecording()) return true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    final dir = await _evidenceDir();
    final timestamp = DateTime.now();
    final path = '${dir.path}/evidence_${timestamp.millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    } catch (_) {
      return false;
    }
    _recordingStartedAt = timestamp;
    _activeIncidentId = incidentId;
    return true;
  }

  /// Stops the active recording (if any), encrypts it, and adds it to the
  /// local index.
  static Future<Recording?> stopRecording() async {
    if (!await _recorder.isRecording()) return null;
    final path = await _recorder.stop();
    final startedAt = _recordingStartedAt;
    final incidentId = _activeIncidentId;
    _recordingStartedAt = null;
    _activeIncidentId = null;
    if (path == null) return null;

    final durationSeconds = startedAt == null
        ? null
        : DateTime.now().difference(startedAt).inSeconds;
    final createdAt = startedAt ?? DateTime.now();

    String encryptedPath;
    try {
      encryptedPath = await EncryptionService.encryptFile(File(path));
    } catch (_) {
      return null;
    }

    final recording = Recording(
      id: createdAt.millisecondsSinceEpoch.toString(),
      type: RecordingType.audio,
      title: 'SOS Audio — ${_formatTitleDate(createdAt)}',
      localPath: encryptedPath,
      createdAt: createdAt,
      durationSeconds: durationSeconds,
      incidentId: incidentId,
    );

    final list = List<Recording>.from(await _loadIndex())..insert(0, recording);
    await _saveIndex(list);
    return recording;
  }

  /// Discards the active recording without saving it (e.g. false alarm).
  static Future<void> cancelRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
    _recordingStartedAt = null;
    _activeIncidentId = null;
  }

  /// Opens the camera for a photo, encrypts it, and adds it to the local
  /// index. Returns null if the user cancelled or the camera couldn't be
  /// opened — never throws.
  static Future<Recording?> captureImage({String? incidentId}) async {
    XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    } catch (_) {
      return null;
    }
    if (file == null) return null;
    return _encryptAndIndex(File(file.path), RecordingType.photo, incidentId: incidentId);
  }

  /// Opens the camera for a short video, encrypts it, and adds it to the
  /// local index. Returns null if the user cancelled or the camera
  /// couldn't be opened — never throws.
  static Future<Recording?> captureVideo({String? incidentId}) async {
    XFile? file;
    try {
      file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
    } catch (_) {
      return null;
    }
    if (file == null) return null;
    return _encryptAndIndex(File(file.path), RecordingType.video, incidentId: incidentId);
  }

  static Future<Recording?> _encryptAndIndex(
    File plainFile,
    RecordingType type, {
    String? incidentId,
  }) async {
    final createdAt = DateTime.now();
    String encryptedPath;
    try {
      encryptedPath = await EncryptionService.encryptFile(plainFile);
    } catch (_) {
      return null;
    }
    final recording = Recording(
      id: createdAt.millisecondsSinceEpoch.toString(),
      type: type,
      title: '${_titleFor(type)} — ${_formatTitleDate(createdAt)}',
      localPath: encryptedPath,
      createdAt: createdAt,
      incidentId: incidentId,
    );
    final list = List<Recording>.from(await _loadIndex())..insert(0, recording);
    await _saveIndex(list);
    return recording;
  }

  static String _titleFor(RecordingType type) => switch (type) {
    RecordingType.audio => 'Audio',
    RecordingType.video => 'Video',
    RecordingType.photo => 'Photo',
  };

  static Stream<List<Recording>> streamRecordings() {
    _loadIndex().then((list) => _controller.add(List.unmodifiable(list)));
    return _controller.stream;
  }

  /// Decrypts [recording] into a fresh temp file for viewing — call only
  /// after a successful BiometricService.authenticate(). The caller must
  /// pass the result to [cleanupDecrypted] once done viewing so the
  /// plaintext copy doesn't linger on disk.
  static Future<File> decryptForViewing(Recording recording) async {
    final tempDir = await getTemporaryDirectory();
    final withoutEncSuffix = recording.localPath.endsWith('.enc')
        ? recording.localPath.substring(0, recording.localPath.length - 4)
        : recording.localPath;
    final ext = withoutEncSuffix.contains('.') ? withoutEncSuffix.split('.').last : 'bin';
    final dest = File('${tempDir.path}/evidence_view_${recording.id}.$ext');
    return EncryptionService.decryptToFile(recording.localPath, dest);
  }

  /// Deletes a plaintext file produced by [decryptForViewing]. Safe to
  /// call even if the file is already gone.
  static Future<void> cleanupDecrypted(File file) async {
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Best-effort — a leftover temp file in the app's own cache dir
        // isn't a real exposure and will be cleared by the OS eventually.
      }
    }
  }

  static Future<void> deleteRecording(Recording recording) async {
    final file = File(recording.localPath);
    if (await file.exists()) await file.delete();
    final list = List<Recording>.from(await _loadIndex())
      ..removeWhere((r) => r.id == recording.id);
    await _saveIndex(list);
  }

  static String _formatTitleDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
