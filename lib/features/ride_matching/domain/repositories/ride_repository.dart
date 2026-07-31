abstract class IRideRepository {
  Future<String> createRideRequest({
    required String passengerId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double destLat,
    required double destLng,
    required String destAddress,
    required String vehicleType,
    required double offeredFare,
    required double distance,
    required String paymentMethod,
    String serviceType = 'ride',
    String? packageDescription,
    String? deliveryNotes,
    int passengerCount = 1,
    bool isDeliveryLocationConfirmed = true,
    String? recipientPhone,
    String? recipientRegion,
    String? recipientStreet,
    String? recipientBuilding,
    String? recipientFloor,
    String? recipientLandmark,
    String? recipientToken,
  });

  Future<List<Map<String, dynamic>>> searchAvailableDrivers({
    required double pickupLat,
    required double pickupLng,
    required String vehicleType,
    required double maxRangeKm,
  });

  Future<bool> sendDriverBid({
    required String requestId,
    required String driverId,
    required double bidPrice,
    required int etaMinutes,
  });

  Future<bool> acceptDriverBid({
    required String requestId,
    required String driverId,
    required double agreedPrice,
  });

  Future<void> cancelRideRequest({
    required String requestId,
    required String reason,
    required String cancelledBy,
  });

  Future<void> completeRide({
    required String requestId,
    required String driverId,
    required double fare,
  });
}
