import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../models/route_model.dart';

class SnappedPosition {
  final LatLng coordinate;
  final double distanceToPolyline; // distance in meters from raw GPS to snapped point
  final int segmentIndex; // segment index in route points

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
  double _variance = 1.0; // estimation uncertainty
  bool _initialized = false;

  static const double _processNoise = 0.00001; // model drift per update
  static const double _minAccuracyVariance = 0.000001;

  /// Filters a raw GPS position and returns the smoothed coordinate.
  /// [accuracy] is the reported GPS accuracy in meters.
  LatLng filter(LatLng raw, double accuracy) {
    // Convert meter-accuracy to approximate degree-variance
    // 1 degree lat ≈ 111320 meters
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

    // Prediction step: increase uncertainty
    _variance += _processNoise;

    // Update step: Kalman gain
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

class NavigationService {
  int _lastMatchedIndex = 0;
  int _offRouteCount = 0;
  bool _isOffRoute = false;
  final _GpsFilter _gpsFilter = _GpsFilter();

  int get lastMatchedIndex => _lastMatchedIndex;
  bool get isOffRoute => _isOffRoute;

  void reset() {
    _lastMatchedIndex = 0;
    _offRouteCount = 0;
    _isOffRoute = false;
    _gpsFilter.reset();
  }

  /// Applies the GPS Kalman filter to smooth noisy raw coordinates.
  LatLng filterGps(LatLng raw, double accuracy) {
    return _gpsFilter.filter(raw, accuracy);
  }

  /// Snaps a raw GPS point to the closest segment on the route polyline.
  /// Uses a windowed search around the last matched index to optimize performance
  /// and avoid snapping to parallel streets.
  SnappedPosition snapToRoute(LatLng rawLocation, RouteModel route) {
    final points = route.points;
    if (points.isEmpty) {
      return SnappedPosition(coordinate: rawLocation, distanceToPolyline: 0, segmentIndex: 0);
    }
    if (points.length == 1) {
      final dist = _calculateDistance(rawLocation, points[0]);
      return SnappedPosition(coordinate: points[0], distanceToPolyline: dist, segmentIndex: 0);
    }

    // Windowed search bounds: [lastMatchedIndex - 2, lastMatchedIndex + 10]
    int start = math.max(0, _lastMatchedIndex - 2);
    int end = math.min(points.length - 2, _lastMatchedIndex + 10);

    SnappedPosition bestSnap = _findBestSnapInRange(rawLocation, points, start, end);

    // If snapped distance is too far (e.g. > 35m) in the local window, search the entire route
    if (bestSnap.distanceToPolyline > 35.0) {
      final globalBestSnap = _findBestSnapInRange(rawLocation, points, 0, points.length - 2);
      if (globalBestSnap.distanceToPolyline < bestSnap.distanceToPolyline) {
        bestSnap = globalBestSnap;
      }
    }

    _lastMatchedIndex = bestSnap.segmentIndex;

    // Off-route detection: consecutive readings where distance to snapped point is > 45 meters
    if (bestSnap.distanceToPolyline > 45.0) {
      _offRouteCount++;
      if (_offRouteCount >= 3) {
        _isOffRoute = true;
      }
    } else {
      _offRouteCount = 0;
      _isOffRoute = false;
    }

    return bestSnap;
  }

  /// Calculates the exact path distance along the route polyline from the snapped point index
  /// up to a target point index.
  double calculatePathDistance(RouteModel route, LatLng snappedPoint, int segmentIndex, int targetPointIndex) {
    final points = route.points;
    if (points.isEmpty || segmentIndex >= points.length) return 0.0;
    if (targetPointIndex <= segmentIndex) return 0.0;

    double totalDistance = 0.0;

    // Distance from snapped location to the end of its matched segment
    final nextIdx = segmentIndex + 1;
    if (nextIdx < points.length) {
      totalDistance += _calculateDistance(snappedPoint, points[nextIdx]);
    }

    // Distances of all intermediate segments
    for (int i = nextIdx; i < targetPointIndex; i++) {
      if (i + 1 < points.length) {
        totalDistance += _calculateDistance(points[i], points[i + 1]);
      }
    }

    return totalDistance;
  }

  /// Sums remaining route distance from current segment index to the end of the route.
  double calculateRemainingDistance(RouteModel route, LatLng snappedPoint, int segmentIndex) {
    return calculatePathDistance(route, snappedPoint, segmentIndex, route.points.length - 1);
  }

  /// Finds the currently active step index in the route based on the snapped segment index.
  int findCurrentStepIndex(RouteModel route, int segmentIndex) {
    final steps = route.steps;
    if (steps.isEmpty) return 0;

    // Find the step where segmentIndex is between step[i].pointIndex and step[i+1].pointIndex
    for (int i = 0; i < steps.length - 1; i++) {
      if (segmentIndex >= steps[i].pointIndex && segmentIndex < steps[i + 1].pointIndex) {
        return i;
      }
    }

    // Fallback: if we passed the last turn, it is the last step (arrive)
    return steps.length - 1;
  }

  /// Calculates the bearing between two geographical points (in degrees, 0-360).
  double calculateBearing(LatLng from, LatLng to) {
    final double lat1 = from.latitude * math.pi / 180.0;
    final double lat2 = to.latitude * math.pi / 180.0;
    final double dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360) % 360;
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

    // Vector projection factor t
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
      // Direct approximation if geolocator throws
      const double r = 6371000.0; // Earth radius in meters
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
