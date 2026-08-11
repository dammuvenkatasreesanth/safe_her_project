import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Pure geofence math shared by Live Tracking's "left the safe zone" check
/// and Auto Safe Arrival — split out from live_tracking_tab.dart so the
/// distance thresholds are unit-testable without a device or GPS fix.
class GeofenceEvaluator {
  GeofenceEvaluator._();

  /// True once [current] is further than [radiusMeters] from [center].
  static bool hasExitedZone({
    required LatLng center,
    required LatLng current,
    required double radiusMeters,
  }) {
    return _distanceMeters(center, current) > radiusMeters;
  }

  /// True once [current] is within [radiusMeters] of [home] — default
  /// matches Auto Safe Arrival's "close enough to call it arrived".
  static bool hasArrived({
    required LatLng home,
    required LatLng current,
    double radiusMeters = 150,
  }) {
    return _distanceMeters(home, current) < radiusMeters;
  }

  static double _distanceMeters(LatLng a, LatLng b) => Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
}
