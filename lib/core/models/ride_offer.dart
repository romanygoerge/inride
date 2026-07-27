enum OfferStatus { pending, accepted, rejected, countered }

class RideOffer {
  final String id;
  final String driverId;
  final String passengerId;
  final String driverName;
  final String driverAvatar;
  final double driverRating;
  final String vehicleType;
  final String vehicleName;
  final String licensePlate;
  final double price;
  final Duration eta;
  final DateTime timestamp;
  final OfferStatus status;
  final String requestId;

  RideOffer({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.driverName,
    required this.driverAvatar,
    required this.driverRating,
    required this.vehicleType,
    required this.vehicleName,
    required this.licensePlate,
    required this.price,
    required this.eta,
    required this.timestamp,
    required this.status,
    required this.requestId,
  });

  factory RideOffer.fromMap(Map<String, dynamic> data) {
    final timeRaw = data['created_at'] ?? data['timestamp'];
    DateTime timeObj = DateTime.now();
    if (timeRaw is String) {
      timeObj = DateTime.tryParse(timeRaw) ?? DateTime.now();
    } else if (timeRaw is DateTime) {
      timeObj = timeRaw;
    }

    return RideOffer(
      id: data['id'] as String? ?? '',
      driverId: data['driver_id'] ?? data['driverId'] ?? '',
      passengerId: data['passenger_id'] ?? data['passengerId'] ?? '',
      driverName: data['driver_name'] ?? data['driverName'] ?? 'سائق',
      driverAvatar: data['driver_avatar'] ?? data['driverAvatar'] ?? '',
      driverRating: ((data['driver_rating'] ?? data['driverRating']) as num?)?.toDouble() ?? 5.0,
      vehicleType: data['vehicle_type'] ?? data['vehicleType'] ?? 'car',
      vehicleName: data['vehicle_name'] ?? data['vehicleName'] ?? '',
      licensePlate: data['license_plate'] ?? data['licensePlate'] ?? '',
      price: ((data['price'] as num? ?? 0.0)).toDouble(),
      eta: Duration(minutes: ((data['eta_minutes'] ?? data['etaMinutes']) as num? ?? 5).toInt()),
      timestamp: timeObj,
      status: _parseStatus(data['status'] as String? ?? 'pending'),
      requestId: data['request_id'] ?? data['requestId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return toDatabaseMap();
  }

  /// Returns ONLY valid PostgreSQL column names for Supabase `ride_offers` table
  Map<String, dynamic> toDatabaseMap() {
    final map = <String, dynamic>{
      'id': id,
      'request_id': requestId,
      'driver_id': driverId,
      'driver_name': driverName,
      'driver_avatar': driverAvatar,
      'driver_rating': driverRating,
      'vehicle_type': vehicleType,
      'vehicle_name': vehicleName,
      'license_plate': licensePlate,
      'price': price,
      'eta_minutes': eta.inMinutes,
      'created_at': timestamp.toUtc().toIso8601String(),
      'status': _statusToString(status),
    };
    if (passengerId.trim().isNotEmpty) {
      map['passenger_id'] = passengerId.trim();
    }
    return map;
  }

  static OfferStatus _parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return OfferStatus.accepted;
      case 'rejected':
        return OfferStatus.rejected;
      case 'countered':
        return OfferStatus.countered;
      default:
        return OfferStatus.pending;
    }
  }

  static String _statusToString(OfferStatus status) {
    switch (status) {
      case OfferStatus.accepted:
        return 'accepted';
      case OfferStatus.rejected:
        return 'rejected';
      case OfferStatus.countered:
        return 'countered';
      case OfferStatus.pending:
        return 'pending';
    }
  }
}
