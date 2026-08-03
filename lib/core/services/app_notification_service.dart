import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'notification_service.dart';
import 'device_token_service.dart';
import '../config/onesignal_config.dart';
import '../models/notification_model.dart';
import '../state/global_state.dart';
import '../../main.dart' show navigatorKey;
import '../../shared/widgets/in_app_notification.dart';


const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'إشعارات عالية الأهمية',
  description: 'قناة مخصصة لإشعارات الرحلات والتوصيل والعروض العاجلة',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

class AppNotificationService {
  static final AppNotificationService instance = AppNotificationService._internal();
  factory AppNotificationService() => instance;
  AppNotificationService._internal();

  bool _isInitialized = false;
  // ignore: unused_field
  String? _currentUserId;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    // ── 1. Flutter Local Notifications (للعرض في الـ Foreground) ──

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            NotificationService.instance.handleNotificationClick(data);
          } catch (e) {
            debugPrint('[AppNotificationService] Error parsing payload: $e');
          }
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(highImportanceChannel);
      await androidPlugin.requestNotificationsPermission();
    }

    // ── 2. OneSignal Initialization ──
    if (!OneSignalConfig.isAppConfigured) {
      debugPrint('[AppNotificationService] WARNING: OneSignal App ID not configured!');
    }

    OneSignal.initialize(OneSignalConfig.appId);
    await OneSignal.Notifications.requestPermission(true);

    // ── 3. Foreground Notification Handler ──
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();

      final notif = event.notification;
      final data = Map<String, dynamic>.from(notif.additionalData ?? {});
      final title = notif.title ?? '';
      final body = notif.body ?? '';
      final type = data['type'] ?? 'info';

      // Check role relevance before displaying banner
      final notifModel = NotificationModel(
        id: notif.notificationId,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        data: data,
      );

      final currentRole = GlobalState.instance.currentRole;
      if (!notifModel.matchesRole(currentRole)) {
        debugPrint('[AppNotificationService] Suppressed foreground notification (type=$type) for role mismatch ($currentRole)');
        return;
      }

      // Generate integer ID from the string notificationId
      final int notifIntId = notif.notificationId.hashCode.abs() % 100000;

      // 1. Display system heads-up notification banner with sound & vibration
      showLocalNotification(
        id: notifIntId,
        title: title,
        body: body,
        type: type,
        data: data,
      );

      // 2. Show interactive floating in-app notification banner
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppNotificationWidget.show(
          context,
          title: title,
          body: body,
          type: type,
          onTap: () {
            debugPrint('[Notification] Notification opened: $data');
            NotificationService.instance.handleNotificationClick(data);
          },
        );
      }

      debugPrint('[AppNotificationService] Foreground notification handled with banner: type=$type, title=$title');
    });

    // ── 4. Notification Tap Handler (Background / Terminated) ──
    OneSignal.Notifications.addClickListener((event) {
      final data = Map<String, dynamic>.from(event.notification.additionalData ?? {});
      final actionId = event.result.actionId;
      debugPrint('[Notification] Notification opened actionId=$actionId: $data');

      if (actionId == 'reject_trip') {
        debugPrint('[Notification] Driver dismissed/rejected trip push notification');
        return;
      }

      NotificationService.instance.handleNotificationClick(data);
    });

    _isInitialized = true;
    debugPrint('[AppNotificationService] Initialized successfully with OneSignal.');
  }

  /// Called after user logs in to register device push token in Supabase user_devices table
  Future<void> savePlayerIdForUser(String userId) async {
    if (kIsWeb) return;
    _currentUserId = userId;
    await DeviceTokenService.instance.registerDeviceToken(userId);
  }

  /// Legacy compatibility method
  Future<void> saveTokenToDatabase(String userId, String token) async {
    await savePlayerIdForUser(userId);
  }

  /// Called on user logout to deactivate device token
  Future<void> clearTokenFromDatabase(String userId) async {
    _currentUserId = null;
    if (kIsWeb) return;
    await DeviceTokenService.instance.deactivateCurrentDeviceToken(userId);
  }

  /// Check if notification type is trip-critical (requires immediate attention)
  bool _isTripCritical(String type) {
    const criticalTypes = {
      'new_trip', 'new_ride', 'delivery_request',
      'accept_trip', 'ride_accepted', 'delivery_accepted',
      'driver_arrived', 'captain_arrived', 'trip_started',
      'new_offer', 'driver_offer', 'counter_offer',
    };
    return criticalTypes.contains(type.trim().toLowerCase());
  }

  /// عرض إشعار محلي احترافي بانر (يُستخدم للـ Foreground)
  void showLocalNotification({
    required int id,
    required String title,
    required String body,
    String type = 'info',
    Map<String, dynamic>? data,
  }) {
    if (kIsWeb) return;

    final isCritical = _isTripCritical(type);

    _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          highImportanceChannel.id,
          highImportanceChannel.name,
          channelDescription: highImportanceChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          // BigTextStyle allows the notification to expand and show full body text
          styleInformation: BigTextStyleInformation(
            body,
            htmlFormatBigText: false,
            contentTitle: title,
            htmlFormatContentTitle: false,
            summaryText: 'inRide',
            htmlFormatSummaryText: false,
          ),
          // Full screen intent for critical trip notifications (driver incoming, etc.)
          fullScreenIntent: isCritical,
          // Category for proper notification grouping
          category: isCritical ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
          // Auto-cancel when tapped
          autoCancel: true,
          // Show timestamp
          showWhen: true,
          // Accent color matching app theme
          color: const Color(0xFF1976D2),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // Banner presentation on iOS
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }
}
