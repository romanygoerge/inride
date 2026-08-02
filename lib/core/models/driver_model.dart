class DriverModel {
  final String uid;
  final bool isOnline;
  final bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? vehicleId;
  final String verificationStatus; // 'unregistered' | 'submitted' | 'verified'
  final double? rating;
  final int? ratingCount;
  final int? completedTrips;

  DriverModel({
    required this.uid,
    required this.isOnline,
    required this.isAvailable,
    this.currentLatitude,
    this.currentLongitude,
    this.vehicleId,
    required this.verificationStatus,
    this.rating,
    this.ratingCount,
    this.completedTrips,
  });

  factory DriverModel.fromMap(Map<String, dynamic> data, String id) {
    return DriverModel(
      uid: id,
      isOnline: data['is_online'] ?? data['isOnline'] ?? false,
      isAvailable: data['is_available'] ?? data['isAvailable'] ?? false,
      currentLatitude: ((data['current_latitude'] ?? data['currentLatitude']) as num?)?.toDouble(),
      currentLongitude: ((data['current_longitude'] ?? data['currentLongitude']) as num?)?.toDouble(),
      vehicleId: data['vehicle_id'] ?? data['vehicleId'],
      verificationStatus: data['verification_status'] ?? data['verificationStatus'] ?? 'unregistered',
      rating: (data['rating'] as num?)?.toDouble(),
      ratingCount: (data['rating_count'] ?? data['ratingCount'] ?? data['total_ratings']) as int?,
      completedTrips: (data['total_trips'] ?? data['completedTrips']) as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'vehicleId': vehicleId,
      'verificationStatus': verificationStatus,
      'rating': rating,
      'ratingCount': ratingCount,
      'completedTrips': completedTrips,
    };
  }

  /// Returns ONLY valid PostgreSQL column names for Supabase `drivers` table
  Map<String, dynamic> toDatabaseMap() {
    final map = <String, dynamic>{
      'id': uid,
      'is_online': isOnline,
      'is_available': isAvailable,
      'verification_status': verificationStatus,
    };
    if (currentLatitude != null) map['current_latitude'] = currentLatitude;
    if (currentLongitude != null) map['current_longitude'] = currentLongitude;
    if (vehicleId != null) map['vehicle_id'] = vehicleId;
    if (rating != null) map['rating'] = rating;
    if (completedTrips != null) map['total_trips'] = completedTrips;
    return map;
  }
}
