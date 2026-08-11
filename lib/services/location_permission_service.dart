import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationAccessStatus {
  granted,
  gpsDisabled,
  denied,
  deniedForever,
  /// Permission is granted and GPS is on, but a real fix still couldn't be
  /// obtained (weak signal, indoors, or a cold-start timeout). Distinct
  /// from [denied]/[deniedForever] since re-requesting permission won't
  /// help here — only moving somewhere with better signal or retrying will.
  unavailable,
}

/// Reports *why* location isn't available, on top of the existing
/// [LocationService] (which is shared with Module 4 and intentionally
/// always falls back silently to a default point — left unmodified here).
/// Nearby Help uses this to show the right message and action instead of
/// just quietly using the fallback location.
class LocationPermissionService {
  LocationPermissionService._();

  static Future<LocationAccessStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationAccessStatus.gpsDisabled;

    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return LocationAccessStatus.deniedForever;
    }
    if (status.isDenied) {
      return LocationAccessStatus.denied;
    }
    return LocationAccessStatus.granted;
  }

  static Future<void> openSettings() => openAppSettings();
}
