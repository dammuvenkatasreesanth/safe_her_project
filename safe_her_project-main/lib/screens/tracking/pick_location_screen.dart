import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';

/// Lets the user drag the map so a fixed centre pin lands on their
/// destination — the classic "pin the spot" picker pattern.
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key, required this.initialCenter});

  final LatLng initialCenter;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final _mapController = MapController();
  late LatLng _center = widget.initialCenter;
  String _label = 'Move the map to choose a spot';
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _reverseGeocode(_center);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!hasGesture) return;
    setState(() => _loading = true);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _reverseGeocode(_center),
    );
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final label = await GeocodingService.reverse(point);
    if (!mounted) return;
    setState(() {
      _label =
          label ??
          'Dropped pin (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safeher.app',
              ),
            ],
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(19),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.r6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _loading
                              ? Text(
                                  'Locating...',
                                  style: AppTextStyles.b3.copyWith(
                                    color: AppColors.neutral400,
                                  ),
                                )
                              : Text(
                                  _label,
                                  style: AppTextStyles.b3,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: 'Confirm This Location',
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(PlaceResult(label: _label, point: _center)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
