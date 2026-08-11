import 'package:flutter_test/flutter_test.dart';
import 'package:safe_her/services/safety_score_service.dart';

void main() {
  group('SafetyScoreService.levelForCounts', () {
    test('lots of police and lighting scores safe in daytime', () {
      // 3 police (*3=9) + 2 lamps = 11 >= 8
      expect(
        SafetyScoreService.levelForCounts(3, 2, isNight: false),
        RiskLevel.safe,
      );
    });

    test('nothing nearby scores high risk regardless of time of day', () {
      expect(SafetyScoreService.levelForCounts(0, 0, isNight: false), RiskLevel.high);
      expect(SafetyScoreService.levelForCounts(0, 0, isNight: true), RiskLevel.high);
    });

    test('a middling score lands in moderate', () {
      // 1 police (*3=3) + 0 lamps = 3, right at the moderate floor
      expect(
        SafetyScoreService.levelForCounts(1, 0, isNight: false),
        RiskLevel.moderate,
      );
    });

    test('night discount can push a daytime-safe score down to moderate', () {
      // 1 police (*3=3) + 5 lamps = 8 -> safe by day
      expect(
        SafetyScoreService.levelForCounts(1, 5, isNight: false),
        RiskLevel.safe,
      );
      // Same counts at night: (8 * 0.6).round() = 5 -> moderate
      expect(
        SafetyScoreService.levelForCounts(1, 5, isNight: true),
        RiskLevel.moderate,
      );
    });

    test('the unknown-mirrors-failed fallback (1 police, 4 lamps) is moderate, not high', () {
      // SafetyScoreService._fetchCounts falls back to (1, 4) when every
      // Overpass mirror fails — this must not read as "high risk", since
      // that's a false signal, not an actual unsafe reading.
      expect(
        SafetyScoreService.levelForCounts(1, 4, isNight: false),
        RiskLevel.moderate,
      );
    });
  });
}
