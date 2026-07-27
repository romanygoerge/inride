import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'navigation_state.dart';
import 'navigation_state_manager.dart';
import 'snap_to_route_controller.dart';
import 'route_controller.dart';

/// Monitors the driver's position relative to the route and automatically
/// triggers rerouting when the driver goes off-route.
///
/// Uses a throttle timer to prevent excessive reroute requests.
class RouteRecalculationController {
  final NavigationStateManager _stateManager;
  final SnapToRouteController _snapController;
  final RouteController _routeController;

  bool _isRerouting = false;
  Timer? _reRouteThrottleTimer;
  LatLng? _targetDestination;

  /// Minimum interval between reroute attempts.
  static const Duration reRouteThrottle = Duration(seconds: 3);

  /// Called when a new route is successfully calculated after reroute.
  void Function()? onRerouteComplete;

  RouteRecalculationController({
    required NavigationStateManager stateManager,
    required SnapToRouteController snapController,
    required RouteController routeController,
  })  : _stateManager = stateManager,
        _snapController = snapController,
        _routeController = routeController;

  bool get isRerouting => _isRerouting;

  /// Sets the current navigation target destination.
  void setDestination(LatLng destination) {
    _targetDestination = destination;
  }

  /// Checks if rerouting should be triggered based on current off-route status.
  ///
  /// Call this after each location update.
  void checkAndReroute(LatLng currentLocation) {
    if (!_snapController.isOffRoute || _isRerouting || _targetDestination == null) return;
    _triggerReroute(currentLocation);
  }

  /// Triggers a throttled reroute.
  void _triggerReroute(LatLng currentLocation) {
    if (_reRouteThrottleTimer != null && _reRouteThrottleTimer!.isActive) return;
    _isRerouting = true;

    // Show rerouting status in UI
    _stateManager.setPhase(NavigationPhase.rerouting, message: 'جاري إعادة حساب المسار...');

    _reRouteThrottleTimer = Timer(reRouteThrottle, () async {
      if (_targetDestination == null) {
        _isRerouting = false;
        return;
      }

      try {
        debugPrint('[RouteRecalculationController] Off-route detected! Rerouting...');
        final newRoute = await _routeController.fetchRouteForReroute(currentLocation, _targetDestination!);

        if (newRoute != null && newRoute.isNotEmpty) {
          // Reset snap controller for the new route
          _snapController.reset();

          // Update state with new route
          _stateManager.replaceRoute(newRoute);

          // Notify observers
          onRerouteComplete?.call();

          debugPrint('[RouteRecalculationController] Reroute successful');
        } else {
          _stateManager.setPhase(NavigationPhase.error, message: 'فشل إعادة حساب المسار');
        }
      } catch (e) {
        debugPrint('[RouteRecalculationController] Reroute failed: $e');
        // Restore active status on failure
        _stateManager.setPhase(NavigationPhase.activeNavigation);
      } finally {
        _isRerouting = false;
      }
    });
  }

  /// Cleans up timers.
  void dispose() {
    _reRouteThrottleTimer?.cancel();
    _reRouteThrottleTimer = null;
    _targetDestination = null;
  }
}
