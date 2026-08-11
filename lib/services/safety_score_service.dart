import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum RiskLevel { safe, moderate, high }

/// A real (if simple) safety heuristic: it is NOT verified crime data —
/// there's no free, keyless source for that — it's real-time density of
/// two honest, public signals from OpenStreetMap: police proximity and
/// street lighting, discounted after dark. More of both raises the score;
/// fewer of both plus nighttime lowers it. Treat this as "better-lit and
/// closer to help", not a certified safety guarantee.
class SafetyScoreService {
  SafetyScoreService._();

  static final _client = http.Client();

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static bool get _isNight {
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 19;
  }

  /// Scores a single point's surrounding neighborhood (default 300m).
  static Future<RiskLevel> scoreZone(LatLng center, {int radiusMeters = 300}) async {
    final counts = await _fetchCounts(center, radiusMeters);
    return _levelFor(counts);
  }

  /// Scores a route by sampling a few points along it (start, quarter
  /// marks, end) rather than every vertex — keeps this to a handful of
  /// Overpass calls per route instead of hundreds.
  static Future<RiskLevel> scoreRoute(List<LatLng> points) async {
    if (points.isEmpty) return RiskLevel.moderate;
    final samples = <LatLng>[
      points.first,
      points[points.length ~/ 2],
      points.last,
    ];
    var totalPolice = 0;
    var totalLamps = 0;
    for (final p in samples) {
      final counts = await _fetchCounts(p, 250);
      totalPolice += counts.$1;
      totalLamps += counts.$2;
    }
    return _levelFor((totalPolice, totalLamps));
  }

  static RiskLevel _levelFor((int police, int lamps) counts) =>
      levelForCounts(counts.$1, counts.$2, isNight: _isNight);

  /// The scoring bucket itself, split out from [_levelFor] so it's
  /// unit-testable without depending on the real wall-clock hour.
  @visibleForTesting
  static RiskLevel levelForCounts(int policeCount, int lampCount, {required bool isNight}) {
    var score = policeCount * 3 + lampCount;
    if (isNight) score = (score * 0.6).round();
    if (score >= 8) return RiskLevel.safe;
    if (score >= 3) return RiskLevel.moderate;
    return RiskLevel.high;
  }

  /// (policeCount, streetLampCount) near [center].
  static Future<(int, int)> _fetchCounts(LatLng center, int radiusMeters) async {
    final query =
        '[out:json][timeout:15];('
        'node["amenity"="police"](around:$radiusMeters,${center.latitude},${center.longitude});'
        'node["highway"="street_lamp"](around:$radiusMeters,${center.latitude},${center.longitude});'
        ');out;';

    for (final endpoint in _endpoints) {
      try {
        final response = await _client
            .post(Uri.parse(endpoint), body: {'data': query})
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = (data['elements'] as List).cast<Map<String, dynamic>>();
        var police = 0;
        var lamps = 0;
        for (final e in elements) {
          final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
          if (tags['amenity'] == 'police') police++;
          if (tags['highway'] == 'street_lamp') lamps++;
        }
        return (police, lamps);
      } catch (_) {
        continue; // try the next mirror
      }
    }
    // Every mirror failed — treat as "unknown", not "unsafe": callers get
    // a moderate score rather than a false high-risk reading.
    return (1, 4);
  }
}
