import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/screen_header.dart';

enum _PlaceType { police, hospital, ngo }

class _Place {
  const _Place({
    required this.name,
    required this.type,
    required this.point,
    required this.distanceKm,
  });
  final String name;
  final _PlaceType type;
  final LatLng point;
  final double distanceKm;

  String get typeLabel => switch (type) {
    _PlaceType.police => 'Police',
    _PlaceType.hospital => 'Hospital',
    _PlaceType.ngo => 'NGO',
  };

  IconData get icon => switch (type) {
    _PlaceType.police => Icons.local_police_rounded,
    _PlaceType.hospital => Icons.local_hospital_rounded,
    _PlaceType.ngo => Icons.diversity_3_rounded,
  };

  Color get color => switch (type) {
    _PlaceType.police => const Color(0xFF2563EB),
    _PlaceType.hospital => const Color(0xFFE0334D),
    _PlaceType.ngo => const Color(0xFF7C3AED),
  };
}

class NearbyHelpScreen extends StatefulWidget {
  const NearbyHelpScreen({super.key});

  @override
  State<NearbyHelpScreen> createState() => _NearbyHelpScreenState();
}

class _NearbyHelpScreenState extends State<NearbyHelpScreen> {
  final _mapController = MapController();
  String _filter = 'All';
  LatLng? _location;
  List<_Place> _places = [];
  bool _loading = true;
  bool _usingFallback = false;

  static const _filters = ['All', 'Police', 'Hospital', 'NGO'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _location = location);

    List<_Place> places;
    try {
      places = await _fetchOverpass(location);
      if (places.isEmpty) throw Exception('empty');
    } catch (_) {
      places = _fallbackPlaces(location);
      _usingFallback = true;
    }
    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    if (!mounted) return;
    setState(() {
      _places = places;
      _loading = false;
    });
  }

  Future<List<_Place>> _fetchOverpass(LatLng center) async {
    final query =
        '[out:json][timeout:12];('
        'node["amenity"="police"](around:3000,${center.latitude},${center.longitude});'
        'node["amenity"="hospital"](around:3000,${center.latitude},${center.longitude});'
        'node["office"="ngo"](around:3000,${center.latitude},${center.longitude});'
        'node["amenity"="social_facility"](around:3000,${center.latitude},${center.longitude});'
        ');out center 30;';
    final response = await http
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('overpass status ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List).cast<Map<String, dynamic>>();
    final results = <_Place>[];
    for (final e in elements) {
      final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
      final name = tags['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      final lat = (e['lat'] as num?)?.toDouble();
      final lon = (e['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final point = LatLng(lat, lon);
      final type = tags['amenity'] == 'police'
          ? _PlaceType.police
          : tags['amenity'] == 'hospital'
          ? _PlaceType.hospital
          : _PlaceType.ngo;
      results.add(
        _Place(
          name: name,
          type: type,
          point: point,
          distanceKm: LocationService.distanceKm(center, point),
        ),
      );
    }
    return results;
  }

  List<_Place> _fallbackPlaces(LatLng center) {
    final raw = [
      (
        name: 'Dhanmondi Police Station',
        type: _PlaceType.police,
        point: const LatLng(23.7395, 90.3745),
      ),
      (
        name: 'Square Hospital Ltd',
        type: _PlaceType.hospital,
        point: const LatLng(23.7522, 90.3752),
      ),
      (
        name: 'Neonatal & General Hospital',
        type: _PlaceType.hospital,
        point: const LatLng(23.7480, 90.3720),
      ),
      (
        name: "Women's Support NGO",
        type: _PlaceType.ngo,
        point: const LatLng(23.7440, 90.3700),
      ),
      (
        name: 'Rapa Plaza Police Outpost',
        type: _PlaceType.police,
        point: const LatLng(23.7500, 90.3760),
      ),
    ];
    return [
      for (final p in raw)
        _Place(
          name: p.name,
          type: p.type,
          point: p.point,
          distanceKm: LocationService.distanceKm(center, p.point),
        ),
    ];
  }

  void _focus(LatLng point) {
    _mapController.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filter == 'All'
        ? _places
        : _places.where((p) => p.typeLabel == _filter).toList();

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
                  child: _location == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : AppMap(
                          center: _location!,
                          zoom: 14.5,
                          controller: _mapController,
                          markers: [
                            youAreHereMarker(_location!, size: 36),
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
              if (_usingFallback && !_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Showing saved nearby locations (live data unavailable)',
                    style: AppTextStyles.b5.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final f in _filters) ...[
                    ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppColors.primary.withValues(alpha: 0.12),
                      labelStyle: AppTextStyles.b4,
                      side: const BorderSide(color: AppColors.neutral300),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          'No places found nearby.',
                          style: AppTextStyles.b3,
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 11),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, i) => _PlaceCard(
                          place: visible[i],
                          onTap: () => _focus(visible[i].point),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});

  final _Place place;
  final VoidCallback onTap;

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
            Container(
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
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.neutral300),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
