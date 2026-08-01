import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'pick_location_screen.dart';

class JourneyPlan {
  const JourneyPlan({
    required this.fromLabel,
    required this.from,
    required this.toLabel,
    required this.to,
  });
  final String fromLabel;
  final LatLng from;
  final String toLabel;
  final LatLng to;
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
  String _fromLabel = 'Locating...';
  PlaceResult? _selectedDestination;
  List<PlaceResult> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;

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
    _debounce?.cancel();
    super.dispose();
  }

  void _onToChanged(String value) {
    setState(() => _selectedDestination = null);
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
        builder: (_) =>
            PickLocationScreen(initialCenter: widget.currentLocation),
      ),
    );
    if (result != null) _selectSuggestion(result);
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
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 1, height: 20, color: AppColors.neutral300),
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Start Journey',
            onPressed: _selectedDestination == null
                ? null
                : () => Navigator.of(context).pop(
                    JourneyPlan(
                      fromLabel: _fromLabel,
                      from: widget.currentLocation,
                      toLabel: _selectedDestination!.label.split(',').first,
                      to: _selectedDestination!.point,
                    ),
                  ),
          ),
        ],
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
