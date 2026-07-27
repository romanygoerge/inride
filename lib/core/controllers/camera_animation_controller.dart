import 'package:latlong2/latlong.dart' as ll;
import 'map_controller.dart';

/// Manages camera transitions that are NOT part of the continuous tracking loop.
///
/// This includes:
/// - Initial route overview (fit bounds)
/// - Transition from overview to navigation mode
/// - Camera update after reroute
///
/// The continuous tracking camera (follow vehicle) is handled by [CameraController].
class CameraAnimationController {
  final MapController _mapController;

  CameraAnimationController({required MapController mapController})
      : _mapController = mapController;

  /// Animates the camera to show the complete route between start and end.
  ///
  /// Called when a new route is loaded, giving the driver/passenger
  /// a full overview of the path at street-visible zoom levels.
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
      final cameraOptions = await _mapController.cameraForCoordinateBounds(
        bounds,
        // top=120 for HUD, bottom=300 for bottom sheet, sides=60
        MbxEdgeInsets(top: 120.0, bottom: 300.0, left: 60.0, right: 60.0),
      );
      if (cameraOptions != null) {
        // Clamp zoom to street-visible level (12-16)
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

  /// Smoothly transitions the camera from route overview to navigation mode.
  ///
  /// Zooms in on the vehicle position with tilt and bearing.
  Future<void> transitionToNavigation(ll.LatLng vehiclePosition, double bearing) async {
    if (!_mapController.isBound) return;

    try {
      await _mapController.easeCamera(
        CameraOptions(
          center: vehiclePosition,
          zoom: 18.0,
          bearing: bearing,
          pitch: 45.0,
        ),
        animationOptions: MapAnimationOptions(duration: 1200),
      );
    } catch (_) {}
  }

  /// Updates camera to show the new route after a reroute event.
  ///
  /// Briefly shows the full route, then returns to navigation mode.
  Future<void> onRerouteComplete(ll.LatLng vehiclePosition, ll.LatLng destination, double bearing) async {
    if (!_mapController.isBound) return;

    // Brief overview of new route
    await fitRouteBounds(vehiclePosition, destination);

    // Then transition back to navigation mode after a short delay
    await Future.delayed(const Duration(milliseconds: 1500));
    await transitionToNavigation(vehiclePosition, bearing);
  }

  /// Fits the camera to show both the driver and a target point.
  Future<void> fitDriverAndTarget(ll.LatLng driver, ll.LatLng target) async {
    if (!_mapController.isBound) return;

    try {
      final bounds = CoordinateBounds(
        southwest: ll.LatLng(
          driver.latitude < target.latitude ? driver.latitude : target.latitude,
          driver.longitude < target.longitude ? driver.longitude : target.longitude,
        ),
        northeast: ll.LatLng(
          driver.latitude > target.latitude ? driver.latitude : target.latitude,
          driver.longitude > target.longitude ? driver.longitude : target.longitude,
        ),
      );

      final cameraOptions = await _mapController.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 120.0, bottom: 300.0, left: 60.0, right: 60.0),
      );

      if (cameraOptions != null) {
        final finalZoom = (cameraOptions.zoom ?? 14.5).clamp(12.0, 16.5);
        await _mapController.easeCamera(
          CameraOptions(
            center: cameraOptions.center,
            zoom: finalZoom,
            bearing: 0.0,
            pitch: 0.0,
          ),
          animationOptions: MapAnimationOptions(duration: 800),
        );
      }
    } catch (_) {}
  }
}
