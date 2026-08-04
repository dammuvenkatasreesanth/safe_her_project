import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/evidence_model.dart';
import '../../services/evidence_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';

/// Module 7 — Evidence Recording & Storage.
///
/// Was a static mock list; now backed live by [EvidenceService], which
/// reads/writes Firestore's `recordings` collection + Firebase Storage.
/// Visual language (card layout, colors, radii) is unchanged from the
/// original shell — only the data source and the new capture/upload
/// affordances are added, so this stays consistent with the rest of the
/// app rather than introducing a new look.
class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  final _evidenceService = EvidenceService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  /// Tracks in-flight uploads by a local temp key so the list can show a
  /// progress row before the Firestore doc exists yet (Requirement #8).
  final Map<String, double> _uploadProgress = {};
  final Map<String, String> _uploadLabels = {};

  bool _isRecordingAudio = false;
  Duration _recordingElapsed = Duration.zero;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Snackbar helper — consistent success/error feedback (Requirement #8's
  // "Success/Error Snackbar" from the UI spec)
  // ---------------------------------------------------------------------

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Location (Requirement #5, "GPS unavailable" error case)
  // ---------------------------------------------------------------------

  Future<(double?, double?)> _currentLatLng() async {
    final loc = await LocationService.getCurrentLocation();
    if (loc == null) {
      _showSnackbar('Location unavailable — saving evidence without GPS tag.');
      return (null, null);
    }
    return (loc.latitude, loc.longitude);
  }

  // ---------------------------------------------------------------------
  // Permissions (Camera / Microphone denied — explicit error cases)
  // ---------------------------------------------------------------------

  Future<bool> _ensurePermission(Permission permission, String deniedMessage) async {
    final status = await permission.request();
    if (status.isGranted) return true;
    _showSnackbar(deniedMessage, isError: true);
    return false;
  }

  // ---------------------------------------------------------------------
  // Upload pipeline shared by every capture/upload path
  // ---------------------------------------------------------------------

  Future<void> _uploadFile(File file, EvidenceType type, String label) async {
    final key = '${DateTime.now().microsecondsSinceEpoch}';
    final (lat, lng) = await _currentLatLng();

    setState(() {
      _uploadProgress[key] = 0;
      _uploadLabels[key] = label;
    });

    await for (final progress in _evidenceService.uploadEvidence(
      file: file,
      type: type,
      latitude: lat,
      longitude: lng,
    )) {
      if (!mounted) return;
      if (progress.error != null) {
        setState(() => _uploadProgress.remove(key));
        _uploadLabels.remove(key);
        _showSnackbar(progress.error!, isError: true);
        return;
      }
      setState(() => _uploadProgress[key] = progress.fraction);
      if (progress.completedEvidence != null) {
        setState(() {
          _uploadProgress.remove(key);
          _uploadLabels.remove(key);
        });
        _showSnackbar('$label uploaded successfully.');
      }
    }
  }

  // ---------------------------------------------------------------------
  // Capture: Photo (Requirement #1)
  // ---------------------------------------------------------------------

  Future<void> _capturePhoto() async {
    if (!await _ensurePermission(
      Permission.camera,
      'Camera permission denied — enable it in Settings to capture photos.',
    )) {
      return;
    }
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) return;
      await _uploadFile(File(picked.path), EvidenceType.photo, 'Photo');
    } catch (e) {
      _showSnackbar('Could not capture photo: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Capture: Video (Requirement #2)
  // ---------------------------------------------------------------------

  Future<void> _captureVideo() async {
    if (!await _ensurePermission(
      Permission.camera,
      'Camera permission denied — enable it in Settings to record video.',
    )) {
      return;
    }
    if (!await _ensurePermission(
      Permission.microphone,
      'Microphone permission denied — video will have no audio until enabled.',
    )) {
      // Not fatal — proceed without audio rather than blocking the capture.
    }
    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;
      await _uploadFile(File(picked.path), EvidenceType.video, 'Video');
    } catch (e) {
      _showSnackbar('Could not record video: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Capture: Audio (Requirement #3)
  // ---------------------------------------------------------------------

  Future<void> _startAudioRecording() async {
    if (!await _ensurePermission(
      Permission.microphone,
      'Microphone permission denied — enable it in Settings to record audio.',
    )) {
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      _showSnackbar('Microphone permission denied.', isError: true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/evidence_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecordingAudio = true;
      _recordingElapsed = Duration.zero;
    });
    _tickRecordingClock();
  }

  void _tickRecordingClock() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isRecordingAudio || !mounted) return;
      setState(() => _recordingElapsed += const Duration(seconds: 1));
      _tickRecordingClock();
    });
  }

  Future<void> _stopAudioRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecordingAudio = false);
    if (path == null) return;
    await _uploadFile(File(path), EvidenceType.audio, 'Audio recording');
  }

  // ---------------------------------------------------------------------
  // Upload from device storage (Requirement #4)
  // ---------------------------------------------------------------------

  Future<void> _uploadFromDevice() async {
    try {
      final picked = await _imagePicker.pickMedia();
      if (picked == null) return;
      final isVideo = picked.path.toLowerCase().endsWith('.mp4') ||
          picked.path.toLowerCase().endsWith('.mov') ||
          picked.path.toLowerCase().endsWith('.m4v');
      await _uploadFile(
        File(picked.path),
        isVideo ? EvidenceType.video : EvidenceType.photo,
        isVideo ? 'Video' : 'Photo',
      );
    } catch (e) {
      _showSnackbar('Could not access device storage: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Text note (Requirement #3's "optional text notes")
  // ---------------------------------------------------------------------

  Future<void> _addTextNote() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Text Note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Describe what happened...',
            filled: true,
            fillColor: AppColors.fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.r4),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note == null || note.trim().isEmpty) return;

    try {
      final (lat, lng) = await _currentLatLng();
      await _evidenceService.saveTextNote(textNote: note, latitude: lat, longitude: lng);
      _showSnackbar('Note saved.');
    } on EvidenceException catch (e) {
      _showSnackbar(e.message, isError: true);
    } catch (e) {
      _showSnackbar('Could not save note: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Capture options sheet
  // ---------------------------------------------------------------------

  void _showCaptureSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.photo_camera_outlined,
                label: 'Capture Photo',
                onTap: () {
                  Navigator.pop(context);
                  _capturePhoto();
                },
              ),
              _SheetAction(
                icon: Icons.videocam_outlined,
                label: 'Record Video',
                onTap: () {
                  Navigator.pop(context);
                  _captureVideo();
                },
              ),
              _SheetAction(
                icon: Icons.mic_none_rounded,
                label: 'Record Audio',
                onTap: () {
                  Navigator.pop(context);
                  _startAudioRecording();
                },
              ),
              _SheetAction(
                icon: Icons.upload_file_outlined,
                label: 'Upload from Device',
                onTap: () {
                  Navigator.pop(context);
                  _uploadFromDevice();
                },
              ),
              _SheetAction(
                icon: Icons.notes_rounded,
                label: 'Add Text Note',
                onTap: () {
                  Navigator.pop(context);
                  _addTextNote();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Delete (Requirements #10, #11)
  // ---------------------------------------------------------------------

  Future<void> _confirmDelete(EvidenceModel evidence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Evidence?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _evidenceService.deleteEvidence(evidence.id);
      _showSnackbar('Evidence deleted.');
    } on EvidenceException catch (e) {
      _showSnackbar(e.message, isError: true);
    } catch (e) {
      _showSnackbar('Could not delete evidence: $e', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Preview (tap a card)
  // ---------------------------------------------------------------------

  Future<void> _openPreview(EvidenceModel evidence) async {
    if (evidence.fileType == EvidenceType.note) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Text Note'),
          content: Text(evidence.textNote ?? ''),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    if (evidence.fileType == EvidenceType.photo && evidence.storageUrl != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: InteractiveViewer(child: Image.network(evidence.storageUrl!)),
        ),
      );
      return;
    }

    // Video / audio: open externally rather than bundling a player package
    // this app doesn't already depend on.
    if (evidence.storageUrl != null) {
      final uri = Uri.parse(evidence.storageUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar('Could not open file for preview.', isError: true);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCaptureSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'My Evidence'),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Auto-saved recordings from SOS alerts and reports',
                  style: AppTextStyles.b3,
                ),
              ),
              if (_isRecordingAudio) ...[
                const SizedBox(height: 12),
                _RecordingBar(
                  elapsed: _recordingElapsed,
                  onStop: _stopAudioRecording,
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<EvidenceModel>>(
                  stream: _evidenceService.watchEvidenceForCurrentUser(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorState(
                        message: 'Could not load evidence. Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData && _uploadProgress.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final entries = snapshot.data ?? const <EvidenceModel>[];
                    final uploadingKeys = _uploadProgress.keys.toList();

                    if (entries.isEmpty && uploadingKeys.isEmpty) {
                      return const _EmptyState();
                    }

                    return ListView.separated(
                      itemCount: uploadingKeys.length + entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, i) {
                        if (i < uploadingKeys.length) {
                          final key = uploadingKeys[i];
                          return _UploadingCard(
                            label: _uploadLabels[key] ?? 'Uploading',
                            progress: _uploadProgress[key] ?? 0,
                          );
                        }
                        final entry = entries[i - uploadingKeys.length];
                        return _EvidenceCard(
                          entry: entry,
                          onTap: () => _openPreview(entry),
                          onDelete: entry.isLocked ? null : () => _confirmDelete(entry),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Presentational widgets
// ---------------------------------------------------------------------

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: AppTextStyles.semibold16),
      onTap: onTap,
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.elapsed, required this.onStop});

  final Duration elapsed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 4, backgroundColor: Colors.redAccent),
          const SizedBox(width: 8),
          Text(
            'Recording audio · $m:$s',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: onStop,
            child: const Text('Stop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _UploadingCard extends StatelessWidget {
  const _UploadingCard({required this.label, required this.progress});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.semibold16),
              const Spacer(),
              Text('${(progress * 100).toStringAsFixed(0)}%', style: AppTextStyles.b5),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress == 0 ? null : progress,
              minHeight: 6,
              backgroundColor: AppColors.neutral200,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 40, color: AppColors.neutral400),
            const SizedBox(height: 12),
            Text(
              'No evidence yet. Tap + to capture a photo, video, audio, or note.',
              textAlign: TextAlign.center,
              style: AppTextStyles.b3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.b3),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.entry, required this.onTap, this.onDelete});

  final EvidenceModel entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  IconData get _icon => switch (entry.fileType) {
        EvidenceType.audio => Icons.mic_none_rounded,
        EvidenceType.video => Icons.videocam_outlined,
        EvidenceType.photo => Icons.photo_camera_outlined,
        EvidenceType.note => Icons.notes_rounded,
      };

  String get _dateLabel {
    final t = entry.timestamp;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    final minute = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${months[t.month - 1]} ${t.year} · $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final locked = entry.isLocked;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300),
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(_icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileType == EvidenceType.note
                        ? (entry.textNote ?? 'Text Note')
                        : entry.fileName,
                    style: AppTextStyles.semibold16,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(_dateLabel, style: AppTextStyles.b5),
                ],
              ),
            ),
            _StatusBadge(status: entry.status),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.neutral400,
                onPressed: onDelete,
              ),
            ] else if (locked) ...[
              const SizedBox(width: 8),
              Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.neutral400),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EvidenceStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      EvidenceStatus.uploaded => (const Color(0xFF16A34A), Icons.cloud_done_outlined, 'Synced'),
      EvidenceStatus.pending => (AppColors.neutral400, Icons.cloud_upload_outlined, 'Uploading'),
      EvidenceStatus.failed => (const Color(0xFFDC2626), Icons.error_outline_rounded, 'Failed'),
      EvidenceStatus.reported => (AppColors.primaryGrey, Icons.lock_outline_rounded, 'Locked'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.b5.copyWith(color: color)),
        ],
      ),
    );
  }
}
