import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../models/contact.dart';
import '../../services/contacts_service.dart';
import '../../services/evidence_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/incident_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';
import '../evidence/evidence_screen.dart';

enum _SosState { idle, countingDown, sent }

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.autoTrigger = false});

  /// True when this screen was opened by Voice Command hearing a trigger
  /// phrase — starts the countdown immediately instead of waiting for a
  /// hold/shake, same end state either way.
  final bool autoTrigger;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  _SosState _state = _SosState.idle;
  int _count = 3;
  Timer? _timer;
  LatLng? _location;
  String? _locationLabel;

  StreamSubscription<AccelerometerEvent>? _shakeSub;
  DateTime? _lastShakePulse;
  static const _shakeThreshold = 22.0;
  static const _shakeWindow = Duration(milliseconds: 1400);

  // Instance-level and re-read on every screen open (not `static final`,
  // which would freeze this at whatever ContactsService had cached the
  // very first time this screen was ever built — often an empty list if
  // opened before Module 2's startup sync finishes).
  late List<Contact> _contacts = ContactsService.contacts;

  @override
  void initState() {
    super.initState();
    _contacts = ContactsService.contacts;
    LocationService.getCurrentLocation().then((loc) async {
      if (!mounted) return;
      setState(() => _location = loc);
      final label = await GeocodingService.reverse(loc);
      if (mounted) setState(() => _locationLabel = label);
    });
    _listenForShake();
    if (widget.autoTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
    }
  }

  void _listenForShake() {
    if (kIsWeb) return; // accelerometer isn't reliably available in browsers
    _shakeSub = accelerometerEventStream().listen((event) {
      if (_state != _SosState.idle) return;
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (magnitude < _shakeThreshold) return;
      final now = DateTime.now();
      if (_lastShakePulse != null &&
          now.difference(_lastShakePulse!) <= _shakeWindow) {
        _lastShakePulse = null;
        HapticFeedback.heavyImpact();
        _startCountdown();
      } else {
        _lastShakePulse = now;
      }
    });
  }

  void _startCountdown() {
    if (_state != _SosState.idle) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _state = _SosState.countingDown;
      _count = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count == 1) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _state = _SosState.sent);
        // Fire-and-forget: log to History (Module 9) without blocking the
        // UI on network — the alert is already visually "sent" from the
        // user's point of view.
        IncidentService.submitSos(
          contactNames: _contacts.map((c) => c.name).toList(),
          locationLabel: _locationLabel,
          locationLatLng: _location,
        ).then((id) {
          // The user may have already tapped "I'm Safe Now" while this
          // Firestore write was in flight — don't start a recording nobody
          // will ever stop.
          if (!mounted || _state != _SosState.sent) return Future.value(false);
          return EvidenceService.startRecording(incidentId: id);
        }).catchError((_) => false);
      } else {
        HapticFeedback.lightImpact();
        setState(() => _count--);
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (_state == _SosState.sent) {
      // A recording only exists once the alert actually went out — a
      // cancelled countdown never started one.
      EvidenceService.stopRecording().catchError((_) => null);
    }
    setState(() => _state = _SosState.idle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'SOS Alert'),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: switch (_state) {
                    _SosState.idle => _IdleView(
                      key: const ValueKey('idle'),
                      onTrigger: _startCountdown,
                      contacts: _contacts,
                      location: _location,
                      shakeEnabled: !kIsWeb,
                    ),
                    _SosState.countingDown => _CountdownView(
                      key: const ValueKey('countdown'),
                      count: _count,
                      onCancel: _cancel,
                    ),
                    _SosState.sent => _SentView(
                      key: const ValueKey('sent'),
                      contacts: _contacts,
                      location: _location,
                      onCancel: _cancel,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleView extends StatefulWidget {
  const _IdleView({
    super.key,
    required this.onTrigger,
    required this.contacts,
    required this.location,
    required this.shakeEnabled,
  });

  final VoidCallback onTrigger;
  final List<Contact> contacts;
  final LatLng? location;
  final bool shakeEnabled;

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> with TickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();
  late final _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _hapticTicker;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hapticTicker?.cancel();
        widget.onTrigger();
      }
    });
  }

  void _pressStart() {
    HapticFeedback.selectionClick();
    _hold.forward();
    _hapticTicker = Timer.periodic(
      const Duration(milliseconds: 140),
      (_) => HapticFeedback.selectionClick(),
    );
  }

  void _pressEnd() {
    _hapticTicker?.cancel();
    if (_hold.value < 1.0) _hold.reverse();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _hold.dispose();
    _hapticTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.contacts;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatusChip(
                  icon: Icons.location_on_rounded,
                  label: widget.location == null
                      ? 'Locating...'
                      : 'Location Ready',
                  ok: widget.location != null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  icon: Icons.people_alt_rounded,
                  label: '${contacts.length} Contacts Ready',
                  ok: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r5),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: widget.location == null
                  ? Container(color: AppColors.fieldFill)
                  : AppMap(
                      center: widget.location!,
                      zoom: 14,
                      interactive: false,
                      markers: [youAreHereMarker(widget.location!, size: 32)],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => _PulseRing(progress: _pulse.value),
                ),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) =>
                      _PulseRing(progress: (_pulse.value + 0.5) % 1),
                ),
                GestureDetector(
                  onTapDown: (_) => _pressStart(),
                  onTapUp: (_) => _pressEnd(),
                  onTapCancel: _pressEnd,
                  child: AnimatedBuilder(
                    animation: _hold,
                    builder: (context, child) {
                      final scale = 1 + _hold.value * 0.04;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SizedBox(
                      width: 210,
                      height: 210,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _hold,
                            builder: (context, _) => SizedBox(
                              width: 210,
                              height: 210,
                              child: CircularProgressIndicator(
                                value: _hold.value,
                                strokeWidth: 5,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 194,
                            height: 194,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'HOLD FOR SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Press and hold, or shake your phone twice.\nWe alert your contacts with your live location.',
            textAlign: TextAlign.center,
            style: AppTextStyles.b3,
          ),
          const SizedBox(height: 16),
          if (widget.shakeEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.vibration_rounded,
                    size: 16,
                    color: AppColors.neutral400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Shake detection is armed',
                    style: AppTextStyles.b5.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Will notify',
            style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in contacts) _ContactChip(name: c.name)],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: ok ? AppColors.primary : AppColors.neutral400,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.b5,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = 210 + progress * 40;
    return Opacity(
      opacity: (1 - progress).clamp(0, 1) * 0.5,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _CountdownView extends StatelessWidget {
  const _CountdownView({
    super.key,
    required this.count,
    required this.onCancel,
  });

  final int count;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(count),
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(seconds: 1),
                curve: Curves.linear,
                builder: (context, value, _) => SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: (count - 1 + value) / 3,
                    strokeWidth: 6,
                    backgroundColor: AppColors.neutral200,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey('scale$count'),
                tween: Tween(begin: 1.3, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  '$count',
                  style: AppTextStyles.h5.copyWith(fontSize: 72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Sending SOS alert...', style: AppTextStyles.b1),
        const SizedBox(height: 6),
        Text(
          'Tap Cancel if this was a mistake',
          style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
        ),
        const Spacer(),
        PrimaryButton(label: 'Cancel', outlined: true, onPressed: onCancel),
      ],
    );
  }
}

class _SentView extends StatefulWidget {
  const _SentView({
    super.key,
    required this.contacts,
    required this.location,
    required this.onCancel,
  });

  final List<Contact> contacts;
  final LatLng? location;
  final VoidCallback onCancel;

  @override
  State<_SentView> createState() => _SentViewState();
}

class _SentViewState extends State<_SentView>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  bool _showSms = false;
  bool _weakConnection = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    _checkSmsFallback();
  }

  Future<void> _checkSmsFallback() async {
    final enabled = await SettingsService.getSmsFallback();
    final noConnection = await ShareService.hasNoConnection();
    if (!mounted) return;
    setState(() {
      _showSms = enabled;
      _weakConnection = noConnection;
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _clock?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert Active',
                      style: AppTextStyles.h5.copyWith(fontSize: 22),
                    ),
                    Text(
                      'Active for $_elapsedLabel',
                      style: AppTextStyles.b4.copyWith(
                        color: AppColors.neutral400,
                      ),
                    ),
                  ],
                ),
              ),
              const _RecordingBadge(),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r5),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: widget.location == null
                  ? Container(color: AppColors.fieldFill)
                  : AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => AppMap(
                        center: widget.location!,
                        zoom: 15,
                        interactive: false,
                        circles: [
                          CircleMarker(
                            point: widget.location!,
                            radius: 60 + _pulse.value * 80,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(
                              alpha: (1 - _pulse.value) * 0.18,
                            ),
                            borderColor: AppColors.primary.withValues(
                              alpha: (1 - _pulse.value) * 0.4,
                            ),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                        markers: [youAreHereMarker(widget.location!)],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_weakConnection) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(AppRadius.r4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.signal_cellular_connected_no_internet_0_bar_rounded,
                    size: 16,
                    color: Color(0xFF92400E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showSms
                          ? "No data connection — use Send SMS below, it doesn't need one."
                          : 'No data connection. Turn on SMS Fallback in Accessibility settings to alert contacts without data.',
                      style: AppTextStyles.b5.copyWith(color: const Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your live location was shared with:',
              style: AppTextStyles.b3,
            ),
          ),
          const SizedBox(height: 10),
          for (final contact in widget.contacts)
            _DeliveryTile(
              contact: contact,
              location: widget.location,
              showSms: _showSms,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: _EmergencyCallButton(label: 'Police', number: '100'),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: _EmergencyCallButton(label: 'Ambulance', number: '108'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: "I'm Safe Now",
            outlined: true,
            onPressed: widget.onCancel,
          ),
        ],
      ),
    );
  }
}

class _RecordingBadge extends StatefulWidget {
  const _RecordingBadge();

  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge>
    with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EvidenceScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _blink,
              child: const CircleAvatar(
                radius: 4,
                backgroundColor: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'REC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryTile extends StatefulWidget {
  const _DeliveryTile({
    required this.contact,
    required this.location,
    required this.showSms,
  });

  final Contact contact;
  final LatLng? location;

  /// Whether to also offer the SMS-fallback action — true when the "SMS
  /// Fallback" setting is on and/or the device currently has no data
  /// connection, so WhatsApp delivery can't be relied on.
  final bool showSms;

  @override
  State<_DeliveryTile> createState() => _DeliveryTileState();
}

class _DeliveryTileState extends State<_DeliveryTile> {
  bool _calling = false;
  bool _whatsAppOpened = false;
  bool _whatsAppSending = false;
  bool _smsOpened = false;
  bool _smsSending = false;

  String get _message => ShareService.buildLocationMessage(
    widget.location!,
    note: 'SOS! I need help.',
  );

  Future<void> _call() async {
    if (_calling) return;
    setState(() => _calling = true);
    final ok = await ShareService.callNumber(widget.contact.phone);
    if (!mounted) return;
    setState(() => _calling = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the phone dialer.")),
      );
    }
  }

  Future<void> _openWhatsApp() async {
    if (widget.location == null || _whatsAppSending) return;
    setState(() => _whatsAppSending = true);
    final ok = await ShareService.openWhatsApp(widget.contact.phone, _message);
    if (!mounted) return;
    setState(() {
      _whatsAppSending = false;
      if (ok) _whatsAppOpened = true;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open WhatsApp")),
      );
    }
  }

  Future<void> _sendSms() async {
    if (widget.location == null || _smsSending) return;
    setState(() => _smsSending = true);
    final ok = await ShareService.sendSms(widget.contact.phone, _message);
    if (!mounted) return;
    setState(() {
      _smsSending = false;
      if (ok) _smsOpened = true;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the SMS app")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.contact.name,
                  style: AppTextStyles.semibold16,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _calling ? null : _call,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _calling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.call_rounded, color: Colors.white, size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Spacer(),
              _DeliveryAction(
                opened: _whatsAppOpened,
                sending: _whatsAppSending,
                openedLabel: 'Opened in WhatsApp',
                actionLabel: 'Open in WhatsApp',
                icon: Icons.chat_bubble_rounded,
                onPressed: _openWhatsApp,
              ),
            ],
          ),
          if (widget.showSms) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Spacer(),
                _DeliveryAction(
                  opened: _smsOpened,
                  sending: _smsSending,
                  openedLabel: 'Sent via SMS',
                  actionLabel: 'Send SMS',
                  icon: Icons.sms_rounded,
                  onPressed: _sendSms,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryAction extends StatelessWidget {
  const _DeliveryAction({
    required this.opened,
    required this.sending,
    required this.openedLabel,
    required this.actionLabel,
    required this.icon,
    required this.onPressed,
  });

  final bool opened;
  final bool sending;
  final String openedLabel;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: opened
          ? Row(
              key: const ValueKey('opened'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  openedLabel,
                  style: AppTextStyles.b5.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            )
          : sending
          ? const SizedBox(
              key: ValueKey('sending'),
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.neutral400,
              ),
            )
          : TextButton.icon(
              key: const ValueKey('open'),
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(actionLabel),
            ),
    );
  }
}

class _EmergencyCallButton extends StatelessWidget {
  const _EmergencyCallButton({required this.label, required this.number});

  final String label;
  final String number;

  Future<void> _call(BuildContext context) async {
    final ok = await ShareService.callNumber(number);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the phone dialer.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.r4),
      onTap: () => _call(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300),
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Column(
          children: [
            const Icon(Icons.call_rounded, size: 20),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.semibold16),
            Text(number, style: AppTextStyles.b5),
          ],
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(name, style: AppTextStyles.b4),
    );
  }
}
