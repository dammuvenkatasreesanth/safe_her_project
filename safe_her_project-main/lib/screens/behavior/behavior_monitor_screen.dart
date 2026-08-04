import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';

/// Frontend shell for Module 6 (AI Movement/Behavior Detection). The toggle
/// and log are UI-only — wire `sensors_plus` accelerometer data into a
/// trained TFLite classifier here, and push anomalies into `_log`.
class BehaviorMonitorScreen extends StatefulWidget {
  const BehaviorMonitorScreen({super.key});

  @override
  State<BehaviorMonitorScreen> createState() => _BehaviorMonitorScreenState();
}

class _BehaviorMonitorScreenState extends State<BehaviorMonitorScreen> {
  bool _enabled = true;

  static const _log = [
    (
      icon: Icons.check_circle_outline_rounded,
      label: 'Normal walking pattern',
      time: '2 min ago',
      ok: true,
    ),
    (
      icon: Icons.check_circle_outline_rounded,
      label: 'Steady pace detected',
      time: '18 min ago',
      ok: true,
    ),
    (
      icon: Icons.warning_amber_rounded,
      label: 'Sudden stop detected — no alert needed',
      time: '1 hr ago',
      ok: false,
    ),
    (
      icon: Icons.check_circle_outline_rounded,
      label: 'Normal walking pattern',
      time: '3 hr ago',
      ok: true,
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
              const ScreenHeader(title: 'Behavior Monitor'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            (_enabled
                                    ? AppColors.primary
                                    : AppColors.neutral400)
                                .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.directions_walk_rounded,
                        size: 20,
                        color: _enabled
                            ? AppColors.primary
                            : AppColors.neutral400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Anomaly Detection',
                            style: AppTextStyles.semibold16,
                          ),
                          Text(
                            _enabled
                                ? 'Watching for running, sudden stops & falls'
                                : 'Monitoring paused',
                            style: AppTextStyles.b5.copyWith(
                              color: AppColors.neutral400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_enabled) ...[
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live status: Normal',
                      style: AppTextStyles.semibold16.copyWith(
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Recent activity', style: AppTextStyles.b2),
                const SizedBox(height: 10),
                for (final entry in _log)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.neutral300),
                      borderRadius: BorderRadius.circular(AppRadius.r4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          entry.icon,
                          size: 18,
                          color: entry.ok
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(entry.label, style: AppTextStyles.b3),
                        ),
                        Text(
                          entry.time,
                          style: AppTextStyles.b5.copyWith(
                            color: AppColors.neutral400,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
