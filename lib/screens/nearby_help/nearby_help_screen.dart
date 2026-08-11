import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/place.dart';
import '../../providers/nearby_help_provider.dart';
import '../../services/location_permission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/screen_header.dart';

class NearbyHelpScreen extends StatefulWidget {
  const NearbyHelpScreen({super.key});

  @override
  State<NearbyHelpScreen> createState() => _NearbyHelpScreenState();
}

class _NearbyHelpScreenState extends State<NearbyHelpScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  late final NearbyHelpProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = NearbyHelpProvider()..load();
    _searchController.addListener(() {
      _provider.setQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _focus(LatLng point) => _mapController.move(point, 16);

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for this place.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the phone app.")),
      );
    }
  }

  Future<void> _openDirections(Place place) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${place.point.latitude},${place.point.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open Google Maps.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<NearbyHelpProvider>(
        builder: (context, provider, _) {
          final visible = provider.visiblePlaces;
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeader(title: 'Nearby Help'),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.r5),
                      child: SizedBox(
                        height: 190,
                        child: provider.location == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                            : AppMap(
                                center: provider.location!,
                                zoom: 14.5,
                                controller: _mapController,
                                markers: [
                                  youAreHereMarker(provider.location!, size: 36),
                                  for (final p in visible)
                                    placeMarker(
                                      p.point,
                                      icon: p.icon,
                                      color: p.color,
                                      onTap: () => _focus(p.point),
                                    ),
                                ],
                              ),
                      ),
                    ),
                    if (provider.locationStatus != null &&
                        provider.locationStatus != LocationAccessStatus.granted)
                      _LocationBanner(
                        status: provider.locationStatus!,
                        onOpenSettings: provider.openLocationSettings,
                        onRetry: provider.refresh,
                      )
                    else if ((provider.isUsingFallback || provider.isUsingCache) &&
                        !provider.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          provider.isUsingCache
                              ? 'Showing recently saved nearby locations — may be out of date.'
                              : "Live data unavailable — showing example locations that may not be near you.",
                          style: AppTextStyles.b5.copyWith(
                            color: AppColors.neutral400,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _searchController,
                      hint: 'Search nearby places',
                      prefix: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.neutral400,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final f in NearbyHelpProvider.filters) ...[
                          ChoiceChip(
                            label: Text(f),
                            selected: provider.filter == f,
                            onSelected: (_) => provider.setFilter(f),
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            labelStyle: AppTextStyles.b4,
                            side: const BorderSide(color: AppColors.neutral300),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: provider.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      provider.query.isNotEmpty
                                          ? 'No places match "${provider.query}".'
                                          : provider.location == null
                                          ? "Couldn't get your location, so we can't show places near you."
                                          : 'No places found nearby.',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.b3,
                                    ),
                                    if (provider.query.isEmpty && provider.location == null) ...[
                                      const SizedBox(height: 10),
                                      TextButton(onPressed: provider.refresh, child: const Text('Retry')),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: provider.refresh,
                              child: ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 11),
                                padding: const EdgeInsets.only(bottom: 24),
                                itemBuilder: (context, i) => _PlaceCard(
                                  place: visible[i],
                                  onTap: () => _focus(visible[i].point),
                                  onCall: () => _call(visible[i].phone),
                                  onDirections: () =>
                                      _openDirections(visible[i]),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.status,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final LocationAccessStatus status;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      LocationAccessStatus.gpsDisabled =>
        'Location services are off. Turn on GPS for accurate nearby results.',
      LocationAccessStatus.denied =>
        "Location permission denied — we can't show places near you without it.",
      LocationAccessStatus.deniedForever =>
        'Location permission is blocked. Enable it in Settings for accurate results.',
      LocationAccessStatus.unavailable =>
        "Couldn't get a GPS fix. Move to an open area or check your connection, then retry.",
      LocationAccessStatus.granted => '',
    };
    final showSettings = status == LocationAccessStatus.deniedForever;
    final showRetry = status == LocationAccessStatus.unavailable || status == LocationAccessStatus.gpsDisabled;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.neutral400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
            ),
          ),
          if (showSettings)
            TextButton(
              onPressed: onOpenSettings,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Settings', style: AppTextStyles.b5),
            ),
          if (showRetry)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Retry', style: AppTextStyles.b5),
            ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onTap,
    required this.onCall,
    required this.onDirections,
  });

  final Place place;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300),
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Row(
          children: [
            Container(
              width: 41,
              height: 41,
              decoration: BoxDecoration(
                color: place.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(place.icon, size: 20, color: place.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: AppTextStyles.semibold16,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${place.typeLabel} · ${place.distanceKm.toStringAsFixed(1)} km',
                    style: AppTextStyles.b5,
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onCall,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onDirections,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
