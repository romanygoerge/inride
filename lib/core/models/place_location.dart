import 'dart:math';

class PlaceLocation {
  final String? placeId;
  final double latitude;
  final double longitude;
  final String placeName;
  final String formattedAddress;
  final DateTime timestamp;
  final String? category;
  final String? subCategory;
  final String? placeType;
  final String city;
  final String? district;
  final String? mallName;
  final String? phone;
  final bool coordinatesVerified;
  final String? source;
  final List<String> aliases;
  final String? nameAr;
  final String? nameEn;
  final double? distanceKm;
  final double? distanceMeters;
  final bool isSaved;
  final bool isHistory;
  final int popularity;
  final double? finalScore;

  const PlaceLocation({
    this.placeId,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.formattedAddress,
    required this.timestamp,
    this.category,
    this.subCategory,
    this.placeType,
    this.city = 'مدينة السادات',
    this.district,
    this.mallName,
    this.phone,
    this.coordinatesVerified = true,
    this.source,
    this.aliases = const [],
    this.nameAr,
    this.nameEn,
    this.distanceKm,
    this.distanceMeters,
    this.isSaved = false,
    this.isHistory = false,
    this.popularity = 0,
    this.finalScore,
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

  String get localizedDistance {
    if (distanceKm == null && distanceMeters == null) return '';
    final km = distanceKm ?? ((distanceMeters ?? 0) / 1000.0);
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters م';
    } else {
      return '${km.toStringAsFixed(1)} كم';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'formattedAddress': formattedAddress,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'subCategory': subCategory,
      'placeType': placeType,
      'city': city,
      'district': district,
      'mallName': mallName,
      'phone': phone,
      'coordinatesVerified': coordinatesVerified,
      'source': source,
      'aliases': aliases,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'distanceKm': distanceKm,
      'distanceMeters': distanceMeters,
      'isSaved': isSaved,
      'isHistory': isHistory,
      'popularity': popularity,
      'finalScore': finalScore,
    };
  }

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      placeId: json['placeId'] as String? ?? json['id'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble() ?? (json['lon'] as num?)?.toDouble() ?? 0.0,
      placeName: (json['placeName'] as String?) ??
          (json['title'] as String?) ??
          (json['name_ar'] as String?) ??
          (json['name_en'] as String?) ??
          '',
      formattedAddress: (json['formattedAddress'] as String?) ??
          (json['address'] as String?) ??
          (json['address_ar'] as String?) ??
          (json['address_en'] as String?) ??
          '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      category: json['category'] as String?,
      subCategory: json['subCategory'] as String? ?? json['sub_category'] as String?,
      placeType: json['placeType'] as String? ?? json['place_type'] as String?,
      city: json['city'] as String? ?? 'مدينة السادات',
      district: json['district'] as String?,
      mallName: json['mallName'] as String? ?? json['mall_name'] as String? ?? json['parent_place'] as String?,
      phone: json['phone'] as String?,
      coordinatesVerified: json['coordinatesVerified'] == true ||
          json['coordinates_verified'] == true ||
          (json['coordinatesVerified'] == null && json['coordinates_verified'] == null),
      source: json['source'] as String?,
      aliases: (json['aliases'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      nameAr: json['name_ar'] as String? ?? json['nameAr'] as String?,
      nameEn: json['name_en'] as String? ?? json['nameEn'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? (json['distanceKm'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? (json['distanceMeters'] as num?)?.toDouble(),
      isSaved: json['is_saved'] == true || json['isSaved'] == true,
      isHistory: json['is_history'] == true || json['isHistory'] == true,
      popularity: (json['popularity'] as num?)?.toInt() ?? 0,
      finalScore: (json['final_score'] as num?)?.toDouble() ?? (json['finalScore'] as num?)?.toDouble(),
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
      final distKm = _haversineDistance(latitude, longitude, other.latitude, other.longitude);
      if (distKm < 0.1) {
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
    String? category,
    String? subCategory,
    String? placeType,
    String? city,
    String? district,
    String? mallName,
    String? phone,
    bool? coordinatesVerified,
    String? source,
    List<String>? aliases,
    String? nameAr,
    String? nameEn,
    double? distanceKm,
    double? distanceMeters,
    bool? isSaved,
    bool? isHistory,
    int? popularity,
    double? finalScore,
  }) {
    return PlaceLocation(
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      placeType: placeType ?? this.placeType,
      city: city ?? this.city,
      district: district ?? this.district,
      mallName: mallName ?? this.mallName,
      phone: phone ?? this.phone,
      coordinatesVerified: coordinatesVerified ?? this.coordinatesVerified,
      source: source ?? this.source,
      aliases: aliases ?? this.aliases,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      distanceKm: distanceKm ?? this.distanceKm,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isSaved: isSaved ?? this.isSaved,
      isHistory: isHistory ?? this.isHistory,
      popularity: popularity ?? this.popularity,
      finalScore: finalScore ?? this.finalScore,
    );
  }

  @override
  String toString() {
    return 'PlaceLocation(name: $placeName, address: $formattedAddress, lat: $latitude, lng: $longitude, id: $placeId, distKm: $distanceKm)';
  }
}
