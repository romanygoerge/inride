import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../models/route_model.dart';
import 'navigation_state_manager.dart';

/// Result of snapping a GPS coordinate to the route polyline.
class SnappedPosition {
  final LatLng coordinate;
  final double distanceToPolyline; // meters from raw GPS to snapped point
  final int segmentIndex;

  SnappedPosition({
    required this.coordinate,
    required this.distanceToPolyline,
    required this.segmentIndex,
  });
}

/// Simplified Kalman-inspired GPS filter that smooths noisy coordinates
/// without introducing significant lag.
class _GpsFilter {
  double _lat = 0.0;
  double _lng = 0.0;
  double _variance = 1.0;
  bool _initialized = false;

  static const double _processNoise = 0.00001;
  static const double _minAccuracyVariance = 0.000001;

  /// Filters a raw GPS position and returns the smoothed coordinate.
  LatLng filter(LatLng raw, double accuracy) {
    final double measurementVariance = math.max(
      _minAccuracyVariance,
      (accuracy / 111320.0) * (accuracy / 111320.0),
    );

    if (!_initialized) {
      _lat = raw.latitude;
      _lng = raw.longitude;
      _variance = measurementVariance;
      _initialized = true;
      return LatLng(_lat, _lng);
    }

    _variance += _processNoise;

    final double gain = _variance / (_variance + measurementVariance);
    _lat += gain * (raw.latitude - _lat);
    _lng += gain * (raw.longitude - _lng);
    _variance *= (1.0 - gain);

    return LatLng(_lat, _lng);
  }

  void reset() {
    _initialized = false;
    _variance = 1.0;
  }
}

/// Responsible for snapping raw GPS coordinates to the nearest point
/// on the active route polyline.
///
/// Applies a Kalman filter for GPS smoothing, then projects the filtered
/// coordinate onto the closest route segment. Detects off-route conditions
/// based on consecutive distance violations.
class SnapToRouteController {
  final NavigationStateManager _stateManager;

  int _lastMatchedIndex = 0;
  int _offRouteCount = 0;
  bool _isOffRoute = false;
  final _GpsFilter _gpsFilter = _GpsFilter();

  /// Number of consecutive off-route readings before triggering reroute.
  static const int offRouteThreshold = 3;

  /// Distance in meters beyond which a position is considered off-route.
  static const double offRouteDistanceMeters = 45.0;

  /// Distance in meters to trigger a full-route search instead of windowed.
  static const double windowFallbackDistance = 35.0;

  SnapToRouteController({required NavigationStateManager stateManager})
      : _stateManager = stateManager;

  int get lastMatchedIndex => _lastMatchedIndex;
  bool get isOffRoute => _isOffRoute;

  /// Resets all internal state for a new navigation session.
  void reset() {
    _lastMatchedIndex = 0;
    _offRouteCount = 0;
    _isOffRoute = false;
    _gpsFilter.reset();
  }

  /// Processes a raw GPS coordinate and snaps it to the active route.
  ///
  /// Returns the [SnappedPosition] result and updates [NavigationStateManager].
  /// Returns null if no active route exists.
  SnappedPosition? snap(LatLng rawLocation, double accuracy) {
    final route = _stateManager.activeRoute;
    if (route == null || route.points.isEmpty) return null;

    // Apply Kalman filter
    final filteredLocation = _gpsFilter.filter(rawLocation, accuracy);

    // Snap to route
    final snapped = _snapToRoute(filteredLocation, route);

    // Update state manager
    _stateManager.updateSnappedLocation(
      snapped.coordinate,
      snapped.segmentIndex,
      _isOffRoute,
    );

    return snapped;
  }

  /// Core snap-to-route algorithm using windowed search with global fallback.
  SnappedPosition _snapToRoute(LatLng location, RouteModel route) {
    final points = route.points;

    if (points.length == 1) {
      final dist = _calculateDistance(location, points[0]);
      return SnappedPosition(coordinate: points[0], distanceToPolyline: dist, segmentIndex: 0);
    }

    // Windowed search: [lastMatchedIndex - 2, lastMatchedIndex + 10]
    int start = math.max(0, _lastMatchedIndex - 2);
    int end = math.min(points.length - 2, _lastMatchedIndex + 10);

    SnappedPosition bestSnap = _findBestSnapInRange(location, points, start, end);

    // Global fallback if local window distance is too large
    if (bestSnap.distanceToPolyline > windowFallbackDistance) {
      final globalBestSnap = _findBestSnapInRange(location, points, 0, points.length - 2);
      if (globalBestSnap.distanceToPolyline < bestSnap.distanceToPolyline) {
        bestSnap = globalBestSnap;
      }
    }

    _lastMatchedIndex = bestSnap.segmentIndex;

    // Off-route detection: consecutive readings > threshold distance
    if (bestSnap.distanceToPolyline > offRouteDistanceMeters) {
      _offRouteCount++;
      if (_offRouteCount >= offRouteThreshold) {
        _isOffRoute = true;
      }
    } else {
      _offRouteCount = 0;
      _isOffRoute = false;
    }

    return bestSnap;
  }

  SnappedPosition _findBestSnapInRange(LatLng rawLocation, List<LatLng> points, int start, int end) {
    double minDistance = double.maxFinite;
    LatLng bestPoint = rawLocation;
    int bestSegmentIndex = start;

    for (int i = start; i <= end; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final snapped = _projectPointOnSegment(rawLocation, p1, p2);
      final dist = _calculateDistance(rawLocation, snapped);

      if (dist < minDistance) {
        minDistance = dist;
        bestPoint = snapped;
        bestSegmentIndex = i;
      }
    }

    return SnappedPosition(
      coordinate: bestPoint,
      distanceToPolyline: minDistance,
      segmentIndex: bestSegmentIndex,
    );
  }

  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final double dy = b.latitude - a.latitude;
    final double dx = b.longitude - a.longitude;

    if (dy == 0 && dx == 0) return a;

    double t = ((p.latitude - a.latitude) * dy + (p.longitude - a.longitude) * dx) / (dy * dy + dx * dx);
    t = t.clamp(0.0, 1.0);

    return LatLng(
      a.latitude + t * dy,
      a.longitude + t * dx,
    );
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
