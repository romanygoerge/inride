import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'map_controller.dart';

class PolylineManager {
  final MapController _mapController;

  PolylineManager({required MapController mapController}) : _mapController = mapController;

  /// Draws the complete active route polyline on the map.
  Future<void> drawRoute(List<ll.LatLng> points, {List<ll.LatLng>? secondaryPoints}) async {
    await clear();
    if (points.isEmpty || !_mapController.isBound) return;

    final activeLine = fm.Polyline(
      points: points,
      color: const Color(0xFF1A73E8), // Premium Blue
      strokeWidth: 5.5,
      borderColor: const Color(0xFF0D47A1).withValues(alpha: 0.3),
      borderStrokeWidth: 1.0,
    );

    final List<fm.Polyline> lines = [activeLine];

    if (secondaryPoints != null && secondaryPoints.isNotEmpty) {
      final secondaryLine = fm.Polyline(
        points: secondaryPoints,
        color: const Color(0xFF9AA0A6), // Gray
        strokeWidth: 5.0,
      );
      lines.add(secondaryLine);
    }

    _mapController.updatePolylines(lines);
    
    // Draw directional arrows along the path
    await _drawRouteArrows(points);
  }

  /// Updates the polyline visually by changing the color of the traveled portion.
  Future<void> updateRouteProgress(List<ll.LatLng> fullPoints, int currentSegmentIndex, {List<ll.LatLng>? secondaryPoints}) async {
    if (fullPoints.isEmpty || !_mapController.isBound) return;

    try {
      final List<ll.LatLng> completedPoints = fullPoints.sublist(0, math.min(currentSegmentIndex + 1, fullPoints.length));
      final List<ll.LatLng> remainingPoints = fullPoints.sublist(math.min(currentSegmentIndex, fullPoints.length - 1));

      final List<fm.Polyline> polylines = [];

      // Draw completed path
      if (completedPoints.length > 1) {
        polylines.add(fm.Polyline(
          points: completedPoints,
          color: const Color(0xFF9AA0A6), // Gray
          strokeWidth: 5.0,
        ));
      }

      // Draw remaining path
      if (remainingPoints.length > 1) {
        polylines.add(fm.Polyline(
          points: remainingPoints,
          color: const Color(0xFF1A73E8), // Premium Blue
          strokeWidth: 5.5,
          borderColor: const Color(0xFF0D47A1).withValues(alpha: 0.3),
          borderStrokeWidth: 1.0,
        ));
      } else if (remainingPoints.isNotEmpty && completedPoints.isNotEmpty) {
        // Just in case we are at the very end
        polylines.add(fm.Polyline(
          points: [completedPoints.last, remainingPoints.first],
          color: const Color(0xFF1A73E8),
          strokeWidth: 5.5,
        ));
      }

      if (secondaryPoints != null && secondaryPoints.isNotEmpty) {
        polylines.add(fm.Polyline(
          points: secondaryPoints,
          color: const Color(0xFF9AA0A6), // Gray
          strokeWidth: 5.0,
        ));
      }

      _mapController.updatePolylines(polylines);

      // Update directional arrows for the remaining path
      await _drawRouteArrows(remainingPoints);
    } catch (_) {
      // Fallback: draw single line if split updates fail
      await drawRoute(fullPoints, secondaryPoints: secondaryPoints);
    }
  }

  /// Clears all lines and arrows from the map.
  Future<void> clear() async {
    _mapController.updatePolylines([]);
    _mapController.updateArrowMarkers([]);
  }

  Future<void> _drawRouteArrows(List<ll.LatLng> points) async {
    if (points.length < 2 || !_mapController.isBound) {
      _mapController.updateArrowMarkers([]);
      return;
    }

    final List<fm.Marker> arrowMarkers = [];
    double accumulatedDistance = 0.0;
    const double arrowSpacingMeters = 150.0; // Place arrow every 150 meters

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final segmentDist = _calculateDistance(p1, p2);
      accumulatedDistance += segmentDist;

      if (accumulatedDistance >= arrowSpacingMeters) {
        final bearing = _calculateBearing(p1, p2);
        arrowMarkers.add(fm.Marker(
          point: p1,
          width: 20,
          height: 20,
          child: Transform.rotate(
            angle: bearing * math.pi / 180,
            child: const RouteArrowWidget(),
          ),
        ));
        accumulatedDistance = 0.0;
      }
    }

    _mapController.updateArrowMarkers(arrowMarkers);
  }

  double _calculateDistance(ll.LatLng p1, ll.LatLng p2) {
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

  double _calculateBearing(ll.LatLng from, ll.LatLng to) {
    final double lat1 = from.latitude * math.pi / 180.0;
    final double lat2 = to.latitude * math.pi / 180.0;
    final double dLon = (to.longitude - from.longitude) * math.pi / 180.0;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360) % 360;
  }

  int mathMin(int a, int b) => a < b ? a : b;
}

// Directional arrow widget rendered on the route
class RouteArrowWidget extends StatelessWidget {
  const RouteArrowWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _ArrowPainter(),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintOutline = Paint()
      ..color = const Color(0xFF0D47A1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    double cx = size.width / 2;
    double cy = size.height / 2;
    double arrowSize = size.width * 0.4;
    
    path.moveTo(cx, cy - arrowSize); // Top tip
    path.lineTo(cx - arrowSize * 0.6, cy + arrowSize * 0.6); // Bottom left
    path.lineTo(cx, cy + arrowSize * 0.25); // Inner point
    path.lineTo(cx + arrowSize * 0.6, cy + arrowSize * 0.6); // Bottom right
    path.close();

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
