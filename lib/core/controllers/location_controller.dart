import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import 'navigation_state.dart';
import 'navigation_state_manager.dart';

/// Callback signature for valid location updates.
typedef LocationUpdateCallback = void Function(LatLng location, double speed, double accuracy, double heading);

/// Manages GPS location stream, applies quality filters (accuracy, jump detection),
/// handles GPS loss detection, and publishes valid location updates.
///
/// This controller replaces the GPS stream management previously scattered across
/// [TripNavigationManager] and [OsmMapWidget].
class LocationController {
  final LocationService _locationService;
  final NavigationStateManager _stateManager;

  StreamSubscription<Position>? _gpsSubscription;
  Timer? _gpsLostTimer;
  Position? _lastAcceptedPosition;
  bool _isActive = false;

  /// Called on every valid, filtered GPS update.
  LocationUpdateCallback? onLocationUpdate;

  /// Duration without GPS updates before declaring signal lost.
  static const Duration gpsLostThreshold = Duration(seconds: 8);

  /// Maximum GPS accuracy in meters to accept a reading.
  static const double maxAccuracy = 25.0;

  /// Maximum speed in m/s that is physically plausible (126 km/h).
  static const double maxPlausibleSpeed = 35.0;

  /// Minimum distance in meters for a jump to be suspicious.
  static const double jumpDistanceThreshold = 60.0;

  LocationController({
    required LocationService locationService,
    required NavigationStateManager stateManager,
  })  : _locationService = locationService,
        _stateManager = stateManager;

  bool get isActive => _isActive;
  Position? get lastPosition => _lastAcceptedPosition;

  /// Starts listening to the GPS location stream.
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    _gpsSubscription?.cancel();
    _gpsSubscription = _locationService.getLocationStream().listen(
      _onRawGpsUpdate,
      onError: (err) {
        debugPrint('[LocationController] GPS Stream error: $err');
        _onGpsLost();
      },
      cancelOnError: false,
    );

    _resetGpsLostTimer();

    // Trigger an initial position immediately
    try {
      final currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      ).timeout(const Duration(seconds: 2));
      _onRawGpsUpdate(currentPos);
    } catch (_) {
      // Will rely on stream updates
    }
  }

  /// Stops listening to GPS and cleans up timers.
  void stop() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _gpsLostTimer?.cancel();
    _gpsLostTimer = null;
    _isActive = false;
    _lastAcceptedPosition = null;
  }

  /// Processes a raw GPS update through quality filters.
  void _onRawGpsUpdate(Position pos) {
    if (!_isActive) return;

    // Reset GPS lost timer
    _resetGpsLostTimer();

    // Restore active status if GPS was lost
    if (_stateManager.phase == NavigationPhase.gpsLost) {
      _stateManager.setPhase(NavigationPhase.activeNavigation);
    }

    // Apply quality filters
    if (!_shouldAcceptPosition(pos)) return;

    _lastAcceptedPosition = pos;

    final rawLatLng = LatLng(pos.latitude, pos.longitude);
    final speed = pos.speed >= 0.0 ? pos.speed : 0.0;

    // Update motion state
    _stateManager.updateMotion(speed, pos.heading);

    // Notify observers
    onLocationUpdate?.call(rawLatLng, speed, pos.accuracy, pos.heading);
  }

  /// Validates GPS position quality before accepting it.
  bool _shouldAcceptPosition(Position newPos) {
    // Accuracy filter
    if (newPos.accuracy <= 0 || newPos.accuracy > maxAccuracy) {
      return false;
    }

    // First position is always accepted
    if (_lastAcceptedPosition == null) {
      return true;
    }

    // Jump filter: detect sudden jumps due to GPS noise
    final double dt = newPos.timestamp
        .difference(_lastAcceptedPosition!.timestamp)
        .inMilliseconds / 1000.0;

    if (dt > 0) {
      final double distance = Geolocator.distanceBetween(
        _lastAcceptedPosition!.latitude,
        _lastAcceptedPosition!.longitude,
        newPos.latitude,
        newPos.longitude,
      );

      final double speed = distance / dt;
      if (speed > maxPlausibleSpeed && distance > jumpDistanceThreshold && dt < 15.0) {
        debugPrint('[LocationController] Rejected GPS jump: ${distance.toInt()}m in ${dt.toStringAsFixed(1)}s');
        return false;
      }
    }

    return true;
  }

  void _resetGpsLostTimer() {
    _gpsLostTimer?.cancel();
    _gpsLostTimer = Timer(gpsLostThreshold, _onGpsLost);
  }

  void _onGpsLost() {
    if (!_isActive) return;
    debugPrint('[LocationController] GPS signal lost!');
    _stateManager.setPhase(NavigationPhase.gpsLost, message: 'تم فقدان إشارة GPS');
  }

  void dispose() {
    stop();
  }
}
