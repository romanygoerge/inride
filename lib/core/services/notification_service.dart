import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../state/global_state.dart';
import '../../main.dart' show navigatorKey;
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/passenger/presentation/pages/passenger_ride_active_page.dart';
import '../../features/driver/presentation/pages/driver_home_page.dart';
import '../utils/snappy_page_route.dart';
import '../../features/common/notifications_page.dart';
import '../config/onesignal_config.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _repository = NotificationRepository();
  final Set<String> _sentNotificationIds = {};

  // ────────────────────────────────────────────────────────────────────
  // Notification Click Handler — يوجّه المستخدم للشاشة المناسبة
  // ────────────────────────────────────────────────────────────────────
  Future<void> handleNotificationClick(Map<String, dynamic> data) async {
    final String type = data['type'] ?? 'admin_notifications';
    debugPrint('[NotificationService] Handling tap type: $type, data: $data');

    // 1. رحلة جديدة / طلب توصيل
    if (type == 'new_trip' ||
        type == 'new_ride' ||
        type == 'delivery_request' ||
        type == 'new_offer' ||
        type == 'driver_offer') {
      if (GlobalState.instance.currentRole == UserRole.driver) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomePage()),
            (route) => false,
          );
        }
      } else if (GlobalState.instance.currentRole == UserRole.rider) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
      return;
    }

    // 2. قبول الرحلة / وصول السائق / بدء الرحلة
    if (type == 'accept_trip' ||
        type == 'ride_accepted' ||
        type == 'delivery_accepted' ||
        type == 'driver_arrived' ||
        type == 'captain_arrived' ||
        type == 'trip_started') {
      if (GlobalState.instance.currentRole == UserRole.rider) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.push(
            context,
            SnappyPageRoute(page: const PassengerRideActivePage()),
          );
        }
      }
      return;
    }

    // 3. إلغاء / إنهاء / دفع
    if (type == 'cancel_trip' ||
        type == 'trip_finished' ||
        type == 'trip_completed' ||
        type == 'payment') {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    // 4. رسالة دردشة
    if (type == 'new_message' || type == 'chat_message') {
      final tripId = data['tripId'];
      final partnerId = data['partnerId'];
      final partnerName = data['partnerName'] ?? 'inRide Partner';
      final myId = GlobalState.instance.userUid;

      if (tripId != null && partnerId != null && myId != null) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                tripId: tripId,
                myId: myId,
                partnerId: partnerId,
                partnerName: partnerName,
              ),
            ),
          );
        }
      }
      return;
    }

    // 5. عروض (url إن وُجد)
    if (type == 'offers') {
      final urlStr = data['url'];
      if (urlStr != null && urlStr.isNotEmpty) {
        final url = Uri.parse(urlStr);
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
          return;
        }
      }
    }

    // افتراضي: صفحة الإشعارات
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.push(
        context,
        SnappyPageRoute(page: const NotificationsPage()),
      );
    }
  }

  // Debug Logs Buffer for NotificationDebugPage
  final List<Map<String, dynamic>> debugLogs = [];
  Map<String, dynamic>? lastPushSent;
  String? lastError;

  void _addLog(Map<String, dynamic> log) {
    debugLogs.insert(0, log);
    if (debugLogs.length > 100) debugLogs.removeLast();
  }

  // ────────────────────────────────────────────────────────────────────
  // إرسال إشعار Push عبر OneSignal REST API
  // ────────────────────────────────────────────────────────────────────
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    bool forceSelf = false,
  }) async {
    final myId = GlobalState.instance.userUid;

    if (recipientId == myId && !forceSelf) {
      debugPrint('[NotificationService] Skipped sending notification to self.');
      return;
    }

    final String notifId = data?['id'] ??
        '${recipientId}_${type}_${DateTime.now().millisecondsSinceEpoch}';

    if (_sentNotificationIds.contains(notifId) && !forceSelf) {
      debugPrint('[NotificationService] Skipped duplicate notification: $notifId');
      return;
    }
    _sentNotificationIds.add(notifId);

    // 1. حفظ الإشعار في قاعدة بيانات المستلم
    final notification = NotificationModel(
      id: notifId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      data: data ?? {},
    );
    await _repository.saveNotification(recipientId, notification);

    // 2. جلب OneSignal Player ID من قاعدة البيانات
    try {
      final userRes = await _supabase
          .from('users')
          .select('fcm_token')
          .eq('id', recipientId)
          .maybeSingle();

      String playerId = '';
      if (userRes != null && userRes['fcm_token'] != null) {
        playerId = (userRes['fcm_token'] as String).trim();
      }

      await _sendViaOneSignal(
        notifId: notifId,
        recipientId: recipientId,
        playerId: playerId,
        title: title,
        body: body,
        type: type,
        payload: {
          'id': notifId,
          'recipientId': recipientId,
          'type': type,
          ...?data,
        },
      );
    } catch (e) {
      lastError = e.toString();
      debugPrint('[NotificationService] Error sending push to $recipientId: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // OneSignal REST API - إرسال الإشعار
  // ────────────────────────────────────────────────────────────────────
  Future<void> _sendViaOneSignal({
    required String notifId,
    required String recipientId,
    required String playerId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    if (!OneSignalConfig.isConfigured) {
      debugPrint('[NotificationService] OneSignal not configured, skipping push.');
      return;
    }

    try {
      final url = Uri.parse('https://api.onesignal.com/notifications');

      // تحويل جميع القيم إلى String (OneSignal data payload يقبل strings فقط)
      final Map<String, String> stringifiedData = {};
      payload.forEach((key, value) {
        stringifiedData[key] = value.toString();
      });

      final messageBody = <String, dynamic>{
        'app_id': OneSignalConfig.appId,
        'target_channel': 'push',
        'include_aliases': {
          'external_id': [recipientId]
        },
        'headings': {'en': title, 'ar': title},
        'contents': {'en': body, 'ar': body},
        'data': stringifiedData,
        'android_channel_id': 'high_importance_channel',
        'android_accent_color': 'FF1976D2',
        'priority': 10,
        'ttl': 86400,
        'small_icon': 'ic_launcher',
      };

      if (playerId.isNotEmpty && playerId != 'default_token' && playerId.length > 10) {
        messageBody['include_player_ids'] = [playerId];
      }

      final logData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String().substring(11, 19),
        'type': type,
        'recipientId': recipientId,
        'playerId': playerId,
        'title': title,
        'body': body,
        'payload': payload,
        'success': false,
        'statusCode': 0,
        'responseBody': '',
      };

      int retries = 0;
      bool success = false;
      final client = http.Client();

      debugPrint('''
==================================================
TRIP / CHAT EVENT NOTIFICATION LOG
Event Type: $type
Notif ID: $notifId
Recipient User ID (External ID): $recipientId
Recipient Player ID: $playerId
Title: $title
Body: $body
Payload: $payload
Sending Request to OneSignal REST API...
==================================================''');

      while (!success && retries < 3) {
        try {
          final response = await client
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Key ${OneSignalConfig.restApiKey}',
                },
                body: json.encode(messageBody),
              )
              .timeout(const Duration(seconds: 10));

          logData['statusCode'] = response.statusCode;
          logData['responseBody'] = response.body;

          if (response.statusCode == 200) {
            success = true;
            logData['success'] = true;
            lastPushSent = logData;
            lastError = null;
            debugPrint('''
[NotificationService] OneSignal Response Success:
HTTP Status: ${response.statusCode}
Response Body: ${response.body}
==================================================''');
          } else {
            retries++;
            lastError = 'OneSignal HTTP ${response.statusCode}: ${response.body}';
            debugPrint('[NotificationService] OneSignal error ${response.statusCode}: '
                '${response.body} — retry $retries/3');
            await Future.delayed(Duration(seconds: retries * 2));
          }
        } catch (e) {
          retries++;
          lastError = 'HTTP Error: $e';
          logData['responseBody'] = 'Error: $e';
          debugPrint('[NotificationService] OneSignal HTTP error: $e — retry $retries/3');
          await Future.delayed(Duration(seconds: retries * 2));
        }
      }

      _addLog(logData);
      client.close();
    } catch (e) {
      lastError = 'Setup Error: $e';
      debugPrint('[NotificationService] OneSignal setup failed: $e');
    }
  }
}
