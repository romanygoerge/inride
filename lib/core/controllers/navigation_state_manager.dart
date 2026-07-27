import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'navigation_state.dart';
import '../models/route_model.dart';

/// Central state manager for the navigation system.
///
/// This is the **single source of truth** for all navigation data.
/// UI widgets should listen to this instead of individual controllers.
/// Controllers update state through well-defined methods.
class NavigationStateManager extends ChangeNotifier {
  NavigationData _state = NavigationData.idle;

  /// The current immutable navigation state snapshot.
  NavigationData get state => _state;

  // ─── Convenience getters (backward-compatible with old NavigationController API) ───

  RouteModel? get activeRoute => _state.activeRoute;
  LatLng? get snappedLocation => _state.snappedLocation;
  double get remainingDistance => _state.remainingDistance;
  double get remainingDuration => _state.remainingDuration;
  int get currentStepIndex => _state.currentStepIndex;
  double get distanceToNextTurn => _state.distanceToNextTurn;
  double get speed => _state.speed;
  double get speedKmH => _state.speedKmH;
  double get bearing => _state.bearing;
  bool get isOffRoute => _state.isOffRoute;
  bool get isAutoFollow => _state.isAutoFollow;
  NavigationPhase get phase => _state.phase;
  String get errorMessage => _state.errorMessage;
  bool get isNavigating => _state.isNavigating;
  bool get isRerouting => _state.phase == NavigationPhase.rerouting;
  int get lastMatchedSegmentIndex => _state.lastMatchedSegmentIndex;

  RouteStep? get currentStep => _state.currentStep;
  RouteStep? get nextStep => _state.nextStep;
  String get currentStreetName => _state.currentStreetName;
  String get nextStreetName => _state.nextStreetName;
  String get currentInstruction => _state.currentInstruction;
  String get maneuverType => _state.maneuverType;
  String get maneuverModifier => _state.maneuverModifier;
  double get maneuverDegree => _state.maneuverDegree;
  int? get exitNumber => _state.exitNumber;
  String get formattedETA => _state.formattedETA;
  String get formattedRemainingDistance => _state.formattedRemainingDistance;
  String get formattedDistanceToTurn => _state.formattedDistanceToTurn;
  List<LatLng> get remainingRoutePoints => _state.remainingRoutePoints;

  // ─── State Mutation Methods (called by individual controllers) ───

  /// Sets the active route and transitions to route overview phase.
  void setRoute(RouteModel route) {
    _state = _state.copyWith(
      phase: NavigationPhase.routeOverview,
      activeRoute: route,
      remainingDistance: route.distance,
      remainingDuration: route.duration,
      currentStepIndex: 0,
      distanceToNextTurn: route.steps.isNotEmpty ? route.steps[0].distance : 0.0,
      isOffRoute: false,
      errorMessage: '',
      lastMatchedSegmentIndex: 0,
    );
    notifyListeners();
  }

  /// Transitions to active navigation phase.
  void beginActiveNavigation() {
    if (_state.activeRoute == null) return;
    _state = _state.copyWith(
      phase: NavigationPhase.activeNavigation,
      isAutoFollow: true,
    );
    notifyListeners();
  }

  /// Updates snapped location from SnapToRouteController.
  void updateSnappedLocation(LatLng snapped, int segmentIndex, bool isOffRoute) {
    _state = _state.copyWith(
      snappedLocation: snapped,
      lastMatchedSegmentIndex: segmentIndex,
      isOffRoute: isOffRoute,
    );
    // Don't notify here — will be done in batch by updateTrackingMetrics
  }

  /// Updates tracking metrics from RouteTrackingController.
  void updateTrackingMetrics({
    required double remainingDistance,
    required double remainingDuration,
    required int currentStepIndex,
    required double distanceToNextTurn,
  }) {
    _state = _state.copyWith(
      remainingDistance: remainingDistance,
      remainingDuration: remainingDuration,
      currentStepIndex: currentStepIndex,
      distanceToNextTurn: distanceToNextTurn,
    );
    notifyListeners();
  }

  /// Updates speed and bearing from LocationController.
  void updateMotion(double speed, double bearing) {
    _state = _state.copyWith(speed: speed, bearing: bearing);
    // Don't notify separately — batched with tracking update
  }

  /// Updates the navigation phase.
  void setPhase(NavigationPhase phase, {String message = ''}) {
    if (_state.phase != phase || _state.errorMessage != message) {
      _state = _state.copyWith(phase: phase, errorMessage: message);
      notifyListeners();
    }
  }

  /// Updates auto-follow state.
  void setAutoFollow(bool active) {
    if (_state.isAutoFollow != active) {
      _state = _state.copyWith(isAutoFollow: active);
      notifyListeners();
    }
  }

  /// Replaces route after recalculation (reroute).
  void replaceRoute(RouteModel newRoute) {
    _state = _state.copyWith(
      phase: NavigationPhase.activeNavigation,
      activeRoute: newRoute,
      remainingDistance: newRoute.distance,
      remainingDuration: newRoute.duration,
      currentStepIndex: 0,
      distanceToNextTurn: newRoute.steps.isNotEmpty ? newRoute.steps[0].distance : 0.0,
      isOffRoute: false,
      errorMessage: '',
      lastMatchedSegmentIndex: 0,
    );
    notifyListeners();
  }

  /// Resets all state back to idle.
  void reset() {
    _state = NavigationData.idle;
    notifyListeners();
  }
}
