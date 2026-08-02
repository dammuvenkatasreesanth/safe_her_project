import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/contact.dart';
import '../../services/location_service.dart';
import '../../services/share_service.dart';
import '../../services/tracking_service.dart';
import '../../services/contacts_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/contact_whatsapp_tile.dart';
import '../../widgets/primary_button.dart';
import 'start_journey_sheet.dart';

enum _TrackingMode { idle, sharingOnly, onJourney }

class LiveTrackingTab extends StatefulWidget {
  const LiveTrackingTab({super.key});

  @override
  State<LiveTrackingTab> createState() => LiveTrackingTabState();
}

class LiveTrackingTabState extends State<LiveTrackingTab> {
  _TrackingMode _mode = _TrackingMode.idle;
  bool _geofenceEnabled = false;
  double _geofenceRadius = 500;
  LatLng? _location;
  double _speedKmh = 0;
  JourneyPlan? _journey;
  String? _sessionId;
  List<String> _sharedWithUserIds = [];
  StreamSubscription? _locationStream;

  @override
  void initState() {
    super.initState();
    LocationService.getCurrentLocation().then((loc) {
      if (mounted) setState(() => _location = loc);
    });
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    super.dispose();
  }

  Future<void> _startJourney() async {
    if (_location == null) return;
    final plan = await showStartJourneySheet(context, _location!);
    if (plan != null && mounted) {
      final sid = await TrackingService.startSession(
        ownerId: 'user_123', // TODO: Pull from Auth
        ownerName: 'Ananya Sharma', // TODO: Pull from Auth
        destinationLabel: plan.toLabel,
        destinationLatLng: plan.to,
        vehicleNumber: plan.vehicleNumber,
        etaMinutes: plan.etaMinutes,
      );
      final registeredIds = await _shareWithRegisteredContacts(sid);

      setState(() {
        _journey = plan;
        _sessionId = sid;
        _sharedWithUserIds = registeredIds;
        _mode = _TrackingMode.onJourney;
      });

      _startLocationStreaming();
    }
  }

  /// Auto-shares a newly created session with every contact who has a
  /// SafeHer account (a "registered" contact) — the user shouldn't have
  /// to manually pick these every time; "Share With More Contacts" is
  /// for anyone beyond this default set.
  Future<List<String>> _shareWithRegisteredContacts(String sessionId) async {
    final registeredIds = ContactsService.getInAppContacts()
        .map((c) => c.userId!)
        .toList();
    if (registeredIds.isNotEmpty) {
      await TrackingService.shareWithUsers(sessionId, registeredIds);
    }
    return registeredIds;
  }

  void _startLocationStreaming() {
    _locationStream?.cancel();
    _locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 50, // Update every 50 meters
          ),
        ).listen((pos) {
          final loc = LatLng(pos.latitude, pos.longitude);
          // Position.speed is m/s from the GPS hardware; convert to km/h and
          // guard against the occasional negative/NaN reading at low signal.
          final speed = pos.speed.isFinite && pos.speed > 0
              ? pos.speed * 3.6
              : 0.0;
          if (mounted) {
            setState(() {
              _location = loc;
              _speedKmh = speed;
            });
          }
          if (_sessionId != null) {
            TrackingService.updateLocation(_sessionId!, loc);
          }
        });
  }

  /// Starts sharing the current location, same as tapping "Share Your
  /// Location" on this tab — exposed publicly so the Home tab's button
  /// can trigger it after switching to this tab. No-ops if a session
  /// (sharing or journey) is already active.
  Future<void> startSharingLocation() async {
    if (_mode != _TrackingMode.idle) return;
    await _shareOnly();
  }

  Future<void> _shareOnly() async {
    if (_location == null) return;
    final sid = await TrackingService.startSession(
      ownerId: 'user_123', // TODO: Pull from Auth
      ownerName: 'Ananya Sharma', // TODO: Pull from Auth
      destinationLabel: 'Current Location',
      destinationLatLng: _location!,
    );
    final registeredIds = await _shareWithRegisteredContacts(sid);

    setState(() {
      _sessionId = sid;
      _sharedWithUserIds = registeredIds;
      _mode = _TrackingMode.sharingOnly;
    });

    _startLocationStreaming();
  }

  Future<void> _stop() async {
    if (_sessionId != null) {
      await TrackingService.endSession(_sessionId!);
    }
    _locationStream?.cancel();
    setState(() {
      _mode = _TrackingMode.idle;
      _journey = null;
      _sessionId = null;
      _sharedWithUserIds = [];
    });
  }

  String _buildShareMessage() {
    if (_journey != null && _sessionId != null) {
      return ShareService.buildTripMessage(
        destination: _journey!.toLabel,
        vehicleNumber: _journey!.vehicleNumber,
        sessionId: _sessionId!,
      );
    }
    return ShareService.buildLocationMessage(_location!);
  }

  Future<void> _openShareSheet() async {
    final contacts = ContactsService.getInAppContacts();
    final selectedIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
      ),
      builder: (context) => _ShareTripSheet(
        contacts: contacts,
        allContacts: ContactsService.contacts,
        alreadySharedIds: _sharedWithUserIds,
        message: _buildShareMessage(),
        onShareExternal: _shareExternally,
      ),
    );

    if (selectedIds != null && selectedIds.isNotEmpty && _sessionId != null) {
      await TrackingService.shareWithUsers(_sessionId!, selectedIds);
      setState(() {
        _sharedWithUserIds = {..._sharedWithUserIds, ...selectedIds}.toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip shared with selected contacts')),
        );
      }
    }
  }

  /// Shows who the session is currently shared with, plus an "Add More
  /// Contacts" action that opens the full picker (in-app + WhatsApp).
  Future<void> _showSharingStatus() async {
    final sharedContacts = ContactsService.contacts
        .where((c) => c.userId != null && _sharedWithUserIds.contains(c.userId))
        .toList();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
      ),
      builder: (context) => _SharingStatusSheet(
        contacts: sharedContacts,
        onAddMore: _openShareSheet,
      ),
    );
  }

  void _shareExternally() {
    if (_sessionId == null) return;
    ShareService.shareViaOtherApps(_buildShareMessage());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Tracking',
            style: AppTextStyles.calloutBold.copyWith(
              fontSize: 20,
              height: 33 / 20,
            ),
          ),
          const SizedBox(height: 20),
          switch (_mode) {
            _TrackingMode.idle => _IdleState(
              location: _location,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              onShare: _shareOnly,
              onStartJourney: _startJourney,
            ),
            _TrackingMode.sharingOnly => _SharingOnlyState(
              location: _location,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              sharedWithUserIds: _sharedWithUserIds,
              onStop: _stop,
              onShare: () => _openShareSheet(),
              onShowSharingStatus: _showSharingStatus,
            ),
            _TrackingMode.onJourney => _JourneyState(
              journey: _journey!,
              location: _location,
              speedKmh: _speedKmh,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              sharedWithUserIds: _sharedWithUserIds,
              onStop: _stop,
              onShare: () => _openShareSheet(),
              onShowSharingStatus: _showSharingStatus,
            ),
          },
          const SizedBox(height: 10),
          _GeofenceCard(
            enabled: _geofenceEnabled,
            radius: _geofenceRadius,
            onToggle: (v) => setState(() => _geofenceEnabled = v),
            onRadiusChanged: (v) => setState(() => _geofenceRadius = v),
          ),
        ],
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  const _IdleState({
    required this.onShare,
    required this.onStartJourney,
    required this.location,
    required this.geofenceEnabled,
    required this.geofenceRadius,
  });

  final VoidCallback onShare;
  final VoidCallback onStartJourney;
  final LatLng? location;
  final bool geofenceEnabled;
  final double geofenceRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(AppRadius.r5),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: AspectRatio(
              aspectRatio: 311 / 260,
              child: location == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : AppMap(
                      center: location!,
                      zoom: 15,
                      markers: [youAreHereMarker(location!)],
                      circles: geofenceEnabled
                          ? [
                              CircleMarker(
                                point: location!,
                                radius: geofenceRadius,
                                useRadiusInMeter: true,
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderColor: AppColors.primary,
                                borderStrokeWidth: 2,
                              ),
                            ]
                          : [],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "You aren't sharing your location yet",
              style: AppTextStyles.b3,
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Share Your Location', onPressed: onShare),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Start a Journey',
            outlined: true,
            onPressed: onStartJourney,
          ),
        ],
      ),
    );
  }
}

class _SharingOnlyState extends StatelessWidget {
  const _SharingOnlyState({
    required this.onStop,
    required this.onShare,
    required this.onShowSharingStatus,
    required this.location,
    required this.geofenceEnabled,
    required this.geofenceRadius,
    required this.sharedWithUserIds,
  });

  final VoidCallback onStop;
  final VoidCallback onShare;
  final VoidCallback onShowSharingStatus;
  final LatLng? location;
  final bool geofenceEnabled;
  final double geofenceRadius;
  final List<String> sharedWithUserIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200),
            borderRadius: BorderRadius.circular(AppRadius.r5),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r4),
                child: AspectRatio(
                  aspectRatio: 311 / 260,
                  child: location == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : AppMap(
                          center: location!,
                          zoom: 15,
                          markers: [youAreHereMarker(location!)],
                          circles: geofenceEnabled
                              ? [
                                  CircleMarker(
                                    point: location!,
                                    radius: geofenceRadius,
                                    useRadiusInMeter: true,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderColor: AppColors.primary,
                                    borderStrokeWidth: 2,
                                  ),
                                ]
                              : [],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Stop Sharing Live Location',
                outlined: true,
                onPressed: onStop,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Share With More Contacts',
                onPressed: onShare,
              ),
              const SizedBox(height: 2),
              Text(
                'Location shared — no destination set',
                style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SharedWithCard(
          onTap: onShowSharingStatus,
          sharedWithUserIds: sharedWithUserIds,
        ),
      ],
    );
  }
}

/// The traveler's own live position — a profile-photo pin, distinct from
/// the plain "you are here" dot used for idle/sharing-only states.
Marker _profileMarker(LatLng point) {
  return Marker(
    point: point,
    width: 44,
    height: 44,
    alignment: Alignment.center,
    child: Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: Colors.white, width: 3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
        image: DecorationImage(
          image: AssetImage('assets/images/avatar_shape.png'),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

class _JourneyState extends StatelessWidget {
  const _JourneyState({
    required this.journey,
    required this.location,
    required this.speedKmh,
    required this.onStop,
    required this.onShare,
    required this.onShowSharingStatus,
    required this.geofenceEnabled,
    required this.geofenceRadius,
    required this.sharedWithUserIds,
  });

  final JourneyPlan journey;
  final LatLng? location;
  final double speedKmh;
  final VoidCallback onStop;
  final VoidCallback onShare;
  final VoidCallback onShowSharingStatus;
  final bool geofenceEnabled;
  final double geofenceRadius;
  final List<String> sharedWithUserIds;

  @override
  Widget build(BuildContext context) {
    final hasRoute = journey.routePoints.length >= 2;
    final distanceKm =
        journey.routeDistanceKm ??
        LocationService.distanceKm(journey.from, journey.to);
    final etaMin =
        journey.routeDurationMin ??
        (distanceKm / 25 * 60).clamp(2, 240).round(); // assumes ~25km/h avg
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral200),
            borderRadius: BorderRadius.circular(AppRadius.r5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _RouteLabel(
                      icon: Icons.trip_origin,
                      color: AppColors.primary,
                      label: journey.fromLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _RouteLabel(
                      icon: Icons.location_on,
                      color: Colors.black87,
                      label: journey.toLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r4),
                child: AspectRatio(
                  aspectRatio: 311 / 260,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(
                          hasRoute
                              ? journey.routePoints
                              : [journey.from, journey.to],
                        ),
                        padding: const EdgeInsets.all(40),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.safeher.app',
                      ),
                      if (geofenceEnabled)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: journey.from,
                              radius: geofenceRadius,
                              useRadiusInMeter: true,
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderColor: AppColors.primary,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: hasRoute
                                ? journey.routePoints
                                : [journey.from, journey.to],
                            color: AppColors.primary,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          placeMarker(
                            journey.to,
                            icon: Icons.flag_rounded,
                            color: Colors.black87,
                          ),
                          _profileMarker(location ?? journey.from),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Stop Sharing Live Location',
                outlined: true,
                onPressed: onStop,
              ),
              const SizedBox(height: 10),
              PrimaryButton(label: 'Share This Trip', onPressed: onShare),
              const SizedBox(height: 2),
              Text(
                'Location Shared for ${journey.etaMinutes ?? 20} Min',
                style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SharedWithCard(
          onTap: onShowSharingStatus,
          sharedWithUserIds: sharedWithUserIds,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.neutral300),
            borderRadius: BorderRadius.circular(AppRadius.r4),
          ),
          child: Column(
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.send_rounded, size: 20),
              ),
              const SizedBox(height: 13),
              Text('Journey in Progress', style: AppTextStyles.semibold16),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatColumn(
                    value: '${distanceKm.toStringAsFixed(1)} Km',
                    label: 'Distance',
                  ),
                  const SizedBox(width: 28),
                  _StatColumn(value: '$etaMin Min', label: 'ETA'),
                  const SizedBox(width: 28),
                  _StatColumn(
                    value: '${speedKmh.toStringAsFixed(1)} Kmph',
                    label: 'Speed',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteLabel extends StatelessWidget {
  const _RouteLabel({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.b4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SharedWithCard extends StatelessWidget {
  const _SharedWithCard({required this.onTap, required this.sharedWithUserIds});

  final VoidCallback onTap;
  final List<String> sharedWithUserIds;

  @override
  Widget build(BuildContext context) {
    final contacts = ContactsService.contacts
        .where((c) => c.userId != null && sharedWithUserIds.contains(c.userId))
        .toList();
    final subtitle = contacts.isEmpty
        ? 'Tap to add contacts'
        : contacts.map((c) => c.name).join(', ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300),
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sharing with', style: AppTextStyles.semibold16),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: AppTextStyles.b5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (contacts.isNotEmpty) _AvatarStack(count: contacts.length),
          ],
        ),
      ),
    );
  }
}

class _GeofenceCard extends StatelessWidget {
  const _GeofenceCard({
    required this.enabled,
    required this.radius,
    required this.onToggle,
    required this.onRadiusChanged,
  });

  final bool enabled;
  final double radius;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F3F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.security_rounded, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safe Zone Alerts', style: AppTextStyles.semibold16),
                    Text(
                      'Notify contacts if you leave this area',
                      style: AppTextStyles.b5,
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: enabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Text('Radius', style: AppTextStyles.b4),
                        Expanded(
                          child: Slider(
                            value: radius,
                            min: 100,
                            max: 1500,
                            divisions: 14,
                            activeColor: AppColors.primary,
                            label: '${radius.round()} m',
                            onChanged: onRadiusChanged,
                          ),
                        ),
                        Text('${radius.round()} m', style: AppTextStyles.b4),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = count.clamp(1, 3);
    return SizedBox(
      width: 18.0 * (shown - 1) + 32,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/avatar_shape.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.b3.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.b5),
      ],
    );
  }
}

class _ShareTripSheet extends StatefulWidget {
  const _ShareTripSheet({
    required this.contacts,
    required this.allContacts,
    required this.alreadySharedIds,
    required this.message,
    required this.onShareExternal,
  });

  final List<Contact> contacts;
  final List<Contact> allContacts;
  final List<String> alreadySharedIds;
  final String message;
  final VoidCallback onShareExternal;

  @override
  State<_ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends State<_ShareTripSheet> {
  final List<String> _selectedIds = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share your trip',
            style: AppTextStyles.h5.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose in-app contacts to notify, or share externally.',
            style: AppTextStyles.b3,
          ),
          const SizedBox(height: 20),
          if (widget.contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No in-app contacts found. Add them in the Contacts tab.',
                style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: widget.contacts.length,
              itemBuilder: (context, index) {
                final contact = widget.contacts[index];
                final alreadyShared = widget.alreadySharedIds.contains(
                  contact.userId,
                );
                final isSelected =
                    alreadyShared || _selectedIds.contains(contact.userId);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(contact.name, style: AppTextStyles.b3),
                  subtitle: Text(
                    alreadyShared
                        ? '${contact.phone} • Already sharing'
                        : contact.phone,
                    style: AppTextStyles.b5,
                  ),
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: alreadyShared
                      ? null
                      : (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(contact.userId!);
                            } else {
                              _selectedIds.remove(contact.userId);
                            }
                          });
                        },
                );
              },
            ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Share with Selected',
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedIds),
          ),
          const SizedBox(height: 24),
          Text(
            'Send via WhatsApp',
            style: AppTextStyles.h5.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Opens a pre-filled chat — you still tap Send.',
            style: AppTextStyles.b4.copyWith(color: AppColors.neutral400),
          ),
          const SizedBox(height: 12),
          for (final contact in widget.allContacts)
            ContactWhatsAppTile(contact: contact, message: widget.message),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Share via Other Apps',
            outlined: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onShareExternal();
            },
          ),
        ],
      ),
    );
  }
}

/// Read-only view of who a session is currently shared with, reached by
/// tapping the "Sharing with" card — replaces jumping straight into the
/// contact picker, which is now reached via "Add More Contacts" instead.
class _SharingStatusSheet extends StatelessWidget {
  const _SharingStatusSheet({required this.contacts, required this.onAddMore});

  final List<Contact> contacts;
  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sharing your location with',
            style: AppTextStyles.h5.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 16),
          if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "You aren't sharing with any registered contacts yet.",
                style: AppTextStyles.b3.copyWith(color: AppColors.neutral400),
              ),
            )
          else
            for (final contact in contacts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact.name, style: AppTextStyles.semibold16),
                          Text(contact.phone, style: AppTextStyles.b5),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Add More Contacts',
            onPressed: () {
              Navigator.pop(context);
              onAddMore();
            },
          ),
        ],
      ),
    );
  }
}
