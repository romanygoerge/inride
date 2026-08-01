import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';

/// Compatibility classes to match old Mapbox APIs and prevent compilation errors
class CameraOptions {
  final LatLng? center;
  final double? zoom;
  final double? bearing;
  final double? pitch;

  CameraOptions({this.center, this.zoom, this.bearing, this.pitch});
}

class MapAnimationOptions {
  final int duration;
  MapAnimationOptions({required this.duration});
}

class CoordinateBounds {
  final LatLng southwest;
  final LatLng northeast;
  final bool infiniteBounds;

  CoordinateBounds({
    required this.southwest,
    required this.northeast,
    this.infiniteBounds = true,
  });
}

class MbxEdgeInsets {
  final double top;
  final double bottom;
  final double left;
  final double right;

  MbxEdgeInsets({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });
}

class MapController extends ChangeNotifier {
  fm.MapController? _flutterMapController;
  TickerProvider? _vsync;

  // Overlays state
  final List<fm.Marker> _userMarkers = [];
  final List<fm.Marker> _arrowMarkers = [];
  final List<fm.Polyline> _polylines = [];

  // Active camera animation controller
  AnimationController? _cameraAnimationController;

  void bind(fm.MapController controller) {
    _flutterMapController = controller;
  }

  void unbind() {
    _flutterMapController = null;
    _vsync = null;
    _cameraAnimationController?.stop();
    _cameraAnimationController?.dispose();
    _cameraAnimationController = null;
  }

  void setVsync(TickerProvider vsync) {
    _vsync = vsync;
  }

  bool get isBound => _flutterMapController != null;
  fm.MapController? get flutterMapController => _flutterMapController;

  // Overlays getters
  List<fm.Marker> get allMarkers => [..._userMarkers, ..._arrowMarkers];
  List<fm.Polyline> get polylines => [..._polylines];

  void updateUserMarkers(List<fm.Marker> markers) {
    _userMarkers.clear();
    _userMarkers.addAll(markers);
    notifyListeners();
  }

  void updateArrowMarkers(List<fm.Marker> markers) {
    _arrowMarkers.clear();
    _arrowMarkers.addAll(markers);
    notifyListeners();
  }

  void updatePolylines(List<fm.Polyline> polylines) {
    _polylines.clear();
    _polylines.addAll(polylines);
    notifyListeners();
  }

  void clearOverlays() {
    _userMarkers.clear();
    _arrowMarkers.clear();
    _polylines.clear();
    notifyListeners();
  }

  /// Smoothly animates the map viewport using custom cubic interpolation
  Future<void> easeCamera(CameraOptions cameraOptions, {MapAnimationOptions? animationOptions}) async {
    if (!isBound || _vsync == null) return;

    final targetCenter = cameraOptions.center ?? _flutterMapController!.camera.center;
    final targetZoom = cameraOptions.zoom ?? _flutterMapController!.camera.zoom;
    final targetBearing = cameraOptions.bearing ?? _flutterMapController!.camera.rotation;

    final duration = Duration(milliseconds: animationOptions?.duration ?? 600);

    // Stop current camera animations before starting a new one
    _cameraAnimationController?.stop();
    _cameraAnimationController?.dispose();

    _cameraAnimationController = AnimationController(vsync: _vsync!, duration: duration);

    final startCenter = _flutterMapController!.camera.center;
    final startZoom = _flutterMapController!.camera.zoom;
    final startBearing = _flutterMapController!.camera.rotation;

    // Normalize bearing to find shortest angle rotation path
    double diff = (targetBearing - startBearing) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final endBearing = startBearing + diff;

    final animation = CurvedAnimation(
      parent: _cameraAnimationController!,
      curve: Curves.easeOutCubic,
    );

    final completer = Completer<void>();

    _cameraAnimationController!.addListener(() {
      final t = animation.value;
      final lat = startCenter.latitude + (targetCenter.latitude - startCenter.latitude) * t;
      final lng = startCenter.longitude + (targetCenter.longitude - startCenter.longitude) * t;
      final zoom = startZoom + (targetZoom - startZoom) * t;
      final bearing = startBearing + (endBearing - startBearing) * t;

      if (isBound) {
        _flutterMapController!.move(LatLng(lat, lng), zoom);
        _flutterMapController!.rotate(bearing % 360);
      }
    });

    _cameraAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        if (!completer.isCompleted) completer.complete();
      }
    });

    _cameraAnimationController!.forward();

    return completer.future;
  }

  /// Alias for easeCamera to support flight transitions
  Future<void> flyCamera(CameraOptions cameraOptions, {MapAnimationOptions? animationOptions}) async {
    await easeCamera(cameraOptions, animationOptions: animationOptions);
  }

  /// Moves and rotates the camera instantly without animation
  Future<void> setCamera(CameraOptions cameraOptions) async {
    if (!isBound) return;
    final targetCenter = cameraOptions.center ?? _flutterMapController!.camera.center;
    final targetZoom = cameraOptions.zoom ?? _flutterMapController!.camera.zoom;
    final targetBearing = cameraOptions.bearing ?? _flutterMapController!.camera.rotation;

    _flutterMapController!.move(targetCenter, targetZoom);
    _flutterMapController!.rotate(targetBearing % 360);
  }

  /// Calculates the camera options required to fit the coordinate bounds with padding
  Future<CameraOptions?> cameraForCoordinateBounds(
    CoordinateBounds bounds,
    MbxEdgeInsets padding, {
    double? bearing,
    double? pitch,
  }) async {
    if (!isBound) return null;

    final centerZoom = fm.CameraFit.bounds(
      bounds: fm.LatLngBounds(bounds.southwest, bounds.northeast),
      padding: EdgeInsets.only(
        top: padding.top,
        bottom: padding.bottom,
        left: padding.left,
        right: padding.right,
      ),
    ).fit(_flutterMapController!.camera);

    return CameraOptions(
      center: centerZoom.center,
      zoom: centerZoom.zoom,
      bearing: bearing ?? 0.0,
      pitch: pitch ?? 0.0,
    );
  }

  /// Fits camera to bounds between two LatLng points
  void fitBounds(LatLng start, LatLng end) {
    if (!isBound) return;
    final bounds = fm.LatLngBounds(start, end);
    _flutterMapController?.fitCamera(fm.CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }
}

