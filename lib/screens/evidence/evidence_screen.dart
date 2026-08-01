import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';

enum _EvidenceType { audio, video, photo }

class _Evidence {
  const _Evidence({
    required this.type,
    required this.title,
    required this.date,
    required this.duration,
    required this.synced,
  });
  final _EvidenceType type;
  final String title;
  final String date;
  final String duration;
  final bool synced;

  IconData get icon => switch (type) {
    _EvidenceType.audio => Icons.mic_none_rounded,
    _EvidenceType.video => Icons.videocam_outlined,
    _EvidenceType.photo => Icons.photo_camera_outlined,
  };
}

/// Frontend shell for Module 7 (Audio/Video Recording & Cloud Evidence
/// Storage). Backed by mock entries — wire the `camera`/`record` plugins
/// and real cloud upload here.
class EvidenceScreen extends StatelessWidget {
  const EvidenceScreen({super.key});

  static const _entries = [
    _Evidence(
      type: _EvidenceType.video,
      title: 'SOS Recording',
      date: '29 Jul 2026 · 9:14 PM',
      duration: '02:41',
      synced: true,
    ),
    _Evidence(
      type: _EvidenceType.audio,
      title: 'SOS Recording',
      date: '29 Jul 2026 · 9:14 PM',
      duration: '02:41',
      synced: true,
    ),
    _Evidence(
      type: _EvidenceType.video,
      title: 'Incident Report Attachment',
      date: '14 Jul 2026 · 10:20 PM',
      duration: '00:38',
      synced: true,
    ),
    _Evidence(
      type: _EvidenceType.photo,
      title: 'Report Photo',
      date: '14 Jul 2026 · 10:19 PM',
      duration: '—',
      synced: false,
    ),
  ];

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
                  'Auto-saved recordings from SOS alerts and reports',
                  style: AppTextStyles.b3,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 11),
                  itemBuilder: (context, i) =>
                      _EvidenceCard(entry: _entries[i]),
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

  final _Evidence entry;

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
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(entry.icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: AppTextStyles.semibold16,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.date} · ${entry.duration}',
                  style: AppTextStyles.b5,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (entry.synced
                          ? const Color(0xFF16A34A)
                          : AppColors.neutral400)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  entry.synced
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  size: 13,
                  color: entry.synced
                      ? const Color(0xFF16A34A)
                      : AppColors.neutral400,
                ),
                const SizedBox(width: 4),
                Text(
                  entry.synced ? 'Synced' : 'Uploading',
                  style: AppTextStyles.b5.copyWith(
                    color: entry.synced
                        ? const Color(0xFF16A34A)
                        : AppColors.neutral400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
