import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/risk_service.dart';
import '../../services/route_safety_service.dart';
import '../../services/routing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';

/// Fetches real road-route alternatives between two points and lets the
/// user pick one before a journey starts. Pops the chosen [RouteOption],
/// or `null` if the user chose to continue without one (routing fetch
/// failed / no network) — callers should fall back to a direct route.
class SelectRouteScreen extends StatefulWidget {
  const SelectRouteScreen({
    super.key,
    required this.from,
    required this.to,
    required this.fromLabel,
    required this.toLabel,
  });

  final LatLng from;
  final LatLng to;
  final String fromLabel;
  final String toLabel;

  @override
  State<SelectRouteScreen> createState() => _SelectRouteScreenState();
}

class _SelectRouteScreenState extends State<SelectRouteScreen> {
  List<RouteOption> _routes = [];
  RouteRecommendation? _recommendation;
  bool _loading = true;
  bool _scoringFailed = false;
  int _selectedIndex = 0;
  TravelMode _mode = TravelMode.driving;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _onModeChanged(TravelMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _loading = true;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    final routes = _mode == TravelMode.driving
        ? await RoutingService.getRoutes(from: widget.from, to: widget.to)
        : await RoutingService.getWalkingRoute(
            from: widget.from,
            to: widget.to,
          );

    // Milestone 3/4: score every route with the full safety algorithm
    // (risk zones crossed, distance inside them, nearby emergency
    // facilities, time of day) and auto-recommend the safest one.
    // Best-effort — if scoring fails, routes still show, just unranked.
    RouteRecommendation? recommendation;
    var initialIndex = 0;
    var scoringFailed = false;
    if (routes.isNotEmpty) {
      try {
        recommendation = await RouteSafetyService.evaluate(routes);
        final rec = recommendation;
        if (rec != null) {
          for (final route in routes) {
            final evaluation = rec.evaluations.firstWhere(
              (e) => identical(e.route, route),
            );
            route.riskLevel = evaluation.highRiskZonesCrossed > 0
                ? RiskLevel.high
                : evaluation.moderateRiskZonesCrossed > 0
                ? RiskLevel.moderate
                : RiskLevel.safe;
            route.safetyScore = evaluation.safetyScore;
          }
          // Only the recommended-safest route carries the "why" sentence
          // forward — it's a comparison against the fastest route, so it
          // wouldn't make sense attached to every option.
          rec.safest.route.safetyExplanation = rec.explanation;
          initialIndex = routes.indexWhere(
            (r) => identical(r, rec.safest.route),
          );
          if (initialIndex < 0) initialIndex = 0;
        } else {
          scoringFailed = true;
        }
      } catch (_) {
        // Leave riskLevel null / recommendation null — screen still works,
        // but tell the user why they won't see a safety score this time.
        scoringFailed = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _routes = routes;
      _recommendation = recommendation;
      _scoringFailed = scoringFailed;
      _selectedIndex = initialIndex;
      _loading = false;
    });
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
              ScreenHeader(
                title: 'Choose Your Route',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Driving',
                      icon: Icons.directions_car_rounded,
                      selected: _mode == TravelMode.driving,
                      onTap: () => _onModeChanged(TravelMode.driving),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeChip(
                      label: 'Walking (approx.)',
                      icon: Icons.directions_walk_rounded,
                      selected: _mode == TravelMode.walking,
                      onTap: () => _onModeChanged(TravelMode.walking),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _routes.isEmpty
                    ? _NoRoutesView(
                        onContinue: () => Navigator.of(context).pop(),
                      )
                    : _RoutesView(
                        from: widget.from,
                        to: widget.to,
                        routes: _routes,
                        recommendation: _recommendation,
                        scoringFailed: _scoringFailed,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
                        onConfirm: () =>
                            Navigator.of(context).pop(_routes[_selectedIndex]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoRoutesView extends StatelessWidget {
  const _NoRoutesView({required this.onContinue});

  final VoidCallback onContinue;

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
              size: 48,
              color: AppColors.neutral400,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't fetch route options",
              style: AppTextStyles.h5.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We'll start your journey with a direct route instead.",
              style: AppTextStyles.b3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Continue Anyway', onPressed: onContinue),
          ],
        ),
      ),
    );
  }
}

class _RoutesView extends StatelessWidget {
  const _RoutesView({
    required this.from,
    required this.to,
    required this.routes,
    required this.recommendation,
    required this.scoringFailed,
    required this.selectedIndex,
    required this.onSelect,
    required this.onConfirm,
  });

  final LatLng from;
  final LatLng to;
  final List<RouteOption> routes;
  final RouteRecommendation? recommendation;
  final bool scoringFailed;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints([
      for (final r in routes) ...r.points,
    ]);
    final rec = recommendation;
    final fastestIndex = rec == null
        ? 0
        : routes.indexWhere((r) => identical(r, rec.fastest.route));
    final safestIndex = rec == null
        ? 0
        : routes.indexWhere((r) => identical(r, rec.safest.route));
    final showingSafest = rec != null && selectedIndex == safestIndex;
    final showingFastest = rec != null && selectedIndex == fastestIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r4),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(40),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safeher.app',
                ),
                PolylineLayer(
                  polylines: [
                    for (var i = 0; i < routes.length; i++)
                      if (i != selectedIndex)
                        Polyline(
                          points: routes[i].points,
                          color: AppColors.neutral400.withValues(alpha: 0.5),
                          strokeWidth: 3,
                        ),
                    Polyline(
                      points: routes[selectedIndex].points,
                      color: AppColors.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    youAreHereMarker(from, size: 32),
                    placeMarker(
                      to,
                      icon: Icons.flag_rounded,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (routes.length == 1 && routes.first.isApproximate) ...[
          const SizedBox(height: 12),
          const _ApproximateRouteBanner(),
        ],
        if (scoringFailed && routes.length > 1) ...[
          const SizedBox(height: 12),
          const _ScoringFailedBanner(),
        ],
        if (rec != null &&
            routes.length > 1 &&
            fastestIndex >= 0 &&
            safestIndex >= 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Fastest',
                  icon: Icons.speed_rounded,
                  selected: showingFastest,
                  onTap: () => onSelect(fastestIndex),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeChip(
                  label: 'Safest',
                  icon: Icons.shield_rounded,
                  selected: showingSafest,
                  onTap: () => onSelect(safestIndex),
                ),
              ),
            ],
          ),
          if (rec.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExplanationBanner(text: rec.explanation),
          ],
        ],
        const SizedBox(height: 14),
        Text(
          '${routes.length} route${routes.length > 1 ? 's' : ''} found',
          style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: routes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RouteCard(
              route: routes[i],
              selected: i == selectedIndex,
              evaluation: rec?.evaluations.firstWhere(
                (e) => identical(e.route, routes[i]),
                orElse: () => rec.evaluations.first,
              ),
              onTap: () => onSelect(i),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Confirm Route', onPressed: onConfirm),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.neutral300,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.neutral400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.b4.copyWith(
                color: selected ? Colors.white : AppColors.neutral900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoringFailedBanner extends StatelessWidget {
  const _ScoringFailedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.neutral300.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
            size: 16,
            color: AppColors.neutral400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't score route safety this time (network hiccup fetching "
              'risk data). Showing routes unranked — try again in a moment.',
              style: AppTextStyles.b5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproximateRouteBanner extends StatelessWidget {
  const _ApproximateRouteBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Approximate straight-line path, not real turn-by-turn walking '
              'directions. Distance and time are estimates — actual '
              'footpaths and streets may differ.',
              style: AppTextStyles.b5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationBanner extends StatelessWidget {
  const _ExplanationBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.b5.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _SafetyScorePill extends StatelessWidget {
  const _SafetyScorePill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? const Color(0xFF16A34A)
        : score >= 45
        ? const Color(0xFFF59E0B)
        : const Color(0xFFE0334D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Safety ${score.round()}',
        style: AppTextStyles.b5.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    final color = level == RiskLevel.high
        ? const Color(0xFFE0334D)
        : const Color(0xFFF59E0B);
    final label = level == RiskLevel.high ? 'High risk' : 'Moderate risk';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.b5.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
    this.evaluation,
  });

  final RouteOption route;
  final bool selected;
  final VoidCallback onTap;
  final RouteSafetyEvaluation? evaluation;

  @override
  Widget build(BuildContext context) {
    final eval = evaluation;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.neutral300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.r4),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.neutral300,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(route.label, style: AppTextStyles.semibold16),
                      if (eval != null) ...[
                        const SizedBox(width: 8),
                        _SafetyScorePill(score: eval.safetyScore),
                      ],
                      if (route.riskLevel != null &&
                          route.riskLevel != RiskLevel.safe) ...[
                        const SizedBox(width: 8),
                        _RiskBadge(level: route.riskLevel!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${route.distanceKm.toStringAsFixed(1)} km • ${route.durationMin} min',
                    style: AppTextStyles.b5.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                  if (eval != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (eval.totalRiskZonesCrossed > 0)
                          '${eval.totalRiskZonesCrossed} risk zone'
                              '${eval.totalRiskZonesCrossed == 1 ? '' : 's'} crossed',
                        if (eval.nearbyEmergencyFacilities > 0)
                          '${eval.nearbyEmergencyFacilities} emergency facilit'
                              '${eval.nearbyEmergencyFacilities == 1 ? 'y' : 'ies'} nearby',
                      ].join(' • '),
                      style: AppTextStyles.b5.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
