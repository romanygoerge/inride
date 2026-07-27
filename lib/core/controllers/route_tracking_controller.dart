import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../models/route_model.dart';
import 'navigation_state_manager.dart';

/// Tracks the driver's progress along the active route.
///
/// Determines the current step index, distance to next turn, remaining
/// distance and remaining duration based on the snapped position and
/// segment index.
class RouteTrackingController {
  final NavigationStateManager _stateManager;

  /// Called when the current step index changes (for TTS coordination).
  void Function(int previousIndex, int newIndex)? onStepChanged;

  RouteTrackingController({required NavigationStateManager stateManager})
      : _stateManager = stateManager;

  /// Updates tracking metrics given the current snapped position and segment index.
  ///
  /// This method should be called after [SnapToRouteController.snap()] has
  /// updated the snapped location in the state manager.
  void updateProgress(LatLng snappedLocation, int segmentIndex) {
    final route = _stateManager.activeRoute;
    if (route == null || route.points.isEmpty) return;

    // Calculate remaining distance
    final remainingDistance = _calculateRemainingDistance(route, snappedLocation, segmentIndex);

    // Scale OSRM duration proportionally to remaining distance
    double remainingDuration = 0.0;
    if (route.distance > 0) {
      remainingDuration = route.duration * (remainingDistance / route.distance);
    }

    // Find current step index
    final previousStepIndex = _stateManager.currentStepIndex;
    final currentStepIndex = _findCurrentStepIndex(route, segmentIndex);

    // Calculate distance to next turn
    double distanceToNextTurn;
    final steps = route.steps;
    if (currentStepIndex < steps.length - 1) {
      final nextStepObj = steps[currentStepIndex + 1];
      distanceToNextTurn = _calculatePathDistance(
        route,
        snappedLocation,
        segmentIndex,
        nextStepObj.pointIndex,
      );
    } else {
      distanceToNextTurn = remainingDistance;
    }

    // Update state manager
    _stateManager.updateTrackingMetrics(
      remainingDistance: remainingDistance,
      remainingDuration: remainingDuration,
      currentStepIndex: currentStepIndex,
      distanceToNextTurn: distanceToNextTurn,
    );

    // Notify step change
    if (currentStepIndex != previousStepIndex) {
      onStepChanged?.call(previousStepIndex, currentStepIndex);
    }
  }

  /// Finds the currently active step based on segment index.
  int _findCurrentStepIndex(RouteModel route, int segmentIndex) {
    final steps = route.steps;
    if (steps.isEmpty) return 0;

    for (int i = 0; i < steps.length - 1; i++) {
      if (segmentIndex >= steps[i].pointIndex && segmentIndex < steps[i + 1].pointIndex) {
        return i;
      }
    }

    return steps.length - 1;
  }

  /// Calculates the exact path distance along the route from the snapped point
  /// to a target point index.
  double _calculatePathDistance(RouteModel route, LatLng snappedPoint, int segmentIndex, int targetPointIndex) {
    final points = route.points;
    if (points.isEmpty || segmentIndex >= points.length) return 0.0;
    if (targetPointIndex <= segmentIndex) return 0.0;

    double totalDistance = 0.0;

    final nextIdx = segmentIndex + 1;
    if (nextIdx < points.length) {
      totalDistance += _calculateDistance(snappedPoint, points[nextIdx]);
    }

    for (int i = nextIdx; i < targetPointIndex; i++) {
      if (i + 1 < points.length) {
        totalDistance += _calculateDistance(points[i], points[i + 1]);
      }
    }

    return totalDistance;
  }

  /// Sums remaining route distance from snapped position to end of route.
  double _calculateRemainingDistance(RouteModel route, LatLng snappedPoint, int segmentIndex) {
    return _calculatePathDistance(route, snappedPoint, segmentIndex, route.points.length - 1);
  }

  /// Calculates bearing between two geographical points (degrees 0-360).
  double calculateBearing(LatLng from, LatLng to) {
    final double lat1 = from.latitude * math.pi / 180.0;
    final double lat2 = to.latitude * math.pi / 180.0;
    final double dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360) % 360;
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    try {
      return Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
    } catch (_) {
      const double r = 6371000.0;
      final double lat1 = p1.latitude * math.pi / 180.0;
      final double lat2 = p2.latitude * math.pi / 180.0;
      final double dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
      final double dLon = (p2.longitude - p1.longitude) * math.pi / 180.0;

      final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
      final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return r * c;
    }
  }
}
