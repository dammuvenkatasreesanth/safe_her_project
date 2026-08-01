import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/primary_button.dart';
import 'start_journey_sheet.dart';

enum _TrackingMode { idle, sharingOnly, onJourney }

class LiveTrackingTab extends StatefulWidget {
  const LiveTrackingTab({super.key});

  @override
  State<LiveTrackingTab> createState() => _LiveTrackingTabState();
}

class _LiveTrackingTabState extends State<LiveTrackingTab>
    with SingleTickerProviderStateMixin {
  _TrackingMode _mode = _TrackingMode.idle;
  bool _geofenceEnabled = false;
  double _geofenceRadius = 500;
  LatLng? _location;
  JourneyPlan? _journey;
  late final AnimationController _routeController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    LocationService.getCurrentLocation().then((loc) {
      if (mounted) setState(() => _location = loc);
    });
  }

  @override
  void dispose() {
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _startJourney() async {
    if (_location == null) return;
    final plan = await showStartJourneySheet(context, _location!);
    if (plan != null && mounted) {
      setState(() {
        _journey = plan;
        _mode = _TrackingMode.onJourney;
      });
    }
  }

  void _shareOnly() {
    setState(() => _mode = _TrackingMode.sharingOnly);
  }

  void _stop() {
    setState(() {
      _mode = _TrackingMode.idle;
      _journey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Tracking',
            style: AppTextStyles.calloutBold.copyWith(
              fontSize: 20,
              height: 33 / 20,
            ),
          ),
          const SizedBox(height: 20),
          switch (_mode) {
            _TrackingMode.idle => _IdleState(
              location: _location,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              onShare: _shareOnly,
              onStartJourney: _startJourney,
            ),
            _TrackingMode.sharingOnly => _SharingOnlyState(
              location: _location,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              onStop: _stop,
            ),
            _TrackingMode.onJourney => _JourneyState(
              journey: _journey!,
              routeController: _routeController,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              onStop: _stop,
            ),
          },
          const SizedBox(height: 10),
          _GeofenceCard(
            enabled: _geofenceEnabled,
            radius: _geofenceRadius,
            onToggle: (v) => setState(() => _geofenceEnabled = v),
            onRadiusChanged: (v) => setState(() => _geofenceRadius = v),
          ),
        ],
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState({
    required this.onShare,
    required this.onStartJourney,
    required this.location,
    required this.geofenceEnabled,
    required this.geofenceRadius,
  });

  final VoidCallback onShare;
  final VoidCallback onStartJourney;
  final LatLng? location;
  final bool geofenceEnabled;
  final double geofenceRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(AppRadius.r5),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: AspectRatio(
              aspectRatio: 311 / 260,
              child: location == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : AppMap(
                      center: location!,
                      zoom: 15,
                      markers: [youAreHereMarker(location!)],
                      circles: geofenceEnabled
                          ? [
                              CircleMarker(
                                point: location!,
                                radius: geofenceRadius,
                                useRadiusInMeter: true,
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderColor: AppColors.primary,
                                borderStrokeWidth: 2,
                              ),
                            ]
                          : [],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "You aren't sharing your location yet",
              style: AppTextStyles.b3,
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Share Your Location', onPressed: onShare),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Start a Journey',
            outlined: true,
            onPressed: onStartJourney,
          ),
        ],
      ),
    );
  }
}

class _SharingOnlyState extends StatelessWidget {
  const _SharingOnlyState({
    required this.onStop,
    required this.location,
    required this.geofenceEnabled,
    required this.geofenceRadius,
  });

  final VoidCallback onStop;
  final LatLng? location;
  final bool geofenceEnabled;
  final double geofenceRadius;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200),
            borderRadius: BorderRadius.circular(AppRadius.r5),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r4),
                child: AspectRatio(
                  aspectRatio: 311 / 260,
                  child: location == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : AppMap(
                          center: location!,
                          zoom: 15,
                          markers: [youAreHereMarker(location!)],
                          circles: geofenceEnabled
                              ? [
                                  CircleMarker(
                                    point: location!,
                                    radius: geofenceRadius,
                                    useRadiusInMeter: true,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderColor: AppColors.primary,
                                    borderStrokeWidth: 2,
                                  ),
                                ]
                              : [],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Stop Sharing Live Location',
                outlined: true,
                onPressed: onStop,
              ),
              const SizedBox(height: 2),
              Text(
                'Location shared — no destination set',
                style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SharedWithCard(),
      ],
    );
  }
}

class _JourneyState extends StatelessWidget {
  const _JourneyState({
    required this.journey,
    required this.routeController,
    required this.onStop,
    required this.geofenceEnabled,
    required this.geofenceRadius,
  });

  final JourneyPlan journey;
  final AnimationController routeController;
  final VoidCallback onStop;
  final bool geofenceEnabled;
  final double geofenceRadius;

  @override
  Widget build(BuildContext context) {
    final distanceKm = LocationService.distanceKm(journey.from, journey.to);
    final etaMin = (distanceKm / 25 * 60)
        .clamp(2, 240)
        .round(); // assumes ~25km/h avg
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200),
            borderRadius: BorderRadius.circular(AppRadius.r5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _RouteLabel(
                      icon: Icons.trip_origin,
                      color: AppColors.primary,
                      label: journey.fromLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _RouteLabel(
                      icon: Icons.location_on,
                      color: Colors.black87,
                      label: journey.toLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r4),
                child: AspectRatio(
                  aspectRatio: 311 / 260,
                  child: AnimatedBuilder(
                    animation: routeController,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(
                        routeController.value,
                      );
                      final moving = LatLng(
                        journey.from.latitude +
                            (journey.to.latitude - journey.from.latitude) * t,
                        journey.from.longitude +
                            (journey.to.longitude - journey.from.longitude) * t,
                      );
                      final bounds = LatLngBounds.fromPoints([
                        journey.from,
                        journey.to,
                      ]);
                      return FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(40),
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.safeher.app',
                          ),
                          if (geofenceEnabled)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: journey.from,
                                  radius: geofenceRadius,
                                  useRadiusInMeter: true,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderColor: AppColors.primary,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [journey.from, journey.to],
                                color: AppColors.primary,
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              placeMarker(
                                journey.to,
                                icon: Icons.flag_rounded,
                                color: Colors.black87,
                              ),
                              youAreHereMarker(moving),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Stop Sharing Live Location',
                outlined: true,
                onPressed: onStop,
              ),
              const SizedBox(height: 2),
              Text(
                'Location Shared for 20 Min',
                style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SharedWithCard(),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral300),
            borderRadius: BorderRadius.circular(AppRadius.r4),
          ),
          child: Column(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.send_rounded, size: 20),
              ),
              const SizedBox(height: 13),
              Text('Journey in Progress', style: AppTextStyles.semibold16),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatColumn(
                    value: '${distanceKm.toStringAsFixed(1)} Km',
                    label: 'Distance',
                  ),
                  const SizedBox(width: 28),
                  _StatColumn(value: '$etaMin Min', label: 'ETA'),
                  const SizedBox(width: 28),
                  const _StatColumn(value: '4.2 Kmph', label: 'Speed'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.b4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SharedWithCard extends StatelessWidget {
  const _SharedWithCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sharing with', style: AppTextStyles.semibold16),
              const SizedBox(height: 5),
              Text('Emergency Help Now', style: AppTextStyles.b5),
            ],
          ),
          const _AvatarStack(),
        ],
      ),
    );
  }
}

class _GeofenceCard extends StatelessWidget {
  const _GeofenceCard({
    required this.enabled,
    required this.radius,
    required this.onToggle,
    required this.onRadiusChanged,
  });

  final bool enabled;
  final double radius;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.security_rounded, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safe Zone Alerts', style: AppTextStyles.semibold16),
                    Text(
                      'Notify contacts if you leave this area',
                      style: AppTextStyles.b5,
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Text('Radius', style: AppTextStyles.b4),
                        Expanded(
                          child: Slider(
                            value: radius,
                            min: 100,
                            max: 1500,
                            divisions: 14,
                            activeColor: AppColors.primary,
                            label: '${radius.round()} m',
                            onChanged: onRadiusChanged,
                          ),
                        ),
                        Text('${radius.round()} m', style: AppTextStyles.b4),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/avatar_shape.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.b3.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.b5),
      ],
    );
  }
}
