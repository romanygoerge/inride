class RideRequestModel {
  final String requestId;
  final String passengerId;
  final String? driverId;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationAddress;
  final String vehicleType;
  final double offeredFare;
  final double distance;
  final String status;
  final DateTime createdAt;
  final String paymentMethod;
  final String serviceType;
  final String? packageDescription;
  final String? deliveryNotes;
  final int passengerCount;
  final String? pickupPhotoUrl;
  final String? deliveryPhotoUrl;
  final bool isDeliveryLocationConfirmed;
  final String? recipientPhone;
  final String? recipientRegion;
  final String? recipientStreet;
  final String? recipientBuilding;
  final String? recipientFloor;
  final String? recipientLandmark;
  final String? recipientToken;

  final String? lastCounterDriverId;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime? cancelledAt;

  RideRequestModel({
    required this.requestId,
    required this.passengerId,
    this.driverId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationAddress,
    required this.vehicleType,
    required this.offeredFare,
    required this.distance,
    required this.status,
    required this.createdAt,
    this.paymentMethod = 'كاش',
    this.serviceType = 'ride',
    this.packageDescription,
    this.deliveryNotes,
    this.passengerCount = 1,
    this.pickupPhotoUrl,
    this.deliveryPhotoUrl,
    this.isDeliveryLocationConfirmed = false,
    this.recipientPhone,
    this.recipientRegion,
    this.recipientStreet,
    this.recipientBuilding,
    this.recipientFloor,
    this.recipientLandmark,
    this.recipientToken,
    this.lastCounterDriverId,
    this.cancelledBy,
    this.cancelReason,
    this.cancelledAt,
  });

  RideRequestModel copyWith({
    String? requestId,
    String? passengerId,
    String? driverId,
    double? pickupLatitude,
    double? pickupLongitude,
    String? pickupAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationAddress,
    String? vehicleType,
    double? offeredFare,
    double? distance,
    String? status,
    DateTime? createdAt,
    String? paymentMethod,
    String? serviceType,
    String? packageDescription,
    String? deliveryNotes,
    int? passengerCount,
    String? pickupPhotoUrl,
    String? deliveryPhotoUrl,
    bool? isDeliveryLocationConfirmed,
    String? recipientPhone,
    String? recipientRegion,
    String? recipientStreet,
    String? recipientBuilding,
    String? recipientFloor,
    String? recipientLandmark,
    String? recipientToken,
    String? lastCounterDriverId,
    String? cancelledBy,
    String? cancelReason,
    DateTime? cancelledAt,
  }) {
    return RideRequestModel(
      requestId: requestId ?? this.requestId,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      vehicleType: vehicleType ?? this.vehicleType,
      offeredFare: offeredFare ?? this.offeredFare,
      distance: distance ?? this.distance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      serviceType: serviceType ?? this.serviceType,
      packageDescription: packageDescription ?? this.packageDescription,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      passengerCount: passengerCount ?? this.passengerCount,
      pickupPhotoUrl: pickupPhotoUrl ?? this.pickupPhotoUrl,
      deliveryPhotoUrl: deliveryPhotoUrl ?? this.deliveryPhotoUrl,
      isDeliveryLocationConfirmed: isDeliveryLocationConfirmed ?? this.isDeliveryLocationConfirmed,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      recipientRegion: recipientRegion ?? this.recipientRegion,
      recipientStreet: recipientStreet ?? this.recipientStreet,
      recipientBuilding: recipientBuilding ?? this.recipientBuilding,
      recipientFloor: recipientFloor ?? this.recipientFloor,
      recipientLandmark: recipientLandmark ?? this.recipientLandmark,
      recipientToken: recipientToken ?? this.recipientToken,
      lastCounterDriverId: lastCounterDriverId ?? this.lastCounterDriverId,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  factory RideRequestModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parsedCancelledAt;
    final cAt = data['cancelled_at'] ?? data['cancelledAt'];
    if (cAt != null) {
      if (cAt is int) {
        parsedCancelledAt = DateTime.fromMillisecondsSinceEpoch(cAt);
      } else if (cAt is String) {
        parsedCancelledAt = DateTime.tryParse(cAt);
      } else if (cAt is DateTime) {
        parsedCancelledAt = cAt;
      }
    }

    final rawCreated = data['created_at'] ?? data['createdAt'];
    DateTime createdDate = DateTime.now();
    if (rawCreated is String) {
      createdDate = DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now();
    } else if (rawCreated is int) {
      createdDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is DateTime) {
      createdDate = rawCreated;
    }

    return RideRequestModel(
      requestId: id,
      passengerId: data['passenger_id'] ?? data['passengerId'] ?? '',
      driverId: data['driver_id'] ?? data['driverId'],
      pickupLatitude: ((data['pickup_latitude'] ?? data['pickupLatitude']) as num? ?? 0.0).toDouble(),
      pickupLongitude: ((data['pickup_longitude'] ?? data['pickupLongitude']) as num? ?? 0.0).toDouble(),
      pickupAddress: data['pickup_address'] ?? data['pickupAddress'] ?? '',
      destinationLatitude: ((data['destination_latitude'] ?? data['destinationLatitude']) as num? ?? 0.0).toDouble(),
      destinationLongitude: ((data['destination_longitude'] ?? data['destinationLongitude']) as num? ?? 0.0).toDouble(),
      destinationAddress: data['destination_address'] ?? data['destinationAddress'] ?? '',
      vehicleType: data['vehicle_type'] ?? data['vehicleType'] ?? 'car',
      offeredFare: ((data['offered_fare'] ?? data['offeredFare']) as num? ?? 0.0).toDouble(),
      distance: ((data['distance']) as num? ?? 0.0).toDouble(),
      status: data['status'] ?? 'Pending',
      createdAt: createdDate,
      paymentMethod: data['payment_method'] ?? data['paymentMethod'] ?? 'كاش',
      serviceType: data['service_type'] ?? data['serviceType'] ?? 'ride',
      packageDescription: data['package_description'] ?? data['packageDescription'],
      deliveryNotes: data['delivery_notes'] ?? data['deliveryNotes'],
      passengerCount: ((data['passenger_count'] ?? data['passengerCount']) as num? ?? 1).toInt(),
      pickupPhotoUrl: data['pickup_photo_url'] ?? data['pickupPhotoUrl'],
      deliveryPhotoUrl: data['delivery_photo_url'] ?? data['deliveryPhotoUrl'],
      isDeliveryLocationConfirmed: data['is_delivery_location_confirmed'] ?? data['isDeliveryLocationConfirmed'] ?? true,
      recipientPhone: data['recipient_phone'] ?? data['recipientPhone'],
      recipientRegion: data['recipient_region'] ?? data['recipientRegion'],
      recipientStreet: data['recipient_street'] ?? data['recipientStreet'],
      recipientBuilding: data['recipient_building'] ?? data['recipientBuilding'],
      recipientFloor: data['recipient_floor'] ?? data['recipientFloor'],
      recipientLandmark: data['recipient_landmark'] ?? data['recipientLandmark'],
      recipientToken: data['recipient_token'] ?? data['recipientToken'],
      lastCounterDriverId: data['last_counter_driver_id'] ?? data['lastCounterDriverId'],
      cancelledBy: data['cancelled_by'] ?? data['cancelledBy'],
      cancelReason: data['cancel_reason'] ?? data['cancellationReason'] ?? data['cancelReason'],
      cancelledAt: parsedCancelledAt,
    );
  }

  Map<String, dynamic> toMap() {
    return toDatabaseMap();
  }

  /// Returns ONLY valid PostgreSQL column names for Supabase `ride_requests` table
  Map<String, dynamic> toDatabaseMap() {
    final map = <String, dynamic>{
      'id': requestId,
      'passenger_id': passengerId,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'pickup_address': pickupAddress,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'destination_address': destinationAddress,
      'vehicle_type': vehicleType,
      'offered_fare': offeredFare,
      'distance': distance,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'payment_method': paymentMethod,
      'service_type': serviceType,
      'passenger_count': passengerCount,
      'is_delivery_location_confirmed': isDeliveryLocationConfirmed,
    };

    if (driverId != null) map['driver_id'] = driverId;
    if (packageDescription != null) map['package_description'] = packageDescription;
    if (deliveryNotes != null) map['delivery_notes'] = deliveryNotes;
    if (pickupPhotoUrl != null) map['pickup_photo_url'] = pickupPhotoUrl;
    if (deliveryPhotoUrl != null) map['delivery_photo_url'] = deliveryPhotoUrl;
    if (recipientPhone != null) map['recipient_phone'] = recipientPhone;
    if (recipientRegion != null) map['recipient_region'] = recipientRegion;
    if (recipientStreet != null) map['recipient_street'] = recipientStreet;
    if (recipientBuilding != null) map['recipient_building'] = recipientBuilding;
    if (recipientFloor != null) map['recipient_floor'] = recipientFloor;
    if (recipientLandmark != null) map['recipient_landmark'] = recipientLandmark;
    if (recipientToken != null) map['recipient_token'] = recipientToken;
    if (lastCounterDriverId != null) map['last_counter_driver_id'] = lastCounterDriverId;
    if (cancelledBy != null) map['cancelled_by'] = cancelledBy;
    if (cancelReason != null) {
      map['cancel_reason'] = cancelReason;
      map['cancellation_reason'] = cancelReason;
    }
    if (cancelledAt != null) map['cancelled_at'] = cancelledAt!.toIso8601String();

    return map;
  }
}
