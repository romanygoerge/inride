import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../core/state/global_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_coordinates_helper.dart';
import '../../core/repositories/ride_repository.dart';
import '../../core/services/location_service.dart';
import '../../core/services/trip_navigation_manager.dart';
import '../../core/controllers/map_controller.dart';
import '../../core/controllers/navigation_controller.dart';
import '../../core/DI/injection_container.dart' show sl;
import '../../core/controllers/marker_manager.dart'; // VehicleMarkerWidget
import '../../core/utils/vehicle_helper.dart';

class NearbyDriverInfo {
  final double lat;
  final double lng;
  final String vehicleType;
  NearbyDriverInfo({required this.lat, required this.lng, required this.vehicleType});
}

class OsmMapWidget extends StatefulWidget {
  final bool showPOIs;
  final double bottomPadding;
  const OsmMapWidget({super.key, this.showPOIs = false, this.bottomPadding = 260});

  @override
  State<OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<OsmMapWidget> with TickerProviderStateMixin {
  final fm.MapController _flutterMapController = fm.MapController();

  String _normalizeVehicleType(String type) => VehicleHelper.normalizeVehicleType(type);

  bool _isAutoFollow = true;
  bool _isDisposed = false;
  bool _isLocating = false;

  StreamSubscription? _driversSubscription;
  List<NearbyDriverInfo> _nearbyDriversList = [];

  // User location tracking variables (for idle state)
  StreamSubscription<geo.Position>? _userLocationSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  ll.LatLng? _currentMarkerLatLng;
  double _currentMarkerBearing = 0.0;
  geo.Position? _lastFilteredPosition;

  // Animation controller for smooth transition of the user marker
  AnimationController? _markerAnimController;
  ll.LatLng? _animStartLatLng;
  ll.LatLng? _animEndLatLng;
  double _animStartBearing = 0.0;
  double _animEndBearing = 0.0;

  @override
  void initState() {
    super.initState();

    _markerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _markerAnimController!.addListener(_onMarkerAnimTick);

    // Bind map controller wrapper
    sl<MapController>().bind(_flutterMapController);
    sl<MapController>().setVsync(this);

    GlobalState.instance.addListener(_onStateChange);
    // Listen to MapController state changes to rebuild overlays
    sl<MapController>().addListener(_onMapControllerChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToNearbyDrivers();
      _initUserLocationTracking();
    });
  }

  void _onMapControllerChange() {
    if (mounted && !_isDisposed && !(_markerAnimController?.isAnimating ?? false)) {
      setState(() {});
    }
  }

  void _onStateChange() {
    if (!mounted || _isDisposed) return;
    final state = GlobalState.instance;
    if (state.rideStatus != RideStatus.idle && state.rideStatus != RideStatus.completed) {
      if (_isAutoFollow && state.driverLatitude != null && state.driverLongitude != null) {
        final driverLatLng = ll.LatLng(state.driverLatitude!, state.driverLongitude!);
        sl<MapController>().easeCamera(
          CameraOptions(center: driverLatLng, zoom: 16.0),
          animationOptions: MapAnimationOptions(duration: 800),
        );
      }
    }
    setState(() {});
  }

  Future<void> _getCurrentLocationAndCenter() async {
    final state = GlobalState.instance;
    setState(() {
      _isAutoFollow = true;
    });

    if (sl<TripNavigationManager>().isNavigating) {
      final navCtrl = sl<NavigationController>();
      navCtrl.setAutoFollow(true);
      if (navCtrl.snappedLocation != null) {
        sl<TripNavigationManager>().cameraController?.recenter(navCtrl.snappedLocation!, GlobalState.instance.driverBearing);
      }
      return;
    }

    if (state.rideStatus != RideStatus.idle && state.rideStatus != RideStatus.completed) {
      if (state.driverLatitude != null && state.driverLongitude != null) {
        final driverLatLng = ll.LatLng(state.driverLatitude!, state.driverLongitude!);
        await sl<MapController>().easeCamera(
          CameraOptions(center: driverLatLng, zoom: 16.0),
          animationOptions: MapAnimationOptions(duration: 800),
        );
      } else if (_currentMarkerLatLng != null) {
        await sl<MapController>().easeCamera(
          CameraOptions(center: _currentMarkerLatLng, zoom: 16.0),
          animationOptions: MapAnimationOptions(duration: 800),
        );
      }
      return;
    }

    if (_isLocating) return;
    setState(() {
      _isLocating = true;
    });

    try {
      final hasPermission = await LocationService.instance.checkPermission();
      if (!hasPermission) return;

      final isGPSEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!isGPSEnabled) return;

      final position = await LocationService.instance.getCurrentLocation();
      if (position != null) {
        final newLatLng = ll.LatLng(position.latitude, position.longitude);
        
        await sl<MapController>().easeCamera(
          CameraOptions(
            center: newLatLng,
            zoom: 16.0,
          ),
          animationOptions: MapAnimationOptions(duration: 800),
        );
        
        MapCoordinatesHelper.deviceLocation = newLatLng;
        _onUserLocationUpdate(position);
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _initUserLocationTracking() async {
    _userLocationSubscription?.cancel();
    _compassSubscription?.cancel();
    
    try {
      final hasPermission = await LocationService.instance.checkPermission();
      if (!hasPermission) return;

      final isGPSEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!isGPSEnabled) return;

      final compassStream = FlutterCompass.events;
      if (compassStream != null) {
        _compassSubscription = compassStream.listen(
          (event) => _onCompassUpdate(event.heading),
          onError: (err) => debugPrint("[Compass] Stream error: $err"),
        );
      }

      final initialPosition = await LocationService.instance.getCurrentLocation();
      if (initialPosition != null && !_isDisposed) {
        final initialLatLng = ll.LatLng(initialPosition.latitude, initialPosition.longitude);
        _lastFilteredPosition = initialPosition;
        
        setState(() {
          _currentMarkerLatLng = initialLatLng;
          _currentMarkerBearing = initialPosition.heading;
        });

        MapCoordinatesHelper.deviceLocation = initialLatLng;

        if (_isAutoFollow && !sl<TripNavigationManager>().isNavigating) {
          await sl<MapController>().easeCamera(
            CameraOptions(
              center: initialLatLng,
              zoom: 16.5,
              bearing: 0.0,
            ),
            animationOptions: MapAnimationOptions(duration: 800),
          );
        }
      }

      _userLocationSubscription = LocationService.instance.getLocationStream().listen(
        _onUserLocationUpdate,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("[Live Tracking] Error starting tracking: $e");
    }
  }

  void _onUserLocationUpdate(geo.Position position) {
    if (_isDisposed) return;
    if (sl<TripNavigationManager>().isNavigating) return; // Managed by TripNavigationManager

    // Simple jump filter
    if (_lastFilteredPosition != null) {
      final double dt = position.timestamp.difference(_lastFilteredPosition!.timestamp).inMilliseconds / 1000.0;
      final double distance = geo.Geolocator.distanceBetween(
        _lastFilteredPosition!.latitude,
        _lastFilteredPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (dt > 0) {
        final double speed = distance / dt;
        if (speed > 35.0 && distance > 60.0 && dt < 15.0) return; // Reject jump
      }
    }

    _lastFilteredPosition = position;
    final newLatLng = ll.LatLng(position.latitude, position.longitude);
    final isMoving = position.speed > 0.833;
    final newBearing = position.heading;

    MapCoordinatesHelper.deviceLocation = newLatLng;

    if (_currentMarkerLatLng == null) {
      setState(() {
        _currentMarkerLatLng = newLatLng;
        _currentMarkerBearing = newBearing;
      });

      if (_isAutoFollow) {
        sl<MapController>().easeCamera(
          CameraOptions(center: newLatLng, zoom: 16.5),
          animationOptions: MapAnimationOptions(duration: 600),
        );
      }
    } else {
      _animStartLatLng = _currentMarkerLatLng ?? newLatLng;
      _animEndLatLng = newLatLng;
      _animStartBearing = _currentMarkerBearing;
      _animEndBearing = isMoving ? _normalizeBearingAngle(_animStartBearing, newBearing) : _animStartBearing;

      if (_isAutoFollow) {
        sl<MapController>().easeCamera(
          CameraOptions(center: newLatLng, zoom: 16.5),
          animationOptions: MapAnimationOptions(duration: 600),
        );
      }

      if (_markerAnimController != null) {
        _markerAnimController!.stop();
        _markerAnimController!.forward(from: 0.0);
      }
    }
  }

  void _onCompassUpdate(double? heading) {
    if (heading == null || _isDisposed || sl<TripNavigationManager>().isNavigating) return;
    
    final isMoving = _lastFilteredPosition != null && _lastFilteredPosition!.speed > 0.833;
    if (!isMoving) {
      final diff = (heading - _currentMarkerBearing).abs() % 360;
      final shortestDiff = diff > 180 ? 360 - diff : diff;
      if (shortestDiff < 3.0) return;
      
      _currentMarkerBearing = _lerpAngle(_currentMarkerBearing, heading, 0.3) % 360;
    }
  }

  void _onMarkerAnimTick() {
    if (_markerAnimController == null || _animStartLatLng == null || _animEndLatLng == null) return;
    if (sl<TripNavigationManager>().isNavigating) return;

    final t = _markerAnimController!.value;
    final lat = _animStartLatLng!.latitude + (_animEndLatLng!.latitude - _animStartLatLng!.latitude) * t;
    final lng = _animStartLatLng!.longitude + (_animEndLatLng!.longitude - _animStartLatLng!.longitude) * t;
    
    final isMoving = _lastFilteredPosition != null && _lastFilteredPosition!.speed > 0.833;
    if (isMoving) {
      final bearing = _animStartBearing + (_animEndBearing - _animStartBearing) * t;
      _currentMarkerBearing = bearing % 360;
    }
    
    _currentMarkerLatLng = ll.LatLng(lat, lng);

    if (t == 1.0 && mounted && !_isDisposed) {
      setState(() {});
    }
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

  double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff > 180) {
      diff -= 360;
    }
    if (diff < -180) {
      diff += 360;
    }
    return a + diff * t;
  }

  void _listenToNearbyDrivers() {
    _driversSubscription?.cancel();
    final state = GlobalState.instance;
    final startLatLng = MapCoordinatesHelper.getLatLngForAddress(state.fromAddress);

    _driversSubscription = RideRepository.instance
        .streamNearbyDrivers(
          lat: startLatLng.latitude,
          lng: startLatLng.longitude,
          radiusInKm: 5.0,
        )
        .listen((documents) {
      if (!mounted || _isDisposed) return;
      final List<NearbyDriverInfo> newList = [];
      try {
        for (final data in documents) {
          final lat = ((data['current_latitude'] ?? data['currentLatitude'] ?? data['latitude']) as num?)?.toDouble();
          final lng = ((data['current_longitude'] ?? data['currentLongitude'] ?? data['longitude']) as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          final String vehicleType = data['vehicle_type'] ?? data['vehicleType'] ?? 'car';
          newList.add(NearbyDriverInfo(lat: lat, lng: lng, vehicleType: vehicleType));
        }
      } catch (e) {
        debugPrint('[OsmMapWidget] Error processing drivers: $e');
      }
      if (mounted) {
        setState(() {
          _nearbyDriversList = newList;
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _markerAnimController?.dispose();
    _userLocationSubscription?.cancel();
    _compassSubscription?.cancel();
    _driversSubscription?.cancel();
    
    GlobalState.instance.removeListener(_onStateChange);
    sl<MapController>().removeListener(_onMapControllerChange);
    sl<MapController>().unbind();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final navManager = sl<TripNavigationManager>();
    final isNavigating = navManager.isNavigating;
    
    final defaultLoc = MapCoordinatesHelper.deviceLocation ?? const ll.LatLng(30.0130, 31.2080);
    
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) {
            if (_isAutoFollow) {
              setState(() { _isAutoFollow = false; });
            }
            if (isNavigating) {
              sl<NavigationController>().setAutoFollow(false);
            }
          },
          child: fm.FlutterMap(
            mapController: _flutterMapController,
            options: fm.MapOptions(
              initialCenter: defaultLoc,
              initialZoom: 13.5,
              onMapReady: () {
                navManager.initialize(sl<MapController>(), this);
                if (isNavigating) {
                  navManager.restoreActiveRoute();
                } else if (_currentMarkerLatLng != null) {
                  sl<MapController>().easeCamera(
                    CameraOptions(center: _currentMarkerLatLng, zoom: 16.5),
                    animationOptions: MapAnimationOptions(duration: 0),
                  );
                } else if (MapCoordinatesHelper.deviceLocation != null) {
                  sl<MapController>().easeCamera(
                    CameraOptions(center: MapCoordinatesHelper.deviceLocation, zoom: 16.5),
                    animationOptions: MapAnimationOptions(duration: 0),
                  );
                }
              },
            ),
            children: [
              fm.TileLayer(
                urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.inride.app',
                tileProvider: fm.NetworkTileProvider(),
              ),
              fm.PolylineLayer(
                polylines: sl<MapController>().polylines,
              ),
              fm.MarkerLayer(
                markers: [
                  ...sl<MapController>().allMarkers,
                  
                  // Show pulsing location marker only when NOT navigating
                  if (!isNavigating && _currentMarkerLatLng != null)
                    fm.Marker(
                      point: _currentMarkerLatLng!,
                      width: 64,
                      height: 64,
                      child: Transform.rotate(
                        angle: _currentMarkerBearing * math.pi / 180,
                        child: const PulseUserLocationMarker(),
                      ),
                    ),
                    
                  // Show nearby drivers only when idle
                  if (state.rideStatus == RideStatus.idle)
                    for (final driverData in _nearbyDriversList)
                      fm.Marker(
                        point: ll.LatLng(driverData.lat, driverData.lng),
                        width: 52,
                        height: 52,
                        child: VehicleMarkerWidget(type: driverData.vehicleType),
                      ),

                  // Show active trip markers for passenger view
                  if (state.rideStatus != RideStatus.idle && state.rideStatus != RideStatus.completed) ...[
                    // Pickup marker
                    fm.Marker(
                      point: state.currentRideRequest != null
                          ? ll.LatLng(state.currentRideRequest!.pickupLatitude, state.currentRideRequest!.pickupLongitude)
                          : MapCoordinatesHelper.getLatLngForAddress(state.fromAddress),
                      width: 52,
                      height: 52,
                      child: const PickupMarkerWidget(),
                    ),
                    // Destination marker
                    fm.Marker(
                      point: state.currentRideRequest != null
                          ? ll.LatLng(state.currentRideRequest!.destinationLatitude, state.currentRideRequest!.destinationLongitude)
                          : MapCoordinatesHelper.getLatLngForAddress(state.toAddress),
                      width: 52,
                      height: 52,
                      child: const DestinationMarkerWidget(),
                    ),
                    // Driver (Captain) marker
                    if (state.driverLatitude != null && state.driverLongitude != null)
                      fm.Marker(
                        point: ll.LatLng(state.driverLatitude!, state.driverLongitude!),
                        width: 52,
                        height: 52,
                        child: Transform.rotate(
                          angle: state.driverBearing * math.pi / 180,
                          child: VehicleMarkerWidget(
                            type: _normalizeVehicleType(state.acceptedOffer?.driver.vehicleType ?? 'car'),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Permanent Single Recenter/Location Button
        Positioned(
          bottom: widget.bottomPadding,
          right: 16,
          child: AnimatedScale(
            scale: _isLocating ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _isLocating ? null : _getCurrentLocationAndCenter,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: _isLocating
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumBlue),
                            ),
                          )
                        : const Icon(Icons.my_location, color: AppColors.mediumBlue, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CachedTileProvider extends fm.TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(fm.TileCoordinates coordinates, fm.TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(url, headers: const {'User-Agent': 'inRideApp/1.0'});
  }
}

class PulseUserLocationMarker extends StatefulWidget {
  const PulseUserLocationMarker({super.key});

  @override
  State<PulseUserLocationMarker> createState() => _PulseUserLocationMarkerState();
}

class _PulseUserLocationMarkerState extends State<PulseUserLocationMarker> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 24 + 40 * _pulseController!.value,
              height: 24 + 40 * _pulseController!.value,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.28 * (1.0 - _pulseController!.value)),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.navigation, color: Colors.white, size: 11)),
            ),
          ],
        );
      },
    );
  }
}
