class VehicleHelper {
  /// Checks if driver's vehicle type matches the passenger's requested vehicle type or service.
  /// Handles English ('car', 'private_car', 'motorcycle', 'scooter', 'delivery')
  /// and Arabic ('ملاكي', 'سيارة', 'عربية', 'موتوسيكل', 'بايك', 'اسكوتر', 'ديلفري', 'طرد', 'توصيل').
  static bool isVehicleTypeMatching(
    String? driverType, 
    String? requestType, {
    String? serviceType,
  }) {
    final rawS = (serviceType ?? '').trim().toLowerCase();
    final rawR = (requestType ?? '').trim().toLowerCase();
    final isDeliv = rawS == 'delivery' || 
        rawS == 'طرد' || 
        rawS == 'توصيل' || 
        rawS == 'ديلفري' || 
        rawS.contains('delivery') || 
        rawS.contains('توصيل') || 
        rawS.contains('طرد') ||
        rawR == 'delivery' || 
        rawR == 'طرد' || 
        rawR == 'توصيل' || 
        rawR == 'ديلفري' || 
        rawR.contains('delivery') || 
        rawR.contains('توصيل') || 
        rawR.contains('طرد');

    final dNorm = normalizeVehicleType(driverType ?? 'car');
    final rNorm = normalizeVehicleType(requestType ?? 'car');

    // 1. Delivery requests: if customer specifically requested car for a large parcel, only cars match. Otherwise all vehicles match.
    if (isDeliv) {
      if (rNorm == 'car') {
        return dNorm == 'car';
      }
      return true;
    }

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
    
    // Bike / Motorcycle keywords & Egyptian popular models
    if (t == 'motorcycle' ||
        t == 'bike' ||
        t == 'موتوسيكل' ||
        t == 'موتسيكل' ||
        t == 'موتسكل' ||
        t == 'موتوسيكلات' ||
        t == 'بايك' ||
        t == 'دراجة' ||
        t == 'دراجة نارية' ||
        t == 'دراجات' ||
        t.contains('موتوسيكل') ||
        t.contains('موتسيكل') ||
        t.contains('موتسكل') ||
        t.contains('بايك') ||
        t.contains('حلاوة') ||
        t.contains('حلاوه') ||
        t.contains('دايون') ||
        t.contains('dayun') ||
        t.contains('بكسر') ||
        t.contains('بوكسر') ||
        t.contains('boxer') ||
        t.contains('بجاج') ||
        t.contains('bajaj') ||
        t.contains('هوجان') ||
        t.contains('هوجن') ||
        t.contains('haojue') ||
        t.contains('haojiang') ||
        t.contains('بينيلي') ||
        t.contains('بنيللي') ||
        t.contains('benelli') ||
        t.contains('tvs') ||
        t.contains('فيسبا') ||
        t.contains('vespa') ||
        t.contains('هوندا') ||
        t.contains('honda') ||
        t.contains('توكتوك') ||
        t.contains('توك توك')) {
      return 'motorcycle';
    }
    
    // Scooter keywords
    if (t == 'scooter' || 
        t == 'اسكوتر' || 
        t == 'إسكوتر' || 
        t == 'سكوتر' || 
        t == 'سكوترز' ||
        t.contains('اسكوتر') || 
        t.contains('إسكوتر') || 
        t.contains('سكوتر') ||
        t.contains('sym') ||
        t.contains('marine')) {
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
        t.contains('toyota') ||
        t.contains('شيفروليه') ||
        t.contains('شفروليه') ||
        t.contains('chevrolet') ||
        t.contains('نيسان') ||
        t.contains('nissan') ||
        t.contains('هيونداي') ||
        t.contains('hyundai') ||
        t.contains('سوزوكي') ||
        t.contains('suzuki') ||
        t.contains('كيا') ||
        t.contains('kia') ||
        t.contains('فيات') ||
        t.contains('fiat') ||
        t.contains('ملاكي') ||
        t.contains('سيارة') ||
        t.contains('عربية')) {
      return 'car';
    }

    return 'car';
  }

  /// Returns localized display label for vehicle type based on current locale
  static String getLocalizedLabel(String type, bool isArabic) {
    final normalized = normalizeVehicleType(type);
    switch (normalized) {
      case 'motorcycle':
        return isArabic ? 'موتوسيكل / بايك' : 'Motorcycle';
      case 'scooter':
        return isArabic ? 'اسكوتر' : 'Scooter';
      case 'car':
      default:
        return isArabic ? 'سيارة ملاكي' : 'Private Car';
    }
  }

  /// Returns Arabic display label for vehicle type (backwards compatibility)
  static String getArabicLabel(String type) {
    return getLocalizedLabel(type, true);
  }
}

