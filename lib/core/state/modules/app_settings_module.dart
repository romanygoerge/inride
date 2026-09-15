import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Module responsible for application settings and fare configuration.
class AppSettingsModule {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic> appSettings = {
    'first_km_fare': 20.0,
    'extra_km_fare': 5.0,
    'ac_km_fare': 1.0,
    'heat_hour_km_fare': 1.0,
    'heat_start_hour': 11,
    'heat_end_hour': 15,
    'out_of_city_threshold_km': 5.0,
    'out_of_city_extra_fare': 20.0,
    'out_of_city_pricing_enabled': true,
    'defaultFareCar': 45.0,
    'defaultFareScooter': 20.0,
    'defaultFareMotorcycle': 15.0,
    'commissionRate': 10.0,
    'commission_rate': 10.0,
    'minFare': 10.0,
    'maxFare': 500.0,
    'demo_mode_enabled': false,
    'demo_passenger_enabled': false,
    'demo_driver_enabled': false,
    'demo_phone': '01000000000',
    'demo_otp': '123456',
    'demo_driver_name': 'كابتن تجريبي (Demo)',
    'demo_passenger_name': 'راكب تجريبي (Demo)',
    'otp_support_whatsapp': '01204062941',
    'is_maintenance_mode': false,
    'maintenance_title': 'التطبيق تحت الصيانة حالياً',
    'maintenance_message': 'نعمل على تحسين وتحديث خدمات inRide لنقدم لكم تجربة أفضل وأسرع. سنعود للعمل قريباً جداً.',
  };

  double get outOfCityThresholdKm =>
      (appSettings['out_of_city_threshold_km'] as num?)?.toDouble() ?? 5.0;
  double get outOfCityExtraFare =>
      (appSettings['out_of_city_extra_fare'] as num?)?.toDouble() ?? 20.0;
  bool get isOutOfCityPricingEnabled =>
      appSettings['out_of_city_pricing_enabled'] != false;

  bool get isMaintenanceMode => appSettings['is_maintenance_mode'] == true;
  String get maintenanceTitle =>
      (appSettings['maintenance_title'] as String?)?.isNotEmpty == true
          ? appSettings['maintenance_title'] as String
          : 'التطبيق تحت الصيانة حالياً';
  String get maintenanceMessage =>
      (appSettings['maintenance_message'] as String?)?.isNotEmpty == true
          ? appSettings['maintenance_message'] as String
          : 'نعمل على تحسين وتحديث خدمات inRide لنقدم لكم تجربة أفضل وأسرع. سنعود للعمل قريباً جداً.';

  Future<void> refreshSettings(VoidCallback onUpdate) async {
    try {
      final data = await _supabase.from('app_settings').select().maybeSingle();
      if (data != null) {
        appSettings.addAll(Map<String, dynamic>.from(data));
        if (data['commission_rate'] != null) {
          appSettings['commissionRate'] = (data['commission_rate'] as num).toDouble();
        }
        onUpdate();
      }
    } catch (e) {
      debugPrint('[AppSettingsModule] Error refreshing settings: $e');
    }
  }

  void initSettingsListener(VoidCallback onUpdate) {
    try {
      _supabase.from('app_settings').select().maybeSingle().then((data) {
        if (data != null) {
          appSettings.addAll(Map<String, dynamic>.from(data));
          if (data['commission_rate'] != null) {
            appSettings['commissionRate'] = (data['commission_rate'] as num).toDouble();
          }
          onUpdate();
        }
      }).catchError((e) {
        debugPrint('[AppSettingsModule] Error fetching initial settings: $e');
      });

      _supabase
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .listen((dataList) {
        if (dataList.isNotEmpty) {
          appSettings.addAll(Map<String, dynamic>.from(dataList.first));
          if (dataList.first['commission_rate'] != null) {
            appSettings['commissionRate'] = (dataList.first['commission_rate'] as num).toDouble();
          }
          onUpdate();
        }
      });
    } catch (e) {
      debugPrint('[AppSettingsModule] Error initializing settings listener: $e');
    }
  }
}
