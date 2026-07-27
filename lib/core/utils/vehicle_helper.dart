class VehicleHelper {
  /// Checks if driver's vehicle type matches the passenger's requested vehicle type.
  /// Handles English ('car', 'private_car', 'motorcycle', 'scooter') and Arabic ('ملاكي', 'سيارة', 'عربية', 'موتوسيكل', 'بايك', 'اسكوتر', 'ديلفري').
  static bool isVehicleTypeMatching(String? driverType, String? requestType) {
    if (driverType == null || driverType.trim().isEmpty || requestType == null || requestType.trim().isEmpty) {
      return true; // Don't block if unspecified
    }

    final rawR = requestType.trim().toLowerCase();
    // Delivery requests can be served by any driver vehicle type
    if (rawR == 'delivery' || rawR == 'طرد' || rawR == 'توصيل' || rawR == 'ديلفري') {
      return true;
    }

    final dNorm = normalizeVehicleType(driverType);
    final rNorm = normalizeVehicleType(requestType);

    // Direct normalized match (car vs car, motorcycle vs motorcycle, scooter vs scooter)
    if (dNorm == rNorm) return true;

    // Both bikes/motorcycles and scooters can serve bike/scooter ride requests
    if ((dNorm == 'motorcycle' || dNorm == 'scooter') && (rNorm == 'motorcycle' || rNorm == 'scooter')) {
      return true;
    }

    // Car drivers can serve car ride requests
    if (dNorm == 'car' && rNorm == 'car') {
      return true;
    }

    return false;
  }

  /// Normalizes vehicle type to standard key ('car', 'motorcycle', 'scooter')
  static String normalizeVehicleType(String rawType) {
    final t = rawType.trim().toLowerCase();
    if (t.isEmpty) return 'car';
    
    // Bike / Motorcycle keywords & models
    if (t == 'motorcycle' ||
        t == 'bike' ||
        t == 'موتوسيكل' ||
        t == 'موتسيكل' ||
        t == 'بايك' ||
        t == 'دراجة' ||
        t == 'دراجة نارية' ||
        t.contains('موتوسيكل') ||
        t.contains('بايك') ||
        t.contains('حلاوة') ||
        t.contains('دايون') ||
        t.contains('بكسر') ||
        t.contains('فيسبا') ||
        t.contains('هوندا') ||
        t.contains('توكتوك') ||
        t.contains('توك توك')) {
      return 'motorcycle';
    }
    
    // Scooter keywords
    if (t == 'scooter' || t == 'اسكوتر' || t == 'إسكوتر' || t.contains('اسكوتر')) {
      return 'scooter';
    }

    // Car / Private Car keywords & models
    if (t == 'car' ||
        t == 'private_car' ||
        t == 'سيارة' ||
        t == 'عربية' ||
        t == 'ملاكي' ||
        t == 'سيارة ملاكي' ||
        t == 'عربية ملاكي' ||
        t == 'تاكسي' ||
        t == 'ride' ||
        t == 'trip' ||
        t.contains('جامبو') ||
        t.contains('تويوتا') ||
        t.contains('شيفروليه') ||
        t.contains('شفروليه') ||
        t.contains('نيسان') ||
        t.contains('هيونداي') ||
        t.contains('سوزوكي') ||
        t.contains('كيا') ||
        t.contains('فيات') ||
        t.contains('ملاكي') ||
        t.contains('سيارة') ||
        t.contains('عربية')) {
      return 'car';
    }

    return 'car';
  }

  /// Returns Arabic display label for vehicle type
  static String getArabicLabel(String type) {
    final normalized = normalizeVehicleType(type);
    switch (normalized) {
      case 'motorcycle':
        return 'موتوسيكل / بايك';
      case 'scooter':
        return 'اسكوتر';
      case 'car':
      default:
        return 'سيارة ملاكي';
    }
  }
}
