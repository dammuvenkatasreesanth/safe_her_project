import 'package:flutter/material.dart';
import '../../models/recording.dart';
import '../../services/biometric_service.dart';
import '../../services/evidence_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';
import 'evidence_viewer_screen.dart';

extension on Recording {
  IconData get icon => switch (type) {
        RecordingType.audio => Icons.mic_none_rounded,
        RecordingType.video => Icons.videocam_outlined,
        RecordingType.photo => Icons.photo_camera_outlined,
      };

  String get formattedDate {
    final d = createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${two(d.day)} ${_month(d.month)} ${d.year} · $hour12:${two(d.minute)} $ampm';
  }

  String get formattedDuration {
    final s = durationSeconds;
    if (s == null) return '—';
    final m = s ~/ 60;
    final rem = s % 60;
    return '$m:${rem.toString().padLeft(2, '0')}';
  }

  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}

/// Module 7 — lists encrypted evidence captured on this device. Audio
/// auto-records during an SOS alert (see sos_screen.dart); photo/video/
/// audio can also be captured manually from here. Everything is
/// AES-encrypted at rest (EncryptionService) and never uploaded anywhere;
/// viewing an entry requires the device's biometric/PIN lock.
class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  bool _recordingAudio = false;
  bool _busy = false;

  Future<void> _toggleAudio() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (_recordingAudio) {
      final saved = await EvidenceService.stopRecording();
      if (!mounted) return;
      setState(() {
        _recordingAudio = false;
        _busy = false;
      });
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save the recording.")),
        );
      }
    } else {
      final started = await EvidenceService.startRecording();
      if (!mounted) return;
      setState(() {
        _recordingAudio = started;
        _busy = false;
      });
      if (!started) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is needed to record audio.')),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await EvidenceService.captureImage();
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return; // user cancelled — nothing to report
  }

  Future<void> _captureVideo() async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await EvidenceService.captureVideo();
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return; // user cancelled — nothing to report
  }

  Future<void> _open(Recording entry) async {
    final canAuth = await BiometricService.canAuthenticate();
    if (canAuth) {
      final ok = await BiometricService.authenticate(
        reason: 'Unlock to view this evidence',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    final file = await EvidenceService.decryptForViewing(entry);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EvidenceViewerScreen(recording: entry, file: file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  'Encrypted on this device — unlock with your phone lock to view.',
                  style: AppTextStyles.b3,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CaptureButton(
                      icon: _recordingAudio ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                      label: _recordingAudio ? 'Stop' : 'Audio',
                      active: _recordingAudio,
                      onTap: _busy ? null : _toggleAudio,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CaptureButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Photo',
                      onTap: (_busy || _recordingAudio) ? null : _capturePhoto,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CaptureButton(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      onTap: (_busy || _recordingAudio) ? null : _captureVideo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Recording>>(
                  stream: EvidenceService.streamRecordings(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load your evidence.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.b3,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    final entries = snapshot.data!;
                    if (entries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_off_outlined, size: 40, color: AppColors.neutral400),
                              const SizedBox(height: 12),
                              Text(
                                'No evidence yet. Capture audio, a photo, or video above — '
                                'or it will auto-save when your next SOS alert fires.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.b3.copyWith(color: AppColors.neutral400),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (context, i) => _EvidenceCard(
                        entry: entries[i],
                        onTap: () => _open(entries[i]),
                      ),
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

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = active
        ? const Color(0xFFE0334D)
        : disabled
        ? AppColors.neutral400
        : AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: active ? color : AppColors.neutral300),
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.b5.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.entry, required this.onTap});

  final Recording entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(entry.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: AppTextStyles.semibold16, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${entry.formattedDate} · ${entry.formattedDuration}', style: AppTextStyles.b5),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text('Encrypted', style: AppTextStyles.b5.copyWith(color: const Color(0xFF16A34A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
