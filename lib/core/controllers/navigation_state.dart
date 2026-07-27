import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

/// All possible phases of the navigation lifecycle.
enum NavigationPhase {
  /// No navigation session is active.
  idle,

  /// A route is being fetched from the routing engine.
  routeLoading,

  /// The route has been fetched and is shown as an overview (fit bounds).
  routeOverview,

  /// Active turn-by-turn navigation with camera following the driver.
  activeNavigation,

  /// The driver went off-route and a new route is being calculated.
  rerouting,

  /// The driver has arrived at the target (pickup or destination).
  arrived,

  /// GPS signal has been lost for more than the threshold duration.
  gpsLost,

  /// The system is operating on a cached route without network.
  offline,

  /// A fatal error occurred (e.g. route fetch failed after all retries).
  error,
}

/// Immutable snapshot of all navigation data at a single point in time.
/// Used by [NavigationStateManager] and consumed by the UI layer.
class NavigationData {
  final NavigationPhase phase;
  final RouteModel? activeRoute;
  final LatLng? snappedLocation;
  final double remainingDistance; // meters
  final double remainingDuration; // seconds
  final int currentStepIndex;
  final double distanceToNextTurn; // meters
  final double speed; // meters/second
  final double bearing; // degrees 0-360
  final bool isOffRoute;
  final bool isAutoFollow;
  final String errorMessage;
  final int lastMatchedSegmentIndex;

  const NavigationData({
    this.phase = NavigationPhase.idle,
    this.activeRoute,
    this.snappedLocation,
    this.remainingDistance = 0.0,
    this.remainingDuration = 0.0,
    this.currentStepIndex = 0,
    this.distanceToNextTurn = 0.0,
    this.speed = 0.0,
    this.bearing = 0.0,
    this.isOffRoute = false,
    this.isAutoFollow = true,
    this.errorMessage = '',
    this.lastMatchedSegmentIndex = 0,
  });

  /// Creates a copy with selective overrides.
  NavigationData copyWith({
    NavigationPhase? phase,
    RouteModel? activeRoute,
    LatLng? snappedLocation,
    double? remainingDistance,
    double? remainingDuration,
    int? currentStepIndex,
    double? distanceToNextTurn,
    double? speed,
    double? bearing,
    bool? isOffRoute,
    bool? isAutoFollow,
    String? errorMessage,
    int? lastMatchedSegmentIndex,
  }) {
    return NavigationData(
      phase: phase ?? this.phase,
      activeRoute: activeRoute ?? this.activeRoute,
      snappedLocation: snappedLocation ?? this.snappedLocation,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      distanceToNextTurn: distanceToNextTurn ?? this.distanceToNextTurn,
      speed: speed ?? this.speed,
      bearing: bearing ?? this.bearing,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      isAutoFollow: isAutoFollow ?? this.isAutoFollow,
      errorMessage: errorMessage ?? this.errorMessage,
      lastMatchedSegmentIndex: lastMatchedSegmentIndex ?? this.lastMatchedSegmentIndex,
    );
  }

  /// Convenience getters matching the old NavigationController API.
  double get speedKmH => speed * 3.6;
  bool get isNavigating => phase != NavigationPhase.idle;

  RouteStep? get currentStep {
    if (activeRoute == null || activeRoute!.steps.isEmpty) return null;
    if (currentStepIndex >= activeRoute!.steps.length) return null;
    return activeRoute!.steps[currentStepIndex];
  }

  RouteStep? get nextStep {
    if (activeRoute == null || activeRoute!.steps.isEmpty) return null;
    final nextIdx = currentStepIndex + 1;
    if (nextIdx >= activeRoute!.steps.length) return null;
    return activeRoute!.steps[nextIdx];
  }

  String get currentStreetName => currentStep?.streetName ?? '';

  String get nextStreetName {
    if (currentStep?.nextStreetName.isNotEmpty == true) {
      return currentStep!.nextStreetName;
    }
    return nextStep?.streetName ?? '';
  }

  String get currentInstruction {
    if (activeRoute == null || activeRoute!.steps.isEmpty) return 'اتبع المسار المرسوم';
    return currentStep?.instruction ?? 'اتبع المسار المرسوم';
  }

  String get maneuverType => currentStep?.maneuverType ?? '';
  String get maneuverModifier => currentStep?.maneuverModifier ?? '';
  double get maneuverDegree => currentStep?.maneuverDegree ?? 0.0;
  int? get exitNumber => currentStep?.exitNumber;

  /// Formatted remaining time string.
  String get formattedETA {
    final minutes = (remainingDuration / 60.0).ceil();
    if (minutes < 1) return 'أقل من دقيقة';
    if (minutes < 60) return '$minutes د';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours س';
    return '$hours س $mins د';
  }

  /// Formatted remaining distance string.
  String get formattedRemainingDistance {
    if (remainingDistance > 999) {
      return '${(remainingDistance / 1000).toStringAsFixed(1)} كم';
    }
    return '${remainingDistance.round()} م';
  }

  /// Formatted distance to next turn.
  String get formattedDistanceToTurn {
    if (distanceToNextTurn > 999) {
      return '${(distanceToNextTurn / 1000).toStringAsFixed(1)} كم';
    }
    return '${distanceToNextTurn.round()} م';
  }

  /// Returns the remaining route points starting from the snapped location.
  List<LatLng> get remainingRoutePoints {
    if (activeRoute == null || activeRoute!.points.isEmpty) return [];
    final idx = lastMatchedSegmentIndex;
    final List<LatLng> remPoints = [];
    if (snappedLocation != null) {
      remPoints.add(snappedLocation!);
    }
    if (idx + 1 < activeRoute!.points.length) {
      remPoints.addAll(activeRoute!.points.sublist(idx + 1));
    }
    return remPoints;
  }

  /// Reset to idle state.
  static const NavigationData idle = NavigationData();
}
