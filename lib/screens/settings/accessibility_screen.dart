import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../services/voice_command_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';
import '../tracking/pick_location_screen.dart';

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
  String? _homeLabel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final autoSafeArrival = await SettingsService.getAutoSafeArrival();
    final smsFallback = await SettingsService.getSmsFallback();
    final voiceCommand = await SettingsService.getVoiceCommand();
    final home = await SettingsService.getHomeLocation();
    if (!mounted) return;
    setState(() {
      _autoSafeArrival = autoSafeArrival;
      _smsFallback = smsFallback;
      _voiceCommand = voiceCommand;
      _homeLabel = home?.$3;
      _loading = false;
    });
  }

  // Only used to give the map picker somewhere to start if a real GPS fix
  // isn't available — the user searches/drags to their actual home either
  // way, so this doesn't need to be accurate (unlike Nearby Help/SOS/Safe
  // Route, which must never substitute a fake location for a real one).
  static const _fallbackMapCenter = LatLng(20.5937, 78.9629); // center of India

  Future<void> _setHomeLocation() async {
    final current = await LocationService.getCurrentLocation();
    if (!mounted) return;
    final result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(initialCenter: current ?? _fallbackMapCenter),
      ),
    );
    if (result == null) return;
    await SettingsService.setHomeLocation(
      lat: result.point.latitude,
      lng: result.point.longitude,
      label: result.label,
    );
    if (mounted) setState(() => _homeLabel = result.label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Padding(
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
                      onChanged: (v) {
                        setState(() => _autoSafeArrival = v);
                        SettingsService.setAutoSafeArrival(v);
                      },
                      trailing: _autoSafeArrival
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: _setHomeLocation,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.edit_location_alt_outlined,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _homeLabel == null
                                            ? 'Set home location'
                                            : 'Home: $_homeLabel',
                                        style: AppTextStyles.b5.copyWith(
                                          color: AppColors.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                    _ToggleRow(
                      icon: Icons.sms_outlined,
                      title: 'SMS Fallback',
                      subtitle: 'Send alerts by SMS if data connection is weak',
                      value: _smsFallback,
                      onChanged: (v) {
                        setState(() => _smsFallback = v);
                        SettingsService.setSmsFallback(v);
                      },
                    ),
                    _ToggleRow(
                      icon: Icons.mic_none_rounded,
                      title: 'Voice Command',
                      subtitle: 'Trigger SOS by saying "Help me" or "Emergency"',
                      value: _voiceCommand,
                      onChanged: (v) async {
                        setState(() => _voiceCommand = v);
                        await SettingsService.setVoiceCommand(v);
                        final ok = await VoiceCommandService.syncWithSetting();
                        if (!context.mounted) return;
                        if (v && !ok) {
                          setState(() => _voiceCommand = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Microphone permission is needed for Voice Command.'),
                            ),
                          );
                        }
                      },
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          ?trailing,
        ],
      ),
    );
  }
}
