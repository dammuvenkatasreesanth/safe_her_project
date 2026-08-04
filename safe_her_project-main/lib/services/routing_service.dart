import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A single candidate road route between two points.
class RouteOption {
  const RouteOption({
    required this.label,
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });

  final String label; // 'Fastest Route', 'Alternate Route 1', ...
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  // TODO(module-5 safe-route): once Module 5 exposes real risk-zone
  // scoring, add a safetyScore/riskLevel field here and surface it in
  // select_route_screen.dart instead of the generic labels below.
}

/// Free, keyless road routing via OSRM's public demo server.
///
/// Known limitation: the public demo only serves the `driving` profile —
/// there's no walking/cycling profile available on this free endpoint, so
/// routes are car-routed even for on-foot journeys. A different provider
/// would be needed for real foot routing.
class RoutingService {
  RoutingService._();

  static Future<List<RouteOption>> getRoutes({
    required LatLng from,
    required LatLng to,
  }) async {
    final path =
        '/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.https('router.project-osrm.org', path, {
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
        final coords =
            (route['geometry']['coordinates'] as List).cast<List>();
        final points = [
          for (final c in coords) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
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
            label: i == 0 ? 'Fastest Route' : 'Alternate Route $i',
            points: parsed[i].points,
            distanceKm: parsed[i].distanceKm,
            durationMin: parsed[i].durationMin,
          ),
      ];
    } catch (_) {
      return [];
    }
  }
}
