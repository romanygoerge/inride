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
    'defaultFareCar': 45.0,
    'defaultFareScooter': 20.0,
    'defaultFareMotorcycle': 15.0,
    'commissionRate': 10.0,
    'minFare': 10.0,
    'maxFare': 500.0,
    'demo_mode_enabled': true,
    'demo_phone': '01000000000',
    'demo_otp': '123456',
    'demo_driver_name': 'كابتن تجريبي (Demo)',
    'demo_passenger_name': 'راكب تجريبي (Demo)',
  };

  void initSettingsListener(VoidCallback onUpdate) {
    try {
      _supabase.from('app_settings').select().maybeSingle().then((data) {
        if (data != null) {
          appSettings.addAll(Map<String, dynamic>.from(data));
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
          onUpdate();
        }
      });
    } catch (e) {
      debugPrint('[AppSettingsModule] Error initializing settings listener: $e');
    }
  }
}
