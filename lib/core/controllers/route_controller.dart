import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../repositories/route_repository.dart';
import 'navigation_state.dart';
import 'navigation_state_manager.dart';

/// Manages route fetching with retry logic and cache coordination.
///
/// Encapsulates the route fetch → parse → deliver pipeline that was
/// previously embedded inside [TripNavigationManager].
class RouteController {
  final RouteService _routeService;
  final RouteRepository _routeRepository;
  final NavigationStateManager _stateManager;

  /// Maximum number of retry attempts for route fetching.
  static const int maxRetries = 3;

  /// Last successfully fetched route points (used for offline fallback).
  List<LatLng>? _lastKnownRoutePoints;

  /// Called when a new route is successfully fetched.
  void Function(RouteModel route)? onRouteReady;

  RouteController({
    required RouteService routeService,
    required RouteRepository routeRepository,
    required NavigationStateManager stateManager,
  })  : _routeService = routeService,
        _routeRepository = routeRepository,
        _stateManager = stateManager;

  List<LatLng>? get lastKnownRoutePoints => _lastKnownRoutePoints;

  /// Fetches a route from start to end with exponential backoff retry.
  ///
  /// Updates [NavigationStateManager] with the result.
  /// Returns the fetched [RouteModel] or null on failure.
  Future<RouteModel?> fetchRoute(LatLng start, LatLng end) async {
    _stateManager.setPhase(NavigationPhase.routeLoading);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final route = await _routeService.getRoute(start, end);

        if (route.isEmpty) {
          if (attempt == maxRetries) {
            _stateManager.setPhase(NavigationPhase.error, message: 'لم يتم العثور على مسار');
            return null;
          }
          continue;
        }

        _lastKnownRoutePoints = route.points;
        _stateManager.setRoute(route);
        onRouteReady?.call(route);
        return route;
      } catch (e) {
        debugPrint('[RouteController] Route fetch attempt $attempt/$maxRetries failed: $e');

        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        } else {
          // All retries exhausted
          if (_lastKnownRoutePoints != null && _lastKnownRoutePoints!.isNotEmpty) {
            _stateManager.setPhase(NavigationPhase.offline, message: 'يتم عرض آخر مسار معروف');
          } else {
            _stateManager.setPhase(NavigationPhase.error, message: 'فشل تحميل المسار. تحقق من الاتصال');
          }
          return null;
        }
      }
    }
    return null;
  }

  /// Fetches a new route for rerouting (used by [RouteRecalculationController]).
  ///
  /// Does NOT update the state manager directly — the caller is responsible
  /// for calling [NavigationStateManager.replaceRoute()].
  Future<RouteModel?> fetchRouteForReroute(LatLng currentLocation, LatLng destination) async {
    try {
      // Clear old cache for this coordinate pair
      _routeRepository.clearCache();

      final route = await _routeService.getRoute(currentLocation, destination);
      if (route.isNotEmpty) {
        _lastKnownRoutePoints = route.points;
        return route;
      }
    } catch (e) {
      debugPrint('[RouteController] Reroute fetch failed: $e');
    }
    return null;
  }

  /// Fetches a secondary route without altering navigation state
  Future<RouteModel?> fetchSecondaryRoute(LatLng start, LatLng end) async {
    try {
      final route = await _routeService.getRoute(start, end);
      if (route.isNotEmpty) {
        return route;
      }
    } catch (e) {
      debugPrint('[RouteController] Secondary route fetch failed: $e');
    }
    return null;
  }

  /// Clears internal cached route data.
  void clearCache() {
    _lastKnownRoutePoints = null;
    _routeRepository.clearCache();
  }
}
