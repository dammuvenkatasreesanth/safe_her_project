import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/screen_header.dart';

/// Frontend shell for Module 5 (Safe Route & Risk Zone Prediction).
/// Risk zones here are mock data — swap `_mockZones` for a real scoring
/// service (crime stats + time-of-day + lighting + crowd density) later.
class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

enum _RiskLevel { safe, moderate, high }

class _RiskZone {
  const _RiskZone({
    required this.offset,
    required this.radius,
    required this.level,
  });
  final LatLng offset;
  final double radius;
  final _RiskLevel level;

  Color get color => switch (level) {
    _RiskLevel.safe => const Color(0xFF16A34A),
    _RiskLevel.moderate => const Color(0xFFF59E0B),
    _RiskLevel.high => const Color(0xFFE0334D),
  };
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  LatLng? _location;

  @override
  void initState() {
    super.initState();
    LocationService.getCurrentLocation().then((loc) {
      if (mounted) setState(() => _location = loc);
    });
  }

  List<_RiskZone> _mockZones(LatLng center) => [
    _RiskZone(
      offset: LatLng(center.latitude + 0.004, center.longitude + 0.003),
      radius: 220,
      level: _RiskLevel.safe,
    ),
    _RiskZone(
      offset: LatLng(center.latitude - 0.003, center.longitude + 0.005),
      radius: 180,
      level: _RiskLevel.moderate,
    ),
    _RiskZone(
      offset: LatLng(center.latitude - 0.006, center.longitude - 0.004),
      radius: 160,
      level: _RiskLevel.high,
    ),
    _RiskZone(
      offset: LatLng(center.latitude + 0.006, center.longitude - 0.002),
      radius: 200,
      level: _RiskLevel.safe,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final zones = _location == null ? <_RiskZone>[] : _mockZones(_location!);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Safe Route & Risk Zones'),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r5),
                child: SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: _location == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : Stack(
                          children: [
                            AppMap(
                              center: _location!,
                              zoom: 14,
                              markers: [youAreHereMarker(_location!, size: 36)],
                              circles: [
                                for (final z in zones)
                                  CircleMarker(
                                    point: z.offset,
                                    radius: z.radius,
                                    useRadiusInMeter: true,
                                    color: z.color.withValues(alpha: 0.18),
                                    borderColor: z.color,
                                    borderStrokeWidth: 2,
                                  ),
                              ],
                            ),
                            Positioned(left: 10, bottom: 10, child: _Legend()),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
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
                      child: const Icon(
                        Icons.route_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Routing avoids high-risk zones',
                            style: AppTextStyles.semibold16,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Based on time of day, lighting, and community reports.',
                            style: AppTextStyles.b5.copyWith(
                              color: AppColors.neutral400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Start a journey from Live Tracking to get a route that favors safe and moderate zones.',
                style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendRow(color: Color(0xFF16A34A), label: 'Safe'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFFF59E0B), label: 'Moderate'),
          SizedBox(height: 4),
          _LegendRow(color: Color(0xFFE0334D), label: 'High Risk'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.b5),
      ],
    );
  }
}
