import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_her/services/geofence_service.dart';

void main() {
  group('GeofenceEvaluator.hasExitedZone', () {
    // Bengaluru city-center-ish coordinates — real lat/lng so the Haversine
    // math is exercised the same way it would be in the app.
    const center = LatLng(12.9716, 77.5946);

    test('a point well inside the radius has not exited', () {
      // ~11m north — inside any reasonable safe-zone radius.
      const nearby = LatLng(12.9717, 77.5946);
      expect(
        GeofenceEvaluator.hasExitedZone(center: center, current: nearby, radiusMeters: 500),
        isFalse,
      );
    });

    test('a point clearly outside the radius has exited', () {
      // ~1.1km north — well past a 500m zone.
      const far = LatLng(12.981, 77.5946);
      expect(
        GeofenceEvaluator.hasExitedZone(center: center, current: far, radiusMeters: 500),
        isTrue,
      );
    });

    test('the center itself is never outside its own zone', () {
      expect(
        GeofenceEvaluator.hasExitedZone(center: center, current: center, radiusMeters: 500),
        isFalse,
      );
    });

    test('a smaller radius breaches sooner than a larger one for the same points', () {
      const point = LatLng(12.978, 77.5946); // ~700m north of center
      expect(
        GeofenceEvaluator.hasExitedZone(center: center, current: point, radiusMeters: 500),
        isTrue,
      );
      expect(
        GeofenceEvaluator.hasExitedZone(center: center, current: point, radiusMeters: 2000),
        isFalse,
      );
    });
  });

  group('GeofenceEvaluator.hasArrived', () {
    const home = LatLng(12.9716, 77.5946);

    test('standing at home counts as arrived', () {
      expect(GeofenceEvaluator.hasArrived(home: home, current: home), isTrue);
    });

    test('100m away counts as arrived (inside the default 150m radius)', () {
      const nearby = LatLng(12.9725, 77.5946); // ~100m north
      expect(GeofenceEvaluator.hasArrived(home: home, current: nearby), isTrue);
    });

    test('1km away does not count as arrived', () {
      const far = LatLng(12.981, 77.5946);
      expect(GeofenceEvaluator.hasArrived(home: home, current: far), isFalse);
    });

    test('a custom radius is respected', () {
      const point = LatLng(12.9726, 77.5946); // ~110m north
      expect(
        GeofenceEvaluator.hasArrived(home: home, current: point, radiusMeters: 50),
        isFalse,
      );
      expect(
        GeofenceEvaluator.hasArrived(home: home, current: point, radiusMeters: 200),
        isTrue,
      );
    });
  });
}
