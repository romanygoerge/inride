import 'package:latlong2/latlong.dart';

class RouteModel {
  final List<LatLng> points;
  final double distance; // in meters
  final double duration; // in seconds
  final List<RouteStep> steps;

  RouteModel({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
  });

  factory RouteModel.empty() {
    return RouteModel(
      points: [],
      distance: 0.0,
      duration: 0.0,
      steps: [],
    );
  }

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;
}

class RouteStep {
  final LatLng position;
  final double distance; // in meters
  final double duration; // in seconds
  final String streetName;
  final String nextStreetName; // name of the street after completing this maneuver
  final String instruction;
  final String maneuverType; // turn, roundabout, arrive, depart, new name, etc.
  final String maneuverModifier; // left, right, straight, slight left, sharp right, etc.
  final int pointIndex; // The index of the coordinate in RouteModel.points where this step starts
  final double maneuverDegree; // angle of the turn in degrees (0-360), 0 = straight
  final int? exitNumber; // roundabout exit number (1, 2, 3, etc.)

  RouteStep({
    required this.position,
    required this.distance,
    required this.duration,
    required this.streetName,
    this.nextStreetName = '',
    required this.instruction,
    required this.maneuverType,
    required this.maneuverModifier,
    required this.pointIndex,
    this.maneuverDegree = 0.0,
    this.exitNumber,
  });
}
