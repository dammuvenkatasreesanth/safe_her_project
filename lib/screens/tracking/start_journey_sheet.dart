import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../services/routing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'pick_location_screen.dart';
import 'select_route_screen.dart';

class JourneyPlan {
  const JourneyPlan({
    required this.fromLabel,
    required this.from,
    required this.toLabel,
    required this.to,
    this.vehicleNumber,
    this.etaMinutes,
    this.routePoints = const [],
    this.routeDistanceKm,
    this.routeDurationMin,
    this.routeSafetyScore,
    this.routeExplanation,
  });
  final String fromLabel;
  final LatLng from;
  final String toLabel;
  final LatLng to;
  final String? vehicleNumber;
  final int? etaMinutes;

  /// Real road-route geometry chosen on the route-selection screen, if
  /// the routing fetch succeeded and the user didn't hit "Continue
  /// Anyway". Empty means callers should fall back to a direct line.
  final List<LatLng> routePoints;
  final double? routeDistanceKm;
  final int? routeDurationMin;

  /// 0-100 weighted safety score for the chosen route, and — only when
  /// the chosen route was the recommended-safest one — the plain-English
  /// reason it was recommended. Both null if scoring wasn't attempted or
  /// failed; routeExplanation is also null if the user picked a route
  /// other than the recommended safest one, since the sentence is a
  /// comparison against the fastest route and wouldn't apply.
  final double? routeSafetyScore;
  final String? routeExplanation;
}

/// "From / To" destination picker — a journey can't start without knowing
/// where it's going, so this gates entry into the tracking/route UI.
Future<JourneyPlan?> showStartJourneySheet(
  BuildContext context,
  LatLng currentLocation,
) {
  return showModalBottomSheet<JourneyPlan>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
    ),
    builder: (context) => _StartJourneySheet(currentLocation: currentLocation),
  );
}

class _StartJourneySheet extends StatefulWidget {
  const _StartJourneySheet({required this.currentLocation});

  final LatLng currentLocation;

  @override
  State<_StartJourneySheet> createState() => _StartJourneySheetState();
}

class _StartJourneySheetState extends State<_StartJourneySheet> {
  final _toController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _etaController = TextEditingController();
  String _fromLabel = 'Locating...';
  LatLng? _customFrom;
  PlaceResult? _selectedDestination;
  List<PlaceResult> _suggestions = [];
  bool _searching = false;
  bool _searchedWithNoResults = false;
  Timer? _debounce;

  LatLng get _fromPoint => _customFrom ?? widget.currentLocation;

  @override
  void initState() {
    super.initState();
    GeocodingService.reverse(widget.currentLocation).then((label) {
      if (mounted) {
        setState(() => _fromLabel = label ?? 'Your current location');
      }
    });
  }

  @override
  void dispose() {
    _toController.dispose();
    _vehicleController.dispose();
    _etaController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onToChanged(String value) {
    setState(() {
      _selectedDestination = null;
      _searchedWithNoResults = false;
    });
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      final results = await GeocodingService.search(
        value,
        near: widget.currentLocation,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _searchedWithNoResults = results.isEmpty;
      });
    });
  }

  void _selectSuggestion(PlaceResult place) {
    setState(() {
      _selectedDestination = place;
      _toController.text = place.label;
      _suggestions = [];
    });
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(initialCenter: _fromPoint),
      ),
    );
    if (result != null) _selectSuggestion(result);
  }

  Future<void> _pickOnMapForFrom() async {
    final result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(initialCenter: _fromPoint),
      ),
    );
    if (result != null) {
      setState(() {
        _customFrom = result.point;
        _fromLabel = result.label;
      });
    }
  }

  Future<void> _startJourney() async {
    final destination = _selectedDestination;
    if (destination == null) return;

    final chosenRoute = await Navigator.of(context).push<RouteOption>(
      MaterialPageRoute(
        builder: (_) => SelectRouteScreen(
          from: _fromPoint,
          to: destination.point,
          fromLabel: _fromLabel,
          toLabel: destination.label.split(',').first,
        ),
      ),
    );
    if (!mounted) return;

    Navigator.of(context).pop(
      JourneyPlan(
        fromLabel: _fromLabel,
        from: _fromPoint,
        toLabel: destination.label.split(',').first,
        to: destination.point,
        vehicleNumber: _vehicleController.text.trim(),
        etaMinutes: int.tryParse(_etaController.text.trim()),
        routePoints: chosenRoute?.points ?? const [],
        routeDistanceKm: chosenRoute?.distanceKm,
        routeDurationMin: chosenRoute?.durationMin,
        routeSafetyScore: chosenRoute?.safetyScore,
        routeExplanation: chosenRoute?.safetyExplanation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        15,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 57,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.dot,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start a Journey',
              style: AppTextStyles.h5.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              'Add where you\'re headed so we can track your route.',
              style: AppTextStyles.b3,
            ),
            const SizedBox(height: 20),
            _RoutePointRow(
              icon: Icons.trip_origin,
              iconColor: AppColors.primary,
              label: 'From',
              child: Text(
                _fromLabel,
                style: AppTextStyles.b3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 57, top: 4),
              child: GestureDetector(
                onTap: _pickOnMapForFrom,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pick on map instead',
                      style: AppTextStyles.b4.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 9, top: 6),
              child: Container(
                width: 1,
                height: 20,
                color: AppColors.neutral300,
              ),
            ),
            _RoutePointRow(
              icon: Icons.location_on,
              iconColor: Colors.black87,
              label: 'To',
              child: TextField(
                controller: _toController,
                onChanged: _onToChanged,
                autofocus: true,
                style: AppTextStyles.b3,
                decoration: InputDecoration(
                  hintText: 'Search destination...',
                  hintStyle: AppTextStyles.b3.copyWith(
                    color: AppColors.neutral400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 57, top: 6),
              child: GestureDetector(
                onTap: _pickOnMap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pick on map instead',
                      style: AppTextStyles.b4.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_toController.text.trim().isNotEmpty &&
                _toController.text.trim().length < 3)
              const _SearchHint(
                icon: Icons.info_outline_rounded,
                text: 'Keep typing — at least 3 characters to search',
              )
            else if (_searchedWithNoResults && _selectedDestination == null)
              const _SearchHint(
                icon: Icons.search_off_rounded,
                text: 'No matches found. Try a different search, or pick on map above.',
              ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.neutral200),
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 18),
                      title: Text(
                        s.label,
                        style: AppTextStyles.b4,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectSuggestion(s),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            _RoutePointRow(
              icon: Icons.directions_car_rounded,
              iconColor: AppColors.neutral900,
              label: 'Cab',
              child: TextField(
                controller: _vehicleController,
                style: AppTextStyles.b3,
                decoration: InputDecoration(
                  hintText: 'Vehicle No. (Optional)',
                  hintStyle: AppTextStyles.b3.copyWith(
                    color: AppColors.neutral400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 57),
              child: Container(height: 1, color: AppColors.neutral200),
            ),
            const SizedBox(height: 12),
            _RoutePointRow(
              icon: Icons.access_time_rounded,
              iconColor: AppColors.neutral900,
              label: 'ETA',
              child: TextField(
                controller: _etaController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.b3,
                decoration: InputDecoration(
                  hintText: 'Expected time (Minutes)',
                  hintStyle: AppTextStyles.b3.copyWith(
                    color: AppColors.neutral400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Start Journey',
              onPressed: _selectedDestination == null ? null : _startJourney,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePointRow extends StatelessWidget {
  const _RoutePointRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Small inline hint shown under the destination search field — either
/// "keep typing" (query too short to search yet) or "no matches found"
/// (search completed with zero results). Kept as one widget so both
/// states share the same subdued styling.
class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 57, top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.neutral400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
            ),
          ),
        ],
      ),
    );
  }
}