import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/routing_service.dart';
import '../../services/safety_score_service.dart';
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
  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final routes = await RoutingService.getRoutes(
      from: widget.from,
      to: widget.to,
    );
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _loading = false;
    });
    _scoreRoutes();
  }

  /// Fills in each route's [RouteOption.safetyLevel] as its Overpass fetch
  /// resolves, independently — routes render immediately, safety tags
  /// arrive a moment later rather than blocking the whole screen on them.
  void _scoreRoutes() {
    for (var i = 0; i < _routes.length; i++) {
      final index = i;
      SafetyScoreService.scoreRoute(_routes[index].points).then((level) {
        if (!mounted || index >= _routes.length) return;
        setState(() {
          _routes = [
            for (var j = 0; j < _routes.length; j++)
              j == index ? _routes[j].copyWith(safetyLevel: level) : _routes[j],
          ];
        });
      });
    }
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
    required this.selectedIndex,
    required this.onSelect,
    required this.onConfirm,
  });

  final LatLng from;
  final LatLng to;
  final List<RouteOption> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints([
      for (final r in routes) ...r.points,
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r4),
          child: SizedBox(
            height: 240,
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
                    placeMarker(to, icon: Icons.flag_rounded, color: Colors.black87),
                  ],
                ),
              ],
            ),
          ),
        ),
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final RouteOption route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  Text(route.label, style: AppTextStyles.semibold16),
                  const SizedBox(height: 2),
                  Text(
                    '${route.distanceKm.toStringAsFixed(1)} km • ${route.durationMin} min',
                    style: AppTextStyles.b5.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            ),
            _SafetyChip(level: route.safetyLevel),
          ],
        ),
      ),
    );
  }
}

class _SafetyChip extends StatelessWidget {
  const _SafetyChip({required this.level});

  final RiskLevel? level;

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.neutral300),
      );
    }
    final (color, label) = switch (level!) {
      RiskLevel.safe => (const Color(0xFF16A34A), 'Safer'),
      RiskLevel.moderate => (const Color(0xFFF59E0B), 'Moderate'),
      RiskLevel.high => (const Color(0xFFE0334D), 'Higher risk'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTextStyles.b5.copyWith(color: color)),
    );
  }
}
