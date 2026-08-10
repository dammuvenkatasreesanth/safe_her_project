import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'location_service.dart';
import 'risk_service.dart';

enum TravelMode { driving, walking }

/// A single candidate route between two points — either a real road route
/// (driving) or a synthesized approximation (walking, see below).
class RouteOption {
  RouteOption({
    required this.label,
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    this.isApproximate = false,
    this.riskLevel,
  });

  final String
  label; // 'Fastest Route', 'Alternate Route 1', 'Walking (approx.)', ...
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  /// True for the synthesized walking route — a straight-line estimate,
  /// not real turn-by-turn directions. Callers should show a disclaimer
  /// when this is true rather than presenting it as equal-quality to a
  /// real OSRM route.
  final bool isApproximate;

  /// Set from a [RouteSafetyEvaluation] once RouteSafetyService has scored
  /// this route (see select_route_screen.dart). Null until scored / if
  /// scoring wasn't attempted, so callers should treat null as "unknown"
  /// rather than "safe".
  RiskLevel? riskLevel;

  /// 0-100 weighted safety score from RouteSafetyService, same lifecycle
  /// as [riskLevel] above.
  double? safetyScore;

  /// Only set on the route RouteSafetyService picked as safest — the
  /// plain-English "why this one" sentence, carried through to the
  /// journey-in-progress screen once the user confirms a route (see
  /// JourneyPlan.routeExplanation in start_journey_sheet.dart). Null on
  /// every other route, and on this one too if scoring wasn't attempted.
  String? safetyExplanation;
}

/// Free, keyless road routing via OSRM's public demo server (driving) and
/// OpenStreetMap Germany's public `routed-foot` OSRM instance (walking).
/// Both return real turn-by-turn geometry with alternative routes, same
/// shape either way — only the profile/host differs.
///
/// If the walking fetch fails (network error, no route found, or the
/// endpoint is unreachable), this falls back to a straight-line estimate
/// so the app still works — that fallback is honestly labeled as
/// approximate (`isApproximate: true`) everywhere it's shown, since it
/// won't route around buildings, one-way footpaths, etc.
class RoutingService {
  RoutingService._();

  static const double _walkingSpeedKmh = 5.0;

  static Future<List<RouteOption>> getRoutes({
    required LatLng from,
    required LatLng to,
  }) {
    return _fetchOsrmRoutes(
      host: 'router.project-osrm.org',
      profile: 'driving',
      from: from,
      to: to,
      fastestLabel: 'Fastest Route',
      alternateLabel: 'Alternate Route',
    );
  }

  /// Real walking directions from OSM Germany's free `routed-foot` OSRM
  /// instance, with the same alternatives/safest-vs-fastest flow as
  /// driving. Falls back to a straight-line estimate only if that fetch
  /// fails outright.
  static Future<List<RouteOption>> getWalkingRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final routes = await _fetchOsrmRoutes(
      host: 'routing.openstreetmap.de',
      pathPrefix: '/routed-foot',
      profile: 'foot',
      from: from,
      to: to,
      fastestLabel: 'Fastest Walking Route',
      alternateLabel: 'Alternate Walking Route',
    );
    if (routes.isNotEmpty) return routes;
    return _straightLineFallback(from: from, to: to);
  }

  static Future<List<RouteOption>> _fetchOsrmRoutes({
    required String host,
    required String profile,
    required LatLng from,
    required LatLng to,
    required String fastestLabel,
    required String alternateLabel,
    String pathPrefix = '',
  }) async {
    final path =
        '$pathPrefix/route/v1/$profile/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.https(host, path, {
      'alternatives': 'true',
      'geometries': 'geojson',
      'overview': 'full',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'SafeHerApp/1.0 (safety demo)'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return [];
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];

      final parsed = <RouteOption>[];
      for (final route in routes) {
        final coords = (route['geometry']['coordinates'] as List).cast<List>();
        final points = [
          for (final c in coords)
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ];
        parsed.add(
          RouteOption(
            label: '',
            points: points,
            distanceKm: (route['distance'] as num) / 1000,
            durationMin: ((route['duration'] as num) / 60).round(),
          ),
        );
      }

      parsed.sort((a, b) => a.durationMin.compareTo(b.durationMin));
      return [
        for (var i = 0; i < parsed.length; i++)
          RouteOption(
            label: i == 0 ? fastestLabel : '$alternateLabel $i',
            points: parsed[i].points,
            distanceKm: parsed[i].distanceKm,
            durationMin: parsed[i].durationMin,
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Last-resort fallback when real walking directions can't be fetched
  /// at all — a single straight-line estimate, honestly labeled.
  static List<RouteOption> _straightLineFallback({
    required LatLng from,
    required LatLng to,
  }) {
    final distanceKm = LocationService.distanceKm(from, to);
    final durationMin = ((distanceKm / _walkingSpeedKmh) * 60)
        .clamp(1, 600)
        .round();
    return [
      RouteOption(
        label: 'Walking (approx.)',
        points: _straightLine(from, to, segments: 8),
        distanceKm: distanceKm,
        durationMin: durationMin,
        isApproximate: true,
      ),
    ];
  }

  /// Linearly interpolated points between [from] and [to] — subdivided
  /// purely so the line renders consistently with real routes on the map
  /// (matching stroke behavior), not because it's curved or path-aware.
  static List<LatLng> _straightLine(
    LatLng from,
    LatLng to, {
    required int segments,
  }) {
    return [
      for (var i = 0; i <= segments; i++)
        LatLng(
          from.latitude + (to.latitude - from.latitude) * i / segments,
          from.longitude + (to.longitude - from.longitude) * i / segments,
        ),
    ];
  }
}
