import 'dart:math';

class PlaceLocation {
  final String? placeId;
  final double latitude;
  final double longitude;
  final String placeName;
  final String formattedAddress;
  final DateTime timestamp;

  const PlaceLocation({
    this.placeId,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.formattedAddress,
    required this.timestamp,
  });

  bool get isValid =>
      latitude != 0.0 &&
      longitude != 0.0 &&
      !latitude.isNaN &&
      !longitude.isNaN &&
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0;

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'formattedAddress': formattedAddress,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      placeId: json['placeId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      placeName: (json['placeName'] as String?) ?? (json['title'] as String?) ?? '',
      formattedAddress: (json['formattedAddress'] as String?) ?? (json['address'] as String?) ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Returns true if two locations represent the same geographic place or address (Requirement 9)
  bool isDuplicateOf(PlaceLocation other) {
    if (placeId != null && other.placeId != null && placeId == other.placeId) {
      return true;
    }

    // Normalized formatted address check
    final addr1 = formattedAddress.toLowerCase().trim();
    final addr2 = other.formattedAddress.toLowerCase().trim();
    if (addr1.isNotEmpty && addr1 == addr2) {
      return true;
    }

    // Geographic distance check within 100 meters (~0.1 km)
    if (isValid && other.isValid) {
      final distanceKm = _haversineDistance(latitude, longitude, other.latitude, other.longitude);
      if (distanceKm < 0.1) {
        return true;
      }
    }

    return false;
  }

  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) => degree * pi / 180.0;

  PlaceLocation copyWith({
    String? placeId,
    double? latitude,
    double? longitude,
    String? placeName,
    String? formattedAddress,
    DateTime? timestamp,
  }) {
    return PlaceLocation(
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'PlaceLocation(name: $placeName, address: $formattedAddress, lat: $latitude, lng: $longitude, id: $placeId)';
  }
}
