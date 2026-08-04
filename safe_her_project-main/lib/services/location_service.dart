import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Dhanmondi 32, Dhaka — used whenever we can't get a real device fix
/// (permission denied, desktop/web without geolocation, or timeout).
const LatLng defaultLocation = LatLng(23.7461, 90.3742);

class LocationService {
  LocationService._();

  static Future<LatLng> getCurrentLocation() async {
    try {
      return await _resolve().timeout(
        const Duration(seconds: 20),
        onTimeout: () => defaultLocation,
      );
    } catch (_) {
      return defaultLocation;
    }
  }

  static Future<LatLng> _resolve() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return defaultLocation;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return defaultLocation;
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
