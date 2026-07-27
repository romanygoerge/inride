import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:latlong2/latlong.dart';
import '../state/global_state.dart';
import '../services/location_service.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/navigation_state_manager.dart';
import '../controllers/route_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/route_recalculation_controller.dart';
import '../controllers/camera_controller.dart';
import '../controllers/camera_animation_controller.dart';
import '../controllers/map_controller.dart';
import '../controllers/polyline_manager.dart';
import '../controllers/marker_manager.dart';

/// High-level trip navigation orchestrator.
///
/// Bridges the navigation system with the trip lifecycle (Supabase sync,
/// arrival detection, trip statistics). This is a **thin coordinator** that
/// delegates actual navigation work to specialized controllers.
class TripNavigationManager {
  final NavigationController _navigationController;
  final NavigationStateManager _stateManager;
  final RouteController _routeController;
  final LocationController _locationController;
  final RouteRecalculationController _reRouteController;
  final LocationService _locationService;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Map components (bound at runtime)
  MapController? _mapController;
  PolylineManager? _polylineManager;
  MarkerManager? _markerManager;
  CameraController? _cameraController;
  CameraAnimationController? _cameraAnimationController;

  bool _isNavigating = false;
  String? _activeRideId;
  RideStatus? _currentStatus;
  LatLng? _targetDestination;

  // Trip statistics
  DateTime? _tripStartTime;
  double _totalDistanceTraveled = 0.0;
  LatLng? _lastLoggedLocation;
  final List<double> _speeds = [];
  List<LatLng>? _secondaryRoutePoints;
  bool _isTrackingOnly = false;
  bool _hasShownArrivalOverlay = false;

  TripNavigationManager({
    required NavigationController navigationController,
    required NavigationStateManager stateManager,
    required RouteController routeController,
    required LocationController locationController,
    required RouteRecalculationController reRouteController,
    required LocationService locationService,
  })  : _navigationController = navigationController,
        _stateManager = stateManager,
        _routeController = routeController,
        _locationController = locationController,
        _reRouteController = reRouteController,
        _locationService = locationService;

  bool get isNavigating => _isNavigating;
  LatLng? get targetDestination => _targetDestination;
  NavigationController get navigationController => _navigationController;
  CameraController? get cameraController => _cameraController;

  /// Binds map components and creates camera controllers.
  void initialize(MapController mapController, TickerProvider vsync) {
    _mapController = mapController;
    _polylineManager = PolylineManager(mapController: mapController);
    _markerManager = MarkerManager(mapController: mapController, vsync: vsync);
    _cameraController = CameraController(
      mapController: mapController,
      stateManager: _stateManager,
    );
    _cameraAnimationController = CameraAnimationController(mapController: mapController);

    // Wire up reroute completion to redraw
    _reRouteController.onRerouteComplete = _onRerouteComplete;
  }

  /// Redraws active route and markers after map is bound/recreated.
  Future<void> restoreActiveRoute() async {
    if (!_isNavigating || _mapController == null || !_mapController!.isBound) return;

    final route = _stateManager.activeRoute;
    if (route != null && route.points.isNotEmpty) {
      await _polylineManager?.drawRoute(route.points, secondaryPoints: _secondaryRoutePoints);

      final start = route.points.first;
      final end = route.points.last;
      await _markerManager?.addPickupMarker(start);
      await _markerManager?.addDestinationMarker(end);

      final driverPos = _stateManager.snappedLocation ?? _lastLoggedLocation ?? start;
      final state = GlobalState.instance;
      await _markerManager?.updateDriverMarker(driverPos, state.driverBearing, state.selectedVehicleType);

      await _cameraAnimationController?.fitRouteBounds(start, end);
    }
  }

  /// Start navigation to a destination.
  Future<void> startNavigation({
    required String rideId,
    required RideStatus status,
    required LatLng start,
    required LatLng end,
    LatLng? finalDestination,
  }) async {
    if (_isNavigating) await stopNavigation();

    _activeRideId = rideId;
    _currentStatus = status;
    _targetDestination = end;
    _isNavigating = true;
    _isTrackingOnly = false;
    _hasShownArrivalOverlay = false;

    // Reset statistics
    _tripStartTime = DateTime.now();
    _totalDistanceTraveled = 0.0;
    _lastLoggedLocation = start;
    _speeds.clear();

    // Set reroute destination
    _reRouteController.setDestination(end);

    // Fetch initial route
    final route = await _routeController.fetchRoute(start, end);

    _secondaryRoutePoints = null;
    if (finalDestination != null) {
      final route2 = await _routeController.fetchSecondaryRoute(end, finalDestination);
      if (route2 != null) {
        _secondaryRoutePoints = route2.points;
      }
    }

    if (route != null && _mapController != null && _mapController!.isBound) {
      // Initialize navigation
      _navigationController.startNavigation(route);

      await _polylineManager?.drawRoute(route.points, secondaryPoints: _secondaryRoutePoints);
      await _markerManager?.addPickupMarker(start);
      await _markerManager?.addDestinationMarker(end);
      if (finalDestination != null) {
        await _markerManager?.addDestinationMarker(finalDestination);
        await _cameraAnimationController?.fitRouteBounds(start, finalDestination);
      } else {
        await _cameraAnimationController?.fitRouteBounds(start, end);
      }
    }

    // Start GPS stream with location callback
    _locationController.onLocationUpdate = _onLocationUpdated;
    await _locationController.start();
  }

  /// Start tracking without drawing routes or triggering turn-by-turn navigation.
  Future<void> startTracking({
    required String rideId,
    required RideStatus status,
    required LatLng start,
    required LatLng end,
    LatLng? finalDestination,
  }) async {
    if (_isNavigating) await stopNavigation();

    _activeRideId = rideId;
    _currentStatus = status;
    _targetDestination = end;
    _isNavigating = true;
    _isTrackingOnly = true;
    _hasShownArrivalOverlay = false;

    // Reset statistics
    _tripStartTime = DateTime.now();
    _totalDistanceTraveled = 0.0;
    _lastLoggedLocation = start;
    _speeds.clear();

    if (_mapController != null && _mapController!.isBound) {
      await _markerManager?.addPickupMarker(start);
      await _markerManager?.addDestinationMarker(end);
      if (finalDestination != null) {
        await _markerManager?.addDestinationMarker(finalDestination);
        await _cameraAnimationController?.fitRouteBounds(start, finalDestination);
      } else {
        await _cameraAnimationController?.fitRouteBounds(start, end);
      }
    }

    // Start GPS stream with location callback
    _locationController.onLocationUpdate = _onLocationUpdated;
    await _locationController.start();
  }

  /// Process live GPS updates.
  Future<void> _onLocationUpdated(LatLng rawLatLng, double speed, double accuracy, double heading) async {
    if (!_isNavigating || _targetDestination == null) return;

    _speeds.add(speed);

    if (_lastLoggedLocation != null) {
      final dist = _locationService.calculateDistance(
        _lastLoggedLocation!.latitude,
        _lastLoggedLocation!.longitude,
        rawLatLng.latitude,
        rawLatLng.longitude,
      );
      _totalDistanceTraveled += dist;
    }
    _lastLoggedLocation = rawLatLng;

    final state = GlobalState.instance;
    LatLng compareLatLng = rawLatLng;
    double? remDistKm;
    int? etaMins;

    if (!_isTrackingOnly) {
      _navigationController.updateLocation(rawLatLng, speed, accuracy: accuracy);

      final snappedLatLng = _stateManager.snappedLocation ?? rawLatLng;
      compareLatLng = snappedLatLng;

      await _markerManager?.updateDriverMarker(snappedLatLng, heading, state.selectedVehicleType);
      await _cameraController?.updateCamera(snappedLatLng, heading, speed);

      if (_stateManager.activeRoute != null) {
        final idx = _stateManager.currentStepIndex;
        final steps = _stateManager.activeRoute!.steps;
        if (idx < steps.length) {
          await _polylineManager?.updateRouteProgress(
            _stateManager.activeRoute!.points,
            steps[idx].pointIndex,
            secondaryPoints: _secondaryRoutePoints,
          );
        }
      }

      remDistKm = _stateManager.remainingDistance / 1000.0;
      etaMins = (_stateManager.remainingDuration / 60.0).ceil().clamp(1, 45);

      _reRouteController.checkAndReroute(snappedLatLng);
    } else {
      await _markerManager?.updateDriverMarker(rawLatLng, heading, state.selectedVehicleType);
      
      final straightLineDist = _locationService.calculateDistance(
        rawLatLng.latitude,
        rawLatLng.longitude,
        _targetDestination!.latitude,
        _targetDestination!.longitude,
      );
      
      remDistKm = straightLineDist;
      etaMins = ((straightLineDist / 30.0) * 60.0).ceil().clamp(1, 45);
    }

    await _syncLocationToSupabase(compareLatLng, heading, remDistKm: remDistKm, etaMins: etaMins);

    final distanceToDestination = _locationService.calculateDistance(
      rawLatLng.latitude,
      rawLatLng.longitude,
      _targetDestination!.latitude,
      _targetDestination!.longitude,
    ) * 1000.0;

    if (distanceToDestination <= 100.0 && _currentStatus == RideStatus.driverOnWay && !_hasShownArrivalOverlay) {
      _hasShownArrivalOverlay = true;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        FlutterOverlayWindow.isPermissionGranted().then((granted) {

          if (granted) {
            FlutterOverlayWindow.showOverlay(
              enableDrag: true,
              overlayTitle: "الملاحة للراكب",
              overlayContent: "لقد وصلت إلى الراكب!",
              flag: OverlayFlag.defaultFlag,
              visibility: NotificationVisibility.visibilityPublic,
              positionGravity: PositionGravity.auto,
              height: 250,
              width: WindowSize.matchParent,
            );
          }
        });
      }
    }

    if (distanceToDestination <= 20.0) {
      _onArrivedAtTarget();
    }
  }

  void _onRerouteComplete() {
    final route = _stateManager.activeRoute;
    if (route != null && _mapController != null && _mapController!.isBound) {
      _polylineManager?.drawRoute(route.points);
    }
  }

  Future<void> _syncLocationToSupabase(LatLng pos, double bearing, {double? remDistKm, int? etaMins}) async {
    final state = GlobalState.instance;
    if (state.userUid == null) return;

    try {
      await _supabase.from('drivers').update({
        'current_latitude': pos.latitude,
        'current_longitude': pos.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', state.userUid!);

      if (_activeRideId != null) {
        await _supabase.from('ride_requests').update({
          'driver_latitude': pos.latitude,
          'driver_longitude': pos.longitude,
          'driver_bearing': bearing,
        }).eq('id', _activeRideId!);
      }
    } catch (e) {
      debugPrint('[TripNavigationManager] Supabase sync failed: $e');
    }
  }

  void _onArrivedAtTarget() {
    if (_currentStatus == RideStatus.driverOnWay) {
      debugPrint('[TripNavigationManager] Arrived at pickup radius!');
    } else if (_currentStatus == RideStatus.tripStarted) {
      debugPrint('[TripNavigationManager] Arrived at destination radius!');
    }
  }

  Future<void> stopNavigation() async {
    _locationController.stop();
    _reRouteController.dispose();
    _isNavigating = false;

    if (_activeRideId != null && _tripStartTime != null) {
      await _saveTripStatsToSupabase();
    }

    _navigationController.stopNavigation();
    _cameraController?.reset();
    await _polylineManager?.clear();
    await _markerManager?.clear();

    _activeRideId = null;
    _currentStatus = null;
    _targetDestination = null;
  }

  Future<void> _saveTripStatsToSupabase() async {
    if (_activeRideId == null || _tripStartTime == null) return;

    try {
      await _supabase.from('ride_requests').update({
        'distance': _totalDistanceTraveled,
      }).eq('id', _activeRideId!);
    } catch (e) {
      debugPrint('[TripNavigationManager] Failed saving trip stats: $e');
    }
  }

  void dispose() {
    _locationController.dispose();
    _reRouteController.dispose();
    _markerManager?.dispose();
    _mapController = null;
  }
}
