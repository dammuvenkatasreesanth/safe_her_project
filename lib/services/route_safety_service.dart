import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

import 'location_service.dart';
import 'risk_service.dart';
import 'routing_service.dart';

/// Milestone 3/4 — Route Safety Scoring & Intelligent Recommendation.
///
/// Scores every candidate [RouteOption] for a trip against real risk
/// zones ([RiskService]) and nearby emergency facilities (OSM Overpass),
/// combining:
///   - number of high/moderate risk zones the route crosses
///   - distance travelled inside risky areas
///   - how many police stations / hospitals / clinics sit near the route
///   - route length
///   - time of day (via [RiskAssessment.isNight])
/// into a single 0-100 safety score, then recommends the safest route
/// with a plain-English explanation of the trade-off vs. the fastest one.
class RouteSafetyEvaluation {
  const RouteSafetyEvaluation({
    required this.route,
    required this.safetyScore,
    required this.highRiskZonesCrossed,
    required this.moderateRiskZonesCrossed,
    required this.distanceInRiskyAreasKm,
    required this.nearbyEmergencyFacilities,
  });

  final RouteOption route;

  /// 0-100, higher = safer.
  final double safetyScore;
  final int highRiskZonesCrossed;
  final int moderateRiskZonesCrossed;
  final double distanceInRiskyAreasKm;
  final int nearbyEmergencyFacilities;

  int get totalRiskZonesCrossed =>
      highRiskZonesCrossed + moderateRiskZonesCrossed;
}

class RouteRecommendation {
  const RouteRecommendation({
    required this.evaluations,
    required this.fastest,
    required this.safest,
    required this.explanation,
  });

  /// All routes, evaluated, sorted safest-first.
  final List<RouteSafetyEvaluation> evaluations;
  final RouteSafetyEvaluation fastest;
  final RouteSafetyEvaluation safest;

  /// e.g. "This route is recommended because it avoids 2 high-risk zones
  /// and passes near 3 emergency facilities, though it adds 4 extra
  /// minutes."
  final String explanation;
}

class RouteSafetyService {
  RouteSafetyService._();

  static const double _facilityBufferMeters = 900;
  static const int _emergencyFetchRadiusMeters = 3500;
  static const int _maxSamplesPerRoute = 40;

  static Future<RouteRecommendation?> evaluate(List<RouteOption> routes) async {
    if (routes.isEmpty) return null;

    final mid = _midpoint(routes);

    RiskAssessment assessment;
    try {
      assessment = await RiskService.assess(center: mid);
    } catch (_) {
      assessment = RiskAssessment(
        zones: const [],
        overallScore: 100,
        usingLighting: false,
        usingLiveIncidents: false,
        isNight: DateTime.now().hour >= 19 || DateTime.now().hour < 6,
      );
    }

    var facilities = <LatLng>[];
    try {
      facilities = await _fetchEmergencyFacilities(mid);
    } catch (_) {
      // No emergency-facility signal this time — evaluation still works,
      // it just can't reward routes for passing near help.
    }

    final shortestDistanceKm = routes
        .map((r) => r.distanceKm)
        .reduce((a, b) => a < b ? a : b);

    final evaluations = [
      for (final route in routes)
        evaluateRoute(route, assessment, facilities, shortestDistanceKm),
    ]..sort((a, b) => b.safetyScore.compareTo(a.safetyScore));

    // Ties matter: List.sort isn't guaranteed stable, so without this,
    // which route counts as "safest" among a tie was effectively random
    // — sometimes landing on a slower route with no real reason for the
    // pick, sometimes on the fastest one for no stated reason either.
    // Deterministic tie-break: among routes sharing the top safety score,
    // prefer the fastest one — there's no safety trade-off to justify
    // picking a slower one.
    const scoreTieEpsilon = 0.01;
    final topScore = evaluations.first.safetyScore;
    final tiedForSafest = evaluations
        .where((e) => (e.safetyScore - topScore).abs() <= scoreTieEpsilon)
        .toList();
    final safest = tiedForSafest.reduce(
      (a, b) => a.route.durationMin <= b.route.durationMin ? a : b,
    );
    final fastest = evaluations.reduce(
      (a, b) => a.route.durationMin <= b.route.durationMin ? a : b,
    );

    return RouteRecommendation(
      evaluations: evaluations,
      fastest: fastest,
      safest: safest,
      explanation: _buildExplanation(safest: safest, fastest: fastest),
    );
  }

  /// The pure per-route scoring step — no network calls. Exposed
  /// (non-underscore) and marked [visibleForTesting] so the weighted
  /// algorithm can be unit-tested directly with hand-built
  /// [RiskAssessment]/facility data, instead of only through [evaluate]
  /// which needs live Overpass/Firestore access.
  @visibleForTesting
  static RouteSafetyEvaluation evaluateRoute(
    RouteOption route,
    RiskAssessment assessment,
    List<LatLng> facilities,
    double shortestDistanceKm,
  ) {
    final sampled = _sample(route.points, _maxSamplesPerRoute);

    var highCrossed = 0;
    var moderateCrossed = 0;
    final crossedZoneIndices = <int>{};

    for (final point in sampled) {
      for (var zIndex = 0; zIndex < assessment.zones.length; zIndex++) {
        final zone = assessment.zones[zIndex];
        if (zone.level == RiskLevel.safe) continue;
        final d = LocationService.distanceKm(point, zone.center) * 1000;
        if (d <= zone.radiusMeters && crossedZoneIndices.add(zIndex)) {
          if (zone.level == RiskLevel.high) {
            highCrossed++;
          } else {
            moderateCrossed++;
          }
        }
      }
    }

    // Approximate distance travelled inside any risky zone: each sampled
    // point represents an equal slice of the route's total distance.
    var riskyDistanceKm = 0.0;
    if (sampled.isNotEmpty) {
      final segmentKm = route.distanceKm / sampled.length;
      for (final point in sampled) {
        final insideRisky = assessment.zones.any(
          (z) =>
              z.level != RiskLevel.safe &&
              LocationService.distanceKm(point, z.center) * 1000 <=
                  z.radiusMeters,
        );
        if (insideRisky) riskyDistanceKm += segmentKm;
      }
    }

    final nearbyFacilities = facilities
        .where(
          (f) => sampled.any(
            (p) =>
                LocationService.distanceKm(p, f) * 1000 <=
                _facilityBufferMeters,
          ),
        )
        .length;

    var score = 100.0;
    score -= highCrossed * 18;
    score -= moderateCrossed * 8;
    score -= math.min(25, riskyDistanceKm * 12);
    score += math.min(15, nearbyFacilities * 3.0);
    if (assessment.isNight && (highCrossed > 0 || moderateCrossed > 0)) {
      score -= 8; // time-of-day factor: a risky crossing matters more at night
    }
    // Route length factor: extra distance beyond the shortest candidate
    // means more time exposed on the road/street, independent of whether
    // it happens to cross a mapped risk zone. Capped so a long-but-safe
    // route isn't punished more harshly than actually crossing a zone.
    final extraKm = route.distanceKm - shortestDistanceKm;
    score -= math.min(12, extraKm * 4);
    score = score.clamp(0, 100).toDouble();

    return RouteSafetyEvaluation(
      route: route,
      safetyScore: score,
      highRiskZonesCrossed: highCrossed,
      moderateRiskZonesCrossed: moderateCrossed,
      distanceInRiskyAreasKm: riskyDistanceKm,
      nearbyEmergencyFacilities: nearbyFacilities,
    );
  }

  static String _buildExplanation({
    required RouteSafetyEvaluation safest,
    required RouteSafetyEvaluation fastest,
  }) {
    if (identical(safest.route, fastest.route)) {
      return 'This is also the fastest route, so there\'s no trade-off — take it.';
    }

    final reasons = <String>[];
    final zonesAvoided =
        fastest.totalRiskZonesCrossed - safest.totalRiskZonesCrossed;
    if (zonesAvoided > 0) {
      final highAvoided =
          fastest.highRiskZonesCrossed - safest.highRiskZonesCrossed;
      if (highAvoided > 0) {
        reasons.add(
          'avoids $highAvoided high-risk zone${highAvoided == 1 ? '' : 's'}',
        );
      } else {
        reasons.add(
          'avoids $zonesAvoided risk zone${zonesAvoided == 1 ? '' : 's'}',
        );
      }
    }
    if (safest.nearbyEmergencyFacilities > fastest.nearbyEmergencyFacilities) {
      reasons.add(
        'passes near ${safest.nearbyEmergencyFacilities} emergency '
        'facilit${safest.nearbyEmergencyFacilities == 1 ? 'y' : 'ies'}',
      );
    }
    final reasonText = reasons.isEmpty
        ? 'has a meaningfully higher safety score'
        : reasons.join(' and ');

    final extraMin = safest.route.durationMin - fastest.route.durationMin;
    final timeText = extraMin <= 0
        ? 'without adding travel time'
        : 'though it adds $extraMin extra minute${extraMin == 1 ? '' : 's'}';

    return 'This route is recommended because it $reasonText, $timeText.';
  }

  static LatLng _midpoint(List<RouteOption> routes) {
    final all = routes.expand((r) => r.points).toList();
    if (all.isEmpty) return const LatLng(0, 0);
    final lat = all.map((p) => p.latitude).reduce((a, b) => a + b) / all.length;
    final lng =
        all.map((p) => p.longitude).reduce((a, b) => a + b) / all.length;
    return LatLng(lat, lng);
  }

  static List<LatLng> _sample(List<LatLng> points, int maxSamples) {
    if (points.length <= maxSamples) return points;
    final step = points.length / maxSamples;
    return [for (var i = 0.0; i < points.length; i += step) points[i.floor()]];
  }

  static Future<List<LatLng>> _fetchEmergencyFacilities(LatLng center) async {
    final radius = _emergencyFetchRadiusMeters;
    final query =
        '[out:json][timeout:12];('
        'node["amenity"="police"](around:$radius,${center.latitude},${center.longitude});'
        'node["amenity"="hospital"](around:$radius,${center.latitude},${center.longitude});'
        'node["amenity"="clinic"](around:$radius,${center.latitude},${center.longitude});'
        ');out center 250;';

    final response = await http
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('overpass status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List).cast<Map<String, dynamic>>();

    final points = <LatLng>[];
    for (final e in elements) {
      final lat = (e['lat'] as num?)?.toDouble();
      final lon = (e['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      points.add(LatLng(lat, lon));
    }
    return points;
  }
}
