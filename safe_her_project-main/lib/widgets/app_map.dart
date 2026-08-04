import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// A real, interactive OpenStreetMap view shared by every screen that needs
/// a map (Home, Live Tracking, Nearby Help). Free — no API key required.
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.center,
    this.zoom = 15,
    this.markers = const [],
    this.polylines = const [],
    this.circles = const [],
    this.interactive = true,
    this.controller,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<CircleMarker> circles;
  final bool interactive;
  final MapController? controller;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.safeher.app',
          maxNativeZoom: 19,
        ),
        if (circles.isNotEmpty) CircleLayer(circles: circles),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const _AttributionBadge(),
      ],
    );
  }
}

class _AttributionBadge extends StatelessWidget {
  const _AttributionBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: Colors.white70,
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(fontSize: 9, color: Colors.black54),
        ),
      ),
    );
  }
}

/// A pin-style marker consistent with the app's orange design language.
Marker youAreHereMarker(LatLng point, {double size = 44}) {
  return Marker(
    point: point,
    width: size,
    height: size,
    alignment: Alignment.topCenter,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Colors.white, size: 20),
    ),
  );
}

Marker placeMarker(
  LatLng point, {
  required IconData icon,
  required Color color,
  VoidCallback? onTap,
}) {
  return Marker(
    point: point,
    width: 38,
    height: 38,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    ),
  );
}
