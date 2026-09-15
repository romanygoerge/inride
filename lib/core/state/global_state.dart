import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import '../models/place_location.dart';
import '../models/route_model.dart';
import '../repositories/route_repository.dart';
import '../services/search_history_service.dart';
import '../controllers/map_controller.dart';
import '../models/ride_request_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/ride_repository.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/delete_account_service.dart';
import '../localization/locale_controller.dart';
import '../utils/map_coordinates_helper.dart';
import '../utils/uuid_generator.dart';
import '../utils/app_logger.dart';
import '../../main.dart' show navigatorKey;
import '../../shared/widgets/in_app_notification.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../DI/injection_container.dart' show sl;
import '../services/app_notification_service.dart';
import '../services/notification_service.dart';
import '../services/ride_sound_service.dart';
import '../services/driver_location_service.dart';
import '../controllers/notification_controller.dart';
import '../services/phone_auth_service.dart';
import '../services/meta_analytics_service.dart';
import '../services/support_chat_service.dart';

enum UserRole { rider, driver }


enum DriverVerificationStatus { unregistered, submitted, verified, rejected }

enum RideStatus {
  idle,
  searching,
  driverBidding,
  driverOnWay,
  arrived,
  tripStarted,
  completed,
  cancelled,
  expired
}

class DriverInfo {
  final String name;
  final double rating;
  final int ratingCount;
  final String vehicleType;
  final String vehicleName;
  final String vehicleColor;
  final String licensePlate;
  final String avatar;
  final String phoneNumber;
  final int completedTrips;
  final int completedDeliveries;

  DriverInfo({
    required this.name,
    required this.rating,
    int? ratingCount,
    required this.vehicleType,
    required this.vehicleName,
    required this.vehicleColor,
    required this.licensePlate,
    required this.avatar,
    this.phoneNumber = '',
    int? completedTrips,
    int? completedDeliveries,
  }) : ratingCount = ratingCount ?? 0,
       completedTrips = completedTrips ?? 0,
       completedDeliveries = completedDeliveries ?? 0;
}

class DriverOffer {
  final DriverInfo driver;
  final String driverId;
  final double price;
  final int etaMinutes;
  final String status;

  DriverOffer({
    required this.driver,
    required this.driverId,
    required this.price,
    required this.etaMinutes,
    this.status = 'pending',
  });
}

class GlobalState extends ChangeNotifier with WidgetsBindingObserver {
  static final GlobalState _instance = GlobalState._internal();
  factory GlobalState() => _instance;
  GlobalState._internal() {
    _loadProfileFromCache();
    _initAuthListener();
    _initSettingsListener();
    _initPaymentMethodsListener();
    _startConnectivityMonitor();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Public method to trigger listeners update
  void notify() => notifyListeners();

  static const _lifecycleChannel = MethodChannel('com.inride.app/lifecycle');
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _syncSessionToNative() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final session = _supabase.auth.currentSession;
      await _lifecycleChannel.invokeMethod('updateSessionInfo', {
        'requestId': _currentRequestId,
        'role': _currentRole.name,
        'rideStatus': _rideStatus.name,
        'accessToken': session?.accessToken,
      });
      debugPrint('[Lifecycle] Synced session to native: $_currentRequestId, $_currentRole');
    } catch (e) {
      debugPrint('[Lifecycle] Error syncing session to native: $e');
    }
  }

  Map<String, dynamic> appSettings = {
    'first_km_fare': 20.0,
    'extra_km_fare': 5.0,
    'ac_km_fare': 1.0,
    'heat_hour_km_fare': 1.0,
    'heat_start_hour': 11,
    'heat_end_hour': 15,
    'defaultFareCar': 45.0,
    'defaultFareScooter': 20.0,
    'defaultFareMotorcycle': 15.0,
    'commissionRate': 10.0,
    'minFare': 10.0,
    'maxFare': 500.0,
  };

  static GlobalState get instance => _instance;

  // Authentication State
  String? phoneNumber;
  bool isLoggedIn = false;
  bool isAuthResolved = false;
  
  UserRole _currentRole = UserRole.rider;
  UserRole get currentRole => _currentRole;
  set currentRole(UserRole val) {
    if (_currentRole == val) return;
    _currentRole = val;
    _syncSessionToNative();
  }
  String? userUid;
  String? passengerName;
  String? passengerGender;
  String? passengerAddress;
  String? userName;
  String? userAvatarUrl;
  String? referralCode;
  double userRating = 0.0;
  int userTotalRatingsCount = 0;
  int userCompletedTripsCount = 0;
  bool isOffline = false;

  // Driver Document State
  DriverVerificationStatus verificationStatus = DriverVerificationStatus.unregistered;
  String? driverAddress;
  String? driverRejectionReason;
  String? driverIdCardPath;
  String? driverLicensePath;
  String? vehicleRegistrationPath;
  String? vehicleName;
  String? vehicleNumber;
  String? driverVehicleColor;

  // Vehicle details (new fields)
  String? driverVehicleCategory; // 'motorcycle' or 'private_car'
  bool driverHasAC = false;
  int driverMaxPassengers = 4;
  String? driverNationalIdUrl;
  String? driverLicenseUrl;
  String? driverVehicleFrontUrl;
  List<String> driverVehicleImages = [];

  // App usage & presence tracking
  DateTime? _lastHeartbeatTime;
  Timer? _presenceHeartbeatTimer;
  Timer? _inactiveDebounceTimer;
  bool _isAppInForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[CaptainStatus] App lifecycle state changed: ${state.name}');
    if (state == AppLifecycleState.resumed) {
      _inactiveDebounceTimer?.cancel();
      _inactiveDebounceTimer = null;
      _onAppResumed();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _inactiveDebounceTimer?.cancel();
      _inactiveDebounceTimer = null;
      _onAppPaused();
    } else if (state == AppLifecycleState.inactive) {
      // Debounce transient inactive state (pulling notification shade, system popups)
      _inactiveDebounceTimer?.cancel();
      _inactiveDebounceTimer = Timer(const Duration(seconds: 3), () {
        if (!_isAppInForeground) return;
        _onAppPaused();
      });
    }
  }

  void _startPresenceTracking() {
    _lastHeartbeatTime = DateTime.now();
    _isAppInForeground = true;
    _recordAppOpen();
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPresenceHeartbeat();
    });
  }

  void _stopPresenceTracking() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _inactiveDebounceTimer?.cancel();
    _inactiveDebounceTimer = null;
    _recordAppClose();
    _isAppInForeground = false;
  }

  void _onAppResumed() {
    if (_isAppInForeground) return;
    _isAppInForeground = true;
    _lastHeartbeatTime = DateTime.now();
    _recordAppOpen();
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPresenceHeartbeat();
    });
  }

  void _onAppPaused() {
    if (!_isAppInForeground) return;
    _isAppInForeground = false;
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _recordAppClose();
  }

  Future<void> _recordAppOpen() async {
    final uid = userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;
    debugPrint('[CaptainStatus] Recording app open (server time) for user: $uid');
    try {
      await _supabase.rpc('record_user_app_open', params: {'p_user_id': uid});
      debugPrint('[CaptainStatus] ✓ record_user_app_open success for $uid');
    } catch (e) {
      debugPrint('[CaptainStatus] ❌ record_user_app_open RPC error: $e');
      try {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        final res = await _supabase.from('users').select('app_open_count').eq('id', uid).maybeSingle();
        final currentCount = (res?['app_open_count'] as num?)?.toInt() ?? 0;
        await _supabase.from('users').update({
          'is_app_open': true,
          'last_opened_at': nowIso,
          'last_seen_at': nowIso,
          'app_open_count': currentCount + 1,
        }).eq('id', uid);

        if (currentRole == UserRole.driver || hasDriverProfile) {
          await _supabase.from('drivers').update({
            'is_app_open': true,
            'last_app_open': nowIso,
            'last_seen_at': nowIso,
            'is_online': true,
            'updated_at': nowIso,
          }).eq('id', uid);
        }
      } catch (fbErr) {
        debugPrint('[CaptainStatus] _recordAppOpen fallback error: $fbErr');
      }
    }
  }

  Future<void> _sendPresenceHeartbeat() async {
    final uid = userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null || !_isAppInForeground) return;
    final now = DateTime.now();
    final elapsedSecs = _lastHeartbeatTime != null 
        ? now.difference(_lastHeartbeatTime!).inSeconds 
        : 30;
    _lastHeartbeatTime = now;
    final nowIso = now.toUtc().toIso8601String();

    debugPrint('[CaptainStatus] Sending heartbeat (elapsed: ${elapsedSecs}s) for user $uid');

    // 1. Send user app heartbeat
    try {
      await _supabase.rpc('record_user_app_heartbeat', params: {
        'p_user_id': uid,
        'p_elapsed_seconds': elapsedSecs,
      });
    } catch (_) {
      try {
        final res = await _supabase.from('users').select('total_app_time_seconds').eq('id', uid).maybeSingle();
        final currentTime = (res?['total_app_time_seconds'] as num?)?.toInt() ?? 0;
        await _supabase.from('users').update({
          'is_app_open': true,
          'last_seen_at': nowIso,
          'total_app_time_seconds': currentTime + elapsedSecs,
        }).eq('id', uid);
      } catch (e) {
        debugPrint('[CaptainStatus] _sendPresenceHeartbeat user fallback error: $e');
      }
    }

    // 2. Send captain dedicated heartbeat if driver profile exists or currentRole is driver
    if (currentRole == UserRole.driver || hasDriverProfile) {
      try {
        final params = <String, dynamic>{
          'p_driver_id': uid,
          'p_elapsed_seconds': elapsedSecs,
        };
        if (driverLatitude != null && driverLongitude != null) {
          params['p_lat'] = driverLatitude;
          params['p_lng'] = driverLongitude;
        }
        await _supabase.rpc('record_driver_heartbeat', params: params);
        debugPrint('[CaptainStatus] ✓ Driver heartbeat RPC success (lat=$driverLatitude, lng=$driverLongitude)');
      } catch (e) {
        debugPrint('[CaptainStatus] ❌ Driver heartbeat RPC error: $e');
        try {
          final driverHeartbeat = <String, dynamic>{
            'is_online': true,
            'is_app_open': true,
            'last_seen_at': nowIso,
            'updated_at': nowIso,
          };
          if (driverLatitude != null && driverLongitude != null) {
            driverHeartbeat['current_latitude'] = driverLatitude;
            driverHeartbeat['current_longitude'] = driverLongitude;
          }
          await _supabase.from('drivers').update(driverHeartbeat).eq('id', uid);
        } catch (fbErr) {
          debugPrint('[CaptainStatus] Driver heartbeat fallback update error: $fbErr');
        }
      }
    }
  }

  Future<void> _recordAppClose() async {
    final uid = userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final now = DateTime.now();
    final elapsedSecs = _lastHeartbeatTime != null 
        ? now.difference(_lastHeartbeatTime!).inSeconds 
        : 0;
    _lastHeartbeatTime = now;
    final nowIso = now.toUtc().toIso8601String();

    debugPrint('[CaptainStatus] Recording app close / background for user $uid');
    try {
      await _supabase.rpc('record_user_app_close', params: {
        'p_user_id': uid,
        'p_elapsed_seconds': elapsedSecs,
      });
      debugPrint('[CaptainStatus] ✓ record_user_app_close success');
    } catch (e) {
      debugPrint('[CaptainStatus] ❌ record_user_app_close RPC error: $e');
      try {
        final res = await _supabase.from('users').select('total_app_time_seconds').eq('id', uid).maybeSingle();
        final currentTime = (res?['total_app_time_seconds'] as num?)?.toInt() ?? 0;
        await _supabase.from('users').update({
          'is_app_open': false,
          'last_seen_at': nowIso,
          'total_app_time_seconds': currentTime + elapsedSecs,
        }).eq('id', uid);

        if (currentRole == UserRole.driver || hasDriverProfile) {
          await _supabase.from('drivers').update({
            'is_app_open': false,
            'last_seen_at': nowIso,
            'updated_at': nowIso,
          }).eq('id', uid);
        }
      } catch (fbErr) {
        debugPrint('[CaptainStatus] _recordAppClose fallback error: $fbErr');
      }
    }
  }

  bool get hasDriverProfile => verificationStatus == DriverVerificationStatus.verified || verificationStatus == DriverVerificationStatus.submitted || driverNationalIdUrl != null;
  bool get hasPassengerProfile {
    final pName = passengerName?.trim() ?? '';
    final uName = userName?.trim() ?? '';
    final hasValidPassengerName = pName.isNotEmpty && pName != 'مستخدم جديد' && pName != 'مستخدم' && pName != 'مستخدم هاتف' && pName != 'مستخدم inRide';
    final hasValidUserName = uName.isNotEmpty && uName != 'مستخدم جديد' && uName != 'مستخدم' && uName != 'مستخدم هاتف' && uName != 'مستخدم inRide';
    return hasValidPassengerName || hasValidUserName;
  }
  bool get hasDualRole => hasDriverProfile && hasPassengerProfile;

  Future<void> ensurePassengerProfileExists() async {
    if (userUid == null) return;
    if (!hasPassengerProfile) {
      final nameToUse = userName ?? (passengerName?.isNotEmpty == true ? passengerName : null) ?? 'مستخدم';
      final phoneToUse = phoneNumber ?? '';
      final genderToUse = passengerGender ?? 'ذكر';

      try {
        await _supabase.from('users').upsert({
          'id': userUid!,
          'name': nameToUse,
          'phone_number': phoneToUse,
          'role': 'rider',
        });

        await _supabase.from('passengers').upsert({
          'id': userUid!,
          'name': nameToUse,
          'gender': genderToUse,
          'phone': phoneToUse,
          'created_at': DateTime.now().toIso8601String(),
        });

        passengerName = nameToUse;
        passengerGender = genderToUse;
        notifyListeners();
      } catch (e) {
        debugPrint('Error ensuring passenger profile exists: $e');
      }
    }
  }

  // Rider Request States
  String? fromAddress;
  String? toAddress;
  PlaceLocation? selectedDestinationLocation;
  double? toLat;
  double? toLng;
  double? fromLat;
  double? fromLng;
  RouteModel? currentRouteModel;
  double? calculatedRouteDistanceKm;
  double? calculatedRouteDurationMin;
  double? calculatedRouteFare;

  double offeredFare = 0.0;
  String selectedVehicleType = 'car';
  RideStatus _rideStatus = RideStatus.idle;
  RideStatus get rideStatus => _rideStatus;
  set rideStatus(RideStatus val) {
    if (_rideStatus == val) return;
    _rideStatus = val;
    _syncSessionToNative();
    _handleRideStatusSound(val);
  }

  /// Unified Destination Selection Workflow (Mandatory Requirements 2, 3, 4, 5, 6, 7, 8)
  Future<void> selectDestination(PlaceLocation location, {required String selectionSource}) async {
    // 1. Clear route cache and stale state (Requirements 2, 7, 8)
    try {
      if (sl.isRegistered<RouteRepository>()) {
        sl<RouteRepository>().clearCache();
      }
      if (sl.isRegistered<MapController>()) {
        sl<MapController>().clearOverlays();
      }
    } catch (e) {
      debugPrint('[GlobalState] Clear overlays warning: $e');
    }
    
    currentRouteModel = null;
    calculatedRouteDistanceKm = null;
    calculatedRouteDurationMin = null;
    calculatedRouteFare = null;

    // 2. Validate coordinates (Requirement 4)
    PlaceLocation activeLocation = location;
    if (!activeLocation.isValid) {
      final geocoded = await MapCoordinatesHelper.geocodeAddress(activeLocation.formattedAddress);
      if (geocoded != null) {
        activeLocation = activeLocation.copyWith(
          latitude: geocoded.latitude,
          longitude: geocoded.longitude,
        );
      } else {
        final fallback = MapCoordinatesHelper.getLatLngForAddress(activeLocation.formattedAddress);
        activeLocation = activeLocation.copyWith(
          latitude: fallback.latitude,
          longitude: fallback.longitude,
        );
      }
    }

    // Determine pickup coordinates accurately using actual stored GPS coordinates first
    final LatLng originLatLng = (fromLat != null && fromLng != null && fromLat != 0.0 && fromLng != 0.0)
        ? LatLng(fromLat!, fromLng!)
        : MapCoordinatesHelper.getLatLngForAddress(fromAddress ?? 'موقعي الحالي');
    final destLatLng = LatLng(activeLocation.latitude, activeLocation.longitude);

    // 3. Log coordinates and selection source (Requirement 6)
    AppLogger.rideLog(
      'DestinationSelection',
      'Selection Source: $selectionSource | '
      'Origin: (${originLatLng.latitude}, ${originLatLng.longitude}) | '
      'Destination: (${destLatLng.latitude}, ${destLatLng.longitude}) | '
      'Place: ${activeLocation.placeName} (${activeLocation.formattedAddress})',
    );


    // 4. Update active destination state (Requirement 3)
    toAddress = activeLocation.formattedAddress.isNotEmpty ? activeLocation.formattedAddress : activeLocation.placeName;
    toLat = activeLocation.latitude;
    toLng = activeLocation.longitude;
    fromLat = originLatLng.latitude;
    fromLng = originLatLng.longitude;
    selectedDestinationLocation = activeLocation;

    // Register coordinate in helper cache
    MapCoordinatesHelper.registerCoordinate(toAddress!, destLatLng);
    if (activeLocation.placeName.isNotEmpty) {
      MapCoordinatesHelper.registerCoordinate(activeLocation.placeName, destLatLng);
    }

    // 5. Request completely new route from routing engine (Requirements 2 & 5)
    try {
      if (sl.isRegistered<RouteService>()) {
        final routeService = sl<RouteService>();
        final routeModel = await routeService.getRoute(originLatLng, destLatLng);
        currentRouteModel = routeModel;

        // 6. Calculate distance, duration, ETA, and fare
        final distanceKm = routeModel.distance / 1000.0;
        final durationMin = routeModel.duration / 60.0;
        
        calculatedRouteDistanceKm = distanceKm;
        calculatedRouteDurationMin = durationMin;
        calculatedRouteFare = calculateEstimatedFare(
          distanceInKm: distanceKm,
          vehicleType: selectedVehicleType,
        );

        // 7. Update Map polylines & camera
        if (sl.isRegistered<MapController>()) {
          final mapCtrl = sl<MapController>();
          if (routeModel.points.isNotEmpty) {
            mapCtrl.updatePolylines([
              fm.Polyline(
                points: routeModel.points,
                color: const Color(0xFF1976D2),
                strokeWidth: 5.0,
              ),
            ]);
            mapCtrl.fitBounds(originLatLng, destLatLng);
          }
        }
      }
    } catch (e) {
      debugPrint('[GlobalState] Route request failed: $e');
      final distKm = LocationService.instance.calculateDistance(
        originLatLng.latitude, originLatLng.longitude,
        destLatLng.latitude, destLatLng.longitude,
      );
      calculatedRouteDistanceKm = distKm;
      calculatedRouteDurationMin = distKm * 2.0;
      calculatedRouteFare = calculateEstimatedFare(distanceInKm: distKm, vehicleType: selectedVehicleType);
    }

    // 8. Save/Update Search History (Requirements 1, 9, 10)
    await SearchHistoryService.instance.saveLocation(activeLocation);

    notifyListeners();
  }

  /// Clears active destination and route state (Requirement 7 & 8)
  void clearDestination() {
    toAddress = null;
    toLat = null;
    toLng = null;
    selectedDestinationLocation = null;
    currentRouteModel = null;
    calculatedRouteDistanceKm = null;
    calculatedRouteDurationMin = null;
    calculatedRouteFare = null;
    try {
      if (sl.isRegistered<RouteRepository>()) {
        sl<RouteRepository>().clearCache();
      }
      if (sl.isRegistered<MapController>()) {
        sl<MapController>().clearOverlays();
      }
    } catch (_) {}
    notifyListeners();
  }


  void _handleRideStatusSound(RideStatus status) {
    try {
      final soundService = sl<RideSoundService>();
      switch (status) {
        case RideStatus.driverOnWay:
          soundService.stopIncomingRide();
          soundService.playSuccess();
          break;
        case RideStatus.completed:
          soundService.stopIncomingRide();
          soundService.playTripCompleted();
          break;
        case RideStatus.cancelled:
        case RideStatus.expired:
          soundService.stopIncomingRide();
          soundService.playCancel();
          break;
        case RideStatus.idle:
          soundService.stopIncomingRide();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('[GlobalState] Error playing ride status sound: $e');
    }
  }
  String currentServiceType = 'ride';
  String? currentPackageDescription;
  String? currentDeliveryNotes;
  int? currentPassengerCount;
  String? currentPickupPhotoUrl;
  String? currentDeliveryPhotoUrl;
  RideRequestModel? currentRideRequest;
  String? lastCancelReason;
  String? lastCancelledBy;
  String? lastCompletedRequestId;

  List<DriverOffer> driverOffers = [];
  DriverOffer? acceptedOffer;
  
  double? driverLatitude;
  double? driverLongitude;
  double driverBearing = 0.0;
  String? _currentRequestId;
  String? get currentRequestId => _currentRequestId;
  set currentRequestId(String? val) {
    if (_currentRequestId == val) return;
    _currentRequestId = val;
    _syncSessionToNative();
  }
  String? currentRecipientToken;
  String? activePassengerId;
  String? activePassengerPhone;
  double driverProgress = 0.0;

  StreamSubscription? _rideSubscription;
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription<Position>? _driverLocationStreamSub;
  StreamSubscription? _bidsSubscription;
  StreamSubscription? _driverBidRequestSubscription;
  StreamSubscription? _driverBidCounterSubscription;
  StreamSubscription? _userDocSubscription;
  StreamSubscription? _rechargeStreamSubscription;
  final Set<String> _notifiedRechargeIds = {};
  StreamSubscription? _driverDocSubscription;
  StreamSubscription? _passengerDocSubscription;
  double? passengerCounterPrice;
  Timer? _appBackgroundTimer;

  // ==== Connectivity resilience fields ==== 
  bool _isReconnecting = false; // indicates we are handling reconnection
  bool get isReconnecting => _isReconnecting;
  final List<Future<void> Function()> _pendingActions = []; // queue of actions performed while offline
  final List<LatLng> _cachedDriverLocations = []; // buffer of driver locations when offline

  /// Cache a driver location while offline (max 50 entries)
  void cacheDriverLocation(LatLng location) {
    if (_cachedDriverLocations.length >= 50) {
      _cachedDriverLocations.removeAt(0);
    }
    _cachedDriverLocations.add(location);
  }

  /// Get a copy of the cached driver locations
  List<LatLng> getCachedDriverLocations() => List<LatLng>.unmodifiable(_cachedDriverLocations);

  /// Clear the cached driver locations (after flushing)
  void clearCachedDriverLocations() => _cachedDriverLocations.clear();
  Timer? _rideTimeoutTimer;
  Timer? _connectivityTimer;
  bool isDriverOnline = false;

  void _startConnectivityMonitor() {
    _connectivityTimer?.cancel();
    if (kIsWeb) {
      isOffline = false;
      return;
    }
    // Initial immediate check
    _checkInternetConnection().then((hasNet) {
      isOffline = !hasNet;
      notifyListeners();
    });

    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final bool hasNet = await _checkInternetConnection();
      if (isOffline != !hasNet) {
        final bool wasOffline = isOffline;
        isOffline = !hasNet;
        notifyListeners();
        _showConnectivitySnackBar(hasNet);
        if (wasOffline && hasNet) {
          // Network just came back – handle reconnection
          _handleReconnection();
        }
      }
    });
  }

  Future<bool> _checkInternetConnection() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showConnectivitySnackBar(bool hasInternet) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      InAppNotificationWidget.show(
        context,
        title: hasInternet ? 'تم استعادة الاتصال بالإنترنت 🟢' : 'انقطع الاتصال بالإنترنت ⚠️',
        body: hasInternet
            ? 'تم استعادة الاتصال بالشبكة بنجاح!'
            : 'تعذر الاتصال بالشبكة. تحقق من اتصال الواي فاي أو بيانات الهاتف.',
        type: hasInternet ? 'success' : 'warning',
        onTap: () {},
      );
    }
  }

  Future<void> _saveProfileToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userName != null && userName!.isNotEmpty) await prefs.setString('cached_user_name', userName!);
      if (passengerName != null && passengerName!.isNotEmpty) await prefs.setString('cached_passenger_name', passengerName!);
      if (passengerGender != null && passengerGender!.isNotEmpty) await prefs.setString('cached_passenger_gender', passengerGender!);
      if (passengerAddress != null && passengerAddress!.isNotEmpty) await prefs.setString('cached_passenger_address', passengerAddress!);
      if (phoneNumber != null && phoneNumber!.isNotEmpty) await prefs.setString('cached_phone_number', phoneNumber!);
      await prefs.setString('cached_current_role', _currentRole.name);
      await prefs.setString('cached_verification_status', verificationStatus.name);
      if (driverAddress != null && driverAddress!.isNotEmpty) await prefs.setString('cached_driver_address', driverAddress!);
      if (vehicleName != null && vehicleName!.isNotEmpty) await prefs.setString('cached_vehicle_name', vehicleName!);
      if (vehicleNumber != null && vehicleNumber!.isNotEmpty) await prefs.setString('cached_vehicle_number', vehicleNumber!);
      if (driverVehicleCategory != null && driverVehicleCategory!.isNotEmpty) await prefs.setString('cached_vehicle_category', driverVehicleCategory!);
      if (driverNationalIdUrl != null && driverNationalIdUrl!.isNotEmpty) await prefs.setString('cached_national_id_url', driverNationalIdUrl!);
      debugPrint('[GlobalState] Profile saved to local SharedPreferences cache.');
    } catch (e) {
      debugPrint('[GlobalState] Error saving profile to cache: $e');
    }
  }

  // ------------ Connectivity Helper Methods ------------
  void _enqueuePendingAction(Future<void> Function() action) {
    if (_pendingActions.length >= 20) {
      // Drop oldest to keep size bounded
      _pendingActions.removeAt(0);
    }
    _pendingActions.add(action);
    debugPrint('[Connectivity] Action enqueued, queue size: ${_pendingActions.length}');
  }

  Future<void> _processPendingActions() async {
    if (_pendingActions.isEmpty) return;
    debugPrint('[Connectivity] Processing ${_pendingActions.length} pending actions');
    final actions = List<Future<void> Function()>.from(_pendingActions);
    _pendingActions.clear();
    for (final act in actions) {
      try {
        await act();
      } catch (e) {
        debugPrint('[Connectivity] Pending action failed: $e');
        // Re‑enqueue failed action for next attempt
        _enqueuePendingAction(act);
      }
    }
  }

  Future<void> _handleReconnection() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    notifyListeners();
    debugPrint('[Connectivity] Handling reconnection – re‑subscribing streams');
    // Re‑subscribe to ride updates if a ride is active
    if (currentRequestId != null) {
      // Cancel any existing subscription
      _rideSubscription?.cancel();
      _rideSubscription = null;
      // Re‑subscribe using the same request ID
      final listenedId = currentRequestId!;
      _rideSubscription = RideRepository.instance.streamRideRequest(listenedId).listen((request) async {
        if (_isCancelling) return;
        if (currentRequestId != listenedId) return;
        if (request == null) return;
        // Update state as before
        currentRideRequest = request;
        activeRidePaymentMethod = request.paymentMethod;
        currentPassengerCount = request.passengerCount;
        currentPickupPhotoUrl = request.pickupPhotoUrl;
        currentDeliveryPhotoUrl = request.deliveryPhotoUrl;
        // Preserve existing status handling logic (omitted for brevity)
      });
    }
    // Restart driver location updates if driver is online
    if (currentRole == UserRole.driver && isDriverOnline && userUid != null) {
      try {
        await DriverLocationService.instance.startLocationUpdates(userUid!);
      } catch (_) {}
      // Flush cached locations using the public API
      try {
        await DriverLocationService.instance.flushCachedLocations(userUid!);
      } catch (_) {}
    }
    // Process queued actions
    await _processPendingActions();
    _isReconnecting = false;
    notifyListeners();
    debugPrint('[Connectivity] Reconnection handling complete');
  }

  Future<void> _loadProfileFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userName = prefs.getString('cached_user_name') ?? userName;
      passengerName = prefs.getString('cached_passenger_name') ?? passengerName;
      passengerGender = prefs.getString('cached_passenger_gender') ?? passengerGender;
      passengerAddress = prefs.getString('cached_passenger_address') ?? passengerAddress;
      phoneNumber = prefs.getString('cached_phone_number') ?? phoneNumber;
      
      final savedRole = prefs.getString('cached_current_role');
      if (savedRole == 'driver') {
        _currentRole = UserRole.driver;
      } else if (savedRole == 'rider') {
        _currentRole = UserRole.rider;
      }

      final savedVerif = prefs.getString('cached_verification_status');
      if (savedVerif != null) {
        verificationStatus = DriverVerificationStatus.values.firstWhere(
          (e) => e.name == savedVerif,
          orElse: () => DriverVerificationStatus.unregistered,
        );
      }
      driverAddress = prefs.getString('cached_driver_address') ?? driverAddress;
      vehicleName = prefs.getString('cached_vehicle_name') ?? vehicleName;
      vehicleNumber = prefs.getString('cached_vehicle_number') ?? vehicleNumber;
      driverVehicleCategory = prefs.getString('cached_vehicle_category') ?? driverVehicleCategory;
      driverNationalIdUrl = prefs.getString('cached_national_id_url') ?? driverNationalIdUrl;
      
      debugPrint('[GlobalState] Profile loaded from local cache: passengerName=$passengerName, userName=$userName, role=$_currentRole');
    } catch (e) {
      debugPrint('[GlobalState] Error loading profile from cache: $e');
    }
  }

  Future<void> _clearProfileCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_name');
      await prefs.remove('cached_passenger_name');
      await prefs.remove('cached_passenger_gender');
      await prefs.remove('cached_passenger_address');
      await prefs.remove('cached_phone_number');
      await prefs.remove('cached_current_role');
      await prefs.remove('cached_verification_status');
      await prefs.remove('cached_driver_address');
      await prefs.remove('cached_vehicle_name');
      await prefs.remove('cached_vehicle_number');
      await prefs.remove('cached_vehicle_category');
      await prefs.remove('cached_national_id_url');
      debugPrint('[GlobalState] Profile cache cleared.');
    } catch (e) {
      debugPrint('[GlobalState] Error clearing profile cache: $e');
    }
  }

  Future<void> retryConnectivityAndAuth() async {
    final hasNet = await _checkInternetConnection();
    isOffline = !hasNet;
    if (hasNet) {
      _initAuthListener();
    }
    notifyListeners();
  }

  bool _isCancelling = false;

  double passengerWalletBalance = 0.00;
  double driverWalletBalance = 0.00;

  double get walletBalance => currentRole == UserRole.driver ? driverWalletBalance : passengerWalletBalance;
  set walletBalance(double val) {
    if (currentRole == UserRole.driver) {
      driverWalletBalance = val;
    } else {
      passengerWalletBalance = val;
    }
  }

  double creditLimit = -100.0;
  bool get isCreditLimitReached => walletBalance <= creditLimit;
  DateTime? _lastWalletWarningTime;

  String selectedPaymentMethod = 'كاش';
  String? activeRidePaymentMethod;

  List<Map<String, dynamic>> tripHistory = [];
  List<Map<String, dynamic>> walletTransactions = [];

  void _initAuthListener() {
    // 1. Safety fallback timer: NEVER allow isAuthResolved to stay false for more than 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (!isAuthResolved) {
        debugPrint('[GlobalState] Auth resolution safety timeout reached (2.5s) - forcing isAuthResolved = true');
        isAuthResolved = true;
        notifyListeners();
      }
    });

    try {
      // 2. Immediate check of currentSession / currentUser to avoid waiting on stream delay
      final initialSession = _supabase.auth.currentSession;
      final initialUser = initialSession?.user ?? _supabase.auth.currentUser;

      if (initialUser != null) {
        _handleUserAuth(initialUser, initialSession);
      } else {
        // No stored session found immediately: mark auth resolved after a short moment so login page renders
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!isAuthResolved && _supabase.auth.currentUser == null) {
            isAuthResolved = true;
            notifyListeners();
          }
        });
      }

      // 3. Listen to auth state changes for live login/logout events
      _supabase.auth.onAuthStateChange.listen((authState) async {
        final session = authState.session;
        final user = session?.user;
        try {
          if (user != null) {
            await _handleUserAuth(user, session);
          } else {
            debugPrint('[GlobalState] Auth state changed to signedOut. Cleaning up state & location streams...');
            unawaited(MetaAnalyticsService.instance.clearUserId());
            _stopPresenceTracking();
            try {
              stopDriverLocationTracking(forceOffline: true);
              _stopAllLocationAndTimers();
            } catch (e) {
              debugPrint('[GlobalState] Error stopping location tracking on signout: $e');
            }
            isLoggedIn = false;
            userUid = null;
            phoneNumber = null;
            passengerName = null;
            passengerGender = null;
            passengerAddress = null;
            userName = null;
            userAvatarUrl = null;
            userRating = 5.0;
            verificationStatus = DriverVerificationStatus.unregistered;
            driverIdCardPath = null;
            driverLicensePath = null;
            vehicleRegistrationPath = null;
            vehicleName = null;
            vehicleNumber = null;
            driverVehicleCategory = null;
            driverHasAC = false;
            driverMaxPassengers = 4;
            driverNationalIdUrl = null;
            driverLicenseUrl = null;
            driverVehicleFrontUrl = null;
            driverVehicleImages = [];
            _userDocSubscription?.cancel();
            _userDocSubscription = null;
            _driverDocSubscription?.cancel();
            _driverDocSubscription = null;
            _passengerDocSubscription?.cancel();
            _passengerDocSubscription = null;
            _activeRideMessagesSub?.cancel();
            _clearProfileCache();
            isAuthResolved = true;
            notifyListeners();
          }
        } catch (e) {
          debugPrint("Error initializing auth state in listener: $e");
          isAuthResolved = true;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint("Supabase Auth listener initialization failed: $e");
      isAuthResolved = true;
      notifyListeners();
    }
  }

  void _applyUserData(Map<String, dynamic> data) {
    final String savedRoleInDb = (data['role'] ?? data['current_role'] ?? 'rider').toString();

    final rawPassengerBal = data['wallet_balance'] ?? data['passenger_wallet_balance'] ?? data['walletBalance'];
    passengerWalletBalance = (rawPassengerBal is num) ? rawPassengerBal.toDouble() : (double.tryParse(rawPassengerBal?.toString() ?? '0') ?? 0.0);

    final rawDriverBal = data['driver_wallet_balance'] ?? data['driverWalletBalance'];
    driverWalletBalance = (rawDriverBal is num) 
        ? rawDriverBal.toDouble() 
        : (rawDriverBal != null ? (double.tryParse(rawDriverBal.toString()) ?? 0.0) : passengerWalletBalance);

    final rawLim = data['credit_limit'] ?? data['creditLimit'];
    creditLimit = (rawLim is num) ? rawLim.toDouble() : (double.tryParse(rawLim?.toString() ?? '-100') ?? -100.0);
    
    if (currentRole == UserRole.driver) {
      checkWalletWarnings();
    }
    userName = data['name'];
    userAvatarUrl = data['avatar_url'] ?? data['avatarUrl'];
    referralCode = data['referral_code']?.toString();
    final rawRat = data['rating'];
    userRating = (rawRat is num) ? rawRat.toDouble() : (double.tryParse(rawRat?.toString() ?? '0') ?? 0.0);
    final dbPhone = (data['phone_number'] ?? data['phone'])?.toString().trim();
    if (dbPhone != null && dbPhone.isNotEmpty) {
      phoneNumber = dbPhone;
    }

    if (savedRoleInDb == 'driver' && verificationStatus == DriverVerificationStatus.verified) {
      _currentRole = UserRole.driver;
    }
  }

  Future<void> _applyDriverData(Map<String, dynamic> dData) async {
    final dStatus = dData['verification_status'] ?? dData['verificationStatus'] ?? 'unregistered';
    if (dStatus == 'verified') {
      verificationStatus = DriverVerificationStatus.verified;
    } else if (dStatus == 'submitted') {
      verificationStatus = DriverVerificationStatus.submitted;
    } else if (dStatus == 'rejected') {
      verificationStatus = DriverVerificationStatus.rejected;
    } else {
      verificationStatus = DriverVerificationStatus.unregistered;
    }
    driverAddress = dData['address'];
    driverRejectionReason = dData['rejection_reason'];
    driverNationalIdUrl = dData['national_id_url'];
    driverLicenseUrl = dData['license_url'];
    driverVehicleFrontUrl = dData['vehicle_front_url'];

    final vehicleId = dData['vehicle_id'];
    if (vehicleId != null && vehicleId.toString().trim().isNotEmpty) {
      try {
        final vData = await _supabase.from('vehicles').select().eq('id', vehicleId.toString().trim()).maybeSingle().timeout(const Duration(seconds: 2));
        if (vData != null) {
          vehicleName = vData['model'];
          vehicleNumber = vData['number_plate'];
          driverVehicleColor = vData['color'];
          driverVehicleCategory = vData['vehicle_category'];
          driverHasAC = vData['has_ac'] ?? false;
          driverMaxPassengers = vData['max_passengers'] ?? 4;
          driverVehicleImages = List<String>.from(vData['images'] ?? []);
        }
      } catch (e) {
        debugPrint('Error fetching vehicle details: $e');
      }
    } else {
      vehicleName = dData['vehicle_name'] ?? dData['vehicleName'];
      vehicleNumber = dData['vehicle_number'] ?? dData['vehicleNumber'];
      driverVehicleColor = dData['vehicle_color'] ?? dData['color'] ?? 'أبيض';
      driverVehicleCategory = dData['vehicle_category'] ?? dData['vehicle_type'] ?? dData['vehicleCategory'] ?? dData['vehicleType'];
    }

    if (verificationStatus == DriverVerificationStatus.verified && driverVehicleCategory == null) {
      _notifyDriverToUpdateVehicle();
    }
  }

  void _applyPassengerData(Map<String, dynamic> rData) {
    final rName = (rData['name'] as String?)?.trim();
    passengerName = (rName != null && rName.isNotEmpty) ? rName : userName;
    passengerGender = rData['gender'];
    passengerAddress = rData['address'];
  }

  Future<void> _handleUserAuth(User user, Session? session) async {
    userUid = user.id;
    String? resolvedPhone = user.phone;
    if (resolvedPhone == null || resolvedPhone.isEmpty) {
      final metaPhone = user.userMetadata?['phone'] ?? user.userMetadata?['phone_number'];
      if (metaPhone != null && metaPhone.toString().trim().isNotEmpty) {
        resolvedPhone = metaPhone.toString().trim();
      }
    }
    if (resolvedPhone == null || resolvedPhone.isEmpty) {
      final email = user.email ?? '';
      final phoneMatch = RegExp(r'^phone_(\d+)@').firstMatch(email);
      if (phoneMatch != null) {
        resolvedPhone = phoneMatch.group(1);
      }
    }
    if (resolvedPhone == null || resolvedPhone.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        resolvedPhone = prefs.getString('cached_phone_number') ?? prefs.getString('last_phone_number');
      } catch (_) {}
    }
    if (resolvedPhone != null && resolvedPhone.isNotEmpty) {
      phoneNumber = resolvedPhone;
    }
    isLoggedIn = true;

    unawaited(MetaAnalyticsService.instance.logLogin(
      userId: user.id,
      method: user.appMetadata['provider']?.toString() ?? 'phone',
    ));
    
    try {
      if (!kIsWeb) {
        sl<AppNotificationService>().savePlayerIdForUser(user.id);
      }
      sl<NotificationController>().init(user.id);
      unawaited(SupportChatService.instance.initializeForUser(user.id));
    } catch (e) {
      debugPrint("Notification initialization failed on auth changes: $e");
    }

    // Immediate REST fetch with strict timeouts (FAST & RELIABLE, independent of WebSockets)
    try {
      final userDoc = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (userDoc != null) {
        _applyUserData(userDoc);
      } else {
        try {
          await AuthRepository.instance.fetchOrCreateUserProfile(
            user.id,
            user.phone ?? '',
            _currentRole,
          ).timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Error creating missing user profile: $e');
        }
      }

      // Check for active ride on startup with timeout
      try {
        await recoverActiveRideOnStartup(user.id).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Error recovering active ride on startup: $e');
      }

      // Initial driver fetch with timeout
      try {
        final driverInitial = await _supabase
            .from('drivers')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 2));
        if (driverInitial != null) {
          await _applyDriverData(driverInitial);
        }
      } catch (e) {
        debugPrint('[GlobalState] Error in initial driver fetch: $e');
      }

      // Initial passenger fetch with timeout
      try {
        final passengerInitial = await _supabase
            .from('passengers')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 2));
        if (passengerInitial != null) {
          _applyPassengerData(passengerInitial);
        }
      } catch (e) {
        debugPrint('[GlobalState] Error in initial passenger fetch: $e');
      }
    } catch (e) {
      debugPrint('[GlobalState] Error in fast initial REST fetch: $e');
    } finally {
      // GUARANTEED: Mark auth resolved so UI can display immediately
      isAuthResolved = true;
      _saveProfileToCache();
      notifyListeners();
    }

    // Now start background realtime stream subscriptions for live updates
    _startBackgroundUserStreams(user);
  }

  void _startBackgroundUserStreams(User user) {
    // 1. Wallet recharge requests stream
    _rechargeStreamSubscription?.cancel();
    _rechargeStreamSubscription = _supabase
        .from('wallet_recharge_requests')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((requests) {
      for (final req in requests) {
        final reqId = req['id'] as String?;
        final status = req['status'] as String?;
        final amount = (req['amount'] as num? ?? 0.0).toDouble();
        final reason = (req['rejection_reason'] as String? ?? '').trim();

        if (reqId == null || status == null || status == 'pending') continue;

        if (!_notifiedRechargeIds.contains(reqId)) {
          _notifiedRechargeIds.add(reqId);

          final ctx = navigatorKey.currentContext;
          if (status == 'approved') {
            unawaited(MetaAnalyticsService.instance.logPayment(
              transactionId: reqId,
              amount: amount,
              paymentType: 'wallet_recharge',
            ));
            try {
              sl<RideSoundService>().playNotification();
            } catch (_) {}
            if (ctx != null && ctx.mounted) {
              InAppNotificationWidget.show(
                ctx,
                title: '✅ تم قبول طلب الشحن',
                body: 'تم إضافة ${amount.toStringAsFixed(0)} ج.م إلى رصيد محفظتك بنجاح!',
                onTap: () {},
              );
            }
            reloadUserProfile();
          } else if (status == 'rejected') {
            try {
              sl<RideSoundService>().playNotification();
            } catch (_) {}
            final reasonStr = reason.isNotEmpty ? reason : 'إيصال تحويل غير مطابق أو تعذر التحقق';
            if (ctx != null && ctx.mounted) {
              InAppNotificationWidget.show(
                ctx,
                title: '❌ تم رفض طلب الشحن',
                body: 'تعذر قبول طلب الشحن بمبلغ ${amount.toStringAsFixed(0)} ج.م. السبب: $reasonStr',
                onTap: () {},
              );
            }
            reloadUserProfile();
          }
        }
      }
    }, onError: (e) {
      debugPrint('[GlobalState] Error listening to wallet recharge requests: $e');
    });

    // 2. Users table stream
    _userDocSubscription?.cancel();
    _userDocSubscription = _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((userList) {
      if (userList.isNotEmpty) {
        _applyUserData(Map<String, dynamic>.from(userList.first));
        _saveProfileToCache();
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint("[GlobalState] Error listening to user doc: $e");
    });

    // 3. Drivers table stream
    _driverDocSubscription?.cancel();
    _driverDocSubscription = _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((driverList) async {
      if (driverList.isNotEmpty) {
        await _applyDriverData(Map<String, dynamic>.from(driverList.first));
      } else {
        verificationStatus = DriverVerificationStatus.unregistered;
        vehicleName = null;
        vehicleNumber = null;
      }
      _saveProfileToCache();
      notifyListeners();
    }, onError: (e) {
      debugPrint("[GlobalState] Error listening to driver doc: $e");
    });

    // 4. Passengers table stream
    _passengerDocSubscription?.cancel();
    _passengerDocSubscription = _supabase
        .from('passengers')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((riderList) {
      if (riderList.isNotEmpty) {
        _applyPassengerData(Map<String, dynamic>.from(riderList.first));
      } else {
        if (userName != null && userName!.trim().isNotEmpty) {
          passengerName = userName;
          ensurePassengerProfileExists();
        } else {
          passengerName = null;
        }
        passengerGender = null;
        passengerAddress = null;
      }
      _saveProfileToCache();
      notifyListeners();
    }, onError: (e) {
      debugPrint("[GlobalState] Error listening to passenger doc: $e");
    });

    try {
      fetchTripHistory().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("Error fetching trip history: $e");
    }
    _listenToActiveRideMessages();
    _startPresenceTracking();
  }

  // Dynamic Payment Methods State (Synced with Supabase DB)
  List<Map<String, dynamic>> paymentMethods = [
    {
      'id': '1',
      'name': 'إنستا باي (InstaPay)',
      'code': 'instapay',
      'account_details': officialInstaPayNumber,
      'is_active': true,
      'icon_name': 'ri-flashlight-line'
    }
  ];

  List<Map<String, dynamic>> get activePaymentMethods {
    final list = paymentMethods.where((pm) {
      final code = (pm['code'] as String? ?? '').toLowerCase();
      if (code != 'instapay') return false;
      final active = pm['is_active'];
      if (active == null) return true;
      if (active is bool) return active;
      if (active is num) return active == 1;
      if (active is String) return active.toLowerCase() == 'true' || active == '1';
      return true;
    }).toList();
    if (list.isEmpty) {
      return [
        {
          'id': '1',
          'name': 'إنستا باي (InstaPay)',
          'code': 'instapay',
          'account_details': officialInstaPayNumber,
          'is_active': true,
        }
      ];
    }
    return list;
  }

  static const String officialInstaPayNumber = '01204062941';

  Future<void> _initPaymentMethodsListener() async {
    try {
      final data = await _supabase
          .from('payment_methods')
          .select()
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 4));
      if (data.isNotEmpty) {
        paymentMethods = List<Map<String, dynamic>>.from(data);
        notifyListeners();
        debugPrint('[GlobalState] Initial payment methods fetched: ${paymentMethods.length}');
      }
    } catch (e) {
      debugPrint('[GlobalState] Error fetching payment methods from database: $e');
    }

    try {
      _supabase
          .from('payment_methods')
          .stream(primaryKey: ['id'])
          .listen((dataList) {
            if (dataList.isNotEmpty) {
              paymentMethods = List<Map<String, dynamic>>.from(dataList);
              notifyListeners();
              debugPrint('[GlobalState] Realtime payment methods updated: ${paymentMethods.length}');
            }
          }, onError: (e) {
            debugPrint('[GlobalState] Realtime payment methods stream error: $e');
          });
    } catch (e) {
      debugPrint('[GlobalState] Realtime payment methods stream setup failed: $e');
    }
  }

  Future<void> _initSettingsListener() async {
    // AppSettings defaults
    appSettings = {
      'first_km_fare': 20.0,
      'extra_km_fare': 5.0,
      'ac_km_fare': 1.0,
      'heat_hour_km_fare': 1.0,
      'heat_start_hour': 11,
      'heat_end_hour': 15,
      'defaultFareCar': 25.0,
      'defaultFareScooter': 19.0,
      'defaultFareMotorcycle': 20.0,
      'commissionRate': 10.0,
      'commission_rate': 10.0,
      'minFare': 20.0,
      'maxFare': 10000.0,
      'surge_enabled': true,
      'demo_mode_enabled': false,
      'demo_passenger_enabled': false,
      'demo_driver_enabled': false,
      'demo_phone': '01000000000',
      'demo_otp': '123456',
      'demo_driver_name': 'كابتن تجريبي (Demo)',
      'demo_passenger_name': 'راكب تجريبي (Demo)',
      'region_fares': [
        {'id': '1', 'name': 'القاهرة الكبرى', 'surcharge': 0, 'is_default': true},
        {'id': '2', 'name': 'الإسكندرية (الساحل)', 'surcharge': 5, 'is_default': false}
      ],
      'otp_support_whatsapp': '01204062941',
      'is_maintenance_mode': false,
      'maintenance_title': 'التطبيق تحت الصيانة حالياً',
      'maintenance_message': 'نعمل على تحسين وتحديث خدمات inRide لنقدم لكم تجربة أفضل وأسرع. سنعود للعمل قريباً جداً.',
    };

    try {
      final res = await _supabase
          .from('app_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      if (res != null) {
        appSettings.addAll(res);
        if (res['commission_rate'] != null) {
          appSettings['commissionRate'] = (res['commission_rate'] as num).toDouble();
        }
        notifyListeners();
        debugPrint('[GlobalState] Initial settings fetched: $appSettings');
      }
    } catch (e) {
      debugPrint('[GlobalState] Error fetching app settings from database: $e');
    }

    // Set up realtime stream listener on app_settings table
    try {
      _supabase
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .eq('id', 'default')
          .listen((data) {
            if (data.isNotEmpty) {
              appSettings.addAll(data.first);
              if (data.first['commission_rate'] != null) {
                appSettings['commissionRate'] = (data.first['commission_rate'] as num).toDouble();
              }
              notifyListeners();
              debugPrint('[GlobalState] Realtime settings updated: $appSettings');
            }
          }, onError: (e) {
            debugPrint('[GlobalState] Realtime settings stream error: $e');
          });
    } catch (e) {
      debugPrint('[GlobalState] Realtime settings stream setup failed: $e');
    }
  }

  /// Calculates dynamic estimation of ride fare based on DB setting values
  double calculateEstimatedFare({
    required double distanceInKm,
    required String vehicleType,
    bool hasAC = false,
    double regionSurcharge = 0.0,
  }) {
    final surgeEnabled = (appSettings['surge_enabled'] as bool?) ?? true;
    final firstKmFare = (appSettings['first_km_fare'] as num?)?.toDouble() ?? 20.0;
    final extraKmFare = (appSettings['extra_km_fare'] as num?)?.toDouble() ?? 5.0;
    final acKmFare = (appSettings['ac_km_fare'] as num?)?.toDouble() ?? 1.0;
    final heatHourKmFare = (appSettings['heat_hour_km_fare'] as num?)?.toDouble() ?? 1.0;
    final heatStart = (appSettings['heat_start_hour'] as num?)?.toInt() ?? 11;
    final heatEnd = (appSettings['heat_end_hour'] as num?)?.toInt() ?? 15;

    double fare = 0.0;
    if (distanceInKm <= 1.0) {
      fare = firstKmFare;
    } else {
      final extraKm = distanceInKm - 1.0;
      double perKmRate = extraKmFare;

      // Apply AC surge if vehicle is a car and AC is on
      if (hasAC && (vehicleType == 'car' || vehicleType == 'private_car')) {
        perKmRate += acKmFare;
      }

      // Apply Heat Surge if enabled and trip time is between 11:00 AM and 3:00 PM (15:00)
      if (surgeEnabled) {
        final nowHour = DateTime.now().hour;
        if (nowHour >= heatStart && nowHour < heatEnd) {
          perKmRate += heatHourKmFare;
        }
      }

      fare = firstKmFare + (extraKm * perKmRate);
    }

    // Apply region surcharge if provided
    fare += regionSurcharge;

    final minFare = (appSettings['min_fare'] as num?)?.toDouble() ?? (appSettings['minFare'] as num?)?.toDouble() ?? 20.0;
    final maxFare = (appSettings['max_fare'] as num?)?.toDouble() ?? (appSettings['maxFare'] as num?)?.toDouble() ?? 10000.0;
    return fare.clamp(minFare, maxFare);
  }

  void checkWalletWarnings() {
    if (_lastWalletWarningTime != null && DateTime.now().difference(_lastWalletWarningTime!).inHours < 1) {
      return;
    }

    if (walletBalance <= creditLimit) {
      _lastWalletWarningTime = DateTime.now();
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppNotificationWidget.show(
          context,
          title: 'تم إيقاف الحساب مؤقتاً 🚫',
          body: 'لقد وصلت للحد الائتماني المسموح به. يرجى شحن محفظتك لاستئناف استقبال الرحلات.',
          onTap: () {},
        );
      }
    } else if (walletBalance <= (creditLimit + 10)) {
      _lastWalletWarningTime = DateTime.now();
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppNotificationWidget.show(
          context,
          title: 'تحذير هام: رصيد المحفظة منخفض جداً ⚠️',
          body: 'رصيدك الحالي ${walletBalance.toStringAsFixed(2)} ج.م. يرجى شحن المحفظة قريباً لتجنب إيقاف استقبال الطلبات.',
          onTap: () {},
        );
      }
    }
  }

  Future<void> fetchTripHistory() async {
    if (userUid == null) return;
    try {
      final colName = currentRole == UserRole.rider ? 'passenger_id' : 'driver_id';
      final queryRes = await _supabase
          .from('ride_requests')
          .select()
          .eq(colName, userUid!);

      final docs = List<Map<String, dynamic>>.from(queryRes as List);
      docs.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      tripHistory = docs.map((data) {
        final dateObj = DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now();
        return {
          'date': 'اليوم، ${dateObj.hour}:${dateObj.minute.toString().padLeft(2, '0')}',
          'from': data['pickup_address'] ?? data['pickupAddress'] ?? '',
          'to': data['destination_address'] ?? data['destinationAddress'] ?? '',
          'fromLat': ((data['pickup_latitude'] ?? data['pickupLatitude']) as num? ?? 0.0).toDouble(),
          'fromLng': ((data['pickup_longitude'] ?? data['pickupLongitude']) as num? ?? 0.0).toDouble(),
          'toLat': ((data['destination_latitude'] ?? data['destinationLatitude']) as num? ?? 0.0).toDouble(),
          'toLng': ((data['destination_longitude'] ?? data['destinationLongitude']) as num? ?? 0.0).toDouble(),
          'price': ((data['offered_fare'] ?? data['offeredFare']) as num? ?? 0.0).toDouble(),
          'status': data['status'] == 'Completed' ? 'مكتملة' : 'ملغاة',
          'vehicle': data['vehicle_type'] == 'scooter' ? 'اسكوتر' : (data['vehicle_type'] == 'motorcycle' ? 'موتوسيكل' : 'سيارة'),
          'timestamp': dateObj,
          'dbStatus': data['status'] ?? '',
          'id': data['id']?.toString(),
          'passenger_id': data['passenger_id']?.toString(),
          'driver_id': data['driver_id']?.toString(),
          'passenger_phone': (data['passenger_phone'] ?? data['recipient_phone'])?.toString(),
          'driver_name': data['driver_name']?.toString(),
          'passenger_name': data['passenger_name']?.toString(),
        };
      }).toList();
    } catch (_) {}
  }

  int get todayCompletedTripsCount {
    final now = DateTime.now();
    int count = 0;
    for (var trip in tripHistory) {
      final DateTime? date = trip['timestamp'] as DateTime?;
      final String? dbStatus = trip['dbStatus'] as String?;
      if (date != null && dbStatus == 'Completed') {
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          count++;
        }
      }
    }
    return count;
  }

  Future<void> fetchWalletTransactions() async {
    if (userUid == null) return;
    try {
      final queryRes = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userUid!);
      
      final docs = List<Map<String, dynamic>>.from(queryRes as List);
      docs.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      walletTransactions = docs.map<Map<String, dynamic>>((data) {
        final dateObj = DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now();
        final rawAmt = data['amount'];
        final double amt = (rawAmt is num)
            ? rawAmt.toDouble()
            : (double.tryParse(rawAmt?.toString() ?? '0') ?? 0.0);
        return <String, dynamic>{
          'description': data['title'] ?? data['description'] ?? '',
          'amount': amt,
          'type': data['type'] ?? '',
          'date': '${dateObj.year}/${dateObj.month}/${dateObj.day} - ${dateObj.hour}:${dateObj.minute.toString().padLeft(2, '0')}',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching wallet transactions: $e');
    }
  }

  Future<void> performSafeLogout([BuildContext? context]) async {
    final currentUid = userUid ?? 'unknown';
    AppLogger.logoutLog(currentUid, 'Initiating clean logout procedure');

    // 1. Stop tracking, timers, and sounds
    try {
      stopDriverLocationTracking();
      _stopAllLocationAndTimers();
    } catch (e) {
      AppLogger.error('Logout', 'Error stopping tracking/timers', e);
    }

    try {
      sl<RideSoundService>().stopIncomingRide();
    } catch (_) {}

    // 2. Clear FCM Token
    if (userUid != null && userUid!.isNotEmpty) {
      try {
        sl<AppNotificationService>().clearTokenFromDatabase(userUid!);
      } catch (e) {
        debugPrint('[Logout] Clear token error: $e');
      }
    }

    // 3. Cancel active doc subscriptions and stream listeners
    try {
      await _userDocSubscription?.cancel();
      _userDocSubscription = null;
      await _driverDocSubscription?.cancel();
      _driverDocSubscription = null;
      await _passengerDocSubscription?.cancel();
      _passengerDocSubscription = null;
      await _rechargeStreamSubscription?.cancel();
      _rechargeStreamSubscription = null;
      await _activeRideMessagesSub?.cancel();
      _activeRideMessagesSub = null;
      await _supabase.removeAllChannels();
    } catch (e) {
      debugPrint('[Logout] Cancel channels error: $e');
    }

    // 4. Trigger backend sign out
    try {
      await AuthRepository.instance.signOut();
    } catch (e) {
      AppLogger.error('Logout', 'Supabase signOut error', e);
    }

    // 5. Reset all user identity, vehicle, and ride state
    userUid = null;
    phoneNumber = null;
    isLoggedIn = false;
    isAuthResolved = true;
    _currentRole = UserRole.rider;
    passengerName = null;
    passengerGender = null;
    passengerAddress = null;
    driverAddress = null;
    driverRejectionReason = null;
    userName = null;
    userAvatarUrl = null;
    userRating = 5.0;
    verificationStatus = DriverVerificationStatus.unregistered;
    driverIdCardPath = null;
    driverLicensePath = null;
    vehicleRegistrationPath = null;
    vehicleName = null;
    vehicleNumber = null;
    driverVehicleCategory = null;
    driverHasAC = false;
    driverMaxPassengers = 4;
    driverNationalIdUrl = null;
    driverLicenseUrl = null;
    driverVehicleFrontUrl = null;
    driverVehicleImages = [];
    resetRide();
    _clearProfileCache();

    // 6. Notify listeners
    notifyListeners();

    // 7. Smoothly and directly redirect navigation stack to LoginPage
    try {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[Logout] Navigation reset error: $e');
    }

    AppLogger.logoutLog(currentUid, 'Completed safe logout');
  }

  void reset() {
    performSafeLogout();
  }

  void _stopAllLocationAndTimers() {
    debugPrint('[TripLifecycle] Stopping all location updates, timers, and subscriptions');
    try {
      _driverLocationSubscription?.cancel();
      _driverLocationSubscription = null;
    } catch (_) {}
    try {
      _driverAssignedRidesSub?.cancel();
      _driverAssignedRidesSub = null;
    } catch (_) {}
    try {
      _bidsSubscription?.cancel();
      _bidsSubscription = null;
    } catch (_) {}
    try {
      _driverBidRequestSubscription?.cancel();
      _driverBidRequestSubscription = null;
    } catch (_) {}
    try {
      _driverBidCounterSubscription?.cancel();
      _driverBidCounterSubscription = null;
    } catch (_) {}
    try {
      _activeRideMessagesSub?.cancel();
      _activeRideMessagesSub = null;
    } catch (_) {}
    _appBackgroundTimer?.cancel();
    _appBackgroundTimer = null;
    _rideTimeoutTimer?.cancel();
    _rideTimeoutTimer = null;

    if (userUid != null && currentRole == UserRole.driver) {
      try {
        sl<DriverLocationService>().stopLocationUpdates(userUid!);
      } catch (_) {}
    }
  }

  void resetRide({bool silent = false}) {
    debugPrint('[TripLifecycle] Resetting local ride state (silent: $silent)');
    try {
      _rideSubscription?.cancel();
      _rideSubscription = null;
    } catch (e) {
      debugPrint('[resetRide] Error cancelling _rideSubscription: $e');
    }
    _stopAllLocationAndTimers();

    fromAddress = null;
    toAddress = null;
    offeredFare = 0.0;
    selectedVehicleType = 'car';
    rideStatus = RideStatus.idle;
    currentServiceType = 'ride';
    currentPackageDescription = null;
    currentDeliveryNotes = null;
    currentPassengerCount = null;
    currentPickupPhotoUrl = null;
    currentDeliveryPhotoUrl = null;
    currentRideRequest = null;
    driverOffers.clear();
    acceptedOffer = null;
    driverProgress = 0.0;
    driverLatitude = null;
    driverLongitude = null;
    driverBearing = 0.0;
    if (currentRequestId != null && currentRequestId!.isNotEmpty) {
      lastCompletedRequestId = currentRequestId;
    }
    currentRequestId = null;
    currentRecipientToken = null;
    activePassengerId = null;
    activePassengerPhone = null;
    _lastNotifiedMessageId = null;
    _lastCounterOfferKey = null;
    _lastBidKey = null;
    _notifiedOfferKeys.clear();

    if (userUid != null && currentRole == UserRole.driver) {
      _supabase.from('drivers').update({
        'is_available': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userUid!).then((_) {
        debugPrint('[TripLifecycle] Database driver availability restored to true on resetRide');
      }).catchError((e) {
        debugPrint('[TripLifecycle] Error restoring driver availability: $e');
      });
    }

    if (!silent) {
      notifyListeners();
    }
  }

  Future<void> recoverActiveRideOnStartup(String uid) async {
    try {
      final colName = currentRole == UserRole.rider ? 'passenger_id' : 'driver_id';
      final activeReqRes = await _supabase
          .from('ride_requests')
          .select()
          .eq(colName, uid)
          .inFilter('status', ['Pending', 'Searching', 'Accepted', 'DriverArriving', 'TripStarted']);

      if ((activeReqRes as List).isNotEmpty) {
        final reqMap = Map<String, dynamic>.from(activeReqRes.first);
        currentRequestId = reqMap['id'];
        currentRideRequest = RideRequestModel.fromMap(reqMap, reqMap['id']);
        activePassengerId = (reqMap['passenger_id'] ?? reqMap['passengerId'])?.toString();
        activePassengerPhone = (reqMap['passenger_phone'] ?? reqMap['recipient_phone'])?.toString();
        fromAddress = reqMap['pickup_address'] ?? reqMap['pickupAddress'];
        toAddress = reqMap['destination_address'] ?? reqMap['destinationAddress'];
        offeredFare = ((reqMap['offered_fare'] ?? reqMap['offeredFare']) as num? ?? 0.0).toDouble();
        selectedVehicleType = reqMap['vehicle_type'] ?? reqMap['vehicleType'] ?? 'car';
        
        final status = reqMap['status'];
        if (status == 'Pending' || status == 'Searching') {
          rideStatus = RideStatus.searching;
        } else if (status == 'Accepted') {
          rideStatus = RideStatus.driverOnWay;
        } else if (status == 'DriverArriving') {
          rideStatus = RideStatus.arrived;
        } else if (status == 'TripStarted') {
          rideStatus = RideStatus.tripStarted;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[recoverActiveRideOnStartup] Error: $e');
    }
  }

  Future<String> _uploadToSupabaseStorage({
    required String localPath,
    required String bucketName,
    required String pathInBucket,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception("الملف غير موجود في المسار المحدد: $localPath");
    }

    try {
      final fileBytes = await file.readAsBytes();
      await _supabase.storage.from(bucketName).uploadBinary(
        pathInBucket,
        fileBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/png',
          cacheControl: '3600',
        ),
      ).timeout(const Duration(seconds: 45));

      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(pathInBucket);
      return publicUrl;
    } catch (firstErr) {
      debugPrint('[SupabaseStorage] uploadBinary failed ($firstErr). Retrying with file upload...');
      try {
        await _supabase.storage.from(bucketName).upload(
          pathInBucket,
          file,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
            cacheControl: '3600',
          ),
        ).timeout(const Duration(seconds: 45));

        final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(pathInBucket);
        return publicUrl;
      } catch (fallbackErr) {
        debugPrint("[SupabaseStorage] Error in _uploadToSupabaseStorage fallback: $fallbackErr");
        rethrow;
      }
    }
  }

  Future<String> uploadDriverDocument({
    required String localPath,
    required String folderName,
    required String fileName,
  }) async {
    final uid = userUid ?? _supabase.auth.currentUser?.id ?? '00000000-0000-4000-a000-000000000000';
    try {
      final downloadUrl = await _uploadToSupabaseStorage(
        localPath: localPath,
        bucketName: 'licenses',
        pathInBucket: '$uid/$folderName/$fileName.png',
      );
      return '$downloadUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint("Error in uploadDriverDocument: $e");
      rethrow;
    }
  }

  Future<void> submitDriverDocuments({
    required String name,
    required String number,
    required String idCardFrontUrl,
    required String idCardBackUrl,
    required String driverLicenseFrontUrl,
    required String driverLicenseBackUrl,
    required String vehicleLicenseFrontUrl,
    required String vehicleLicenseBackUrl,
    required List<String> vehicleImages,
    required String driverName,
    required int driverAge,
    required String driverGender,
    String? address,
    String? phone,
    String vehicleCategory = 'motorcycle',
    String vehicleColor = 'أبيض',
    bool hasAC = false,
    int maxPassengers = 4,
  }) async {
    vehicleName = name;
    vehicleNumber = number;
    driverVehicleColor = vehicleColor;
    driverIdCardPath = idCardFrontUrl;
    driverLicensePath = driverLicenseFrontUrl;
    vehicleRegistrationPath = vehicleLicenseFrontUrl;
    driverVehicleCategory = vehicleCategory;
    driverHasAC = hasAC;
    driverMaxPassengers = maxPassengers;
    if (address != null && address.trim().isNotEmpty) {
      driverAddress = address.trim();
      passengerAddress ??= address.trim();
    }
    verificationStatus = DriverVerificationStatus.submitted;

    final uid = userUid ?? _supabase.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('[GlobalState] ❌ Cannot submit driver documents: userUid is null');
      throw Exception('لم يتم الحصول على معرف المستخدم. يرجى إعادة تسجيل الدخول.');
    }

    userUid = uid;
    AppLogger.driverRegistrationLog('Submitting driver documents', driverId: uid, extra: {
      'driverName': driverName,
      'address': address,
      'phone': phone,
      'vehicleCategory': vehicleCategory,
      'vehicleColor': vehicleColor,
    });

    try {
      // 1. Insert/upsert vehicle record
      String? vehicleId;
      try {
        final vRes = await _supabase.from('vehicles').insert({
          'driver_id': uid,
          'model': name,
          'number_plate': number,
          'color': vehicleColor,
          'type': selectedVehicleType,
          'vehicle_category': vehicleCategory,
          'has_ac': hasAC,
          'max_passengers': maxPassengers,
          'images': vehicleImages,
        }).select('id').single();
        vehicleId = vRes['id']?.toString();
      } catch (vErr) {
        debugPrint('[GlobalState] Vehicle insert note: $vErr');
      }

      // 2. Upsert user record with real driver name and phone
      final effectivePhone = (phone != null && phone.trim().isNotEmpty)
          ? phone.trim()
          : (phoneNumber ?? '');

      await _supabase.from('users').upsert({
        'id': uid,
        'name': driverName.trim(),
        'phone_number': effectivePhone,
        'role': 'driver',
      });
      userName = driverName.trim();
      if (effectivePhone.isNotEmpty) phoneNumber = effectivePhone;

      // 3. Upsert driver record with ALL document URLs, address, and verification status 'submitted'
      final driverData = <String, dynamic>{
        'id': uid,
        'verification_status': 'submitted',
        'address': driverAddress ?? '',
        'national_id_url': idCardFrontUrl,
        'national_id_back_url': idCardBackUrl,
        'license_url': driverLicenseFrontUrl,
        'license_back_url': driverLicenseBackUrl,
        'vehicle_front_url': vehicleLicenseFrontUrl,
        'vehicle_back_url': vehicleLicenseBackUrl,
        'is_online': false,
        'is_available': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (vehicleId != null) {
        driverData['vehicle_id'] = vehicleId;
      }

      try {
        await _supabase.from('drivers').upsert(driverData);
      } catch (upsertErr) {
        final errStr = upsertErr.toString();
        if (errStr.contains('PGRST204') || errStr.contains('column')) {
          debugPrint('[GlobalState] Missing columns in drivers table — trying fallback upsert: $upsertErr');
          // Fallback to core columns if database lacks new back URL columns
          final fallbackData = <String, dynamic>{
            'id': uid,
            'verification_status': 'submitted',
            'national_id_url': idCardFrontUrl,
            'license_url': driverLicenseFrontUrl,
            'is_online': false,
            'is_available': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          if (driverAddress != null && driverAddress!.isNotEmpty) {
            fallbackData['address'] = driverAddress;
          }
          if (vehicleId != null) fallbackData['vehicle_id'] = vehicleId;
          await _supabase.from('drivers').upsert(fallbackData);
        } else {
          rethrow;
        }
      }

      debugPrint('[GlobalState] ✓ submitDriverDocuments complete for driver $uid');
    } catch (e) {
      debugPrint('[GlobalState] ❌ Error in submitDriverDocuments: $e');
      rethrow;
    }

    notifyListeners();
  }

  /// Update vehicle details for existing drivers
  Future<void> updateDriverVehicleDetails({
    required String vehicleCategory,
    required bool hasAC,
    required int maxPassengers,
  }) async {
    driverVehicleCategory = vehicleCategory;
    driverHasAC = hasAC;
    driverMaxPassengers = maxPassengers;

    if (userUid != null) {
      try {
        final driverRes = await _supabase.from('drivers').select('vehicle_id').eq('id', userUid!).maybeSingle();
        final vehicleId = driverRes?['vehicle_id'];
        if (vehicleId != null && vehicleId.toString().trim().isNotEmpty) {
          await _supabase.from('vehicles').update({
            'vehicle_category': vehicleCategory,
            'has_ac': hasAC,
            'max_passengers': maxPassengers,
          }).eq('id', vehicleId.toString().trim());
        }
      } catch (e) {
        debugPrint('Error updating vehicle details: $e');
      }
    }
    notifyListeners();
  }

  bool _vehicleUpdateNotified = false;

  void _notifyDriverToUpdateVehicle() {
    if (_vehicleUpdateNotified) return;
    _vehicleUpdateNotified = true;

    Future.delayed(const Duration(seconds: 2), () {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppNotificationWidget.show(
          context,
          title: 'تحديث بيانات المركبة مطلوب 🚗',
          body: 'يرجى تحديث نوع مركبتك (دراجة نارية / سيارة ملاكي) وبيانات التكييف وعدد الركاب من صفحة الملف الشخصي.',
          onTap: () {},
        );
      }
    });
  }

  Future<void> startDriverLocationTracking() async {
    if (isCreditLimitReached) {
      debugPrint('[Wallet] Blocked driver from going online due to credit limit');
      return;
    }

    await _driverLocationStreamSub?.cancel();
    isDriverOnline = true;
    notifyListeners();

    // Immediately attempt location permission check & position fetch
    final hasLocPermission = await LocationService.instance.checkPermission();
    Position? initialPos;
    if (hasLocPermission) {
      initialPos = await LocationService.instance.getCurrentLocation();
      if (initialPos != null) {
        driverLatitude = initialPos.latitude;
        driverLongitude = initialPos.longitude;
      }
    }

    final double? initLat = driverLatitude ?? MapCoordinatesHelper.deviceLocation?.latitude;
    final double? initLng = driverLongitude ?? MapCoordinatesHelper.deviceLocation?.longitude;

    // Immediately update availability & online status in database with coordinates
    if (userUid != null) {
      _listenToDriverAssignedRides();
      debugPrint('[CaptainStatus] Enabling driver trip availability for $userUid (lat=$initLat, lng=$initLng)');
      try {
        await _supabase.rpc('set_driver_trip_availability', params: {
          'p_driver_id': userUid!,
          'p_is_available': true,
        });
        if (initLat != null && initLng != null) {
          await _supabase.from('drivers').update({
            'current_latitude': initLat,
            'current_longitude': initLng,
          }).eq('id', userUid!);
        }
        debugPrint('[CaptainStatus] ✓ set_driver_trip_availability=true success for $userUid');
        
        // Notify driver of online status
        unawaited(NotificationService.instance.sendNotification(
          recipientId: userUid!,
          title: 'أنت متصل الآن 🟢',
          body: 'تم تفعيل الاتصال والتواجد. أنت جاهز الآن لاستقبال طلبات الرحلات.',
          type: 'driver_online',
          forceSelf: true,
        ));
      } catch (e) {
        debugPrint('[CaptainStatus] Error setting trip availability, using fallback: $e');
        try {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          final updateMap = <String, dynamic>{
            'is_online': true,
            'is_available': true,
            'last_seen_at': nowIso,
            'updated_at': nowIso,
          };
          if (initLat != null && initLng != null) {
            updateMap['current_latitude'] = initLat;
            updateMap['current_longitude'] = initLng;
          }
          await _supabase.from('drivers').update(updateMap).eq('id', userUid!);
        } catch (fbErr) {
          debugPrint('[CaptainStatus] Fallback availability update error: $fbErr');
        }
      }
    }

    if (!hasLocPermission) return;

    DateTime lastUpdateTime = DateTime.now().subtract(const Duration(seconds: 5));

    _driverLocationStreamSub = LocationService.instance.getLocationStream().listen((position) {
      driverLatitude = position.latitude;
      driverLongitude = position.longitude;
      
      if (userUid != null && isDriverOnline) {
        final now = DateTime.now();
        if (now.difference(lastUpdateTime).inSeconds >= 5) {
          lastUpdateTime = now;
          final nowIso = now.toUtc().toIso8601String();
          _supabase.from('drivers').update({
            'is_online': true,
            'is_available': rideStatus == RideStatus.idle || rideStatus == RideStatus.driverBidding,
            'current_latitude': position.latitude,
            'current_longitude': position.longitude,
            'last_seen_at': nowIso,
            'updated_at': nowIso,
          }).eq('id', userUid!).catchError((e) {
            debugPrint('[CaptainStatus] Driver location update error: $e');
          });
        }
      }
    });
  }

  Future<void> stopDriverLocationTracking({bool forceOffline = false}) async {
    await _driverLocationStreamSub?.cancel();
    _driverLocationStreamSub = null;
    isDriverOnline = false;
    notifyListeners();

    if (userUid != null) {
      debugPrint('[CaptainStatus] Disabling driver trip availability (forceOffline: $forceOffline) for $userUid');
      try {
        if (forceOffline) {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          await _supabase.from('drivers').update({
            'is_online': false,
            'is_available': false,
            'is_app_open': false,
            'updated_at': nowIso,
          }).eq('id', userUid!);
        } else {
          await _supabase.rpc('set_driver_trip_availability', params: {
            'p_driver_id': userUid!,
            'p_is_available': false,
          });
        }
        debugPrint('[CaptainStatus] ✓ Trip availability disabled successfully');

        unawaited(NotificationService.instance.sendNotification(
          recipientId: userUid!,
          title: 'أنت غير متاح للرحلات الآن 🔴',
          body: 'تم إيقاف استقبال طلبات الرحلات وتحديد الموقع.',
          type: 'driver_offline',
          forceSelf: true,
        ));
      } catch (e) {
        debugPrint('[CaptainStatus] Error updating availability to false: $e');
        try {
          final nowIso = DateTime.now().toUtc().toIso8601String();
          await _supabase.from('drivers').update({
            'is_available': false,
            'updated_at': nowIso,
          }).eq('id', userUid!);
        } catch (_) {}
      }
    }
  }



  Future<void> startSearchingForDrivers(String from, String to, double fare, String type, {int passengerCount = 1}) async {
    await startSearchingForDriversWithDetails(
      from: from,
      to: to,
      fare: fare,
      vehicleType: type,
      serviceType: 'ride',
      passengerCount: passengerCount,
    );
  }

  Future<void> startSearchingForDriversWithDetails({
    required String from,
    required String to,
    required double fare,
    required String vehicleType,
    required String serviceType,
    String? packageDescription,
    String? deliveryNotes,
    int passengerCount = 1,
    bool isDeliveryLocationConfirmed = true,
    String? recipientPhone,
    String? recipientRegion,
    String? recipientStreet,
    String? recipientBuilding,
    String? recipientFloor,
    String? recipientLandmark,
  }) async {
    fromAddress = from;
    toAddress = to;
    offeredFare = fare;
    selectedVehicleType = vehicleType;
    rideStatus = RideStatus.searching;
    currentServiceType = serviceType;
    currentPackageDescription = packageDescription;
    currentDeliveryNotes = deliveryNotes;
    currentPassengerCount = passengerCount;
    notifyListeners();

    if (userUid == null) return;
    _skippedDriverIds.clear();

    final startLatLng = MapCoordinatesHelper.getLatLngForAddress(from);
    final endLatLng = MapCoordinatesHelper.getLatLngForAddress(to);
    
    String finalPickupAddress = from;
    if (from.contains('موقع') || from.contains('location')) {
      final reverseGeocoded = await MapCoordinatesHelper.reverseGeocode(startLatLng.latitude, startLatLng.longitude);
      if (reverseGeocoded.isNotEmpty) {
        finalPickupAddress = reverseGeocoded;
        fromAddress = finalPickupAddress;
      }
    }

    double distance = 0.0;
    try {
      final routeService = sl<RouteService>();
      final route = await routeService.getRoute(startLatLng, endLatLng);
      distance = route.distance / 1000.0;
      if (distance == 0.0) {
        distance = LocationService.instance.calculateDistance(
          startLatLng.latitude,
          startLatLng.longitude,
          endLatLng.latitude,
          endLatLng.longitude,
        );
      }
    } catch (e) {
      distance = LocationService.instance.calculateDistance(
        startLatLng.latitude,
        startLatLng.longitude,
        endLatLng.latitude,
        endLatLng.longitude,
      );
    }

    String? recipientToken;
    if (!isDeliveryLocationConfirmed) {
      recipientToken = _generateSecureToken();
    }
    currentRecipientToken = recipientToken;

    String? phoneToPass = phoneNumber;
    if (phoneToPass == null || phoneToPass.isEmpty) {
      final curUser = _supabase.auth.currentUser;
      if (curUser != null) {
        phoneToPass = curUser.phone ??
            (curUser.userMetadata?['phone'] ?? curUser.userMetadata?['phone_number'])?.toString();
        if (phoneToPass == null || phoneToPass.isEmpty) {
          final m = RegExp(r'^phone_(\d+)@').firstMatch(curUser.email ?? '');
          if (m != null) phoneToPass = m.group(1);
        }
      }
      if (phoneToPass != null && phoneToPass.isNotEmpty) {
        phoneNumber = phoneToPass;
      }
    }

    currentRequestId = await RideRepository.instance.createRideRequest(
      passengerId: userUid!,
      passengerPhone: phoneToPass,
      pickupLat: startLatLng.latitude,
      pickupLng: startLatLng.longitude,
      pickupAddress: finalPickupAddress,
      destLat: endLatLng.latitude,
      destLng: endLatLng.longitude,
      destAddress: to,
      vehicleType: vehicleType,
      offeredFare: fare,
      distance: distance,
      paymentMethod: selectedPaymentMethod,
      serviceType: serviceType,
      packageDescription: packageDescription,
      deliveryNotes: deliveryNotes,
      passengerCount: passengerCount,
      isDeliveryLocationConfirmed: isDeliveryLocationConfirmed,
      recipientPhone: recipientPhone,
      recipientRegion: recipientRegion,
      recipientStreet: recipientStreet,
      recipientBuilding: recipientBuilding,
      recipientFloor: recipientFloor,
      recipientLandmark: recipientLandmark,
      recipientToken: recipientToken,
    );

    if (currentRequestId != null) {
      unawaited(MetaAnalyticsService.instance.logRideRequested(
        rideId: currentRequestId!,
        fare: fare,
        vehicleType: vehicleType,
        serviceType: serviceType,
      ));
    }

    try {
      final nearbyDrivers = await RideRepository.instance.searchAvailableDrivers(
        pickupLat: startLatLng.latitude,
        pickupLng: startLatLng.longitude,
        vehicleType: vehicleType,
        maxRangeKm: 15.0,
      );
      
      for (var d in nearbyDrivers) {
        final driverId = d['driverId'] as String;
        unawaited(NotificationService.instance.sendNotification(
          recipientId: driverId,
          title: serviceType == 'delivery' ? 'طلب توصيل طرد جديد 📦' : 'طلب رحلة جديد 🚗',
          body: serviceType == 'delivery' ? 'يتوفر طلب توصيل طرد قريب منك. اضغط للمعاينة.' : 'يتوفر طلب رحلة قريب منك. اضغط للمعاينة.',
          type: serviceType == 'delivery' ? 'delivery_request' : 'new_ride',
          data: {
            'requestId': currentRequestId!,
            'tripId': currentRequestId!,
            'pickupAddress': finalPickupAddress,
            'destinationAddress': to,
            'pickupLat': startLatLng.latitude.toString(),
            'pickupLng': startLatLng.longitude.toString(),
            'destLat': endLatLng.latitude.toString(),
            'destLng': endLatLng.longitude.toString(),
            'fare': fare.toString(),
            'vehicleType': vehicleType,
            'serviceType': serviceType,
          },
        ));
      }
    } catch (e) {
      debugPrint("Error notifying nearby drivers of new request: $e");
    }

    _rideTimeoutTimer?.cancel();
    _rideTimeoutTimer = Timer(const Duration(minutes: 2), () async {
      if (_isCancelling) return;
      if (rideStatus == RideStatus.searching && currentRequestId != null) {
        try {
          await RideRepository.instance.markRideRequestAsExpired(currentRequestId!);
        } catch (e) {
          debugPrint('[rideTimeoutTimer] Error marking ride as expired: $e');
        }
      }
    });

    final listenedRequestId = currentRequestId!;
    _rideSubscription?.cancel();
    _rideSubscription = RideRepository.instance.streamRideRequest(listenedRequestId).listen((request) async {
      if (_isCancelling) return;
      if (currentRequestId != listenedRequestId) return;
      if (request == null) return;
      
      debugPrint('[Ride] Ride update received: ride_id=$listenedRequestId, status=${request.status}');

      try {
        currentRideRequest = request;
        activeRidePaymentMethod = request.paymentMethod;
        currentPassengerCount = request.passengerCount;
        currentPickupPhotoUrl = request.pickupPhotoUrl;
        currentDeliveryPhotoUrl = request.deliveryPhotoUrl;
        
        // Prevent status regression if ride is already completed
        if (rideStatus == RideStatus.completed && request.status != 'Cancelled' && request.status != 'cancelled') {
          debugPrint('[Ride] Ignoring status update (${request.status}) because ride is already completed');
          return;
        }

        final previousStatus = rideStatus;

        if (request.status == 'Pending' || request.status == 'Searching') {
          rideStatus = RideStatus.searching;
        } else if (request.status == 'Accepted') {
          _rideTimeoutTimer?.cancel();
          _rideTimeoutTimer = null;
          rideStatus = RideStatus.driverOnWay;
          unawaited(MetaAnalyticsService.instance.logRideAccepted(
            rideId: request.requestId,
            fare: request.offeredFare,
            serviceType: request.serviceType,
          ));
          if (previousStatus != RideStatus.driverOnWay) {
            AppNotificationService.instance.showLocalNotification(
              id: request.requestId.hashCode.abs() % 100000,
              title: 'تم قبول طلب الرحلة 🎉',
              body: 'وافق الكابتن على رحلتك وهو في الطريق إليك الآن.',
              type: 'ride_accepted',
              data: {
                'requestId': request.requestId,
                'tripId': request.requestId,
                'driverId': request.driverId ?? '',
                'type': 'ride_accepted',
              },
            );
          }
        } else if (request.status == 'DriverArriving') {
          rideStatus = RideStatus.arrived;
          if (previousStatus != RideStatus.arrived) {
            AppNotificationService.instance.showLocalNotification(
              id: (request.requestId.hashCode.abs() + 10) % 100000,
              title: 'الكابتن وصل 📍',
              body: 'كابتن الرحلة وصل إلى نقطة الاستلام وهو بانتظارك.',
              type: 'captain_arrived',
              data: {
                'requestId': request.requestId,
                'tripId': request.requestId,
                'type': 'captain_arrived',
              },
            );
          }
        } else if (request.status == 'TripStarted') {
          rideStatus = RideStatus.tripStarted;
          unawaited(MetaAnalyticsService.instance.logRideStarted(
            rideId: request.requestId,
            serviceType: request.serviceType,
          ));
          if (previousStatus != RideStatus.tripStarted) {
            AppNotificationService.instance.showLocalNotification(
              id: (request.requestId.hashCode.abs() + 20) % 100000,
              title: 'بدأت الرحلة 🚀',
              body: 'رحلتك بدأت الآن مع الكابتن. نتمنى لك رحلة سعيدة وآمنة.',
              type: 'trip_started',
              data: {
                'requestId': request.requestId,
                'tripId': request.requestId,
                'type': 'trip_started',
              },
            );
          }
        } else if (request.status == 'Completed') {
          rideStatus = RideStatus.completed;
          unawaited(MetaAnalyticsService.instance.logRideCompleted(
            rideId: request.requestId,
            fare: request.offeredFare > 0 ? request.offeredFare : offeredFare,
            paymentMethod: request.paymentMethod,
          ));
          if (previousStatus != RideStatus.completed) {
            final double finalFare = request.offeredFare > 0 ? request.offeredFare : offeredFare;
            AppNotificationService.instance.showLocalNotification(
              id: (request.requestId.hashCode.abs() + 30) % 100000,
              title: 'اكتملت الرحلة 🏁',
              body: 'تم إنهاء الرحلة بنجاح. الأجرة: ${finalFare.round()} ج.م. شكراً لاستخدامك inRide.',
              type: 'trip_finished',
              data: {
                'requestId': request.requestId,
                'tripId': request.requestId,
                'price': finalFare.toString(),
                'paymentMethod': request.paymentMethod,
                'type': 'trip_finished',
              },
            );
          }
          try {
            final userRes = await _supabase.from('users').select('wallet_balance').eq('id', userUid!).maybeSingle();
            if (_isCancelling || currentRequestId != listenedRequestId) return;
            if (userRes != null) {
              walletBalance = (userRes['wallet_balance'] as num? ?? walletBalance).toDouble();
            }
            await fetchTripHistory();
          } catch (e) {
            debugPrint('[rideListener] Error fetching wallet after completion: $e');
          }
        } else if (request.status == 'Cancelled' || request.status == 'cancelled') {
          if (!_isCancelling) {
            lastCancelReason = request.cancelReason ?? 'تم إلغاء الرحلة';
            lastCancelledBy = request.cancelledBy ?? 'driver';
            if (lastCancelledBy != 'passenger' && previousStatus != RideStatus.cancelled) {
              AppNotificationService.instance.showLocalNotification(
                id: (request.requestId.hashCode.abs() + 40) % 100000,
                title: 'تم إلغاء الرحلة ❌',
                body: 'قام الكابتن بإلغاء الرحلة: $lastCancelReason',
                type: 'cancel_trip',
                data: {
                  'requestId': request.requestId,
                  'tripId': request.requestId,
                  'type': 'cancel_trip',
                },
              );
            }
            _stopAllLocationAndTimers();
            _rideSubscription?.cancel();
            _rideSubscription = null;
            rideStatus = RideStatus.cancelled;
            notifyListeners();
          }
        } else if (request.status == 'Expired') {
          if (!_isCancelling) {
            resetRide(silent: true);
            rideStatus = RideStatus.expired;
          }
        }
        
        if (request.driverId != null && acceptedOffer == null && !_isCancelling) {
          try {
            final driverInfo = await fetchDriverInfo(request.driverId!, defaultVehicleType: request.vehicleType);

            acceptedOffer = DriverOffer(
              driverId: request.driverId!,
              driver: driverInfo,
              price: request.offeredFare,
              etaMinutes: 3,
            );

            _driverLocationSubscription?.cancel();
            _driverLocationSubscription = RideRepository.instance.streamDriverLocation(request.driverId!).listen((data) {
              if (_isCancelling) return;
              if (data != null) {
                final newLat = (data['current_latitude'] ?? data['currentLatitude'] as num?)?.toDouble();
                final newLng = (data['current_longitude'] ?? data['currentLongitude'] as num?)?.toDouble();
                if (newLat != null && newLng != null) {
                  if (driverLatitude == null ||
                      (newLat - driverLatitude!).abs() > 0.00003 ||
                      (newLng - driverLongitude!).abs() > 0.00003) {
                    driverLatitude = newLat;
                    driverLongitude = newLng;
                    notifyListeners();
                  }
                }
              }
            });
          } catch (e) {
            debugPrint('[rideListener] Error fetching driver info: $e');
          }
        }
        if (!_isCancelling) {
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[rideListener] Unexpected error: $e');
      }
    });

    driverOffers = [];
    _bidsSubscription?.cancel();
    _bidsSubscription = _supabase
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .eq('request_id', currentRequestId!)
        .listen((offerList) {
      if (_isCancelling) return;
      try {
        var offers = offerList.map((data) {
          final map = Map<String, dynamic>.from(data);
          return DriverOffer(
            driverId: map['driver_id'] ?? map['driverId'] ?? map['id'],
            driver: DriverInfo(
              name: map['driver_name'] ?? map['driverName'] ?? 'كابتن',
              rating: (map['driver_rating'] ?? map['driverRating'] as num? ?? 5.0).toDouble(),
              vehicleType: map['vehicle_type'] ?? map['vehicleType'] ?? 'سيارة',
              vehicleName: map['vehicle_name'] ?? map['vehicleName'] ?? 'سيارة',
              vehicleColor: map['vehicle_color'] ?? map['vehicleColor'] ?? '',
              licensePlate: map['license_plate'] ?? map['licensePlate'] ?? '',
              avatar: (map['driver_avatar'] ?? map['driverAvatar'] ?? '').toString(),
            ),
            price: (map['price'] as num? ?? offeredFare).toDouble(),
            etaMinutes: (map['eta_minutes'] ?? map['etaMinutes'] as int? ?? 5),
            status: map['status'] ?? 'pending',
          );
        }).toList();

        offers = offers.where((offer) => !_skippedDriverIds.contains(offer.driverId) && offer.status == 'pending').toList();
        driverOffers = offers;

        // Prevent downgrading the status if the ride is already accepted or in progress
        if (rideStatus != RideStatus.driverOnWay && 
            rideStatus != RideStatus.arrived && 
            rideStatus != RideStatus.tripStarted && 
            rideStatus != RideStatus.completed) {
          if (driverOffers.isNotEmpty) {
            rideStatus = RideStatus.driverBidding;
          } else {
            rideStatus = RideStatus.searching;
          }
        }
        // Notify passenger with local heads-up notification banner for new or updated offers
        for (final o in offers) {
          final offerKey = '${o.driverId}_${o.price.round()}';
          if (!_notifiedOfferKeys.contains(offerKey)) {
            _notifiedOfferKeys.add(offerKey);
            AppNotificationService.instance.showLocalNotification(
              id: (o.driverId.hashCode.abs() + o.price.toInt()) % 100000,
              title: 'عرض جديد من الكابتن 💰',
              body: 'قدّم الكابتن ${o.driver.name} عرضاً بقيمة ${o.price.round()} ج.م',
              type: 'new_offer',
              data: {
                'requestId': currentRequestId!,
                'tripId': currentRequestId!,
                'driverId': o.driverId,
                'price': o.price.toString(),
                'type': 'new_offer',
              },
            );
          }
        }

        if (!_isCancelling) {
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[bidsListener] Error processing bids: $e');
      }
    });
  }

  final Set<String> _skippedDriverIds = {};
  final Set<String> _notifiedOfferKeys = {};

  /// Guards for counter-offer deduplication
  bool _isSubmittingCounterOffer = false;
  String? _lastCounterOfferKey;

  void skipDriver(String driverId) {
    _skippedDriverIds.add(driverId);
    notifyListeners();
  }

  Future<void> submitCounterOffer(String driverId, double counterPrice) async {
    if (currentRequestId == null || userUid == null) return;

    // Deduplication: skip if same offer is already being submitted
    final offerKey = '${currentRequestId}_${driverId}_${counterPrice.round()}';
    if (_isSubmittingCounterOffer) {
      debugPrint('[counterOffer] Already submitting, skipping duplicate tap');
      // Update the pending key so the in-flight request knows a newer one arrived
      _lastCounterOfferKey = offerKey;
      return;
    }
    if (_lastCounterOfferKey == offerKey) {
      debugPrint('[counterOffer] Identical offer already sent, ignoring');
      return;
    }

    _isSubmittingCounterOffer = true;
    _lastCounterOfferKey = offerKey;

    try {
      // 1. Update ride_offers record
      try {
        await _supabase.from('ride_offers').update({
          'price': counterPrice,
          'status': 'countered',
        }).eq('request_id', currentRequestId!).eq('driver_id', driverId);
      } catch (e) {
        debugPrint('[counterOffer] Warning updating ride_offers: $e');
      }

      // 2. Update ride_requests with offered_fare and last_counter_driver_id
      try {
        await _supabase.from('ride_requests').update({
          'offered_fare': counterPrice,
          'last_counter_driver_id': driverId,
        }).eq('id', currentRequestId!);
      } catch (e) {
        debugPrint('[counterOffer] Fallback updating ride_requests without last_counter_driver_id: $e');
        await _supabase.from('ride_requests').update({
          'offered_fare': counterPrice,
        }).eq('id', currentRequestId!);
      }

      // 3. Dispatch push notification to captain
      try {
        unawaited(NotificationService.instance.sendNotification(
          recipientId: driverId,
          title: 'تفاوض جديد من العميل 💰',
          body: 'اقترح العميل أجرة جديدة: ${counterPrice.round()} ج.م',
          type: 'counter_offer',
          data: {
            'requestId': currentRequestId!,
            'driverId': driverId,
            'price': counterPrice.toString(),
          },
        ));
      } catch (e) {
        debugPrint('[counterOffer] Warning sending notification to driver: $e');
      }

      offeredFare = counterPrice;
      notifyListeners();
    } catch (e) {
      debugPrint('[counterOffer] Error submitting counter-offer: $e');
      rethrow;
    } finally {
      _isSubmittingCounterOffer = false;
    }
  }

  Future<void> confirmDeliveryLocation(
    String requestId,
    double lat,
    double lng,
    String address, {
    double? pickupLat,
    double? pickupLng,
    double accuracy = 0.0,
    String source = 'gps',
    DateTime? timestamp,
  }) async {
    double finalPickupLat = pickupLat ?? 0.0;
    double finalPickupLng = pickupLng ?? 0.0;

    if (pickupLat == null || pickupLng == null) {
      try {
        final docRes = await _supabase.from('ride_requests').select().eq('id', requestId).maybeSingle();
        if (docRes != null) {
          finalPickupLat = ((docRes['pickup_latitude'] ?? docRes['pickupLatitude']) as num? ?? 0.0).toDouble();
          finalPickupLng = ((docRes['pickup_longitude'] ?? docRes['pickupLongitude']) as num? ?? 0.0).toDouble();
        }
      } catch (e) {
        final startLatLng = MapCoordinatesHelper.getLatLngForAddress(fromAddress ?? 'موقعي الحالي');
        finalPickupLat = startLatLng.latitude;
        finalPickupLng = startLatLng.longitude;
      }
    }

    final distance = LocationService.instance.calculateDistance(
      finalPickupLat,
      finalPickupLng,
      lat,
      lng,
    );
    
    double fare = 15.0;
    if (distance > 2.0) {
      fare += (distance - 2.0) * 3.0;
    }
    
    await _supabase.from('ride_requests').update({
      'destination_latitude': lat,
      'destination_longitude': lng,
      'destination_address': address,
      'distance': distance,
      'offered_fare': fare,
      'is_delivery_location_confirmed': true,
    }).eq('id', requestId);
    
    if (currentRequestId == requestId) {
      toAddress = address;
      offeredFare = fare;
      notifyListeners();
    }
  }

  /// Fetch comprehensive real-time driver profile info directly from Supabase
  Future<DriverInfo> fetchDriverInfo(String driverId, {String? defaultVehicleType}) async {
    try {
      // 1. Try secure RPC that bypasses RLS and returns driver real avatar and full profile
      try {
        final rpcRes = await _supabase.rpc('get_driver_full_profile', params: {
          'p_driver_id': driverId,
        });
        if (rpcRes != null) {
          final pMap = Map<String, dynamic>.from(rpcRes is String ? jsonDecode(rpcRes) : rpcRes);
          final vTypeRaw = (pMap['vehicle_type'] ?? defaultVehicleType ?? 'car').toString().toLowerCase();
          final vType = vTypeRaw.contains('scooter') ? 'اسكوتر' : (vTypeRaw.contains('motorcycle') ? 'موتوسيكل' : 'سيارة');
          return DriverInfo(
            name: (pMap['name'] ?? 'كابتن inRide').toString(),
            rating: ((pMap['rating'] as num?) ?? 5.0).toDouble(),
            ratingCount: ((pMap['rating_count'] as num?) ?? 0).toInt(),
            vehicleType: vType,
            vehicleName: (pMap['vehicle_name'] ?? 'سيارة').toString(),
            vehicleColor: (pMap['vehicle_color'] ?? 'أبيض').toString(),
            licensePlate: (pMap['license_plate'] ?? '').toString(),
            avatar: (pMap['avatar_url'] ?? '').toString(),
            phoneNumber: (pMap['phone'] ?? '').toString(),
            completedTrips: ((pMap['completed_trips'] as num?) ?? 0).toInt(),
            completedDeliveries: ((pMap['completed_deliveries'] as num?) ?? 0).toInt(),
          );
        }
      } catch (e) {
        debugPrint('[fetchDriverInfo] RPC get_driver_full_profile error: $e');
      }

      // 2. Fallback direct query
      final driverUserRes = await _supabase.from('users').select().eq('id', driverId).maybeSingle();
      final driverRes = await _supabase.from('drivers').select().eq('id', driverId).maybeSingle();

      final uMap = driverUserRes != null ? Map<String, dynamic>.from(driverUserRes) : {};
      final dMap = driverRes != null ? Map<String, dynamic>.from(driverRes) : {};

      // Vehicle table check if vehicle_id exists
      Map<String, dynamic> vMap = {};
      final vehicleId = dMap['vehicle_id'] ?? dMap['vehicleId'];
      if (vehicleId != null && vehicleId.toString().trim().isNotEmpty) {
        try {
          final vRes = await _supabase.from('vehicles').select().eq('id', vehicleId.toString().trim()).maybeSingle();
          if (vRes != null) vMap = Map<String, dynamic>.from(vRes);
        } catch (_) {}
      }

      // Name resolution: check users & drivers tables, filter out generic placeholders
      String rawName = (uMap['name'] ?? uMap['full_name'] ?? dMap['name'] ?? dMap['driver_name'] ?? dMap['full_name'] ?? '').toString().trim();
      if (rawName.isEmpty || rawName.toLowerCase() == 'in ride' || rawName.toLowerCase() == 'inride' || rawName == 'مستخدم') {
        final fallbackName = (dMap['name'] ?? dMap['driver_name'] ?? uMap['name'] ?? '').toString().trim();
        rawName = (fallbackName.isNotEmpty && fallbackName.toLowerCase() != 'in ride' && fallbackName.toLowerCase() != 'inride')
            ? fallbackName
            : 'كابتن inRide';
      }

      // Phone resolution
      final phone = (uMap['phone_number'] ?? uMap['phone'] ?? dMap['phone_number'] ?? dMap['phone'] ?? '').toString();

      // Rating resolution
      double rating = (dMap['rating'] as num?)?.toDouble() ??
                      (dMap['driver_rating'] as num?)?.toDouble() ??
                      (uMap['rating'] as num?)?.toDouble() ??
                      5.0;
      if (rating <= 0.0) rating = 5.0;

      int ratingCount = (uMap['rating_count'] ?? uMap['total_ratings'] ?? dMap['rating_count'] ?? dMap['total_ratings'] as num?)?.toInt() ?? 0;

      // Vehicle details
      final vTypeRaw = (dMap['vehicle_category'] ?? dMap['vehicle_type'] ?? vMap['type'] ?? defaultVehicleType ?? 'car').toString().toLowerCase();
      final vType = vTypeRaw.contains('scooter') ? 'اسكوتر' : (vTypeRaw.contains('motorcycle') ? 'موتوسيكل' : 'سيارة');
      final vName = (dMap['vehicle_name'] ?? dMap['vehicle_model'] ?? vMap['model'] ?? 'سيارة').toString();
      final vColor = (dMap['vehicle_color'] ?? vMap['color'] ?? 'أبيض').toString();
      final licensePlate = (dMap['vehicle_number'] ?? dMap['license_plate'] ?? vMap['number_plate'] ?? '').toString();

      // Avatar resolution (real avatar only, no Unsplash)
      String avatar = (uMap['avatar_url'] ?? uMap['avatar'] ?? dMap['avatar_url'] ?? '').toString();

      // Completed Trips & Deliveries resolution
      int completedTrips = (dMap['completed_trips'] ?? dMap['completedTrips'] ?? dMap['total_trips'] as num?)?.toInt() ?? 0;
      int completedDeliveries = (dMap['completed_deliveries'] ?? dMap['completedDeliveries'] ?? dMap['total_deliveries'] as num?)?.toInt() ?? 0;

      // Realtime count query from ride_requests table to verify actual completed rides count
      try {
        final reqsRes = await _supabase
            .from('ride_requests')
            .select('service_type')
            .eq('driver_id', driverId)
            .eq('status', 'Completed');
        if (reqsRes.isNotEmpty) {
          int tripsCount = 0;
          int deliveriesCount = 0;
          for (final item in reqsRes) {
            final sType = (item['service_type'] ?? '').toString().toLowerCase();
            if (sType == 'delivery') {
              deliveriesCount++;
            } else {
              tripsCount++;
            }
          }
          if (tripsCount > completedTrips) completedTrips = tripsCount;
          if (deliveriesCount > completedDeliveries) completedDeliveries = deliveriesCount;
        }
      } catch (e) {
        debugPrint('[fetchDriverInfo] Error counting completed rides: $e');
      }

      return DriverInfo(
        name: rawName,
        rating: rating,
        ratingCount: ratingCount,
        vehicleType: vType,
        vehicleName: vName,
        vehicleColor: vColor,
        licensePlate: licensePlate,
        avatar: avatar,
        phoneNumber: phone,
        completedTrips: completedTrips,
        completedDeliveries: completedDeliveries,
      );
    } catch (e) {
      debugPrint('[fetchDriverInfo] Error: $e');
      return DriverInfo(
        name: 'كابتن inRide',
        rating: 5.0,
        vehicleType: defaultVehicleType ?? 'سيارة',
        vehicleName: 'سيارة',
        vehicleColor: 'أبيض',
        licensePlate: '',
        avatar: '',
      );
    }
  }

  Future<void> acceptDriverOffer(DriverOffer offer) async {
    // Fetch full driver info with real database numbers
    final fullDriverInfo = await fetchDriverInfo(offer.driverId, defaultVehicleType: offer.driver.vehicleType);

    acceptedOffer = DriverOffer(
      driverId: offer.driverId,
      driver: DriverInfo(
        name: fullDriverInfo.name.isNotEmpty && fullDriverInfo.name != 'كابتن inRide' ? fullDriverInfo.name : (offer.driver.name.isNotEmpty ? offer.driver.name : fullDriverInfo.name),
        rating: fullDriverInfo.rating > 0 ? fullDriverInfo.rating : offer.driver.rating,
        vehicleType: fullDriverInfo.vehicleType,
        vehicleName: fullDriverInfo.vehicleName.isNotEmpty ? fullDriverInfo.vehicleName : offer.driver.vehicleName,
        vehicleColor: fullDriverInfo.vehicleColor.isNotEmpty ? fullDriverInfo.vehicleColor : offer.driver.vehicleColor,
        licensePlate: fullDriverInfo.licensePlate.isNotEmpty ? fullDriverInfo.licensePlate : offer.driver.licensePlate,
        avatar: fullDriverInfo.avatar.isNotEmpty ? fullDriverInfo.avatar : offer.driver.avatar,
        phoneNumber: fullDriverInfo.phoneNumber.isNotEmpty ? fullDriverInfo.phoneNumber : offer.driver.phoneNumber,
        completedTrips: fullDriverInfo.completedTrips > 0 ? fullDriverInfo.completedTrips : offer.driver.completedTrips,
        completedDeliveries: fullDriverInfo.completedDeliveries > 0 ? fullDriverInfo.completedDeliveries : offer.driver.completedDeliveries,
      ),
      price: offer.price,
      etaMinutes: offer.etaMinutes,
      status: offer.status,
    );
    rideStatus = RideStatus.driverOnWay;
    offeredFare = offer.price;
    notifyListeners();

    if (currentRequestId != null) {
      unawaited(MetaAnalyticsService.instance.logRideAccepted(
        rideId: currentRequestId!,
        fare: offer.price,
        serviceType: currentServiceType,
      ));
      try {
        await _supabase.from('ride_requests').update({
          'status': 'Accepted',
          'driver_id': offer.driverId,
          'offered_fare': offer.price,
        }).eq('id', currentRequestId!);
      } catch (e) {
        await RideRepository.instance.updateRideStatus(currentRequestId!, 'Accepted', driverId: offer.driverId);
      }

      try {
        // Fetch other drivers who submitted bids on this request before updating status
        final otherOffersRes = await _supabase
            .from('ride_offers')
            .select('driver_id')
            .eq('request_id', currentRequestId!)
            .neq('driver_id', offer.driverId);

        await _supabase.from('ride_offers').update({'status': 'accepted'}).eq('request_id', currentRequestId!).eq('driver_id', offer.driverId);
        await _supabase.from('ride_offers').update({'status': 'rejected'}).eq('request_id', currentRequestId!).neq('driver_id', offer.driverId);

        // Send private rejection notice to each other driver individually
        for (final item in otherOffersRes) {
          final otherDriverId = item['driver_id']?.toString();
          if (otherDriverId != null && otherDriverId.isNotEmpty) {
            unawaited(NotificationService.instance.sendNotification(
              recipientId: otherDriverId,
              title: 'تم اختيار كابتن آخر 🚕',
              body: 'شكراً لك، اختار الراكب كابتناً آخر لهذه الرحلة. نتمنى لك التوفيق في الرحلات القادمة!',
              type: 'offer_rejected',
              data: {
                'requestId': currentRequestId!,
                'tripId': currentRequestId!,
              },
            ));
          }
        }
      } catch (e) {
        debugPrint('[acceptDriverOffer] Error updating ride_offers status: $e');
      }

      final isDelivery = currentServiceType == 'delivery';
      unawaited(NotificationService.instance.sendNotification(
        recipientId: offer.driverId,
        title: isDelivery ? 'تم قبول طلب التوصيل 🎉' : 'تم قبول عرض الرحلة 🎉',
        body: 'الراكب قبل عرضك وهو بانتظارك الآن.',
        type: isDelivery ? 'delivery_accepted' : 'ride_accepted',
        data: {
          'requestId': currentRequestId,
          'tripId': currentRequestId,
          'price': offer.price.toString(),
        },
      ));
    }
  }

  Future<void> submitPickupPhoto(String photoUrl) async {
    if (currentRequestId != null) {
      String finalUrl = photoUrl;
      if (!photoUrl.startsWith('http') && !photoUrl.startsWith('data:')) {
        try {
          finalUrl = await _uploadToSupabaseStorage(
            localPath: photoUrl,
            bucketName: 'deliveries',
            pathInBucket: 'pickup_${currentRequestId}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        } catch (e) {
          debugPrint('Error uploading pickup photo: $e');
        }
      }
      await RideRepository.instance.updatePickupPhoto(currentRequestId!, finalUrl);
      currentPickupPhotoUrl = finalUrl;
      notifyListeners();
    }
  }

  Future<void> submitDeliveryPhoto(String photoUrl) async {
    if (currentRequestId != null) {
      String finalUrl = photoUrl;
      if (!photoUrl.startsWith('http') && !photoUrl.startsWith('data:')) {
        try {
          finalUrl = await _uploadToSupabaseStorage(
            localPath: photoUrl,
            bucketName: 'deliveries',
            pathInBucket: 'delivery_${currentRequestId}_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        } catch (e) {
          debugPrint('Error uploading delivery photo: $e');
        }
      }
      await RideRepository.instance.updateDeliveryPhoto(currentRequestId!, finalUrl);
      currentDeliveryPhotoUrl = finalUrl;
      notifyListeners();
    }
  }

  Future<void> startTrip() async {
    rideStatus = RideStatus.tripStarted;
    notifyListeners();

    if (currentRequestId != null) {
      unawaited(MetaAnalyticsService.instance.logRideStarted(
        rideId: currentRequestId!,
        serviceType: currentServiceType,
      ));
      await RideRepository.instance.updateRideStatus(currentRequestId!, 'TripStarted');

      String pId = currentRideRequest?.passengerId ?? activePassengerId ?? '';
      if (pId.isEmpty) {
        try {
          final res = await _supabase.from('ride_requests').select('passenger_id').eq('id', currentRequestId!).maybeSingle();
          if (res != null) pId = res['passenger_id'] ?? '';
        } catch (e) {
          debugPrint('[startTrip] Error resolving passengerId: $e');
        }
      }

      if (pId.isNotEmpty) {
        unawaited(NotificationService.instance.sendNotification(
          recipientId: pId,
          title: 'بدأت الرحلة 🚀',
          body: 'رحلتك بدأت الآن مع الكابتن. نتمنى لك رحلة سعيدة وآمنة.',
          type: 'trip_started',
          data: {
            'requestId': currentRequestId!,
            'tripId': currentRequestId!,
          },
        ));
      }
    }
  }

  Future<void> arriveAtPickup() async {
    rideStatus = RideStatus.arrived;
    notifyListeners();

    if (currentRequestId != null) {
      await RideRepository.instance.updateRideStatus(currentRequestId!, 'DriverArriving');

      String pId = currentRideRequest?.passengerId ?? activePassengerId ?? '';
      if (pId.isEmpty) {
        try {
          final res = await _supabase.from('ride_requests').select('passenger_id').eq('id', currentRequestId!).maybeSingle();
          if (res != null) pId = res['passenger_id'] ?? '';
        } catch (e) {
          debugPrint('[arriveAtPickup] Error resolving passengerId: $e');
        }
      }

      if (pId.isNotEmpty) {
        unawaited(NotificationService.instance.sendNotification(
          recipientId: pId,
          title: 'الكابتن وصل 📍',
          body: 'كابتن الرحلة وصل إلى نقطة الاستلام وهو بانتظارك.',
          type: 'captain_arrived',
          data: {
            'requestId': currentRequestId!,
            'tripId': currentRequestId!,
          },
        ));
      }
    }
  }

  Future<void> completeTrip() async {
    if (isOffline) {
      _enqueuePendingAction(() async => await _completeTripInternal());
      return;
    }
    await _completeTripInternal();
  }

  // Internal implementation without offline check
  Future<void> _completeTripInternal() async {
    rideStatus = RideStatus.completed;
    notifyListeners();

    if (currentRequestId != null) {
      final reqId = currentRequestId!;
      try {
        final reqRes = await _supabase.from('ride_requests').select().eq('id', reqId).maybeSingle();
        if (reqRes != null) {
          final reqData = Map<String, dynamic>.from(reqRes);
          final double price = ((reqData['offered_fare'] ?? reqData['offeredFare']) as num? ?? 0.0).toDouble();
          final String paymentMethod = reqData['payment_method'] ?? reqData['paymentMethod'] ?? 'كاش';
          final String passengerId = reqData['passenger_id'] ?? reqData['passengerId'] ?? '';

          if (passengerId.isNotEmpty) {
            unawaited(NotificationService.instance.sendNotification(
              recipientId: passengerId,
              title: 'اكتملت الرحلة 🏁',
              body: 'تم إنهاء الرحلة بنجاح. شكراً لاستخدامك inRide.',
              type: 'trip_finished',
              data: {
                'requestId': reqId,
                'tripId': reqId,
                'price': price.toString(),
                'paymentMethod': paymentMethod,
              },
            ));
          }
        }
      } catch (e) {
        debugPrint('[TripLifecycle] Notification error on trip completion: $e');
      }

      // Updating status to 'Completed' triggers Supabase DB trigger `trg_handle_trip_completion_finances`
      // which automatically deducts 10% commission, logs the transaction, and updates balances atomically.
      unawaited(MetaAnalyticsService.instance.logRideCompleted(
        rideId: reqId,
        fare: offeredFare > 0 ? offeredFare : 10.0,
        paymentMethod: activeRidePaymentMethod ?? 'cash',
      ));
      await RideRepository.instance.updateRideStatus(reqId, 'Completed');

      // Refresh wallet transactions and user profile in the app
      try {
        await fetchWalletTransactions();
        await reloadUserProfile();
      } catch (e) {
        debugPrint('[TripLifecycle] Error refreshing wallet after trip completion: $e');
      }

      // Restore driver availability in Supabase database immediately on trip completion
      if (userUid != null && currentRole == UserRole.driver) {
        try {
          await _supabase.from('drivers').update({
            'is_available': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', userUid!);
          debugPrint('[TripLifecycle] Restored driver $userUid is_available=true in database on trip completion');
        } catch (e) {
          debugPrint('[TripLifecycle] Error restoring driver availability on trip completion: $e');
        }
      }
    }
  }

  Future<void> submitRating(double rating, String comment, {String? targetUserId, String? targetRole}) async {
    final String? reqId = currentRequestId ?? lastCompletedRequestId;
    String? resolvedReceiverId = targetUserId;
    String resolvedReceiverRole = targetRole ?? (currentRole == UserRole.rider ? 'driver' : 'rider');

    if (resolvedReceiverId == null || resolvedReceiverId.isEmpty) {
      if (currentRole == UserRole.rider) {
        resolvedReceiverId = acceptedOffer?.driverId ?? currentRideRequest?.driverId;
        resolvedReceiverRole = 'driver';
      } else {
        resolvedReceiverId = activePassengerId ?? currentRideRequest?.passengerId;
        resolvedReceiverRole = 'rider';
      }
    }

    if (reqId != null && (resolvedReceiverId == null || resolvedReceiverId.isEmpty)) {
      try {
        final reqDoc = await _supabase.from('ride_requests').select('driver_id, passenger_id').eq('id', reqId).maybeSingle();
        if (reqDoc != null) {
          if (currentRole == UserRole.rider) {
            resolvedReceiverId = reqDoc['driver_id'] as String?;
          } else {
            resolvedReceiverId = reqDoc['passenger_id'] as String?;
          }
        }
      } catch (e) {
        debugPrint('[submitRating] Error fetching request fallback info: $e');
      }
    }

    if (userUid != null && resolvedReceiverId != null && resolvedReceiverId.isNotEmpty) {
      try {
        final ratingId = reqId != null ? '${reqId}_$userUid' : UuidGenerator.v4();
        
        String senderName = userName ?? passengerName ?? '';
        if (senderName.trim().isEmpty || senderName == 'راكب' || senderName == 'كابتن') {
          try {
            final userDoc = await _supabase.from('users').select('name').eq('id', userUid!).maybeSingle();
            if (userDoc != null && userDoc['name'] != null && (userDoc['name'] as String).trim().isNotEmpty) {
              senderName = (userDoc['name'] as String).trim();
            }
          } catch (_) {}
        }
        if (senderName.trim().isEmpty) {
          senderName = currentRole == UserRole.rider ? 'راكب' : 'كابتن';
        }

        final Map<String, dynamic> ratingPayload = {
          'id': ratingId,
          'sender_id': userUid!,
          'receiver_id': resolvedReceiverId,
          'receiver_role': resolvedReceiverRole,
          'rating': rating,
          'comment': comment.trim().isEmpty ? 'بدون تعليق' : comment,
          'created_at': DateTime.now().toIso8601String(),
        };
        if (reqId != null && reqId.isNotEmpty) {
          ratingPayload['request_id'] = reqId;
        }

        debugPrint('[submitRating] Saving rating payload: $ratingPayload');
        await _supabase.from('ratings').upsert(ratingPayload);

        debugPrint('[submitRating] Rating submitted successfully: rating=$rating, receiver=$resolvedReceiverId, role=$resolvedReceiverRole');
        await _updateAverageRating(resolvedReceiverId);
      } catch (e) {
        debugPrint('[submitRating] Error submitting rating: $e');
      }
    } else {
      debugPrint('[submitRating] Notice: Skipped submitting rating. userUid=$userUid, resolvedReceiverId=$resolvedReceiverId');
    }
    resetRide();
  }

  Future<void> _updateAverageRating(String userId) async {
    try {
      final ratingsRes = await _supabase
          .from('ratings')
          .select('rating')
          .or('receiver_id.eq.$userId,to_user_id.eq.$userId');
      final list = List<Map<String, dynamic>>.from(ratingsRes as List);
      if (list.isNotEmpty) {
        double total = 0;
        for (var row in list) {
          total += (row['rating'] as num? ?? 0.0).toDouble();
        }
        double avg = double.parse((total / list.length).toStringAsFixed(1));

        await _supabase.from('users').update({'rating': avg}).eq('id', userId);

        try {
          await _supabase.from('drivers').update({'rating': avg}).eq('id', userId);
        } catch (_) {}

        if (userId == userUid) {
          userRating = avg;
          userTotalRatingsCount = list.length;
          notifyListeners();
        }
      }
      
      // Also fetch completed trips count
      try {
        final isDriver = currentRole == UserRole.driver;
        final tripsRes = await _supabase
            .from('ride_requests')
            .select('id')
            .eq(isDriver ? 'driver_id' : 'passenger_id', userId)
            .or('status.eq.Completed,status.eq.completed,status.eq.FINISHED,status.eq.finished');
        final tripsList = List<Map<String, dynamic>>.from(tripsRes as List);
        if (userId == userUid) {
          userCompletedTripsCount = tripsList.length;
          notifyListeners();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error updating average rating: $e');
    }
  }

  Future<void> cancelRide({
    String cancelledBy = 'passenger',
    String? reason,
  }) async {
    if (isOffline) {
      _enqueuePendingAction(() async => await _cancelRideInternal(cancelledBy: cancelledBy, reason: reason));
      return;
    }
    await _cancelRideInternal(cancelledBy: cancelledBy, reason: reason);
  }

  // Internal implementation without offline check
  Future<void> _cancelRideInternal({
    required String cancelledBy,
    String? reason,
  }) async {
    if (_isCancelling) return;
    _isCancelling = true;

    final defaultReason = cancelledBy == 'driver'
        ? 'تم الإلغاء بواسطة الكابتن'
        : 'تم الإلغاء بواسطة العميل';
    final finalReason = reason ?? defaultReason;

    lastCancelReason = finalReason;
    lastCancelledBy = cancelledBy;

    final requestIdToCancel = currentRequestId;

    try {
      _stopAllLocationAndTimers();
      rideStatus = RideStatus.cancelled;
      notifyListeners();

      if (requestIdToCancel != null) {
        await RideRepository.instance.cancelRideRequest(
          requestIdToCancel,
          finalReason,
          cancelledBy: cancelledBy,
        );
      }
    } catch (e) {
      debugPrint('[TripLifecycle] Error during cancelRide: $e');
    } finally {
      _isCancelling = false;
    }
  }

  StreamSubscription? _driverAssignedRidesSub;

  void _listenToDriverAssignedRides() {
    if (userUid == null) return;
    _driverAssignedRidesSub?.cancel();
    _driverAssignedRidesSub = _supabase
        .from('ride_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', userUid!)
        .listen((list) async {
      if (list.isEmpty) return;
      try {
        // Only process the ride that matches our current active request
        // to prevent stale/old trips from overriding state
        for (var item in list) {
          final map = Map<String, dynamic>.from(item);
          final reqId = map['id'] as String?;

          if (reqId == null) continue;

          // Skip rides that are not our current active request
          // (unless we don't have a current request yet - fresh accept)
          if (currentRequestId != null && currentRequestId != reqId) continue;

          // Prevent status regression if ride is already completed
          final String statusRaw = (map['status'] as String? ?? '').trim();
          final String statusLower = statusRaw.toLowerCase();

          if (rideStatus == RideStatus.completed && statusLower != 'cancelled') {
            debugPrint('[DriverAssignedRides] Ignoring status update ($statusRaw) for completed ride $reqId');
            continue;
          }

          if (statusLower == 'accepted' || statusLower == 'driverarriving' || statusLower == 'driver_arriving' || statusLower == 'tripstarted' || statusLower == 'trip_started' || statusLower == 'in_progress') {
            currentRequestId = reqId;
            activePassengerId = map['passenger_id'] as String?;
            final pPhone = (map['passenger_phone'] ?? map['recipient_phone'])?.toString();
            if (pPhone != null && pPhone.isNotEmpty) {
              activePassengerPhone = pPhone;
            }
            currentRideRequest = RideRequestModel.fromMap(map, reqId);
            fromAddress = map['pickup_address'] as String? ?? map['pickupAddress'] as String? ?? '';
            toAddress = map['destination_address'] as String? ?? map['destinationAddress'] as String? ?? '';
            offeredFare = ((map['offered_fare'] ?? map['offeredFare']) as num? ?? 0.0).toDouble();

            if (statusLower == 'accepted') {
              rideStatus = RideStatus.driverOnWay;
            } else if (statusLower == 'driverarriving' || statusLower == 'driver_arrived') {
              rideStatus = RideStatus.arrived;
            } else if (statusLower == 'tripstarted' || statusLower == 'trip_started' || statusLower == 'in_progress') {
              rideStatus = RideStatus.tripStarted;
            }
            notifyListeners();
          } else if (statusLower == 'completed') {
            if (rideStatus != RideStatus.completed) {
              rideStatus = RideStatus.completed;
              notifyListeners();
            }
          } else if (statusLower == 'cancelled') {
            if (currentRequestId == reqId) {
              final prevStatus = rideStatus;
              rideStatus = RideStatus.cancelled;
              lastCancelReason = map['cancel_reason'] as String? ?? 'تم إلغاء الرحلة';
              lastCancelledBy = map['cancelled_by'] as String? ?? 'passenger';
              if (lastCancelledBy == 'passenger' && prevStatus != RideStatus.cancelled) {
                AppNotificationService.instance.showLocalNotification(
                  id: (reqId.hashCode.abs() + 50) % 100000,
                  title: 'تم إلغاء الرحلة ❌',
                  body: 'قام الراكب بإلغاء الرحلة: $lastCancelReason',
                  type: 'cancel_trip',
                  data: {
                    'requestId': reqId,
                    'tripId': reqId,
                    'type': 'cancel_trip',
                  },
                );
              }
              notifyListeners();
            }
          }
        }
      } catch (e, stack) {
        AppLogger.error('DriverAssignedRides', 'Error processing assigned rides stream', e, stack);
      }
    }, onError: (err) {
      AppLogger.error('DriverAssignedRides', 'Assigned rides stream error', err);
    });
  }

  /// Driver accepts a ride request atomically using row-level locking (Requirement 4)
  Future<void> driverAcceptRide(String requestId, double fare) async {
    if (userUid == null) throw Exception('المستخدم غير مسجل الدخول');
    AppLogger.rideLog('DriverAccept', 'Driver $userUid clicked ACCEPT for request $requestId at fare $fare');

    currentRequestId = requestId;

    try {
      final result = await RideRepository.instance.acceptRideRequest(
        requestId: requestId,
        driverId: userUid!,
        offeredFare: fare,
      );

      final String pId = result['passenger_id'] as String? ?? activePassengerId ?? '';
      activePassengerId = pId;

      // ─── CRITICAL FIX ──────────────────────────────────────────────────────
      // Fetch the FULL ride row immediately after the RPC succeeds so that
      // currentRideRequest / fromAddress / toAddress / offeredFare are all
      // populated BEFORE we call notifyListeners() and before DriverRideActivePage
      // opens.  Without this, the page opens with null state and crashes.
      // (The counter-offer path never crashes because the Supabase stream handler
      //  always populates these fields before navigation.)
      try {
        final rideRow = await _supabase
            .from('ride_requests')
            .select()
            .eq('id', requestId)
            .maybeSingle();

        if (rideRow != null) {
          final rideMap = Map<String, dynamic>.from(rideRow);
          currentRideRequest = RideRequestModel.fromMap(rideMap, requestId);
          fromAddress = rideMap['pickup_address'] as String? ?? rideMap['pickupAddress'] as String? ?? '';
          toAddress = rideMap['destination_address'] as String? ?? rideMap['destinationAddress'] as String? ?? '';
          offeredFare = ((rideMap['offered_fare'] ?? rideMap['offeredFare']) as num? ?? fare).toDouble();
          // Update passenger ID from the actual row if not already set
          if (pId.isEmpty) {
            activePassengerId = rideMap['passenger_id'] as String? ?? '';
          }
          final pPhone = (rideMap['passenger_phone'] ?? rideMap['recipient_phone'])?.toString();
          if (pPhone != null && pPhone.isNotEmpty) {
            activePassengerPhone = pPhone;
          }
        }
      } catch (fetchErr) {
        // Non-fatal: we still proceed with navigation; stream will populate later
        AppLogger.error('DriverAccept', 'Could not pre-fetch ride row after accept (non-fatal)', fetchErr);
        // Set fare at minimum so UI doesn't show 0
        offeredFare = fare;
        fromAddress = fromAddress ?? '';
        toAddress = toAddress ?? '';
      }
      // ────────────────────────────────────────────────────────────────────────

      rideStatus = RideStatus.driverOnWay;
      unawaited(MetaAnalyticsService.instance.logRideAccepted(
        rideId: requestId,
        fare: fare,
        serviceType: 'ride',
      ));
      _listenToDriverAssignedRides();

      // Send push notification to passenger
      if (pId.isNotEmpty) {
        unawaited(NotificationService.instance.sendNotification(
          recipientId: pId,
          title: 'تم قبول طلب الرحلة 🎉',
          body: 'وافق الكابتن على رحلتك وهو في الطريق إليك الآن.',
          type: 'ride_accepted',
          data: {
            'requestId': requestId,
            'tripId': requestId,
            'price': fare.toString(),
            'driverId': userUid!,
          },
        ));
      }

      AppLogger.rideLog('DriverAccept', 'Driver $userUid successfully accepted ride $requestId atomically');
      notifyListeners();
    } catch (e, stack) {
      AppLogger.error('DriverAccept', 'Failed to accept ride $requestId', e, stack);
      rethrow;
    }
  }

  /// Guards for driver bid deduplication
  bool _isSubmittingBid = false;
  String? _lastBidKey;

  Future<void> driverSubmitBid(String requestId, double fare, {String? passengerId}) async {
    if (userUid == null) return;

    // Deduplication: skip if same bid is already being submitted
    final bidKey = '${requestId}_${userUid}_${fare.round()}';
    if (_isSubmittingBid) {
      debugPrint('[driverSubmitBid] Already submitting bid, skipping duplicate tap');
      _lastBidKey = bidKey;
      return;
    }
    if (_lastBidKey == bidKey) {
      debugPrint('[driverSubmitBid] Identical bid already sent, ignoring');
      return;
    }

    _isSubmittingBid = true;
    _lastBidKey = bidKey;
    currentRequestId = requestId;

    try {
      String finalPassengerId = passengerId ?? activePassengerId ?? '';
      if (finalPassengerId.isEmpty) {
        try {
          final reqDoc = await _supabase.from('ride_requests').select('passenger_id').eq('id', requestId).maybeSingle();
          if (reqDoc != null) {
            finalPassengerId = reqDoc['passenger_id'] ?? '';
          }
        } catch (e) {
          AppLogger.error('driverSubmitBid', 'Error fetching passenger_id', e);
        }
      }

      activePassengerId = finalPassengerId;

      final offerId = await RideRepository.instance.sendOffer(
        driverId: userUid!,
        passengerId: finalPassengerId,
        requestId: requestId,
        price: fare,
        eta: const Duration(minutes: 5),
      );

      // Reset last_counter_driver_id since driver has replied with a counter-offer
      try {
        await _supabase.from('ride_requests').update({
          'last_counter_driver_id': null,
        }).eq('id', requestId);
      } catch (e) {
        AppLogger.error('driverSubmitBid', 'Error clearing last_counter_driver_id', e);
      }

      if (finalPassengerId.isNotEmpty) {
        unawaited(NotificationService.instance.sendNotification(
          recipientId: finalPassengerId,
          title: 'عرض جديد من الكابتن 💰',
          body: 'قدم الكابتن عرض سعر جديد: ${fare.toInt()} ج.م',
          type: 'new_offer',
          data: {
            'requestId': requestId,
            'tripId': requestId,
            'driverId': userUid!,
            'price': fare.toString(),
          },
        ));
      }

      _listenToDriverAssignedRides();
      AppLogger.rideLog('DriverBid', 'Submitted counter-offer $offerId for request $requestId to passenger $finalPassengerId ($fare EGP)');
    } finally {
      _isSubmittingBid = false;
    }
  }

  Future<void> reloadUserProfile() async {
    if (userUid != null) {
      try {
        final res = await _supabase.from('users').select().eq('id', userUid!).maybeSingle();
        if (res != null) {
          final rawPassengerBal = res['wallet_balance'] ?? res['passenger_wallet_balance'];
          passengerWalletBalance = (rawPassengerBal is num) ? rawPassengerBal.toDouble() : (double.tryParse(rawPassengerBal?.toString() ?? '0') ?? 0.0);

          final rawDriverBal = res['driver_wallet_balance'];
          if (rawDriverBal != null) {
            driverWalletBalance = (rawDriverBal is num) ? rawDriverBal.toDouble() : (double.tryParse(rawDriverBal.toString()) ?? 0.0);
          }
          userName = res['name'];
          userAvatarUrl = res['avatar_url'];
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error reloading user profile: $e');
      }
    }
  }

  Future<void> chargeWallet(double amount) async {
    if (currentRole == UserRole.driver) {
      driverWalletBalance += amount;
      if (userUid != null) {
        try {
          await _supabase.from('users').update({'driver_wallet_balance': driverWalletBalance}).eq('id', userUid!);
          await _supabase.from('transactions').insert({
            'user_id': userUid!,
            'title': 'شحن رصيد الكابتن',
            'amount': amount,
            'type': 'charge',
            'balance_after': driverWalletBalance,
          });

          unawaited(NotificationService.instance.sendNotification(
            recipientId: userUid!,
            title: 'تم شحن محفظة الكابتن بنجاح 💳',
            body: 'تم إضافة ${amount.round()} ج.م إلى رصيد الكابتن. الرصيد الحالي: ${driverWalletBalance.round()} ج.م',
            type: 'payment',
            data: {
              'amount': amount.toString(),
              'balance': driverWalletBalance.toString(),
            },
          ));
        } catch (e) {
          debugPrint('Error charging driver wallet: $e');
        }
      }
    } else {
      passengerWalletBalance += amount;
      if (userUid != null) {
        try {
          await _supabase.from('users').update({'wallet_balance': passengerWalletBalance, 'passenger_wallet_balance': passengerWalletBalance}).eq('id', userUid!);
          await _supabase.from('transactions').insert({
            'user_id': userUid!,
            'title': 'شحن رصيد الراكب',
            'amount': amount,
            'type': 'charge',
            'balance_after': passengerWalletBalance,
          });

          unawaited(NotificationService.instance.sendNotification(
            recipientId: userUid!,
            title: 'تم شحن محفظة الراكب بنجاح 💳',
            body: 'تم إضافة ${amount.round()} ج.م إلى رصيد الراكب. الرصيد الحالي: ${passengerWalletBalance.round()} ج.م',
            type: 'payment',
            data: {
              'amount': amount.toString(),
              'balance': passengerWalletBalance.toString(),
            },
          ));
        } catch (e) {
          debugPrint('Error charging passenger wallet: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<String> uploadReceiptImage(String localPath) async {
    final uid = userUid ?? '00000000-0000-4000-a000-000000000000';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pathInBucket = '$uid/receipt_$timestamp.png';

    try {
      return await _uploadToSupabaseStorage(
        localPath: localPath,
        bucketName: 'wallet_receipts',
        pathInBucket: pathInBucket,
      ).timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Uploading to wallet_receipts bucket failed: $e, using base64 encoding fallback');
      try {
        final file = File(localPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final b64 = base64Encode(bytes);
          return 'data:image/png;base64,$b64';
        }
      } catch (b64Error) {
        debugPrint('Base64 encoding fallback failed: $b64Error');
      }
      return 'file_upload_fallback';
    }
  }

  Future<bool> chargeWalletPending(double amount, String receiptUrl, String method) async {
    if (userUid == null) throw Exception("يجب تسجيل الدخول أولاً لشحن المحفظة");

    try {
      String finalReceiptUrl = receiptUrl;
      if (!receiptUrl.startsWith('http') && !receiptUrl.startsWith('data:')) {
        try {
          finalReceiptUrl = await uploadReceiptImage(receiptUrl);
        } catch (uploadError) {
          debugPrint('[GlobalState] Receipt upload failed completely: $uploadError');
          finalReceiptUrl = 'file_upload_failed';
        }
      }

      final roleStr = currentRole == UserRole.driver ? 'driver' : 'rider';
      final roleTitle = currentRole == UserRole.driver ? 'الكابتن' : 'الراكب';
      final nameStr = userName ?? passengerName ?? 'مستخدم';
      final phoneStr = phoneNumber ?? _supabase.auth.currentUser?.phone ?? '';

      // Use UTC timestamp for consistency with server/dashboard
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final requestId = UuidGenerator.v4();

      bool insertedReq = false;
      // 1. Insert into wallet_recharge_requests for Admin Dashboard Review
      try {
        await _supabase.from('wallet_recharge_requests').insert({
          'id': requestId,
          'user_id': userUid!,
          'user_type': roleStr,
          'target_role': roleStr,
          'user_name': nameStr,
          'user_phone': phoneStr,
          'amount': amount,
          'payment_method': method,
          'receipt_url': finalReceiptUrl,
          'status': 'pending',
          'created_at': nowUtc,
        }).timeout(const Duration(seconds: 15));
        insertedReq = true;
      } catch (e) {
        debugPrint('[GlobalState] Error writing to wallet_recharge_requests: $e');
        final errStr = e.toString().toLowerCase();

        // Supabase PostgREST inserts the row BEFORE evaluating the RETURNING clause.
        // If the error is NOT a network/timeout issue, the INSERT itself succeeded
        // but PostgREST failed to return the row (usually due to RLS SELECT policy).
        final bool isNetworkError = errStr.contains('socketexception') ||
            errStr.contains('timeoutexception') ||
            errStr.contains('handshakeexception') ||
            errStr.contains('connection refused') ||
            errStr.contains('network is unreachable');

        if (!isNetworkError) {
          // Non-network error → the INSERT most likely landed in the DB.
          // Confirm with a SELECT if possible, but default to success.
          insertedReq = true;
          debugPrint('[GlobalState] Non-network error on insert → treating as success (PostgREST RETURNING issue)');

          try {
            final checkRow = await _supabase
                .from('wallet_recharge_requests')
                .select('id')
                .eq('id', requestId)
                .maybeSingle();
            if (checkRow != null) {
              debugPrint('[GlobalState] Confirmed wallet_recharge_requests inserted with id: $requestId');
            }
          } catch (checkErr) {
            debugPrint('[GlobalState] Verification SELECT also blocked (RLS): $checkErr — still treating as success');
          }
        } else {
          // Genuine network error — the INSERT likely did NOT reach the server
          debugPrint('[GlobalState] Network error on insert → marking as failed');
          insertedReq = false;
        }
      }

      // 2. Insert into transactions for user history
      try {
        await _supabase.from('transactions').insert({
          'id': UuidGenerator.v4(),
          'user_id': userUid!,
          'title': 'شحن رصيد معلق ($roleTitle)',
          'amount': amount,
          'type': 'charge_pending',
          'balance_after': walletBalance,
          'payment_method': method,
          'receipt_url': finalReceiptUrl,
          'notes': 'طلب شحن محفظة $roleTitle عبر $method',
          'created_at': nowUtc,
        }).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[GlobalState] Error writing to transactions: $e');
      }

      // Refresh transactions list so the UI updates immediately
      try {
        await fetchWalletTransactions();
      } catch (e) {
        debugPrint('[GlobalState] Error refreshing wallet transactions: $e');
      }

      notifyListeners();
      return insertedReq;
    } catch (e) {
      debugPrint('Error writing pending transaction: $e');
      return false;
    }
  }


  Future<void> updateName(String newName) async {
    if (userUid != null) {
      userName = newName;
      if (currentRole == UserRole.rider) {
        passengerName = newName;
        await _supabase.from('passengers').update({'name': newName}).eq('id', userUid!);
      }
      await _supabase.from('users').update({'name': newName}).eq('id', userUid!);
      notifyListeners();
    }
  }

  Future<void> updateAddress(String newAddress) async {
    final trimmed = newAddress.trim();
    if (userUid != null) {
      passengerAddress = trimmed;
      driverAddress = trimmed;

      try {
        await _supabase.from('users').update({'address': trimmed}).eq('id', userUid!);
      } catch (e) {
        debugPrint('[GlobalState] updateAddress users table error: $e');
      }

      if (currentRole == UserRole.rider || hasPassengerProfile) {
        try {
          await _supabase.from('passengers').update({'address': trimmed}).eq('id', userUid!);
        } catch (e) {
          debugPrint('[GlobalState] updateAddress passengers table error: $e');
        }
      }

      if (currentRole == UserRole.driver || verificationStatus != DriverVerificationStatus.unregistered) {
        try {
          await _supabase.from('drivers').update({'address': trimmed}).eq('id', userUid!);
        } catch (e) {
          debugPrint('[GlobalState] updateAddress drivers table error: $e');
        }
      }

      notifyListeners();
    }
  }

  Future<void> updateAvatar(String newUrl) async {
    if (userUid != null) {
      userAvatarUrl = newUrl;
      await _supabase.from('users').update({'avatar_url': newUrl}).eq('id', userUid!);
      notifyListeners();
    }
  }

  Future<void> uploadAndSetProfileImage(String localPath) async {
    if (userUid == null) {
      throw Exception("User is not logged in");
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception("الملف غير موجود في المسار المحدد: $localPath");
      }

      final downloadUrl = await _uploadToSupabaseStorage(
        localPath: localPath,
        bucketName: 'avatars',
        pathInBucket: '$userUid/profile.png',
      );
      
      final versionedUrl = '$downloadUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.from('users').update({'avatar_url': versionedUrl}).eq('id', userUid!);
      try {
        await _supabase.from('passengers').update({'avatar_url': versionedUrl}).eq('id', userUid!);
      } catch (_) {}
      try {
        await _supabase.from('drivers').update({'avatar_url': versionedUrl}).eq('id', userUid!);
      } catch (_) {}

      userAvatarUrl = versionedUrl;
      notifyListeners();

      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('[ProfileImageUpload] Error during upload: $e');
      rethrow;
    }
  }

  Future<void> deleteProfileImage() async {
    if (userUid == null) return;
    try {
      await _supabase.from('users').update({'avatar_url': ''}).eq('id', userUid!);
      userAvatarUrl = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[ProfileImageDelete] Error: $e');
    }
  }

  void update() {
    notifyListeners();
  }

  bool canExitApplication() {
    if (currentRole == UserRole.rider) {
      return true;
    } else {
      final hasActiveTrip = rideStatus == RideStatus.driverOnWay || 
                            rideStatus == RideStatus.arrived || 
                            rideStatus == RideStatus.tripStarted;
      return !hasActiveTrip;
    }
  }

  StreamSubscription? _activeRideMessagesSub;
  String? _lastNotifiedMessageId;

  void _listenToActiveRideMessages() {
    _activeRideMessagesSub?.cancel();
    if (currentRequestId == null) return;

    _activeRideMessagesSub = _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', currentRequestId!)
        .listen((msgList) {
      if (msgList.isEmpty) return;

      final sortedList = List<Map<String, dynamic>>.from(msgList);
      sortedList.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      final msg = sortedList.first;
      final senderId = msg['sender_id'] ?? msg['senderId'];
      final messageId = msg['id'];
      final text = msg['text'] ?? '';

      if (senderId != userUid && messageId != _lastNotifiedMessageId) {
        _lastNotifiedMessageId = messageId;
        _triggerInAppMessageNotification(text);
      }
    });
  }

  void _triggerInAppMessageNotification(String text) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final String senderName = currentRole == UserRole.rider
        ? (acceptedOffer?.driver.name ?? 'الكابتن')
        : 'الراكب';

    InAppNotificationWidget.show(
      context,
      title: 'رسالة جديدة من $senderName',
      body: text,
      onTap: () {
        if (currentRequestId != null && userUid != null) {
          final String partnerId = currentRole == UserRole.rider
              ? acceptedOffer!.driverId
              : activePassengerId!;
          final String partnerName = currentRole == UserRole.rider
              ? acceptedOffer!.driver.name
              : (acceptedOffer?.driver.name ?? 'الراكب');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                tripId: currentRequestId!,
                myId: userUid!,
                partnerId: partnerId,
                partnerName: partnerName,
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> selectRole(UserRole role) async {
    currentRole = role;
    if (userUid != null) {
      try {
        await _supabase.from('users').update({'role': role.name}).eq('id', userUid!);
      } catch (e) {
        debugPrint('Error updating role in Supabase: $e');
      }
    }
    notifyListeners();
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    currentRole = role;
    final authRes = await AuthRepository.instance.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );
    // Immediately sync profile data for accurate navigation
    if (authRes.user != null) {
      userUid = authRes.user!.id;
      isLoggedIn = true;
      userName = fullName;
      if (role == UserRole.rider) {
        passengerName = fullName;
      }
      notifyListeners();
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    if (role != null) currentRole = role;
    await AuthRepository.instance.signInWithEmail(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword({required String email}) async {
    await AuthRepository.instance.resetPasswordForEmail(email);
  }

  Future<void> loginWithOTP({
    required String verificationId,
    required String smsCode,
    required UserRole role,
    String? phoneNumber,
  }) async {
    debugPrint('[GlobalState] ▶ loginWithOTP called for $verificationId, role: ${role.name}');
    currentRole = role;

    final authRes = await AuthRepository.instance.verifyOTP(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final activeSession = authRes.session ?? _supabase.auth.currentSession;
    final activeUser = authRes.user ?? _supabase.auth.currentUser;

    debugPrint('[GlobalState] Verifying Auth status: Session=${activeSession != null}, User=${activeUser != null}');

    if (activeSession == null || activeUser == null || activeSession.accessToken.isEmpty) {
      debugPrint('[GlobalState] ✗ loginWithOTP — Invalid Supabase Session or User. Session: $activeSession, User: $activeUser');
      throw Exception('فشل إنشاء جلسة مصادقة صالحة في Supabase Auth. AccessToken/User مفقود.');
    }

    final verifiedUser = activeUser;
    debugPrint('[GlobalState] ✓ loginWithOTP — Session active for userId: ${verifiedUser.id}, AccessToken: ${activeSession.accessToken.substring(0, 15)}...');

    // Store verified data from Supabase Auth user
    userUid = verifiedUser.id;
    isLoggedIn = true;

    // Prefer the phone number from Supabase Auth user object (the verified one)
    final supabasePhone = verifiedUser.phone;
    if (supabasePhone != null && supabasePhone.isNotEmpty) {
      this.phoneNumber = supabasePhone;
      debugPrint('[GlobalState] ✓ phoneNumber set from Supabase Auth: $supabasePhone');
    } else if (phoneNumber != null && phoneNumber.isNotEmpty) {
      this.phoneNumber = phoneNumber;
      debugPrint('[GlobalState] ✓ phoneNumber set from parameter: $phoneNumber');
    }

    try {
      final profile = await AuthRepository.instance.fetchOrCreateUserProfile(
        verifiedUser.id,
        this.phoneNumber ?? '',
        role,
      );
      // Immediately sync profile data into memory for accurate navigation
      userName = profile.name;
      if (role == UserRole.rider) {
        passengerName = profile.name;
      }
    } catch (e) {
      debugPrint('[GlobalState] Profile sync notice on loginWithOTP: $e');
    }

    // Sync driver verification status immediately for driver role
    if (role == UserRole.driver) {
      try {
        final driverRes = await _supabase.from('drivers').select().eq('id', verifiedUser.id).maybeSingle();
        if (driverRes != null) {
          final dStatus = driverRes['verification_status'] ?? 'unregistered';
          if (dStatus == 'verified') {
            verificationStatus = DriverVerificationStatus.verified;
          } else if (dStatus == 'submitted') {
            verificationStatus = DriverVerificationStatus.submitted;
          } else {
            verificationStatus = DriverVerificationStatus.unregistered;
          }
        }
      } catch (e) {
        debugPrint('[GlobalState] Error fetching driver status on loginWithOTP: $e');
      }
    }

    notifyListeners();
    debugPrint('[GlobalState] ✓ loginWithOTP complete — user ${verifiedUser.id} authenticated & state updated');
  }

  /// Demo Account Properties
  bool get isDemoModeEnabled => (appSettings['demo_mode_enabled'] as bool?) ?? false;
  bool get isDemoPassengerEnabled => isDemoModeEnabled && ((appSettings['demo_passenger_enabled'] as bool?) ?? false);
  bool get isDemoDriverEnabled => isDemoModeEnabled && ((appSettings['demo_driver_enabled'] as bool?) ?? false);
  String get demoPhone => (appSettings['demo_phone'] as String?) ?? '01000000000';
  String get demoOtp => (appSettings['demo_otp'] as String?) ?? '123456';
  String get demoDriverName => (appSettings['demo_driver_name'] as String?) ?? 'كابتن تجريبي (Demo)';
  String get demoPassengerName => (appSettings['demo_passenger_name'] as String?) ?? 'راكب تجريبي (Demo)';

  /// WhatsApp OTP Support Number (configurable from dashboard / Supabase)
  String get otpSupportWhatsApp {
    final val = (appSettings['otp_support_whatsapp'] as String?)?.trim();
    if (val != null && val.isNotEmpty) {
      return val;
    }
    return '01204062941';
  }

  /// System Maintenance Mode Flag (configured from Admin Dashboard)
  bool get isMaintenanceMode => appSettings['is_maintenance_mode'] == true;

  /// System Maintenance Mode Title
  String get maintenanceTitle {
    final title = (appSettings['maintenance_title'] as String?)?.trim();
    if (title != null && title.isNotEmpty) return title;
    return 'التطبيق تحت الصيانة حالياً';
  }

  /// System Maintenance Mode Description Message
  String get maintenanceMessage {
    final msg = (appSettings['maintenance_message'] as String?)?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    return 'نعمل على تحسين وتحديث خدمات inRide لنقدم لكم تجربة أفضل وأسرع. سنعود للعمل قريباً جداً.';
  }

  /// Check if user has administrative access to bypass maintenance overlay if needed
  bool get isAdmin {
    final email = _supabase.auth.currentUser?.email?.toLowerCase();
    return phoneNumber == '01204062941' ||
        phoneNumber == '01000000000' ||
        (email != null &&
            (email.contains('admin') || email == 'romanygoerge48@gmail.com'));
  }

  /// Force-refresh app settings from Supabase
  Future<void> refreshAppSettings() async {
    try {
      final res = await _supabase
          .from('app_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();
      if (res != null) {
        appSettings.addAll(res);
        if (res['commission_rate'] != null) {
          appSettings['commissionRate'] =
              (res['commission_rate'] as num).toDouble();
        }
        notifyListeners();
        debugPrint('[GlobalState] Refreshed app settings manually: $appSettings');
      }
    } catch (e) {
      debugPrint('[GlobalState] Error refreshing app settings: $e');
    }
  }

  /// Direct Instant Demo Login Method (bypasses OTP & admin approvals)
  Future<void> loginAsDemo({required UserRole role}) async {
    debugPrint('[GlobalState] 🚀 loginAsDemo called for role: ${role.name}');
    currentRole = role;
    final targetPhone = demoPhone;
    final isDriver = role == UserRole.driver;
    final displayName = isDriver ? demoDriverName : demoPassengerName;

    final authRes = await PhoneAuthService.instance.verifyDemoUser(
      phoneNumber: targetPhone,
      roleName: role.name,
      nameOverride: displayName,
    );

    final activeSession = authRes.session ?? _supabase.auth.currentSession;
    final activeUser = authRes.user ?? _supabase.auth.currentUser;

    if (activeUser == null || activeSession == null) {
      throw Exception('فشل إنشاء جلسة الحساب التجريبي');
    }

    userUid = activeUser.id;
    isLoggedIn = true;
    isAuthResolved = true;
    phoneNumber = activeUser.phone ?? targetPhone;
    userName = displayName;
    try {
      sl<NotificationController>().init(activeUser.id);
      unawaited(SupportChatService.instance.initializeForUser(activeUser.id));
    } catch (_) {}

    if (isDriver) {
      _currentRole = UserRole.driver;
      verificationStatus = DriverVerificationStatus.verified;
      vehicleName = 'تويوتا كورولا 2024';
      vehicleNumber = 'أ ب ج 1234';
      driverVehicleColor = 'أبيض لؤلؤي';
      driverVehicleCategory = 'car';
      driverAddress = 'مدينة السادات، المنوفية';
      driverWalletBalance = 500.0;
      driverHasAC = true;
      driverMaxPassengers = 4;
    } else {
      _currentRole = UserRole.rider;
      passengerName = displayName;
      passengerGender = 'ذكر';
      passengerAddress = 'مدينة السادات، المنوفية';
      passengerWalletBalance = 500.0;
    }

    await _saveProfileToCache();
    _startPresenceTracking();
    notifyListeners();
    debugPrint('[GlobalState] ✓ loginAsDemo complete — Demo user ${activeUser.id} signed in successfully as ${role.name}');
  }

  String _generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> deleteUserAccount() async {
    final isAr = LocaleController.instance.isArabic;
    await DeleteAccountService.instance.deleteAccount(isArabic: isAr);
  }
}

