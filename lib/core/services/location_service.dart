import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../utils/map_coordinates_helper.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;
  LocationService._internal();

  /// Check if location services are enabled and permissions are granted.
  /// Requests permission if not yet determined.
  Future<bool> checkPermission() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Location permission check failed or unsupported on this platform: $e");
      return false;
    }
  }

  /// Get the current user location.
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      );
      MapCoordinatesHelper.deviceLocation = LatLng(position.latitude, position.longitude);
      return position;
    } catch (e) {
      debugPrint("getCurrentPosition failed, trying last known position: $e");
      try {
        // Return last known position if current position fails
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          MapCoordinatesHelper.deviceLocation = LatLng(position.latitude, position.longitude);
        }
        return position;
      } catch (e2) {
        debugPrint("getLastKnownPosition also failed: $e2");
        return null;
      }
    }
  }

  /// Listen to live location updates.
  Stream<Position> getLocationStream() {
    try {
      late final LocationSettings settings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: "التطبيق يتتبع موقعك لتقديم خدمة أفضل ومزامنة الرحلة",
            notificationTitle: "تتبع الموقع مباشر",
            enableWakeLock: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        settings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );
      }

      return Geolocator.getPositionStream(locationSettings: settings).map((pos) {
        MapCoordinatesHelper.deviceLocation = LatLng(pos.latitude, pos.longitude);
        return pos;
      }).handleError((error) {
        debugPrint("Location stream error caught: $error");
      });
    } catch (e) {
      debugPrint("Failed to initialize position stream: $e");
      return const Stream.empty();
    }
  }

  /// Compute distance between two coordinates in kilometers.
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    try {
      double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
      return distanceInMeters / 1000.0;
    } catch (e) {
      debugPrint("Failed to calculate distance: $e");
      return 0.0;
    }
  }
}
