import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceTokenService {
  static final DeviceTokenService instance = DeviceTokenService._internal();
  factory DeviceTokenService() => instance;
  DeviceTokenService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _currentUserId;
  String? _currentDeviceToken;

  /// Get current platform string: 'android', 'ios', 'web'
  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
      default:
        return 'android';
    }
  }

  /// Request push notification permissions and register user's device push token securely in Supabase.
  Future<void> registerDeviceToken(String userId) async {
    if (userId.isEmpty) return;
    _currentUserId = userId;

    try {
      debugPrint('[DeviceTokenService] Requesting notification permissions...');
      final permissionGranted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('[DeviceTokenService] Permission status: $permissionGranted');

      // Login OneSignal External ID to associate user with device
      await OneSignal.login(userId);
      debugPrint('[DeviceTokenService] Logged in user External ID: $userId');

      // Retrieve device token / player ID
      final token = OneSignal.User.pushSubscription.id;
      if (token != null && token.isNotEmpty && token != 'default_token') {
        _currentDeviceToken = token;
        await _saveTokenToSupabase(userId: userId, token: token);
      } else {
        debugPrint('[DeviceTokenService] Device token not available immediately, setting up subscription observer...');
      }

      // Listen for token updates / changes dynamically
      OneSignal.User.pushSubscription.addObserver((state) {
        final updatedToken = state.current.id;
        if (updatedToken != null && updatedToken.isNotEmpty && _currentUserId != null) {
          _currentDeviceToken = updatedToken;
          debugPrint('[DeviceTokenService] Token changed observer triggered: $updatedToken');
          _saveTokenToSupabase(userId: _currentUserId!, token: updatedToken);
        }
      });

    } catch (e) {
      debugPrint('[DeviceTokenService] Error registering device token: $e');
    }
  }

  /// Save token into public.user_devices table with platform and active state.
  Future<void> _saveTokenToSupabase({
    required String userId,
    required String token,
  }) async {
    if (userId.isEmpty || token.isEmpty || token == 'default_token') return;

    try {
      debugPrint('[DeviceTokenService] Saving device token to user_devices table for user_id=$userId');
      
      // Upsert into user_devices table (supports multiple devices per user & prevents duplicates)
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'device_token': token,
        'platform': _platformName,
        'device_type': kIsWeb ? 'browser' : 'phone',
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, device_token');

      debugPrint('[Notification] Active device tokens saved in user_devices: user_id=$userId, token=$token');

      // Legacy fallback updates to users and drivers tables
      try {
        await _supabase.from('users').update({'fcm_token': token}).eq('id', userId);
      } catch (_) {}
      try {
        await _supabase.from('drivers').update({'fcm_token': token}).eq('id', userId);
      } catch (_) {}

    } catch (e) {
      debugPrint('[DeviceTokenService] Error saving token to Supabase: $e');
    }
  }

  /// Deactivate or unregister token when user logs out or app uninstalls
  Future<void> deactivateCurrentDeviceToken(String userId) async {
    final token = _currentDeviceToken ?? OneSignal.User.pushSubscription.id;
    debugPrint('[DeviceTokenService] Deactivating device token for user $userId (token=$token)');

    try {
      if (token != null && token.isNotEmpty) {
        await _supabase
            .from('user_devices')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('device_token', token);

        debugPrint('[Notification] Invalid or logged-out token removed/deactivated: user_id=$userId');
      }

      await OneSignal.logout();
    } catch (e) {
      debugPrint('[DeviceTokenService] Error deactivating device token: $e');
    } finally {
      _currentUserId = null;
      _currentDeviceToken = null;
    }
  }
}
