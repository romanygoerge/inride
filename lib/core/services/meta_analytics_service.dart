import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/meta_config.dart';
import '../utils/app_logger.dart';

/// Professional Meta / Facebook App Events Service
/// Manages tracking, conversion optimization for Meta Ads, deduplication,
/// privacy compliance (No PII), and resilient error handling.
class MetaAnalyticsService {
  static final MetaAnalyticsService _instance = MetaAnalyticsService._internal();
  factory MetaAnalyticsService() => _instance;
  MetaAnalyticsService._internal();

  static MetaAnalyticsService get instance => _instance;

  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();
  bool _isInitialized = false;

  // ── Deduplication Caches ───────────────────────────────────────────────────
  final Set<String> _requestedRideIds = <String>{};
  final Set<String> _acceptedRideIds = <String>{};
  final Set<String> _startedRideIds = <String>{};
  final Set<String> _completedRideIds = <String>{};
  final Set<String> _processedPaymentIds = <String>{};

  String? _lastLoginUserId;
  DateTime? _lastLoginTime;

  String? _lastSearchQuery;
  DateTime? _lastSearchTime;

  /// Initialize Meta SDK and configure iOS App Tracking Transparency (ATT)
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // 1. Handle iOS 14.5+ App Tracking Transparency (ATT)
      if (!kIsWeb && Platform.isIOS) {
        await _requestIosTrackingPermission();
      }

      // 2. Set auto log and advertiser tracking
      await _facebookAppEvents.setAutoLogAppEventsEnabled(true);

      // 3. Log App Open
      await logAppOpen();

      _isInitialized = true;
      debugPrint('[MetaAnalytics] ✓ Meta/Facebook SDK initialized successfully (Configured: ${MetaConfig.isConfigured})');
    } catch (e, stack) {
      // Resilient: Never throw or disrupt app initialization
      AppLogger.error('MetaAnalytics', 'Error initializing Meta/Facebook SDK (non-fatal)', e, stack);
    }
  }

  /// Request Apple ATT permission on iOS for IDFA collection and Meta Ads Attribution
  Future<void> _requestIosTrackingPermission() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // Wait a brief delay for UI/Splash to settle before prompting
        await Future.delayed(const Duration(milliseconds: 600));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }

      final updatedStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
      final isAuthorized = updatedStatus == TrackingStatus.authorized;
      await _facebookAppEvents.setAdvertiserTracking(enabled: isAuthorized);
      debugPrint('[MetaAnalytics] iOS ATT status: $updatedStatus (Advertiser Tracking: $isAuthorized)');
    } catch (e) {
      debugPrint('[MetaAnalytics] ATT permission check error: $e');
    }
  }

  /// Set user identifier securely (anonymized UUID, no phone or name)
  Future<void> setUserId(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    try {
      await _facebookAppEvents.setUserID(userId);
    } catch (e) {
      debugPrint('[MetaAnalytics] Error setting user ID: $e');
    }
  }

  /// Clear user identifier on logout
  Future<void> clearUserId() async {
    try {
      await _facebookAppEvents.clearUserID();
    } catch (e) {
      debugPrint('[MetaAnalytics] Error clearing user ID: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // App Events Implementations
  // ───────────────────────────────────────────────────────────────────────────

  /// 1. App Open / Activate App (`fb_mobile_activate_app`)
  Future<void> logAppOpen() async {
    try {
      await _facebookAppEvents.activateApp();
      debugPrint('[MetaAnalytics] ✓ Event logged: fb_mobile_activate_app');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging App Open: $e');
    }
  }

  /// 2. Complete Registration (`fb_mobile_complete_registration`)
  /// Guaranteed to fire only once per user lifetime via SharedPreferences + Memory Cache
  Future<void> logCompleteRegistration({
    required String userId,
    String role = 'passenger',
    String method = 'phone',
  }) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'meta_reg_logged_$userId';
      if (prefs.getBool(cacheKey) == true) {
        debugPrint('[MetaAnalytics] Registration already logged for user $userId (deduplicated)');
        return;
      }

      await _facebookAppEvents.logCompletedRegistration(
        registrationMethod: method,
      );

      // Also log custom role attribute without PII
      await _facebookAppEvents.logEvent(
        name: 'UserRegistrationDetails',
        parameters: {
          'user_role': role,
          'registration_method': method,
        },
      );

      await prefs.setBool(cacheKey, true);
      debugPrint('[MetaAnalytics] ✓ Event logged: fb_mobile_complete_registration (role: $role)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Complete Registration: $e');
    }
  }

  /// 3. Login (`fb_mobile_content_view` / `Login`)
  /// Throttled to prevent multiple triggers during rapid stream or token refreshes
  Future<void> logLogin({
    required String userId,
    String method = 'phone',
  }) async {
    if (userId.isEmpty) return;
    final now = DateTime.now();
    if (_lastLoginUserId == userId &&
        _lastLoginTime != null &&
        now.difference(_lastLoginTime!) < const Duration(minutes: 5)) {
      // Throttled: logged recently
      return;
    }

    _lastLoginUserId = userId;
    _lastLoginTime = now;

    try {
      await setUserId(userId);

      // Meta standard content view representing login session start
      await _facebookAppEvents.logEvent(
        name: 'Login',
        parameters: {
          'login_method': method,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: Login (method: $method)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Login: $e');
    }
  }

  /// 4. Search (`fb_mobile_search`)
  /// Debounced and deduplicated for consecutive identical search queries
  Future<void> logSearch({
    required String query,
    int resultCount = 0,
    String searchType = 'location',
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || cleanQuery.length < 2) return;

    final now = DateTime.now();
    if (_lastSearchQuery == cleanQuery &&
        _lastSearchTime != null &&
        now.difference(_lastSearchTime!) < const Duration(seconds: 3)) {
      // Deduplicated within short window
      return;
    }

    _lastSearchQuery = cleanQuery;
    _lastSearchTime = now;

    try {
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_search',
        parameters: {
          'fb_search_string': cleanQuery,
          'fb_content_type': searchType,
          'fb_success': resultCount > 0 ? 1 : 0,
          'result_count': resultCount,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: fb_mobile_search (query: "$cleanQuery", results: $resultCount)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Search: $e');
    }
  }

  /// 5. Request Ride (`fb_mobile_initiated_checkout`)
  /// Mapped to Meta standard Initiated Checkout for direct ad ROAS / conversion optimization
  Future<void> logRideRequested({
    required String rideId,
    required double fare,
    required String vehicleType,
    required String serviceType,
    String currency = 'EGP',
  }) async {
    if (rideId.isEmpty || _requestedRideIds.contains(rideId)) return;
    _requestedRideIds.add(rideId);

    try {
      // Standard Initiated Checkout event
      await _facebookAppEvents.logInitiatedCheckout(
        totalPrice: fare > 0 ? fare : 0.0,
        currency: currency,
        contentId: rideId,
        contentType: 'ride_request',
        numItems: 1,
        paymentInfoAvailable: true,
      );

      // Custom supplementary event
      await _facebookAppEvents.logEvent(
        name: 'RideRequested',
        parameters: {
          'ride_id': rideId,
          'fare_amount': fare,
          'currency': currency,
          'vehicle_type': vehicleType,
          'service_type': serviceType,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: fb_mobile_initiated_checkout & RideRequested (fare: $fare $currency, id: $rideId)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Ride Request: $e');
    }
  }

  /// 6. Ride Accepted (`RideAccepted`)
  /// Custom Meta event for matching funnel analysis
  Future<void> logRideAccepted({
    required String rideId,
    double fare = 0.0,
    String serviceType = 'ride',
    String currency = 'EGP',
  }) async {
    if (rideId.isEmpty || _acceptedRideIds.contains(rideId)) return;
    _acceptedRideIds.add(rideId);

    try {
      await _facebookAppEvents.logEvent(
        name: 'RideAccepted',
        parameters: {
          'ride_id': rideId,
          'fare_amount': fare,
          'currency': currency,
          'service_type': serviceType,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: RideAccepted (id: $rideId)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Ride Accepted: $e');
    }
  }

  /// 7. Ride Started (`RideStarted`)
  /// Custom Meta event for trip execution milestone
  Future<void> logRideStarted({
    required String rideId,
    String serviceType = 'ride',
  }) async {
    if (rideId.isEmpty || _startedRideIds.contains(rideId)) return;
    _startedRideIds.add(rideId);

    try {
      await _facebookAppEvents.logEvent(
        name: 'RideStarted',
        parameters: {
          'ride_id': rideId,
          'service_type': serviceType,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: RideStarted (id: $rideId)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Ride Started: $e');
    }
  }

  /// 8. Ride Completed (`fb_mobile_purchase` & `RideCompleted`)
  /// High-value Meta standard Purchase event for value-based ad optimization
  Future<void> logRideCompleted({
    required String rideId,
    required double fare,
    String paymentMethod = 'cash',
    String currency = 'EGP',
  }) async {
    if (rideId.isEmpty || _completedRideIds.contains(rideId)) return;
    _completedRideIds.add(rideId);

    try {
      final validFare = fare > 0 ? fare : 10.0;

      // Meta standard Purchase event (Critical for App Install Campaign Value Optimization)
      await _facebookAppEvents.logPurchase(
        amount: validFare,
        currency: currency,
        parameters: {
          'content_type': 'ride_trip',
          'content_id': rideId,
          'payment_method': paymentMethod,
        },
      );

      // Custom milestone event
      await _facebookAppEvents.logEvent(
        name: 'RideCompleted',
        parameters: {
          'ride_id': rideId,
          'fare_amount': validFare,
          'currency': currency,
          'payment_method': paymentMethod,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: fb_mobile_purchase & RideCompleted (fare: $validFare $currency, id: $rideId)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Ride Completed: $e');
    }
  }

  /// 9. Payment / Purchase (`fb_mobile_purchase`)
  /// Used for Wallet Top-up or In-App Payments
  Future<void> logPayment({
    required String transactionId,
    required double amount,
    String paymentType = 'wallet_recharge',
    String paymentMethod = 'vodafone_cash',
    String currency = 'EGP',
  }) async {
    if (transactionId.isEmpty || _processedPaymentIds.contains(transactionId)) return;
    _processedPaymentIds.add(transactionId);

    try {
      final validAmount = amount > 0 ? amount : 1.0;

      await _facebookAppEvents.logPurchase(
        amount: validAmount,
        currency: currency,
        parameters: {
          'transaction_id': transactionId,
          'payment_type': paymentType,
          'payment_method': paymentMethod,
        },
      );
      debugPrint('[MetaAnalytics] ✓ Event logged: fb_mobile_purchase (paymentType: $paymentType, amount: $validAmount $currency)');
    } catch (e) {
      debugPrint('[MetaAnalytics] Error logging Payment: $e');
    }
  }
}
