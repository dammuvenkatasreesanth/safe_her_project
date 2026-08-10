import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import 'location_service.dart';

/// Thrown by [OverpassService] with a message safe to show to users.
class OverpassException implements Exception {
  const OverpassException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fetches nearby police stations, hospitals, and NGO/social-facility
/// points from the free OSM Overpass API — no key required.
class OverpassService {
  OverpassService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Public Overpass mirrors, tried in order — the main instance
  /// (overpass-api.de) rate-limits and occasionally times out under load,
  /// so a failed attempt falls through to the next mirror before giving up.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Fetches places within [radiusMeters] of [center]. Retries each
  /// endpoint up to [retries] times with a short backoff before moving to
  /// the next mirror. Throws [OverpassException] if every attempt fails —
  /// callers should fall back to cached/offline data in that case.
  Future<List<Place>> fetchNearby(
    LatLng center, {
    int radiusMeters = 3000,
    int retries = 2,
  }) async {
    final query =
        '[out:json][timeout:15];('
        'node["amenity"="police"](around:$radiusMeters,${center.latitude},${center.longitude});'
        'node["amenity"="hospital"](around:$radiusMeters,${center.latitude},${center.longitude});'
        'node["office"="ngo"](around:$radiusMeters,${center.latitude},${center.longitude});'
        'node["amenity"="social_facility"](around:$radiusMeters,${center.latitude},${center.longitude});'
        ');out center 40;';

    Object? lastError;
    for (final endpoint in _endpoints) {
      for (var attempt = 0; attempt <= retries; attempt++) {
        try {
          final response = await _client
              .post(Uri.parse(endpoint), body: {'data': query})
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) {
            throw OverpassException('Overpass returned ${response.statusCode}');
          }
          return _parse(response.body, center);
        } catch (e) {
          lastError = e;
          if (attempt < retries) {
            await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          }
        }
      }
    }
    throw OverpassException(
      lastError?.toString() ?? 'Could not reach the nearby-places service.',
    );
  }

  List<Place> _parse(String body, LatLng center) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final elements = (data['elements'] as List).cast<Map<String, dynamic>>();
    final results = <Place>[];
    for (final e in elements) {
      final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
      final name = tags['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      final lat = (e['lat'] as num?)?.toDouble();
      final lon = (e['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final point = LatLng(lat, lon);
      final type = tags['amenity'] == 'police'
          ? PlaceType.police
          : tags['amenity'] == 'hospital'
          ? PlaceType.hospital
          : PlaceType.ngo;
      final phone =
          tags['phone'] as String? ?? tags['contact:phone'] as String?;
      final address = [
        tags['addr:housenumber'],
        tags['addr:street'],
        tags['addr:city'],
      ].where((p) => p != null && (p as String).trim().isNotEmpty).join(', ');
      results.add(
        Place(
          id: '${e['type']}/${e['id']}',
          name: name,
          type: type,
          point: point,
          distanceKm: LocationService.distanceKm(center, point),
          phone: phone,
          address: address.isEmpty ? null : address,
        ),
      );
    }
    return results;
  }
}
