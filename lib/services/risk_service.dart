import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'location_service.dart';

/// Module 5 — Safe Route & Risk Zone Prediction.
///
/// Produces real risk-zone data (no mock CircleMarkers) by scoring a grid
/// of cells around a point using signals that are actually available for
/// free, without any paid API key:
///
///  - **Lighting** — OSM Overpass `highway=street_lamp` nodes near a cell.
///    Missing street lights matter far more at night than during the day.
///  - **Activity / foot-traffic proxy** — OSM Overpass POIs (cafes, shops,
///    restaurants, pharmacies, bars, banks...). More of these nearby
///    usually means more people around, which correlates with more
///    eyes-on-street.
///  - **Community incident reports** — recent documents in the Firestore
///    `incidents` collection (the same collection Module 9's Report
///    screen is meant to write to, per the project's shared schema). This
///    is the "crowd density / crime stats" signal: real reports pull a
///    cell's score down, weighted by recency and distance.
///  - **Time of day** — night hours amplify the lighting/activity penalty.
///
/// If Overpass and/or Firestore are unreachable, the service degrades
/// gracefully (it never fabricates fake risk data, to avoid misleading a
/// safety app's users) and reports which signals it actually used via
/// [RiskAssessment.usingLighting] / [RiskAssessment.usingLiveIncidents].
enum RiskLevel { safe, moderate, high }

class RiskZone {
  const RiskZone({
    required this.center,
    required this.radiusMeters,
    required this.level,
    required this.score,
    required this.reasons,
  });

  final LatLng center;
  final double radiusMeters;
  final RiskLevel level;

  /// 0-100, higher = safer.
  final double score;

  /// Short human-readable factors that drove this cell's score, e.g.
  /// "2 nearby community reports", "No street lighting detected nearby".
  final List<String> reasons;
}

class RiskAssessment {
  const RiskAssessment({
    required this.zones,
    required this.overallScore,
    required this.usingLighting,
    required this.usingLiveIncidents,
    required this.isNight,
  });

  /// Only the zones worth showing on a map (all moderate/high cells, plus
  /// a couple of the safest cells for context) — not the full raw grid.
  final List<RiskZone> zones;

  /// Average score (0-100) across the whole scored grid.
  final double overallScore;

  final bool usingLighting;
  final bool usingLiveIncidents;
  final bool isNight;

  RiskLevel get overallLevel => RiskService.levelForScore(overallScore);
}

class RiskService {
  RiskService._();

  static const int _gridSize = 5; // 5x5 grid
  static const double _cellSpanMeters = 260; // spacing between cell centers
  static const double _cellRadiusMeters = 170; // drawn circle radius
  static const double _overpassFetchRadiusMeters = 820; // covers the grid

  static Future<RiskAssessment> assess({
    required LatLng center,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final isNight = now.hour >= 19 || now.hour < 6;

    final cellCenters = _buildGrid(center);

    // These two fetches are independent — Overpass has no idea about
    // Firestore incidents and vice versa — so there's no reason to make
    // one wait on the other. Running them sequentially (as this used to)
    // meant up to 12s + 8s = 20s worst case just for this one call, on
    // top of however long location resolution already took. Running them
    // together caps it at whichever one is slower.
    final overpassFuture = _fetchOverpassFeatures(
      center,
    ).then<_OverpassFeatures?>((f) => f).catchError((_) => null);
    final incidentsFuture = _fetchRecentIncidents(
      center,
      now,
    ).then<List<_Incident>?>((list) => list).catchError((_) => null);

    final results = await Future.wait([overpassFuture, incidentsFuture]);
    final features = results[0] as _OverpassFeatures?;
    final incidentsResult = results[1] as List<_Incident>?;

    final lampPoints = features?.lamps ?? <LatLng>[];
    final activityPoints = features?.activity ?? <LatLng>[];
    final incidents = incidentsResult ?? <_Incident>[];
    final overpassOk = features != null;
    final firestoreOk = incidentsResult != null;

    final zones = <RiskZone>[];
    for (final cellCenter in cellCenters) {
      final lampCount = _countWithin(lampPoints, cellCenter, _cellRadiusMeters);
      final activityCount = _countWithin(
        activityPoints,
        cellCenter,
        _cellRadiusMeters,
      );
      final incidentHits = _incidentsWithin(
        incidents,
        cellCenter,
        _cellRadiusMeters,
      );

      final score = _scoreCell(
        lampCount: lampCount,
        activityCount: activityCount,
        incidentHits: incidentHits,
        now: now,
        isNight: isNight,
      );

      final reasons = <String>[
        if (incidentHits.isNotEmpty)
          '${incidentHits.length} nearby community report'
              '${incidentHits.length == 1 ? '' : 's'}',
        if (lampCount == 0 && isNight) 'No street lighting detected nearby',
        if (activityCount == 0) 'Few nearby venues (low foot traffic)',
      ];
      if (reasons.isEmpty) reasons.add('No specific risk signals nearby');

      zones.add(
        RiskZone(
          center: cellCenter,
          radiusMeters: _cellRadiusMeters,
          level: levelForScore(score),
          score: score,
          reasons: reasons,
        ),
      );
    }

    final overall = zones.isEmpty
        ? 100.0
        : zones.map((z) => z.score).reduce((a, b) => a + b) / zones.length;

    final sortedByScore = [...zones]
      ..sort((a, b) => a.score.compareTo(b.score));
    final notable = sortedByScore
        .where((z) => z.level != RiskLevel.safe)
        .toList();
    final safestForContext = sortedByScore.reversed
        .where((z) => !notable.contains(z))
        .take(2);
    final display = [...notable, ...safestForContext];

    return RiskAssessment(
      zones: display,
      overallScore: overall,
      usingLighting: overpassOk,
      usingLiveIncidents: firestoreOk,
      isNight: isNight,
    );
  }

  // NOTE: the old single-route, worst-case-only `scoreRoute()` helper that
  // used to live here has been removed. It's superseded by
  // `RouteSafetyService.evaluate()` (route_safety_service.dart), which
  // scores every candidate route with the full weighted algorithm (zones
  // crossed, distance inside risky areas, nearby emergency facilities,
  // route length, time of day) instead of just returning a worst-case
  // RiskLevel. Keeping both around invites the two to drift out of sync,
  // so this one is gone — use RouteSafetyService for anything route-level.

  // ---- grid ----

  static List<LatLng> _buildGrid(LatLng center) {
    final points = <LatLng>[];
    final half = (_gridSize - 1) / 2;
    for (var row = 0; row < _gridSize; row++) {
      for (var col = 0; col < _gridSize; col++) {
        final dRow = (row - half) * _cellSpanMeters;
        final dCol = (col - half) * _cellSpanMeters;
        points.add(_offsetMeters(center, dRow, dCol));
      }
    }
    return points;
  }

  static LatLng _offsetMeters(
    LatLng origin,
    double dNorthMeters,
    double dEastMeters,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (dNorthMeters / earthRadius) * (180 / math.pi);
    final dLng =
        (dEastMeters /
            (earthRadius * math.cos(origin.latitude * math.pi / 180))) *
        (180 / math.pi);
    return LatLng(origin.latitude + dLat, origin.longitude + dLng);
  }

  static int _countWithin(
    List<LatLng> points,
    LatLng center,
    double radiusMeters,
  ) {
    var count = 0;
    for (final p in points) {
      if (LocationService.distanceKm(center, p) * 1000 <= radiusMeters) count++;
    }
    return count;
  }

  static List<_Incident> _incidentsWithin(
    List<_Incident> incidents,
    LatLng center,
    double radiusMeters,
  ) {
    return incidents
        .where(
          (i) =>
              LocationService.distanceKm(center, i.location) * 1000 <=
              radiusMeters,
        )
        .toList();
  }

  // ---- scoring ----

  static double _scoreCell({
    required int lampCount,
    required int activityCount,
    required List<_Incident> incidentHits,
    required DateTime now,
    required bool isNight,
  }) {
    var score = 100.0;

    if (isNight) {
      score -= lampCount == 0 ? 30 : math.max(0, 15 - lampCount * 3);
    } else {
      score -= lampCount == 0 ? 8 : 0;
    }

    if (activityCount == 0) {
      score -= isNight ? 18 : 10;
    } else {
      score -= math.max(0, 6 - activityCount);
    }

    for (final incident in incidentHits) {
      final ageDays = now.difference(incident.reportedAt).inHours / 24;
      final recencyWeight = ageDays <= 7
          ? 1.0
          : ageDays <= 30
          ? 0.6
          : 0.3;
      score -= 20 * recencyWeight;
    }

    // num.clamp() returns num even on a double receiver, so this needs an
    // explicit toDouble() or the function's declared `double` return type
    // won't typecheck.
    return score.clamp(0, 100).toDouble();
  }

  static RiskLevel levelForScore(double score) {
    if (score >= 70) return RiskLevel.safe;
    if (score >= 45) return RiskLevel.moderate;
    return RiskLevel.high;
  }

  // ---- Overpass (lighting + activity) ----

  static Future<_OverpassFeatures> _fetchOverpassFeatures(LatLng center) async {
    final radius = _overpassFetchRadiusMeters.round();
    final query =
        '[out:json][timeout:12];('
        'node["highway"="street_lamp"](around:$radius,${center.latitude},${center.longitude});'
        'node["amenity"~"cafe|restaurant|fast_food|pharmacy|bar|pub|bank|atm"]'
        '(around:$radius,${center.latitude},${center.longitude});'
        'node["shop"](around:$radius,${center.latitude},${center.longitude});'
        ');out center 400;';

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

    final lamps = <LatLng>[];
    final activity = <LatLng>[];
    for (final e in elements) {
      final lat = (e['lat'] as num?)?.toDouble();
      final lon = (e['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final point = LatLng(lat, lon);
      final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
      if (tags['highway'] == 'street_lamp') {
        lamps.add(point);
      } else {
        activity.add(point);
      }
    }
    return _OverpassFeatures(lamps: lamps, activity: activity);
  }

  // ---- Firestore (community incident reports) ----

  /// Expects documents shaped like the shared schema in the project
  /// README's "Suggested shared backend schema" section:
  ///   incidents/{id}: { location: GeoPoint, reportedAt/createdAt: Timestamp, type: String, ... }
  /// Module 9's Report screen is the intended writer of this collection;
  /// until it's wired up this simply returns an empty list, which is fine
  /// — the score just falls back to lighting + activity + time-of-day.
  static Future<List<_Incident>> _fetchRecentIncidents(
    LatLng center,
    DateTime now,
  ) async {
    final cutoff = now.subtract(const Duration(days: 30));
    final snapshot = await FirebaseFirestore.instance
        .collection('incidents')
        .orderBy('reportedAt', descending: true)
        .limit(200)
        .get()
        .timeout(const Duration(seconds: 8));

    final incidents = <_Incident>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final geo = data['location'];
      if (geo is! GeoPoint) continue;
      final reportedAt =
          (data['reportedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate();
      if (reportedAt == null || reportedAt.isBefore(cutoff)) continue;
      incidents.add(
        _Incident(
          location: LatLng(geo.latitude, geo.longitude),
          reportedAt: reportedAt,
        ),
      );
    }
    return incidents;
  }
}

class _OverpassFeatures {
  const _OverpassFeatures({required this.lamps, required this.activity});
  final List<LatLng> lamps;
  final List<LatLng> activity;
}

class _Incident {
  const _Incident({required this.location, required this.reportedAt});
  final LatLng location;
  final DateTime reportedAt;
}
