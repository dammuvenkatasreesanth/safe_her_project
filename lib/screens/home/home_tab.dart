import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/action_card.dart';
import '../../widgets/app_map.dart';
import '../../widgets/primary_button.dart';
import '../chatbot/chatbot_screen.dart';
import '../contacts/contacts_screen.dart';
import '../fake_call/fake_call_screen.dart';
import '../nearby_help/nearby_help_screen.dart';
import '../report/report_screen.dart';
import '../safe_route/safe_route_screen.dart';
import '../sos/sos_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onShareLocation});

  /// Switches to the Tracking tab and starts live location sharing there —
  /// this button doesn't have its own separate share flow anymore.
  final VoidCallback onShareLocation;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  LatLng? _location;
  String? _address;
  StreamSubscription<Position>? _locationStream;
  DateTime? _lastGeocodeAt;

  @override
  void initState() {
    super.initState();
    LocationService.getCurrentLocation().then((loc) {
      if (mounted) setState(() => _location = loc);
      _maybeReverseGeocode(loc);
    });
    _startLocationStream();
  }

  void _startLocationStream() {
    _locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 40,
          ),
        ).listen(
          (pos) {
            final loc = LatLng(pos.latitude, pos.longitude);
            if (mounted) setState(() => _location = loc);
            _maybeReverseGeocode(loc);
          },
          // Permission can be denied/revoked after this stream starts (e.g.
          // the OS permission dialog hasn't been answered yet on first
          // launch) — without this the stream dies silently and the map
          // never updates again. The initial getCurrentLocation() call
          // above already has its own fallback, so just drop the error.
          onError: (_) {},
        );
  }

  void _maybeReverseGeocode(LatLng loc) {
    final now = DateTime.now();
    if (_lastGeocodeAt != null &&
        now.difference(_lastGeocodeAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastGeocodeAt = now;
    GeocodingService.reverse(loc).then((address) {
      if (mounted && address != null) setState(() => _address = address);
    });
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, there!',
                style: AppTextStyles.h5.copyWith(fontSize: 22, height: 33 / 22),
              ),
              const SizedBox(height: 2),
              Text('Ready for a safe journey today', style: AppTextStyles.b3),
              const SizedBox(height: 24),
              Text(
                "Start your journey and let your loved ones know you're safe.",
                style: AppTextStyles.h5.copyWith(fontSize: 22, height: 33 / 22),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r6),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.r4),
                      child: AspectRatio(
                        aspectRatio: 328 / 186,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _location == null
                              ? const Center(
                                  key: ValueKey('loading'),
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                )
                              : AppMap(
                                  key: const ValueKey('map'),
                                  center: _location!,
                                  zoom: 15,
                                  interactive: false,
                                  markers: [youAreHereMarker(_location!)],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _address ?? 'Locating...',
                        style: AppTextStyles.b3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: 'Share Your Location',
                      onPressed: widget.onShareLocation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ActionCard(
                            icon: Icons.notifications_active_outlined,
                            title: 'SOS Button',
                            subtitle: 'Emergency Help Now',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SosScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: ActionCard(
                            icon: Icons.contacts_outlined,
                            title: 'Contacts',
                            subtitle: 'Call Trusted Contacts',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ContactsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: ActionCard(
                            icon: Icons.phone_in_talk_outlined,
                            title: 'Fake Call',
                            subtitle: 'Make a Fake Call',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FakeCallScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: ActionCard(
                            icon: Icons.shield_outlined,
                            title: 'Nearby Help',
                            subtitle: 'Call nearby law',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NearbyHelpScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: ActionCard(
                            icon: Icons.description_outlined,
                            title: 'Report',
                            subtitle: 'Emergency Help Now',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReportScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: ActionCard(
                            icon: Icons.route_outlined,
                            title: 'Safe Route',
                            subtitle: 'Avoid risky areas',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SafeRouteScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 4,
          bottom: 98,
          child: _ChatFab(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ChatbotScreen())),
          ),
        ),
      ],
    );
  }
}

class _ChatFab extends StatelessWidget {
  const _ChatFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
