import 'dart:math' as math;
import 'package:latlong2/latlong.dart' as ll;
import 'map_controller.dart';
import 'navigation_state_manager.dart';

/// Continuously tracks the vehicle camera during active navigation.
///
/// Handles smooth zoom (speed-based), smooth bearing (anti-jitter),
/// vehicle offset (bottom-third positioning), and 3D perspective.
///
/// This controller is used for the per-frame tracking loop. One-shot
/// transitions (fit bounds, route overview) are handled by [CameraAnimationController].
class CameraController {
  final MapController _mapController;
  final NavigationStateManager _stateManager;

  double _lastZoom = 18.0;
  double _lastBearing = 0.0;

  CameraController({
    required MapController mapController,
    required NavigationStateManager stateManager,
  })  : _mapController = mapController,
        _stateManager = stateManager;

  /// Calculates a camera target offset ahead of the vehicle along the travel direction.
  /// Positions the vehicle in the bottom third of the screen.
  ll.LatLng _calculateOffsetTarget(ll.LatLng pos, double bearing, double zoom) {
    final double offsetMeters = 80.0 * math.pow(2.0, 18.0 - zoom);
    const double metersPerDegreeLat = 111320.0;
    final double rad = bearing * math.pi / 180.0;

    final double latOffset = (offsetMeters / metersPerDegreeLat) * math.cos(rad);
    final double lngOffset = (offsetMeters / (metersPerDegreeLat * math.cos(pos.latitude * math.pi / 180.0))) * math.sin(rad);

    return ll.LatLng(pos.latitude + latOffset, pos.longitude + lngOffset);
  }

  /// Smoothly interpolates bearing using shortest-path angular interpolation.
  double _smoothBearing(double currentBearing, double targetBearing, double factor) {
    double diff = (targetBearing - currentBearing) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (currentBearing + diff * factor) % 360;
  }

  /// Calculates smooth zoom based on speed and proximity to next turn.
  double _calculateTargetZoom(double speedKmH, double distToTurn) {
    // Base zoom: interpolate between 18.5 (stopped) and 16.8 (highway 120 km/h)
    double speedZoom = _lerp(18.5, 16.8, (speedKmH / 120.0).clamp(0.0, 1.0));

    // Zoom in when approaching a turn (< 100m)
    if (distToTurn > 0 && distToTurn < 100.0) {
      final turnFactor = 1.0 - (distToTurn / 100.0).clamp(0.0, 1.0);
      speedZoom = _lerp(speedZoom, 18.8, turnFactor * 0.6);
    }

    // Extra zoom for roundabouts (< 80m)
    if (distToTurn > 0 && distToTurn < 80.0) {
      final nextStep = _stateManager.nextStep;
      if (nextStep != null && (nextStep.maneuverType == 'roundabout' || nextStep.maneuverType == 'rotary')) {
        speedZoom = _lerp(speedZoom, 19.0, 0.4);
      }
    }

    return speedZoom;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Updates camera viewport based on vehicle position, heading, and speed.
  ///
  /// Called on every valid GPS update during active navigation.
  Future<void> updateCamera(ll.LatLng position, double bearing, double speedMetersPerSecond) async {
    if (!_stateManager.isAutoFollow || !_mapController.isBound) return;

    final speedKmH = speedMetersPerSecond * 3.6;
    final distToTurn = _stateManager.distanceToNextTurn;

    // Smooth bearing (heavier smoothing at low speeds)
    final bearingFactor = speedKmH < 5.0 ? 0.15 : 0.4;
    _lastBearing = _smoothBearing(_lastBearing, bearing, bearingFactor);

    // Smooth zoom
    double targetZoom = _calculateTargetZoom(speedKmH, distToTurn);
    _lastZoom = _lerp(_lastZoom, targetZoom, 0.3);

    final targetPoint = _calculateOffsetTarget(position, _lastBearing, _lastZoom);

    try {
      await _mapController.easeCamera(
        CameraOptions(
          center: targetPoint,
          zoom: _lastZoom,
          bearing: _lastBearing,
          pitch: 45.0,
        ),
        animationOptions: MapAnimationOptions(duration: 900),
      );
    } catch (_) {}
  }

  /// Recenters the camera on the vehicle position.
  Future<void> recenter(ll.LatLng position, double bearing) async {
    _stateManager.setAutoFollow(true);
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

  /// Resets zoom and bearing to default values for a new navigation session.
  void reset() {
    _lastZoom = 18.0;
    _lastBearing = 0.0;
  }
}
