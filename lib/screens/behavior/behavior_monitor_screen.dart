import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/motion_classifier.dart';
import '../../theme/app_theme.dart';
import '../../widgets/screen_header.dart';

enum _Severity { ok, warning, severe }

enum _MotionStatus { normal, running, suddenStop, fall }

class _ActivityEntry {
  _ActivityEntry({required this.label, required this.time, required this.severity});
  final String label;
  final DateTime time;
  final _Severity severity;
}

/// Module 6 — real accelerometer-based motion analysis. Classifies the
/// device's raw accelerometer stream into running, sudden-stop, and
/// free-fall-then-impact (possible fall) patterns; no cloud/ML model, just
/// magnitude thresholds on-device, matching the shake-to-trigger pattern
/// already used in sos_screen.dart.
class BehaviorMonitorScreen extends StatefulWidget {
  const BehaviorMonitorScreen({super.key});

  @override
  State<BehaviorMonitorScreen> createState() => _BehaviorMonitorScreenState();
}

class _BehaviorMonitorScreenState extends State<BehaviorMonitorScreen> {
  bool _enabled = true;
  _MotionStatus _status = _MotionStatus.normal;
  final List<_ActivityEntry> _log = [];

  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _statusResetTimer;

  final _classifier = MotionClassifier();
  DateTime? _lastLoggedAt;
  _MotionStatus? _lastLoggedStatus;

  static const _logCooldown = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (_enabled) _startMonitoring();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusResetTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    if (kIsWeb) return; // accelerometer isn't reliably available in browsers
    _log.insert(
      0,
      _ActivityEntry(label: 'Monitoring started', time: DateTime.now(), severity: _Severity.ok),
    );
    _sub = accelerometerEventStream().listen(_onEvent);
  }

  void _stopMonitoring() {
    _sub?.cancel();
    _sub = null;
    _statusResetTimer?.cancel();
    _classifier.reset();
    _status = _MotionStatus.normal;
  }

  void _onEvent(AccelerometerEvent event) {
    final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();
    for (final motionEvent in _classifier.onSample(magnitude, now)) {
      switch (motionEvent) {
        case MotionEvent.fall:
          _recordEvent(_MotionStatus.fall, 'Possible fall detected', _Severity.severe);
        case MotionEvent.suddenStop:
          _recordEvent(_MotionStatus.suddenStop, 'Sudden stop detected', _Severity.warning);
        case MotionEvent.running:
          _recordEvent(_MotionStatus.running, 'Running detected', _Severity.warning);
      }
    }
  }

  void _recordEvent(_MotionStatus status, String label, _Severity severity) {
    final now = DateTime.now();
    // Collapse rapid repeats of the *same* classification into one entry —
    // keyed on status, not time alone, so a real running-then-sudden-stop
    // sequence still logs both halves instead of the second being eaten by
    // the first event's cooldown window.
    if (status == _lastLoggedStatus &&
        _lastLoggedAt != null &&
        now.difference(_lastLoggedAt!) < _logCooldown) {
      return;
    }
    _lastLoggedStatus = status;
    _lastLoggedAt = now;
    if (!mounted) return;
    setState(() {
      _status = status;
      _log.insert(0, _ActivityEntry(label: label, time: now, severity: severity));
      if (_log.length > 20) _log.removeRange(20, _log.length);
    });
    _statusResetTimer?.cancel();
    _statusResetTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _status = _MotionStatus.normal);
    });
  }

  void _setEnabled(bool v) {
    setState(() => _enabled = v);
    if (v) {
      _startMonitoring();
    } else {
      _stopMonitoring();
    }
  }

  (Color, String) get _statusDisplay => switch (_status) {
    _MotionStatus.normal => (const Color(0xFF16A34A), 'Live status: Normal'),
    _MotionStatus.running => (const Color(0xFFF59E0B), 'Live status: Running detected'),
    _MotionStatus.suddenStop => (const Color(0xFFF59E0B), 'Live status: Sudden stop'),
    _MotionStatus.fall => (const Color(0xFFDC2626), 'Live status: Possible fall'),
  };

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusDisplay;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Behavior Monitor'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (_enabled ? AppColors.primary : AppColors.neutral400).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.directions_walk_rounded,
                        size: 20,
                        color: _enabled ? AppColors.primary : AppColors.neutral400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Anomaly Detection', style: AppTextStyles.semibold16),
                          Text(
                            _enabled ? 'Watching for running, sudden stops & falls' : 'Monitoring paused',
                            style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: _setEnabled,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_enabled) ...[
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(statusLabel, style: AppTextStyles.semibold16.copyWith(color: statusColor)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Recent activity', style: AppTextStyles.b2),
                const SizedBox(height: 10),
                if (_log.isEmpty)
                  Text(
                    'No activity yet. Walk around or shake the device to see live detection.',
                    style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
                  )
                else
                  for (final entry in _log)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.neutral300),
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            switch (entry.severity) {
                              _Severity.ok => Icons.check_circle_outline_rounded,
                              _Severity.warning => Icons.warning_amber_rounded,
                              _Severity.severe => Icons.error_outline_rounded,
                            },
                            size: 18,
                            color: switch (entry.severity) {
                              _Severity.ok => const Color(0xFF16A34A),
                              _Severity.warning => const Color(0xFFF59E0B),
                              _Severity.severe => const Color(0xFFDC2626),
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(entry.label, style: AppTextStyles.b3)),
                          Text(
                            _relativeTime(entry.time),
                            style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
