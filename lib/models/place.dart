import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum PlaceType { police, hospital, ngo }

/// A nearby police station, hospital, or NGO/social-facility, sourced from
/// the OSM Overpass API (or the offline fallback list).
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.type,
    required this.point,
    required this.distanceKm,
    this.phone,
    this.address,
  });

  final String id;
  final String name;
  final PlaceType type;
  final LatLng point;
  final double distanceKm;

  /// Phone number if OSM has one tagged (`phone` / `contact:phone`).
  final String? phone;
  final String? address;

  String get typeLabel => switch (type) {
    PlaceType.police => 'Police',
    PlaceType.hospital => 'Hospital',
    PlaceType.ngo => 'NGO',
  };

  IconData get icon => switch (type) {
    PlaceType.police => Icons.local_police_rounded,
    PlaceType.hospital => Icons.local_hospital_rounded,
    PlaceType.ngo => Icons.diversity_3_rounded,
  };

  Color get color => switch (type) {
    PlaceType.police => const Color(0xFF2563EB),
    PlaceType.hospital => const Color(0xFFE0334D),
    PlaceType.ngo => const Color(0xFF7C3AED),
  };

  Place copyWithDistance(double distanceKm) => Place(
    id: id,
    name: name,
    type: type,
    point: point,
    distanceKm: distanceKm,
    phone: phone,
    address: address,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'lat': point.latitude,
    'lon': point.longitude,
    'distanceKm': distanceKm,
    'phone': phone,
    'address': address,
  };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    name: json['name'] as String,
    type: PlaceType.values.byName(json['type'] as String),
    point: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lon'] as num).toDouble(),
    ),
    distanceKm: (json['distanceKm'] as num).toDouble(),
    phone: json['phone'] as String?,
    address: json['address'] as String?,
  );
}
