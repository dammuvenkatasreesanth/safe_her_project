enum MotionEvent { fall, suddenStop, running }

/// Pure accelerometer-magnitude classifier — the exact detection thresholds
/// and state machine BehaviorMonitorScreen drives its UI from, split out so
/// they're unit-testable without a device. Feed it one magnitude+timestamp
/// per sensor sample via [onSample].
class MotionClassifier {
  // Raw accelerometer magnitude includes gravity (~9.8 m/s^2 at rest).
  static const freefallThreshold = 3.0; // near-weightless dip
  static const impactThreshold = 25.0; // hard spike right after a dip
  static const freefallWindow = Duration(milliseconds: 800);
  static const runningThreshold = 16.0;
  static const runningSustainSamples = 6;
  static const suddenStopDelta = 12.0;

  double? _lastMagnitude;
  DateTime? _freefallStartedAt;
  int _highMagnitudeStreak = 0;

  void reset() {
    _lastMagnitude = null;
    _freefallStartedAt = null;
    _highMagnitudeStreak = 0;
  }

  /// Feeds one accelerometer sample in and returns whichever events it
  /// triggers. A fall short-circuits the rest of that sample's checks
  /// (matches the original inline logic); sudden-stop and running are
  /// otherwise independent and can both fire on the same sample.
  List<MotionEvent> onSample(double magnitude, DateTime now) {
    // Fall pattern: a brief near-weightless dip (device in free fall)
    // followed shortly by a hard impact spike.
    if (magnitude < freefallThreshold) {
      _freefallStartedAt ??= now;
    } else {
      if (_freefallStartedAt != null &&
          now.difference(_freefallStartedAt!) < freefallWindow &&
          magnitude > impactThreshold) {
        _freefallStartedAt = null;
        _lastMagnitude = magnitude;
        return const [MotionEvent.fall];
      }
      if (_freefallStartedAt != null && now.difference(_freefallStartedAt!) >= freefallWindow) {
        _freefallStartedAt = null;
      }
    }

    final events = <MotionEvent>[];

    // Sudden stop: sharp deceleration from an already-elevated magnitude.
    if (_lastMagnitude != null) {
      final delta = _lastMagnitude! - magnitude;
      if (_lastMagnitude! > runningThreshold && delta > suddenStopDelta) {
        events.add(MotionEvent.suddenStop);
      }
    }

    // Running: sustained high magnitude over several consecutive samples.
    if (magnitude > runningThreshold) {
      _highMagnitudeStreak++;
      if (_highMagnitudeStreak == runningSustainSamples) {
        events.add(MotionEvent.running);
      }
    } else {
      _highMagnitudeStreak = 0;
    }

    _lastMagnitude = magnitude;
    return events;
  }
}
