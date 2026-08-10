import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/contact.dart';
import '../../services/location_service.dart';
import '../../services/risk_service.dart';
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
  RiskAssessment? _journeySafety;
  List<_JourneyFacility> _journeyFacilities = [];
  bool _locationUnavailable = false;
  bool _loadingLocation = true;
  double _traveledKm = 0;
  bool _arrivalHandled = false;
  bool _sharingLive = true;

  /// How close counts as "arrived" when the geofence toggle is off. When
  /// it's on, [_geofenceRadius] is used instead so the two stay
  /// consistent with what's drawn on the map.
  static const double _defaultArrivalRadiusMeters = 100;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _loadingLocation = true);
    final loc = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _location = loc;
      // defaultLocation is only ever returned when a real fix couldn't be
      // obtained (permission, timeout, no GPS) — see location_service.dart.
      // Comparing against it is how we tell "this is really where you are"
      // from "this is the Dhaka fallback" so the UI can say so instead of
      // silently showing a fallback as if it were real.
      _locationUnavailable = loc == defaultLocation;
      _loadingLocation = false;
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
      try {
        final sid = await TrackingService.startSession(
          ownerId: 'user_123', // TODO: Pull from Auth
          ownerName: 'Ananya Sharma', // TODO: Pull from Auth
          destinationLabel: plan.toLabel,
          destinationLatLng: plan.to,
          vehicleNumber: plan.vehicleNumber,
          etaMinutes: plan.etaMinutes,
        );
        final registeredIds = await _shareWithRegisteredContacts(sid);

        if (!mounted) return;
        setState(() {
          _journey = plan;
          _sessionId = sid;
          _sharedWithUserIds = registeredIds;
          _mode = _TrackingMode.onJourney;
          _traveledKm = 0;
          _arrivalHandled = false;
          _sharingLive = true;
        });

        _startLocationStreaming();
        _loadJourneySafetyContext(plan);
      } catch (e) {
        // Without this, a failed Firestore write (e.g. rules not deployed,
        // or offline) used to fail silently — the sheet would close and
        // the screen would just sit back at idle with no explanation.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't start the journey: $e")),
        );
      }
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
            // Small on purpose (was 50m): with a 50m filter, testing via
            // Chrome DevTools' Sensors panel — where you type in nearby
            // coordinates rather than actually walking — mostly got
            // filtered out entirely, so distance/arrival never updated.
            // 10m is still sane for real GPS, just far more testable.
            distanceFilter: 10,
          ),
        ).listen((pos) {
          final loc = LatLng(pos.latitude, pos.longitude);
          // Position.speed is m/s from the GPS hardware; convert to km/h and
          // guard against the occasional negative/NaN reading at low signal.
          final speed = pos.speed.isFinite && pos.speed > 0
              ? pos.speed * 3.6
              : 0.0;
          final previous = _location;
          if (mounted) {
            setState(() {
              if (_journey != null && previous != null) {
                _traveledKm += LocationService.distanceKm(previous, loc);
              }
              _location = loc;
              _speedKmh = speed;
            });
          }
          if (_sessionId != null && _sharingLive) {
            TrackingService.updateLocation(_sessionId!, loc);
          }
          if (_journey != null && !_arrivalHandled) {
            // Arrival detection runs off the device's own GPS regardless
            // of whether live sharing is paused — "stop sharing" only
            // controls what contacts see, not whether the app itself
            // still knows you've reached your destination.
            _checkArrival(loc);
          }
        });
  }

  /// Compares live location against the destination and, the first time
  /// it's within the arrival radius, hands off to [_handleArrival]. Guards
  /// on [_arrivalHandled] so this can only ever fire once per journey.
  void _checkArrival(LatLng loc) {
    final journey = _journey;
    if (journey == null) return;
    final radiusMeters = _geofenceEnabled
        ? _geofenceRadius
        : _defaultArrivalRadiusMeters;
    final distanceMeters = LocationService.distanceKm(loc, journey.to) * 1000;
    if (distanceMeters <= radiusMeters) {
      _arrivalHandled = true;
      _handleArrival(journey);
    }
  }

  /// Fires once, automatically, the moment the traveler's live location
  /// enters the arrival radius around the destination:
  ///  - flags the Firestore session as arrived + ends it, which anyone
  ///    with the tracking viewer open sees immediately, in real time, with
  ///    no action needed on their end (see tracking_viewer_screen.dart)
  ///  - tells the traveler themselves, in-app, that this happened
  ///
  /// Honest limitation: SafeHer has no SMS/push backend (see
  /// share_service.dart) — contacts who *aren't* actively watching the
  /// live tracking viewer only find out via WhatsApp, which still needs a
  /// tap to actually send. That's why this also opens a pre-filled
  /// "I've arrived" share sheet rather than claiming it silently messaged
  /// everyone.
  Future<void> _handleArrival(JourneyPlan journey) async {
    final sid = _sessionId;
    _locationStream?.cancel();
    try {
      if (sid != null) {
        await TrackingService.endSessionOnArrival(sid);
      }
    } catch (_) {
      // Even if this write fails, still tell the traveler locally and
      // still offer the manual share — don't let a Firestore hiccup hide
      // the fact that they've arrived.
    }
    if (!mounted) return;
    setState(() {
      _mode = _TrackingMode.idle;
      _journey = null;
      _sessionId = null;
      _sharedWithUserIds = [];
      _journeySafety = null;
      _journeyFacilities = [];
      _traveledKm = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "You've arrived at ${journey.toLabel}. Contacts watching your "
          'trip saw this instantly — want to also notify others by '
          'WhatsApp?',
        ),
        action: SnackBarAction(
          label: 'Notify',
          onPressed: () => ShareService.shareViaOtherApps(
            "I've arrived safely at ${journey.toLabel}. — sent via SafeHer",
          ),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
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
    try {
      final sid = await TrackingService.startSession(
        ownerId: 'user_123', // TODO: Pull from Auth
        ownerName: 'Ananya Sharma', // TODO: Pull from Auth
        destinationLabel: 'Current Location',
        destinationLatLng: _location!,
      );
      final registeredIds = await _shareWithRegisteredContacts(sid);

      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _sharedWithUserIds = registeredIds;
        _mode = _TrackingMode.sharingOnly;
      });

      _startLocationStreaming();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't start sharing: $e")));
    }
  }

  /// Best-effort — the risk-zone/nearby-facility overlay is a nice-to-have
  /// on top of an already-started journey, so any failure here just means
  /// the map shows the route without it, never blocks or reverts tracking.
  Future<void> _loadJourneySafetyContext(JourneyPlan plan) async {
    final mid = LatLng(
      (plan.from.latitude + plan.to.latitude) / 2,
      (plan.from.longitude + plan.to.longitude) / 2,
    );
    try {
      final assessment = await RiskService.assess(center: mid);
      final facilities = await _fetchJourneyFacilities(mid);
      if (!mounted) return;
      setState(() {
        _journeySafety = assessment;
        _journeyFacilities = facilities;
      });
    } catch (_) {
      // Leave both null/empty — journey tracking itself doesn't depend on it.
    }
  }

  /// Pauses/resumes what contacts see, without touching the journey
  /// itself — the journey only ends via [_stop] (manual "End Journey") or
  /// [_handleArrival] (automatic, on reaching the destination). Position
  /// tracking and arrival detection keep running locally either way;
  /// this only gates whether that position gets written to Firestore.
  Future<void> _toggleSharing() async {
    final next = !_sharingLive;
    setState(() => _sharingLive = next);
    if (_sessionId != null) {
      try {
        await TrackingService.setSharingPaused(_sessionId!, !next);
      } catch (_) {
        // Best-effort — worst case a contact's view just goes stale
        // until the next successful location write.
      }
    }
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
      _journeySafety = null;
      _journeyFacilities = [];
      _traveledKm = 0;
      _arrivalHandled = false;
      _sharingLive = true;
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
          if (_locationUnavailable && !_loadingLocation) ...[
            _LocationRetryBanner(onRetry: _loadLocation),
            const SizedBox(height: 10),
          ],
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
              traveledKm: _traveledKm,
              geofenceEnabled: _geofenceEnabled,
              geofenceRadius: _geofenceRadius,
              sharedWithUserIds: _sharedWithUserIds,
              riskZones: _journeySafety?.zones ?? const [],
              facilities: _journeyFacilities,
              sharingLive: _sharingLive,
              onToggleSharing: _toggleSharing,
              onEndJourney: _stop,
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
          const SizedBox(height: 6),
          Text(
            "Add a destination next — you'll get to compare Fastest vs "
            'Safest routes before you confirm.',
            style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
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

/// A police/hospital/clinic point fetched for the journey-in-progress map
/// overlay — same three amenity types RouteSafetyService scores routes
/// against, so what you see on the map matches what fed the safety score.
class _JourneyFacility {
  const _JourneyFacility({
    required this.point,
    required this.icon,
    required this.color,
  });
  final LatLng point;
  final IconData icon;
  final Color color;
}

Future<List<_JourneyFacility>> _fetchJourneyFacilities(LatLng center) async {
  const radius = 3000;
  final query =
      '[out:json][timeout:12];('
      'node["amenity"="police"](around:$radius,${center.latitude},${center.longitude});'
      'node["amenity"="hospital"](around:$radius,${center.latitude},${center.longitude});'
      'node["amenity"="clinic"](around:$radius,${center.latitude},${center.longitude});'
      ');out center 60;';

  final response = await http
      .post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      )
      .timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) return [];

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final elements = (data['elements'] as List).cast<Map<String, dynamic>>();

  final result = <_JourneyFacility>[];
  for (final e in elements) {
    final lat = (e['lat'] as num?)?.toDouble();
    final lon = (e['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) continue;
    final amenity = (e['tags'] as Map?)?['amenity'] as String?;
    final isPolice = amenity == 'police';
    result.add(
      _JourneyFacility(
        point: LatLng(lat, lon),
        icon: isPolice
            ? Icons.local_police_rounded
            : Icons.local_hospital_rounded,
        color: isPolice ? const Color(0xFF2563EB) : const Color(0xFFE0334D),
      ),
    );
  }
  return result;
}

class _JourneyState extends StatelessWidget {
  const _JourneyState({
    required this.journey,
    required this.location,
    required this.speedKmh,
    required this.onShare,
    required this.onShowSharingStatus,
    required this.geofenceEnabled,
    required this.geofenceRadius,
    required this.sharedWithUserIds,
    required this.sharingLive,
    required this.onToggleSharing,
    required this.onEndJourney,
    this.riskZones = const [],
    this.facilities = const [],
    this.traveledKm = 0,
  });

  final JourneyPlan journey;
  final LatLng? location;
  final double speedKmh;
  final double traveledKm;
  final VoidCallback onShare;
  final VoidCallback onShowSharingStatus;
  final bool geofenceEnabled;
  final double geofenceRadius;
  final List<RiskZone> riskZones;
  final List<_JourneyFacility> facilities;
  final List<String> sharedWithUserIds;

  /// Whether live location is currently being pushed to contacts. Toggling
  /// this (via [onToggleSharing]) never ends the journey — only
  /// [onEndJourney] does that. See LiveTrackingTabState._toggleSharing /
  /// _stop.
  final bool sharingLive;
  final VoidCallback onToggleSharing;
  final VoidCallback onEndJourney;

  @override
  Widget build(BuildContext context) {
    final hasRoute = journey.routePoints.length >= 2;
    final totalKm =
        journey.routeDistanceKm ??
        LocationService.distanceKm(journey.from, journey.to);
    // "Remaining" is measured live (straight-line to the destination from
    // wherever you actually are right now), not derived from traveledKm —
    // that keeps it correct even if you deviate from the planned route.
    // traveledKm is a separate running total of actual movement, summed
    // from consecutive position-stream updates in LiveTrackingTabState.
    final remainingKm = location != null
        ? LocationService.distanceKm(location!, journey.to)
        : totalKm;
    final etaMin =
        journey.routeDurationMin ??
        (totalKm / 25 * 60).clamp(2, 240).round(); // assumes ~25km/h avg
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
                      if (riskZones.isNotEmpty)
                        CircleLayer(
                          circles: [
                            for (final z in riskZones)
                              if (z.level != RiskLevel.safe)
                                CircleMarker(
                                  point: z.center,
                                  radius: z.radiusMeters,
                                  useRadiusInMeter: true,
                                  color:
                                      (z.level == RiskLevel.high
                                              ? const Color(0xFFE0334D)
                                              : const Color(0xFFF59E0B))
                                          .withValues(alpha: 0.16),
                                  borderColor: z.level == RiskLevel.high
                                      ? const Color(0xFFE0334D)
                                      : const Color(0xFFF59E0B),
                                  borderStrokeWidth: 2,
                                ),
                          ],
                        ),
                      if (geofenceEnabled)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              // Centered on the destination, not the
                              // start — the geofence marks the arrival
                              // zone you're heading into.
                              point: journey.to,
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
                          for (final f in facilities)
                            placeMarker(f.point, icon: f.icon, color: f.color),
                          _profileMarker(location ?? journey.from),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (journey.routeExplanation != null) ...[
                const SizedBox(height: 10),
                _WhySafestCard(text: journey.routeExplanation!),
              ],
              const SizedBox(height: 10),
              PrimaryButton(
                label: sharingLive
                    ? 'Stop Sharing Live Location'
                    : 'Resume Sharing Live Location',
                outlined: true,
                onPressed: onToggleSharing,
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
                    value: '${remainingKm.toStringAsFixed(1)} Km',
                    label: 'Left',
                  ),
                  const SizedBox(width: 20),
                  _StatColumn(
                    value: '${traveledKm.toStringAsFixed(1)} Km',
                    label: 'Traveled',
                  ),
                  const SizedBox(width: 20),
                  _StatColumn(value: '$etaMin Min', label: 'ETA'),
                  const SizedBox(width: 20),
                  _StatColumn(
                    value: '${speedKmh.toStringAsFixed(1)} Kmph',
                    label: 'Speed',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Deliberately separate from "Stop Sharing" above and styled to
        // read as more final — this is the only manual way to end the
        // journey before automatic arrival detection would (see
        // LiveTrackingTabState._checkArrival / _handleArrival).
        TextButton.icon(
          onPressed: onEndJourney,
          icon: const Icon(
            Icons.flag_circle_outlined,
            size: 18,
            color: Color(0xFFB3261E),
          ),
          label: const Text(
            'End Journey',
            style: TextStyle(
              color: Color(0xFFB3261E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when LocationService fell back to its hardcoded default (Dhaka)
/// instead of a real GPS fix — usually a browser permission-prompt timing
/// issue on first load. Makes the fallback visible instead of silently
/// showing a wrong city as if it were real, and gives a one-tap retry
/// instead of requiring a full page refresh.
class _LocationRetryBanner extends StatelessWidget {
  const _LocationRetryBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(color: const Color(0xFFFCD9A8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Couldn't get your real location — showing a fallback. "
              'This is usually a browser permission prompt that needs a tap.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Carries forward the "why this is the safest route" sentence from
/// RouteSafetyService, shown once on the journey-in-progress screen so
/// the reasoning isn't only visible on the route-selection screen you've
/// already left.
class _WhySafestCard extends StatelessWidget {
  const _WhySafestCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F0),
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(color: const Color(0xFFBBE5C3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.b4.copyWith(color: const Color(0xFF166534)),
            ),
          ),
        ],
      ),
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
