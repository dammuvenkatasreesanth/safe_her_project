import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_her/repositories/nearby_places_repository.dart';
import 'package:safe_her/services/overpass_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A real user location far from the old hardcoded Dhaka fallback
// coordinates (23.7461, 90.3742) — Bengaluru, India.
const _bengaluru = LatLng(12.9716, 77.5946);

String _fakeOverpassBody({required String name, required double lat, required double lon}) {
  return '''
  {
    "elements": [
      {"type": "node", "id": 1, "lat": $lat, "lon": $lon, "tags": {"name": "$name", "amenity": "police"}}
    ]
  }
  ''';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NearbyPlacesRepository — no more fake "nearby" data on failure', () {
    test('a live Overpass success returns real places near the given center', () async {
      final client = MockClient((request) async {
        return http.Response(
          _fakeOverpassBody(name: 'Bengaluru City Police Station', lat: 12.975, lon: 77.605),
          200,
        );
      });
      final repo = NearbyPlacesRepository(overpassService: OverpassService(client: client));

      final result = await repo.getNearby(_bengaluru);

      expect(result.source, PlacesSource.live);
      expect(result.places, hasLength(1));
      expect(result.places.first.name, 'Bengaluru City Police Station');
      // Real, small distance from the real center — nothing continent-away.
      expect(result.places.first.distanceKm, lessThan(10));
    });

    test(
      'when Overpass fails and nothing is cached yet, the result is empty — '
      'not a fabricated list of real-sounding places in the wrong city',
      () async {
        final client = MockClient((request) async => http.Response('server error', 500));
        final repo = NearbyPlacesRepository(overpassService: OverpassService(client: client));

        final result = await repo.getNearby(_bengaluru);

        expect(result.source, PlacesSource.unavailable);
        expect(result.places, isEmpty);
        // Regression guard for the specific bug: the old fallback list
        // included "Dhanmondi Police Station" and similar Dhaka names —
        // confirm nothing like that can appear here anymore.
        expect(
          result.places.any((p) => p.name.contains('Dhanmondi') || p.name.contains('Dhaka')),
          isFalse,
        );
      },
    );

    test('when Overpass fails but a previous fetch was cached, cached (real) places are reused', () async {
      // First call succeeds and populates the cache.
      final workingClient = MockClient((request) async {
        return http.Response(
          _fakeOverpassBody(name: 'Cached Real Hospital', lat: 12.98, lon: 77.6),
          200,
        );
      });
      final workingRepo = NearbyPlacesRepository(overpassService: OverpassService(client: workingClient));
      final firstResult = await workingRepo.getNearby(_bengaluru);
      expect(firstResult.source, PlacesSource.live);

      // Second call fails outright — should fall back to the cache from
      // the first call, not to made-up data.
      final failingClient = MockClient((request) async => http.Response('down', 503));
      final failingRepo = NearbyPlacesRepository(overpassService: OverpassService(client: failingClient));
      final secondResult = await failingRepo.getNearby(_bengaluru);

      expect(secondResult.source, PlacesSource.cache);
      expect(secondResult.places, hasLength(1));
      expect(secondResult.places.first.name, 'Cached Real Hospital');
    });
  });
}
