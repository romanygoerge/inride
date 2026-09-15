import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'location_service.dart';
import '../utils/app_logger.dart';
import '../utils/map_coordinates_helper.dart';
import '../state/global_state.dart';

class DriverLocationService {
  static final DriverLocationService instance = DriverLocationService._internal();
  factory DriverLocationService() => instance;
  DriverLocationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _locationTimer;
  bool _isUpdating = false;

  bool get isUpdating => _isUpdating;

  /// Starts periodic location updates for the driver every 10 seconds.
  Future<void> startLocationUpdates(String driverId, {String collectionName = 'drivers'}) async {
    if (_isUpdating) return;

    final hasPermission = await LocationService.instance.checkPermission();
    if (!hasPermission) {
      AppLogger.driverCheckLog(driverId, false, 'Location permission denied in DriverLocationService');
      throw Exception('Location permission not granted');
    }

    _isUpdating = true;
    await _updateDriverLocation(driverId);

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _updateDriverLocation(driverId);
    });
    AppLogger.rideLog('DriverLocation', 'Started periodic location updates for driver $driverId');
  }

  /// Stops the periodic location updates and sets driver offline.
  Future<void> stopLocationUpdates(String driverId, {String collectionName = 'drivers'}) async {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isUpdating = false;

    try {
      await _supabase.from('drivers').update({
        'is_online': false,
        'is_available': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', driverId);
      AppLogger.rideLog('DriverLocation', 'Stopped location updates and set driver $driverId offline');
    } catch (e, stack) {
      AppLogger.error('DriverLocation', 'Error setting driver $driverId offline', e, stack);
    }
  }

  /// Internal helper to fetch current position and update Supabase with valid PostgreSQL columns.
  /// If the device is offline, the location is cached in GlobalState and flushed on reconnection.
  Future<void> _updateDriverLocation(String driverId) async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      double? latitude = position?.latitude ?? MapCoordinatesHelper.deviceLocation?.latitude;
      double? longitude = position?.longitude ?? MapCoordinatesHelper.deviceLocation?.longitude;

      // If offline, cache the location and skip Supabase write
      if (GlobalState.instance.isOffline) {
        if (latitude != null && longitude != null) {
          GlobalState.instance.cacheDriverLocation(LatLng(latitude, longitude));
          AppLogger.rideLog('DriverLocation', 'Offline – cached location for driver $driverId', extra: {
            'lat': latitude,
            'lng': longitude,
          });
        }
        return;
      }

      final updateData = <String, dynamic>{
        'id': driverId,
        'is_online': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (latitude != null && longitude != null) {
        updateData['current_latitude'] = latitude;
        updateData['current_longitude'] = longitude;
      }

      await _supabase.from('drivers').upsert(updateData);
      AppLogger.rideLog('DriverLocation', 'Updated location for driver $driverId', extra: {
        'lat': latitude,
        'lng': longitude,
      });
    } catch (e, stack) {
      AppLogger.error('DriverLocation', 'Error updating location for driver $driverId', e, stack);
    }
  }

  /// Called on reconnection to send the latest cached location to Supabase.
  /// Only sends the most recent location for efficiency.
  Future<void> flushCachedLocations(String driverId) async {
    final cachedLocations = GlobalState.instance.getCachedDriverLocations();
    if (cachedLocations.isEmpty) return;

    // Only send the latest location (most relevant)
    final latest = cachedLocations.last;
    try {
      final updateData = <String, dynamic>{
        'id': driverId,
        'is_online': true,
        'current_latitude': latest.latitude,
        'current_longitude': latest.longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _supabase.from('drivers').upsert(updateData);
      GlobalState.instance.clearCachedDriverLocations();
      AppLogger.rideLog('DriverLocation', 'Flushed cached location for driver $driverId', extra: {
        'lat': latest.latitude,
        'lng': latest.longitude,
        'discarded': cachedLocations.length - 1,
      });
    } catch (e, stack) {
      AppLogger.error('DriverLocation', 'Error flushing cached locations for $driverId', e, stack);
    }
  }
}
