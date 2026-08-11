import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  LocationService._();

  /// The device's real current location, or null if that's genuinely not
  /// available right now (GPS off, permission denied, or no fix within the
  /// timeout).
  ///
  /// This used to silently return a hardcoded fallback point (Dhanmondi,
  /// Dhaka) whenever a real fix failed — every consumer of this (Nearby
  /// Help results, SOS location sharing, Safe Route scoring, incident
  /// tagging) is safety-relevant, and a wrong-but-plausible-looking
  /// location (real place names shown as "2 km away" when the user is
  /// actually thousands of km away) is worse than an honest "unavailable".
  /// Callers must handle null explicitly — most already do, since they
  /// show a loading/locating state until a location arrives.
  static Future<LatLng?> getCurrentLocation() async {
    try {
      return await _resolve().timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<LatLng?> _resolve() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      // A recent cached fix (if any) returns instantly and is usually accurate
      // enough — avoids waiting on a cold GPS fix every time the app opens.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp).inMinutes < 5) {
        return LatLng(last.latitude, last.longitude);
      }
    } catch (_) {
      // fall through to a fresh fix
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    return LatLng(position.latitude, position.longitude);
  }

  static double distanceKm(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) /
        1000;
  }
}
