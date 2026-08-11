import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../services/safety_score_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/screen_header.dart';

/// Module 5 (Safe Route & Risk Zone Prediction). Zone positions are a
/// fixed offset pattern around the user (there's no free source for real
/// neighborhood boundaries), but each zone's color comes from a real,
/// live-fetched heuristic — see SafetyScoreService — not hardcoded levels.
class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _RiskZone {
  const _RiskZone({
    required this.offset,
    required this.radius,
    required this.level,
  });
  final LatLng offset;
  final double radius;
  final RiskLevel level;

  Color get color => switch (level) {
    RiskLevel.safe => const Color(0xFF16A34A),
    RiskLevel.moderate => const Color(0xFFF59E0B),
    RiskLevel.high => const Color(0xFFE0334D),
  };
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  LatLng? _location;
  List<_RiskZone>? _zones;
  bool _locationFailed = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationFailed = false);
    final loc = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (loc == null) {
      setState(() => _locationFailed = true);
      return;
    }
    setState(() => _location = loc);
    await _loadZones(loc);
  }

  /// Four fixed points around the user, each scored for real via a live
  /// Overpass fetch (police + street-lamp density, discounted at night —
  /// see SafetyScoreService for the exact heuristic and why it's honest
  /// about not being verified crime data).
  Future<void> _loadZones(LatLng center) async {
    final offsets = [
      LatLng(center.latitude + 0.004, center.longitude + 0.003),
      LatLng(center.latitude - 0.003, center.longitude + 0.005),
      LatLng(center.latitude - 0.006, center.longitude - 0.004),
      LatLng(center.latitude + 0.006, center.longitude - 0.002),
    ];
    final levels = await Future.wait(
      offsets.map((o) => SafetyScoreService.scoreZone(o)),
    );
    if (!mounted) return;
    setState(() {
      _zones = [
        for (var i = 0; i < offsets.length; i++)
          _RiskZone(offset: offsets[i], radius: 200, level: levels[i]),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final zones = _zones ?? <_RiskZone>[];
    final loadingZones = _location != null && _zones == null;
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
                  child: _locationFailed
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_off_rounded, size: 32, color: AppColors.neutral400),
                                const SizedBox(height: 10),
                                Text(
                                  "Couldn't get your location. Check GPS is on and try again.",
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
                                ),
                                const SizedBox(height: 10),
                                TextButton(onPressed: _loadLocation, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : _location == null
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
                            if (loadingZones)
                              const Positioned(
                                right: 10,
                                top: 10,
                                child: _ScoringChip(),
                              ),
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
                            'Based on live police-station and street-lamp density nearby (OpenStreetMap), adjusted for time of day.',
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

class _ScoringChip extends StatelessWidget {
  const _ScoringChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          Text('Scoring zones...', style: AppTextStyles.b5),
        ],
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
