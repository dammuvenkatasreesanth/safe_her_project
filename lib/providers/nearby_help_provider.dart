import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../repositories/nearby_places_repository.dart';
import '../services/location_permission_service.dart';
import '../services/location_service.dart';

/// Drives the Nearby Help screen: location acquisition + permission
/// status, fetching (with retry/cache/offline fallback baked in via
/// [NearbyPlacesRepository]), and filter/search/sort.
class NearbyHelpProvider extends ChangeNotifier {
  NearbyHelpProvider({NearbyPlacesRepository? repository})
    : _repository = repository ?? NearbyPlacesRepository();

  final NearbyPlacesRepository _repository;

  LatLng? _location;
  List<Place> _places = [];
  bool _isLoading = true;
  PlacesSource? _source;
  LocationAccessStatus? _locationStatus;
  String _filter = 'All';
  String _query = '';

  static const filters = ['All', 'Police', 'Hospital', 'NGO'];

  LatLng? get location => _location;
  bool get isLoading => _isLoading;
  PlacesSource? get source => _source;
  LocationAccessStatus? get locationStatus => _locationStatus;
  String get filter => _filter;
  String get query => _query;

  bool get isUsingFallback => _source == PlacesSource.offlineFallback;
  bool get isUsingCache => _source == PlacesSource.cache;

  List<Place> get visiblePlaces {
    var result = _places;
    if (_filter != 'All') {
      result = result.where((p) => p.typeLabel == _filter).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final status = await LocationPermissionService.checkStatus();

    final location = await LocationService.getCurrentLocation();
    _location = location;

    if (location == null) {
      // Permission can be fine (GPS just hasn't produced a fix yet) even
      // though checkStatus() reported granted — don't show "Location
      // Ready"-adjacent silence when we're about to display nothing real.
      _locationStatus = status == LocationAccessStatus.granted
          ? LocationAccessStatus.unavailable
          : status;
      _places = [];
      _source = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _locationStatus = status;
    notifyListeners();

    final result = await _repository.getNearby(location);
    _places = result.places;
    _source = result.source;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();

  Future<void> openLocationSettings() =>
      LocationPermissionService.openSettings();

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }
}
