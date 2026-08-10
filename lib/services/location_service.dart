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
        const Duration(seconds: 15),
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
      //
      // BUT: on Chrome specifically, this can return a position that's
      // stale in a confusing way — if you've been testing with DevTools'
      // Sensors panel, the browser can keep handing back the position you
      // set several minutes ago even after you change it again, and even
      // across a full page refresh, because the cache lives at the
      // browser/OS level, not the page level. For a safety app, "confidently
      // wrong" is worse than "a couple seconds slower," so this shortcut
      // now only trusts a fix from the last 30 seconds instead of 5
      // minutes — tight enough to stop masking a changed position, loose
      // enough to still skip a redundant fresh GPS request most of the time.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp).inSeconds < 30) {
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
