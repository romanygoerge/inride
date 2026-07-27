import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../services/tts_service.dart';
import 'navigation_state.dart';
import 'navigation_state_manager.dart';
import 'snap_to_route_controller.dart';
import 'route_tracking_controller.dart';

/// Backward-compatible navigation status enum (maps to NavigationPhase).
enum NavigationStatus {
  idle,
  active,
  rerouting,
  gpsLost,
  offline,
  error,
}

/// Main navigation orchestrator that coordinates all navigation sub-controllers.
///
/// This is the primary **public API** used by the UI layer (pages, widgets).
/// It delegates to specialized controllers internally while maintaining
/// a backward-compatible API matching the original NavigationController.
///
/// **Responsibilities:**
/// - Lifecycle management (start/stop navigation)
/// - Voice guidance (TTS) coordination
/// - Forwarding state from [NavigationStateManager] to listeners
///
/// **Delegates to:**
/// - [NavigationStateManager] — central state
/// - [SnapToRouteController] — GPS filtering and route snapping
/// - [RouteTrackingController] — step tracking and progress
/// - [TtsService] — Arabic voice guidance
class NavigationController extends ChangeNotifier {
  final NavigationStateManager _stateManager;
  final SnapToRouteController _snapController;
  final RouteTrackingController _trackingController;
  final TtsService _ttsService;

  // TTS multi-stage tracking state
  int _lastSpokenStepIndex = -1;
  bool _hasSpoken500m = false;
  bool _hasSpoken200m = false;
  bool _hasSpoken50m = false;
  bool _hasSpokenArriving = false;

  NavigationController({
    required NavigationStateManager stateManager,
    required SnapToRouteController snapController,
    required RouteTrackingController trackingController,
    required TtsService ttsService,
  })  : _stateManager = stateManager,
        _snapController = snapController,
        _trackingController = trackingController,
        _ttsService = ttsService {
    // Forward state manager changes to our listeners
    _stateManager.addListener(_onStateChanged);

    // Listen for step changes to reset TTS state
    _trackingController.onStepChanged = _onStepChanged;
  }

  // ─── Backward-Compatible Getters (delegated to NavigationStateManager) ───

  RouteModel? get activeRoute => _stateManager.activeRoute;
  LatLng? get snappedLocation => _stateManager.snappedLocation;
  double get remainingDistance => _stateManager.remainingDistance;
  double get remainingDuration => _stateManager.remainingDuration;
  int get currentStepIndex => _stateManager.currentStepIndex;
  double get distanceToNextTurn => _stateManager.distanceToNextTurn;
  double get speed => _stateManager.speed;
  double get speedKmH => _stateManager.speedKmH;
  bool get isVoiceMuted => _ttsService.isMuted;
  bool get isOffRoute => _stateManager.isOffRoute;
  bool get isAutoFollow => _stateManager.isAutoFollow;
  String get errorMessage => _stateManager.errorMessage;

  NavigationStatus get status => _phaseToStatus(_stateManager.phase);
  bool get isRerouting => _stateManager.isRerouting;

  RouteStep? get currentStep => _stateManager.currentStep;
  RouteStep? get nextStep => _stateManager.nextStep;
  String get currentStreetName => _stateManager.currentStreetName;
  String get nextStreetName => _stateManager.nextStreetName;
  String get currentInstruction => _stateManager.currentInstruction;
  String get maneuverType => _stateManager.maneuverType;
  String get maneuverModifier => _stateManager.maneuverModifier;
  double get maneuverDegree => _stateManager.maneuverDegree;
  int? get exitNumber => _stateManager.exitNumber;
  String get formattedETA => _stateManager.formattedETA;
  String get formattedRemainingDistance => _stateManager.formattedRemainingDistance;
  String get formattedDistanceToTurn => _stateManager.formattedDistanceToTurn;
  List<LatLng> get remainingRoutePoints => _stateManager.remainingRoutePoints;

  // ─── Lifecycle Methods ───

  /// Initializes navigation with a new route.
  void startNavigation(RouteModel route) {
    _snapController.reset();
    _stateManager.setRoute(route);
    _stateManager.beginActiveNavigation();
    _resetTtsState();
    notifyListeners();
  }

  /// Processes a raw GPS location update through the navigation pipeline:
  /// 1. Snap to route
  /// 2. Update tracking metrics
  /// 3. Handle voice instructions
  void updateLocation(LatLng rawLocation, double currentSpeed, {double accuracy = 10.0}) {
    if (_stateManager.activeRoute == null) return;

    // 1. Snap to route (includes Kalman filtering)
    final snapped = _snapController.snap(rawLocation, accuracy);
    if (snapped == null) return;

    // 2. Update tracking metrics
    _trackingController.updateProgress(snapped.coordinate, snapped.segmentIndex);

    // 3. Handle voice instructions
    _handleVoiceInstructions();
  }

  /// Stops the navigation session.
  void stopNavigation() {
    _snapController.reset();
    _stateManager.reset();
    _lastSpokenStepIndex = -1;
    _resetTtsState();
    _ttsService.stop();
    notifyListeners();
  }

  // ─── Voice Guidance ───

  void toggleVoiceMute() {
    _ttsService.toggleMute();
    notifyListeners();
  }

  // ─── Status Control (backward compatibility) ───

  void setStatus(NavigationStatus newStatus, {String message = ''}) {
    _stateManager.setPhase(_statusToPhase(newStatus), message: message);
  }

  void setAutoFollow(bool active) {
    _stateManager.setAutoFollow(active);
  }

  // ─── Internal ───

  void _onStateChanged() {
    notifyListeners();
  }

  void _onStepChanged(int previousIndex, int newIndex) {
    _resetTtsState();
    _lastSpokenStepIndex = newIndex;
  }

  /// Multi-stage voice guidance system.
  void _handleVoiceInstructions() {
    if (_stateManager.activeRoute == null || _stateManager.currentStep == null) return;

    // 1. New step announcement
    if (_stateManager.currentStepIndex != _lastSpokenStepIndex) {
      _lastSpokenStepIndex = _stateManager.currentStepIndex;
      _ttsService.speak(_stateManager.currentStep!.instruction);
      return;
    }

    final dist = _stateManager.distanceToNextTurn;
    final next = _stateManager.nextStep;

    // 2. ~500m warning
    if (!_hasSpoken500m && dist > 0 && dist < 550.0 && dist > 250.0) {
      if (next != null && next.maneuverType != 'arrive') {
        final dir = _getDirectionWord(next.maneuverModifier);
        _ttsService.speak('بعد 500 متر $dir');
        _hasSpoken500m = true;
      }
    }

    // 3. ~200m warning
    if (!_hasSpoken200m && dist > 0 && dist < 250.0 && dist > 80.0) {
      if (next != null) {
        if (next.maneuverType == 'arrive') {
          _ttsService.speak('وجهتك بعد 200 متر');
        } else {
          final dir = _getDirectionWord(next.maneuverModifier);
          String msg = 'بعد 200 متر $dir';
          if (next.streetName.isNotEmpty) {
            msg += ' إلى شارع ${next.streetName}';
          }
          _ttsService.speak(msg);
        }
        _hasSpoken200m = true;
      }
    }

    // 4. ~50m warning (NOW)
    if (!_hasSpoken50m && dist > 0 && dist < 60.0) {
      if (next != null) {
        if (next.maneuverType == 'arrive') {
          _ttsService.speak('وجهتك أمامك مباشرة');
        } else if (next.maneuverType == 'roundabout' || next.maneuverType == 'rotary') {
          final exitStr = _getExitWord(next.exitNumber);
          _ttsService.speak('ادخل الدوار الآن${exitStr != null ? " وخذ المخرج $exitStr" : ""}');
        } else {
          final dir = _getDirectionWord(next.maneuverModifier);
          _ttsService.speak('$dir الآن');
        }
        _hasSpoken50m = true;
      }
    }

    // 5. Arrival
    if (!_hasSpokenArriving && _stateManager.remainingDistance < 30.0 && _stateManager.currentStep?.maneuverType == 'arrive') {
      _ttsService.speak('لقد وصلت إلى وجهتك');
      _hasSpokenArriving = true;
    }
  }

  String _getDirectionWord(String modifier) {
    switch (modifier) {
      case 'left': return 'انعطف يساراً';
      case 'right': return 'انعطف يميناً';
      case 'slight left': return 'انحرف قليلاً لليسار';
      case 'slight right': return 'انحرف قليلاً لليمين';
      case 'sharp left': return 'انعطف بحدة لليسار';
      case 'sharp right': return 'انعطف بحدة لليمين';
      case 'uturn': return 'قم بالدوران للخلف';
      case 'straight': return 'استمر مباشرة';
      default: return 'استمر للأمام';
    }
  }

  String? _getExitWord(int? exitNumber) {
    if (exitNumber == null) return null;
    switch (exitNumber) {
      case 1: return 'الأول';
      case 2: return 'الثاني';
      case 3: return 'الثالث';
      case 4: return 'الرابع';
      case 5: return 'الخامس';
      default: return 'رقم $exitNumber';
    }
  }

  void _resetTtsState() {
    _hasSpoken500m = false;
    _hasSpoken200m = false;
    _hasSpoken50m = false;
    _hasSpokenArriving = false;
  }

  NavigationPhase _statusToPhase(NavigationStatus status) {
    switch (status) {
      case NavigationStatus.idle: return NavigationPhase.idle;
      case NavigationStatus.active: return NavigationPhase.activeNavigation;
      case NavigationStatus.rerouting: return NavigationPhase.rerouting;
      case NavigationStatus.gpsLost: return NavigationPhase.gpsLost;
      case NavigationStatus.offline: return NavigationPhase.offline;
      case NavigationStatus.error: return NavigationPhase.error;
    }
  }

  NavigationStatus _phaseToStatus(NavigationPhase phase) {
    switch (phase) {
      case NavigationPhase.idle: return NavigationStatus.idle;
      case NavigationPhase.routeLoading: return NavigationStatus.active;
      case NavigationPhase.routeOverview: return NavigationStatus.active;
      case NavigationPhase.activeNavigation: return NavigationStatus.active;
      case NavigationPhase.rerouting: return NavigationStatus.rerouting;
      case NavigationPhase.arrived: return NavigationStatus.active;
      case NavigationPhase.gpsLost: return NavigationStatus.gpsLost;
      case NavigationPhase.offline: return NavigationStatus.offline;
      case NavigationPhase.error: return NavigationStatus.error;
    }
  }

  @override
  void dispose() {
    _stateManager.removeListener(_onStateChanged);
    _trackingController.onStepChanged = null;
    super.dispose();
  }
}
