import 'dart:math' as math;
import 'package:latlong2/latlong.dart' as ll;
import 'package:get_it/get_it.dart';
import 'map_controller.dart';
import 'navigation_controller.dart';

class CameraManager {
  final MapController _mapController;
  double _lastZoom = 18.0;
  double _lastBearing = 0.0; // smooth bearing tracking

  bool get isAutoFollow => GetIt.instance<NavigationController>().isAutoFollow;

  CameraManager({required MapController mapController}) : _mapController = mapController;

  void setAutoFollow(bool active) {
    GetIt.instance<NavigationController>().setAutoFollow(active);
  }

  /// Calculates a camera target coordinate that is offset ahead of the vehicle along the direction of travel.
  /// This positions the vehicle in the bottom third of the screen instead of the center.
  ll.LatLng _calculateOffsetTarget(ll.LatLng pos, double bearing, double zoom) {
    // The visual offset (in meters) shifts the center point ahead of the vehicle.
    // Scales exponentially with zoom level to maintain consistent visual positioning on screen.
    final double offsetMeters = 80.0 * math.pow(2.0, 18.0 - zoom);
    const double metersPerDegreeLat = 111320.0;
    final double rad = bearing * math.pi / 180.0;
    
    final double latOffset = (offsetMeters / metersPerDegreeLat) * math.cos(rad);
    final double lngOffset = (offsetMeters / (metersPerDegreeLat * math.cos(pos.latitude * math.pi / 180.0))) * math.sin(rad);

    return ll.LatLng(pos.latitude + latOffset, pos.longitude + lngOffset);
  }

  /// Smoothly interpolates between the current bearing and target bearing
  /// using shortest-path angular interpolation to prevent jitter.
  double _smoothBearing(double currentBearing, double targetBearing, double factor) {
    double diff = (targetBearing - currentBearing) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (currentBearing + diff * factor) % 360;
  }

  /// Calculates smooth zoom level based on speed and proximity to next turn.
  /// Uses continuous interpolation instead of discrete steps.
  double _calculateTargetZoom(double speedKmH, double distToTurn) {
    // Base zoom: interpolate between 18.5 (stopped) and 16.8 (highway speed 120 km/h)
    double speedZoom = _lerp(18.5, 16.8, (speedKmH / 120.0).clamp(0.0, 1.0));

    // If approaching a turn (< 100 meters), zoom in to show maneuver detail
    if (distToTurn > 0 && distToTurn < 100.0) {
      // Interpolate from current zoom to 18.8 as we get closer to the turn
      final turnFactor = 1.0 - (distToTurn / 100.0).clamp(0.0, 1.0);
      speedZoom = _lerp(speedZoom, 18.8, turnFactor * 0.6);
    }

    // If approaching a roundabout, zoom in more to see exits
    final navController = GetIt.instance<NavigationController>();
    if (distToTurn > 0 && distToTurn < 80.0) {
      final nextStep = navController.nextStep;
      if (nextStep != null && (nextStep.maneuverType == 'roundabout' || nextStep.maneuverType == 'rotary')) {
        speedZoom = _lerp(speedZoom, 19.0, 0.4);
      }
    }

    return speedZoom;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Updates camera viewport based on vehicle position, heading (bearing), and current speed.
  Future<void> updateCamera(ll.LatLng position, double bearing, double speedMetersPerSecond) async {
    if (!isAutoFollow || !_mapController.isBound) return;

    final speedKmH = speedMetersPerSecond * 3.6;
    final navController = GetIt.instance<NavigationController>();
    final distToTurn = navController.distanceToNextTurn;

    // Smooth bearing to prevent jitter (heavier smoothing at low speeds)
    final bearingFactor = speedKmH < 5.0 ? 0.15 : 0.4;
    _lastBearing = _smoothBearing(_lastBearing, bearing, bearingFactor);

    // Calculate smooth zoom level
    double targetZoom = _calculateTargetZoom(speedKmH, distToTurn);

    // Smooth zoom transition (don't jump)
    _lastZoom = _lerp(_lastZoom, targetZoom, 0.3);

    final targetPoint = _calculateOffsetTarget(position, _lastBearing, _lastZoom);

    try {
      // Smoothly animate the camera matching the 1s GPS updates (900ms animation duration)
      await _mapController.easeCamera(
        CameraOptions(
          center: targetPoint,
          zoom: _lastZoom,
          bearing: _lastBearing,
          pitch: 45.0, // 3D perspective angle
        ),
        animationOptions: MapAnimationOptions(duration: 900),
      );
    } catch (_) {}
  }

  /// Reset and center camera immediately on the vehicle coordinates.
  Future<void> recenter(ll.LatLng position, double bearing) async {
    setAutoFollow(true);
    _lastBearing = bearing;
    final targetPoint = _calculateOffsetTarget(position, bearing, _lastZoom);
    try {
      await _mapController.easeCamera(
        CameraOptions(
          center: targetPoint,
          zoom: _lastZoom,
          bearing: bearing,
          pitch: 45.0,
        ),
        animationOptions: MapAnimationOptions(duration: 600),
      );
    } catch (_) {}
  }

  /// Zoom out to show the complete route bounds (e.g. pickup to destination).
  /// Called right after the route is fetched to give both driver and passenger
  /// a clear overview of the full path at street level.
  Future<void> fitRouteBounds(ll.LatLng start, ll.LatLng end) async {
    if (!_mapController.isBound) return;

    final double minLat = start.latitude < end.latitude ? start.latitude : end.latitude;
    final double maxLat = start.latitude > end.latitude ? start.latitude : end.latitude;
    final double minLng = start.longitude < end.longitude ? start.longitude : end.longitude;
    final double maxLng = start.longitude > end.longitude ? start.longitude : end.longitude;

    final bounds = CoordinateBounds(
      southwest: ll.LatLng(minLat, minLng),
      northeast: ll.LatLng(maxLat, maxLng),
      infiniteBounds: true,
    );

    try {
      // Padding: top=120 for navigation HUD, bottom=300 for bottom sheet, sides=60
      final cameraOptions = await _mapController.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 120.0, bottom: 300.0, left: 60.0, right: 60.0),
      );
      if (cameraOptions != null) {
        // Cap zoom to a street-visible level (between 12 and 16)
        final zoom = (cameraOptions.zoom ?? 14.0).clamp(12.0, 16.0);
        await _mapController.easeCamera(
          CameraOptions(
            center: cameraOptions.center,
            zoom: zoom,
            bearing: 0.0,
            pitch: 0.0,
          ),
          animationOptions: MapAnimationOptions(duration: 800),
        );
      }
    } catch (_) {}
  }
}

