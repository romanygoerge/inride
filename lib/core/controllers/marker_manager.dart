import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'map_controller.dart';

class MarkerManager {
  final MapController _mapController;
  final TickerProvider _vsync;

  ll.LatLng? _pickupLatLng;
  ll.LatLng? _destinationLatLng;
  ll.LatLng? _driverLatLng;
  double _driverBearing = 0.0;
  String _driverVehicleType = 'car';

  // Animation controller for smooth vehicle marker movement
  AnimationController? _animController;
  ll.LatLng? _animStartLatLng;
  ll.LatLng? _animEndLatLng;
  double _animStartBearing = 0.0;
  double _animEndBearing = 0.0;

  MarkerManager({
    required MapController mapController,
    required TickerProvider vsync,
  })  : _mapController = mapController,
        _vsync = vsync {
    _animController = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 950), // slightly less than 1s GPS interval
    );
    _animController!.addListener(_onAnimTick);
  }

  /// Adds or updates the pickup marker.
  Future<void> addPickupMarker(ll.LatLng position) async {
    _pickupLatLng = position;
    _updateMapControllerMarkers();
  }

  /// Adds or updates the destination marker.
  Future<void> addDestinationMarker(ll.LatLng position) async {
    _destinationLatLng = position;
    _updateMapControllerMarkers();
  }

  /// Updates driver marker location and triggers smooth transition (interpolation).
  Future<void> updateDriverMarker(ll.LatLng position, double bearing, String vehicleType) async {
    _driverVehicleType = vehicleType;

    if (_driverLatLng == null) {
      _driverLatLng = position;
      _driverBearing = bearing;
      _animStartLatLng = position;
      _animEndLatLng = position;
      _animStartBearing = bearing;
      _animEndBearing = bearing;
      _updateMapControllerMarkers();
    } else {
      // Setup animation endpoints
      _animStartLatLng = _animEndLatLng ?? _driverLatLng ?? position;
      _animEndLatLng = position;

      _animStartBearing = _driverBearing;
      // Interpolate bearing using shortest path
      _animEndBearing = _normalizeBearingAngle(_animStartBearing, bearing);

      if (_animController != null) {
        _animController!.stop();
        _animController!.forward(from: 0.0);
      }
    }
  }

  void _onAnimTick() {
    if (_animController == null || _animStartLatLng == null || _animEndLatLng == null) {
      return;
    }

    final t = _animController!.value;
    final double lat = _animStartLatLng!.latitude + (_animEndLatLng!.latitude - _animStartLatLng!.latitude) * t;
    final double lng = _animStartLatLng!.longitude + (_animEndLatLng!.longitude - _animStartLatLng!.longitude) * t;
    final double bearing = _animStartBearing + (_animEndBearing - _animStartBearing) * t;

    _driverLatLng = ll.LatLng(lat, lng);
    _driverBearing = bearing % 360;
    
    _updateMapControllerMarkers();
  }

  void _updateMapControllerMarkers() {
    final List<fm.Marker> list = [];
    if (_pickupLatLng != null) {
      list.add(fm.Marker(
        point: _pickupLatLng!,
        width: 52,
        height: 52,
        child: const PickupMarkerWidget(),
      ));
    }
    if (_destinationLatLng != null) {
      list.add(fm.Marker(
        point: _destinationLatLng!,
        width: 52,
        height: 52,
        child: const DestinationMarkerWidget(),
      ));
    }
    if (_driverLatLng != null) {
      list.add(fm.Marker(
        point: _driverLatLng!,
        width: 52,
        height: 52,
        child: Transform.rotate(
          angle: _driverBearing * math.pi / 180,
          child: VehicleMarkerWidget(type: _driverVehicleType),
        ),
      ));
    }
    _mapController.updateUserMarkers(list);
  }

  double _normalizeBearingAngle(double start, double end) {
    double diff = (end - start) % 360;
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    return start + diff;
  }

  /// Clears all markers.
  Future<void> clear() async {
    _pickupLatLng = null;
    _destinationLatLng = null;
    _driverLatLng = null;
    _updateMapControllerMarkers();
  }

  void dispose() {
    _animController?.removeListener(_onAnimTick);
    _animController?.dispose();
    _animController = null;
  }
}

// Custom Marker Widgets matching the premium InDrive design system
class PickupMarkerWidget extends StatelessWidget {
  const PickupMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.85), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.location_on, color: Colors.cyan, size: 28),
      ),
    );
  }
}

class DestinationMarkerWidget extends StatelessWidget {
  const DestinationMarkerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red.withValues(alpha: 0.85), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.location_on, color: Colors.red, size: 28),
      ),
    );
  }
}

class VehicleMarkerWidget extends StatelessWidget {
  final String type;
  const VehicleMarkerWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.blue;
    IconData icon = Icons.directions_car_filled;
    if (type == 'scooter') {
      color = Colors.orange;
      icon = Icons.electric_scooter;
    } else if (type == 'motorcycle') {
      color = Colors.red;
      icon = Icons.motorcycle;
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.85), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
