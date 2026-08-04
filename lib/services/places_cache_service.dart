import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';

/// Persists the last successful Overpass fetch to disk so:
///  - reopening the app shows results instantly while a fresh fetch runs
///    in the background ("cache API responses")
///  - if the device is offline and Overpass can't be reached, we can show
///    real, recent, nearby data instead of jumping straight to the
///    generic static fallback list.
class PlacesCacheService {
  PlacesCacheService._();

  static const _placesKey = 'nearby_help_cached_places';
  static const _timestampKey = 'nearby_help_cached_at';

  /// How long a cache entry is considered "fresh" before a background
  /// refresh is attempted again on next load.
  static const freshFor = Duration(minutes: 15);

  static Future<void> save(List<Place> places) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(places.map((p) => p.toJson()).toList());
    await prefs.setString(_placesKey, json);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<(List<Place> places, DateTime? cachedAt)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_placesKey);
    if (raw == null) return (<Place>[], null);
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(Place.fromJson)
          .toList();
      final ts = prefs.getInt(_timestampKey);
      final cachedAt = ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : null;
      return (list, cachedAt);
    } catch (_) {
      return (<Place>[], null);
    }
  }

  static Future<bool> isFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_timestampKey);
    if (ts == null) return false;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(cachedAt) < freshFor;
  }
}
