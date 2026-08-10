import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../services/location_service.dart';
import '../services/overpass_service.dart';
import '../services/places_cache_service.dart';

enum PlacesSource { live, cache, offlineFallback }

class PlacesResult {
  const PlacesResult({required this.places, required this.source});
  final List<Place> places;
  final PlacesSource source;
}

/// Single entry point Nearby Help uses to get places: tries a live
/// Overpass fetch first, falls back to the last cached fetch, and finally
/// to a small static list of known Dhaka-area locations if both fail —
/// so the screen is never empty even with zero connectivity.
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
    } catch (_) {
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
        return PlacesResult(places: rescored, source: PlacesSource.cache);
      }
      final fallback = _fallbackPlaces(center)
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return PlacesResult(
        places: fallback,
        source: PlacesSource.offlineFallback,
      );
    }
  }

  List<Place> _fallbackPlaces(LatLng center) {
    final raw = [
      (
        id: 'fallback-1',
        name: 'Dhanmondi Police Station',
        type: PlaceType.police,
        point: const LatLng(23.7395, 90.3745),
      ),
      (
        id: 'fallback-2',
        name: 'Square Hospital Ltd',
        type: PlaceType.hospital,
        point: const LatLng(23.7522, 90.3752),
      ),
      (
        id: 'fallback-3',
        name: 'Neonatal & General Hospital',
        type: PlaceType.hospital,
        point: const LatLng(23.7480, 90.3720),
      ),
      (
        id: 'fallback-4',
        name: "Women's Support NGO",
        type: PlaceType.ngo,
        point: const LatLng(23.7440, 90.3700),
      ),
      (
        id: 'fallback-5',
        name: 'Rapa Plaza Police Outpost',
        type: PlaceType.police,
        point: const LatLng(23.7500, 90.3760),
      ),
    ];
    return [
      for (final p in raw)
        Place(
          id: p.id,
          name: p.name,
          type: p.type,
          point: p.point,
          distanceKm: LocationService.distanceKm(center, p.point),
        ),
    ];
  }
}
