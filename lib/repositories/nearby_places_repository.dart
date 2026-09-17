import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../services/location_service.dart';
import '../services/overpass_service.dart';
import '../services/places_cache_service.dart';

enum PlacesSource { live, cache, unavailable }

class PlacesResult {
  const PlacesResult({required this.places, required this.source, this.errorMessage});
  final List<Place> places;
  final PlacesSource source;

  /// The real reason the live fetch failed (e.g. "Overpass returned 502",
  /// a timeout, "no internet") — only set when [source] is
  /// [PlacesSource.unavailable] or [PlacesSource.cache]. Surfaced in the UI
  /// instead of a generic message so a failure is actually diagnosable from
  /// what the user sees, rather than everyone seeing the same "not working."
  final String? errorMessage;
}

/// Single entry point Nearby Help uses to get places: tries a live
/// Overpass fetch first, then falls back to the last cached fetch (re-
/// scored for the current position) if that fails.
///
/// There is deliberately no third fallback to a static list of made-up
/// "nearby" places. An earlier version of this class did that — a fixed
/// list of real-sounding institution names in Dhaka — and it silently
/// showed those to users anywhere else in the world as if they were real
/// nearby results (with plausible-looking distances) whenever both the
/// live fetch and the cache failed. For a safety feature, a wrong-but-
/// convincing answer is worse than an honest "couldn't load, try again" —
/// see [PlacesSource.unavailable] and nearby_help_screen.dart's retry state.
class NearbyPlacesRepository {
  NearbyPlacesRepository({OverpassService? overpassService})
    : _overpass = overpassService ?? OverpassService();

  final OverpassService _overpass;

  Future<PlacesResult> getNearby(LatLng center) async {
    try {
      final places = await _overpass.fetchNearby(center);
      if (places.isEmpty) throw const OverpassException('no results');
      places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      await PlacesCacheService.save(places);
      return PlacesResult(places: places, source: PlacesSource.live);
    } catch (e) {
      final reason = e is OverpassException ? e.message : e.toString();
      final (cached, _) = await PlacesCacheService.load();
      if (cached.isNotEmpty) {
        final rescored = cached
            .map(
              (p) => p.copyWithDistance(
                LocationService.distanceKm(center, p.point),
              ),
            )
            .toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return PlacesResult(places: rescored, source: PlacesSource.cache, errorMessage: reason);
      }
      return PlacesResult(places: const [], source: PlacesSource.unavailable, errorMessage: reason);
    }
  }
}
