import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../services/risk_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/screen_header.dart';

/// Module 5 (Safe Route & Risk Zone Prediction).
///
/// Risk zones are computed by [RiskService] from real signals — OSM street
/// lighting + points-of-interest density, time of day, and live Firestore
/// community incident reports — instead of mock CircleMarkers.
class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  LatLng? _location;
  RiskAssessment? _assessment;
  bool _loading = true;
  String? _error;
  bool _locationUnavailable = false;
  String _loadingMessage = 'Getting your location…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingMessage = 'Getting your location…';
    });
    try {
      final location = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _location = location;
        _locationUnavailable = location == defaultLocation;
        _loadingMessage = 'Scoring nearby risk zones…';
      });

      final assessment = await RiskService.assess(center: location);
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            "Couldn't score risk zones right now. Check your connection and try again.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: ScreenHeader(title: 'Safe Route & Risk Zones'),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                    color: AppColors.primaryGrey,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_locationUnavailable && !_loading) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                    border: Border.all(color: const Color(0xFFFCD9A8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        size: 18,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Couldn't get your real location — showing a fallback area.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r5),
                        child: SizedBox(
                          height: 320,
                          width: double.infinity,
                          child: _buildMapArea(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (assessment != null)
                        _SummaryCard(assessment: assessment),
                      const SizedBox(height: 14),
                      if (assessment != null &&
                          assessment.zones.isNotEmpty) ...[
                        Text('Nearby zones', style: AppTextStyles.semibold16),
                        const SizedBox(height: 8),
                        ...assessment.zones
                            .where((z) => z.level != RiskLevel.safe)
                            .map((z) => _ZoneTile(zone: z)),
                      ],
                      const SizedBox(height: 8),
                      _HowThisWorksCard(assessment: assessment),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    if (_location == null || _loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              _loadingMessage,
              style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    final assessment = _assessment;
    return Stack(
      children: [
        AppMap(
          center: _location!,
          zoom: 15,
          markers: [youAreHereMarker(_location!, size: 36)],
          circles: [
            for (final z in assessment?.zones ?? const <RiskZone>[])
              CircleMarker(
                point: z.center,
                radius: z.radiusMeters,
                useRadiusInMeter: true,
                color: _colorForLevel(z.level).withValues(alpha: 0.18),
                borderColor: _colorForLevel(z.level),
                borderStrokeWidth: 2,
              ),
          ],
        ),
        const Positioned(left: 10, bottom: 10, child: _Legend()),
      ],
    );
  }
}

Color _colorForLevel(RiskLevel level) => switch (level) {
  RiskLevel.safe => const Color(0xFF16A34A),
  RiskLevel.moderate => const Color(0xFFF59E0B),
  RiskLevel.high => const Color(0xFFE0334D),
};

String _labelForLevel(RiskLevel level) => switch (level) {
  RiskLevel.safe => 'Safe',
  RiskLevel.moderate => 'Moderate',
  RiskLevel.high => 'High Risk',
};

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.assessment});

  final RiskAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final level = assessment.overallLevel;
    final sources = <String>[
      if (assessment.usingLighting) 'street lighting & foot-traffic',
      if (assessment.usingLiveIncidents) 'community reports',
      '${assessment.isNight ? 'night' : 'daytime'} hours',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _colorForLevel(level).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.route_rounded,
              size: 18,
              color: _colorForLevel(level),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Area is currently ${_labelForLevel(level)}',
                  style: AppTextStyles.semibold16,
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on ${sources.join(', ')}.',
                  style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone});

  final RiskZone zone;

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(zone.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_labelForLevel(zone.level)} zone nearby',
                  style: AppTextStyles.b4.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  zone.reasons.join(' · '),
                  style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains the methodology behind the Safe/Moderate/High call, since
/// each zone tile above only gives that specific zone's reasons — this
/// is the general "how do we decide" reference, shown once per screen.
class _HowThisWorksCard extends StatelessWidget {
  const _HowThisWorksCard({required this.assessment});
  final RiskAssessment? assessment;

  @override
  Widget build(BuildContext context) {
    final points = <String>[
      'Street lighting & foot-traffic density (from OpenStreetMap) — '
          'dark, empty streets score lower.',
      'Recent community incident reports for the area, when available.',
      'Time of day — the same street scores lower after dark than in daylight.',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.neutral400,
              ),
              const SizedBox(width: 6),
              Text(
                'How this is scored',
                style: AppTextStyles.b4.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '•  $p',
                style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
              ),
            ),
          if (assessment != null) ...[
            const SizedBox(height: 4),
            Text(
              assessment!.isNight
                  ? "It's currently night hours, so the night penalty above is active for this area."
                  : "It's currently daytime — zones here would score a bit more cautiously after dark.",
              style: AppTextStyles.b5.copyWith(
                color: AppColors.neutral400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.signal_wifi_off_rounded,
              size: 40,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.b4, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
