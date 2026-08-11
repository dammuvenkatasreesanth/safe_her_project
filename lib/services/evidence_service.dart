import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording.dart';

/// Module 7 — Evidence Recording & local Storage.
///
/// Recordings never leave the device: audio is captured with the `record`
/// plugin straight to this app's own documents directory, and the index
/// (title/duration/timestamps) is kept in SharedPreferences alongside it.
/// There is no cloud upload — the project deliberately doesn't use Firebase
/// Storage (it requires the paid Blaze plan), so "your evidence stays on
/// your device" is a real property here, not just a UI claim.
class EvidenceService {
  EvidenceService._();

  static const _indexKey = 'evidence.recordings';
  static final _recorder = AudioRecorder();
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

  /// Stops the active recording (if any) and adds it to the local index.
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
    final recording = Recording(
      id: createdAt.millisecondsSinceEpoch.toString(),
      type: RecordingType.audio,
      title: 'SOS Audio — ${_formatTitleDate(createdAt)}',
      localPath: path,
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

  static Stream<List<Recording>> streamRecordings() {
    _loadIndex().then((list) => _controller.add(List.unmodifiable(list)));
    return _controller.stream;
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
