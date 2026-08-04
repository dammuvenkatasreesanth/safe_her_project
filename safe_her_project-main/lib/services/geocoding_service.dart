import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceResult {
  const PlaceResult({required this.label, required this.point});
  final String label;
  final LatLng point;
}

/// Free destination search via OpenStreetMap's Nominatim API — no key needed.
class GeocodingService {
  GeocodingService._();

  static Future<List<PlaceResult>> search(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '5',
      if (near != null)
        'viewbox':
            '${near.longitude - 0.15},${near.latitude + 0.15},${near.longitude + 0.15},${near.latitude - 0.15}',
      if (near != null) 'bounded': '0',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'SafeHerApp/1.0 (safety demo)'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as List;
      return [
        for (final item in data)
          PlaceResult(
            label: item['display_name'] as String,
            point: LatLng(
              double.parse(item['lat'] as String),
              double.parse(item['lon'] as String),
            ),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> reverse(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'SafeHerApp/1.0 (safety demo)'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
