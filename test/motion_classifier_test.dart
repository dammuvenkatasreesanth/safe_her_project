import 'package:flutter_test/flutter_test.dart';
import 'package:safe_her/services/motion_classifier.dart';

void main() {
  group('MotionClassifier', () {
    late MotionClassifier classifier;
    late DateTime t;

    setUp(() {
      classifier = MotionClassifier();
      t = DateTime(2026, 1, 1, 12, 0, 0);
    });

    test('resting magnitude produces no events', () {
      for (var i = 0; i < 10; i++) {
        final events = classifier.onSample(9.8, t.add(Duration(milliseconds: i * 100)));
        expect(events, isEmpty);
      }
    });

    test('free-fall dip followed by an impact spike within the window fires fall', () {
      // Device at rest, then dropped (near-zero magnitude), then hits the
      // ground (a hard spike) well inside the 800ms free-fall window.
      expect(classifier.onSample(9.8, t), isEmpty);
      expect(classifier.onSample(1.5, t.add(const Duration(milliseconds: 100))), isEmpty);
      final events = classifier.onSample(30.0, t.add(const Duration(milliseconds: 400)));
      expect(events, [MotionEvent.fall]);
    });

    test('an impact spike arriving after the free-fall window does not fire fall', () {
      expect(classifier.onSample(9.8, t), isEmpty);
      expect(classifier.onSample(1.5, t.add(const Duration(milliseconds: 100))), isEmpty);
      // 900ms later — past the 800ms window, so this is just a separate spike.
      final events = classifier.onSample(30.0, t.add(const Duration(milliseconds: 1000)));
      expect(events, isNot(contains(MotionEvent.fall)));
    });

    test('a dip that never spikes produces no fall', () {
      expect(classifier.onSample(9.8, t), isEmpty);
      expect(classifier.onSample(1.5, t.add(const Duration(milliseconds: 100))), isEmpty);
      final events = classifier.onSample(9.5, t.add(const Duration(milliseconds: 300)));
      expect(events, isEmpty);
    });

    test('sustained high magnitude for 6 samples fires running exactly once', () {
      var time = t;
      List<MotionEvent> lastEvents = const [];
      for (var i = 0; i < 6; i++) {
        lastEvents = classifier.onSample(18.0, time);
        time = time.add(const Duration(milliseconds: 200));
        if (i < 5) expect(lastEvents, isNot(contains(MotionEvent.running)));
      }
      expect(lastEvents, contains(MotionEvent.running));

      // Streak already consumed — staying elevated shouldn't refire running
      // on every subsequent sample.
      final again = classifier.onSample(18.0, time);
      expect(again, isNot(contains(MotionEvent.running)));
    });

    test('dropping below the running threshold resets the streak', () {
      var time = t;
      for (var i = 0; i < 5; i++) {
        classifier.onSample(18.0, time);
        time = time.add(const Duration(milliseconds: 200));
      }
      // Streak of 5 so far — one low sample should reset it.
      classifier.onSample(5.0, time);
      time = time.add(const Duration(milliseconds: 200));

      final events = classifier.onSample(18.0, time);
      expect(events, isNot(contains(MotionEvent.running)));
    });

    test('a sharp drop from a high magnitude fires sudden stop', () {
      classifier.onSample(20.0, t);
      final events = classifier.onSample(5.0, t.add(const Duration(milliseconds: 200)));
      expect(events, contains(MotionEvent.suddenStop));
    });

    test('a small drop from a high magnitude does not fire sudden stop', () {
      classifier.onSample(20.0, t);
      final events = classifier.onSample(17.0, t.add(const Duration(milliseconds: 200)));
      expect(events, isNot(contains(MotionEvent.suddenStop)));
    });

    test('reset clears streak/free-fall/last-magnitude state', () {
      classifier.onSample(1.0, t); // start a free-fall window
      for (var i = 0; i < 5; i++) {
        classifier.onSample(18.0, t.add(Duration(milliseconds: 100 * i)));
      }
      classifier.reset();

      // A post-reset spike shouldn't be treated as landing an old free-fall.
      final events = classifier.onSample(30.0, t.add(const Duration(milliseconds: 150)));
      expect(events, isEmpty);
    });
  });
}
