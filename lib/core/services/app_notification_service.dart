import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../repositories/notification_repository.dart';
import 'notification_service.dart';
import '../config/onesignal_config.dart';
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

  final NotificationRepository _repository = NotificationRepository();
  bool _isInitialized = false;
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
    if (!OneSignalConfig.isConfigured) {
      debugPrint('[AppNotificationService] WARNING: OneSignal not configured yet! '
          'Set OneSignalConfig.appId and OneSignalConfig.restApiKey.');
    }

    OneSignal.initialize(OneSignalConfig.appId);
    await OneSignal.Notifications.requestPermission(true);

    // ── 3. Foreground Notification Handler ──
    // عندما يكون التطبيق مفتوحاً، نعرض الإشعار محلياً ونعرض بانر داخل التطبيق
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();

      final notif = event.notification;
      final data = Map<String, dynamic>.from(notif.additionalData ?? {});
      final title = notif.title ?? '';
      final body = notif.body ?? '';

      // 1. عرض إشعار النظام المباشر
      showLocalNotification(
        id: (notif.notificationId as int?) ?? (DateTime.now().millisecondsSinceEpoch % 100000),
        title: title,
        body: body,
        data: data,
      );

      // 2. عرض البانر المنبثق التفاعلي داخل التطبيق
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        InAppNotificationWidget.show(
          context,
          title: title,
          body: body,
          onTap: () => NotificationService.instance.handleNotificationClick(data),
        );
      }

      debugPrint('[AppNotificationService] Foreground notification shown: $title');
    });

    // ── 4. Notification Tap Handler (Background / Terminated) ──
    OneSignal.Notifications.addClickListener((event) {
      final data = Map<String, dynamic>.from(event.notification.additionalData ?? {});
      debugPrint('[AppNotificationService] Notification tapped: $data');
      NotificationService.instance.handleNotificationClick(data);
    });

    // ── 5. Player ID Observer (تحديث تلقائي عند تغيير الـ Player ID) ──
    OneSignal.User.pushSubscription.addObserver((state) {
      final playerId = state.current.id;
      if (playerId != null && playerId.isNotEmpty && _currentUserId != null) {
        _repository.saveFCMToken(_currentUserId!, playerId);
        debugPrint('[AppNotificationService] Player ID updated & saved: $playerId');
      }
    });

    _isInitialized = true;
    debugPrint('[AppNotificationService] Initialized successfully with OneSignal.');
  }


  /// يُستدعى بعد تسجيل الدخول لحفظ OneSignal Player ID في قاعدة البيانات وربط الـ External ID
  Future<void> savePlayerIdForUser(String userId) async {
    if (kIsWeb) return;
    _currentUserId = userId;

    try {
      // 1. ربط الـ External ID الخاص بالمستخدم في OneSignal
      await OneSignal.login(userId);
      debugPrint('[AppNotificationService] OneSignal.login called with External ID: $userId');
    } catch (e) {
      debugPrint('[AppNotificationService] Error calling OneSignal.login: $e');
    }

    // انتظر قليلاً لحين تسجيل OneSignal
    await Future.delayed(const Duration(milliseconds: 800));

    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId != null && playerId.isNotEmpty) {
      await _repository.saveFCMToken(userId, playerId);
      debugPrint('[AppNotificationService] Saved Player ID: $playerId for user $userId');
    } else {
      debugPrint('[AppNotificationService] Player ID not ready yet, observer will save it later...');
    }
  }

  /// Legacy compatibility method
  Future<void> saveTokenToDatabase(String userId, String token) async {
    await savePlayerIdForUser(userId);
  }

  Future<void> clearTokenFromDatabase(String userId) async {
    _currentUserId = null;
    if (kIsWeb) return;
    try {
      await OneSignal.logout();
      debugPrint('[AppNotificationService] OneSignal.logout completed for user $userId');
    } catch (e) {
      debugPrint('[AppNotificationService] Error logging out OneSignal: $e');
    }
    await _repository.clearFCMToken(userId);
  }

  /// عرض إشعار محلي (يُستخدم للـ Foreground)
  void showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    if (kIsWeb) return;
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
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }
}
