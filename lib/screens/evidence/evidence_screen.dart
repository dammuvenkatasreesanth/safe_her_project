import 'package:flutter/material.dart';
import '../../models/recording.dart';
import '../../services/evidence_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';

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

/// Module 7 — lists real recordings from Firestore/Storage (see
/// EvidenceService). Empty until capture is wired up with camera/record
/// plugins; the SOS screen already links here so the entry point exists.
class EvidenceScreen extends StatelessWidget {
  const EvidenceScreen({super.key});

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
                child: Text('Auto-saved recordings from SOS alerts and reports', style: AppTextStyles.b3),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Recording>>(
                  stream: EvidenceService.streamRecordings(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load your evidence. Check your connection.',
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
                                'No evidence yet. Recordings from your next SOS alert or report will show up here.',
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
                      itemBuilder: (context, i) => _EvidenceCard(entry: entries[i]),
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

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.entry});

  final Recording entry;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                const Icon(Icons.cloud_done_outlined, size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text('Synced', style: AppTextStyles.b5.copyWith(color: const Color(0xFF16A34A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
