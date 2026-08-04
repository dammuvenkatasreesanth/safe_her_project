import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  bool _gpsTracking = true;
  bool _autoSafeArrival = false;
  bool _smsFallback = true;
  bool _voiceCommand = false;

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
              const ScreenHeader(title: 'Accessibility'),
              const SizedBox(height: 16),
              _ToggleRow(
                icon: Icons.gps_fixed_rounded,
                title: 'GPS Tracking',
                subtitle: 'Keep your location updated in the background',
                value: _gpsTracking,
                onChanged: (v) => setState(() => _gpsTracking = v),
              ),
              _ToggleRow(
                icon: Icons.home_work_outlined,
                title: 'Auto Safe Arrival',
                subtitle: "Notify contacts automatically when you're home",
                value: _autoSafeArrival,
                onChanged: (v) => setState(() => _autoSafeArrival = v),
              ),
              _ToggleRow(
                icon: Icons.sms_outlined,
                title: 'SMS Fallback',
                subtitle: 'Send alerts by SMS if data connection is weak',
                value: _smsFallback,
                onChanged: (v) => setState(() => _smsFallback = v),
              ),
              _ToggleRow(
                icon: Icons.mic_none_rounded,
                title: 'Voice Command',
                subtitle: 'Trigger SOS by saying "Help me" or "Emergency"',
                value: _voiceCommand,
                onChanged: (v) => setState(() => _voiceCommand = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F3F3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.semibold16),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
