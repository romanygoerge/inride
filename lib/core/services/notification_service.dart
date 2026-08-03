import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../state/global_state.dart';
import '../../main.dart' show navigatorKey;
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/passenger/presentation/pages/passenger_ride_active_page.dart';
import '../../features/driver/presentation/pages/driver_home_page.dart';
import '../utils/snappy_page_route.dart';
import '../../features/common/support_chat_page.dart';
import '../../features/common/wallet_page.dart';
import '../config/onesignal_config.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final NotificationRepository _repository = NotificationRepository();
  // TTL-based dedup cache: key -> timestamp sent (clears entries older than 5 minutes)
  final Map<String, DateTime> _sentNotificationIds = {};
  static const Duration _dedupTtl = Duration(minutes: 5);

  void _cleanupDedupCache() {
    final cutoff = DateTime.now().subtract(_dedupTtl);
    _sentNotificationIds.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  // ────────────────────────────────────────────────────────────────────
  // Notification Click Handler — يوجّه المستخدم للشاشة المناسبة
  // ────────────────────────────────────────────────────────────────────
  Future<void> handleNotificationClick(Map<String, dynamic> data) async {
    final String type = (data['type'] ?? 'admin_notifications').toString();
    debugPrint('[NotificationService] Handling tap type: $type, data: $data');

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('[NotificationService] Context not available');
      return;
    }

    // 1. رسالة دردشة بين الركاب والسائقين
    if (type == 'new_message' || type == 'chat_message') {
      final tripId = data['tripId'] ?? data['trip_id'] ?? data['requestId'] ?? GlobalState.instance.currentRequestId;
      String partnerId = (data['partnerId'] ?? data['partner_id'] ?? data['senderId'] ?? '').toString();
      String partnerName = (data['partnerName'] ?? data['partner_name'] ?? 'مستخدم inRide').toString();
      final myId = GlobalState.instance.userUid;

      if (partnerId.isEmpty) {
        if (GlobalState.instance.currentRole == UserRole.driver) {
          partnerId = GlobalState.instance.currentRideRequest?.passengerId ?? GlobalState.instance.activePassengerId ?? '';
        } else {
          partnerId = GlobalState.instance.acceptedOffer?.driverId ?? '';
        }
      }

      if (tripId != null && tripId.toString().isNotEmpty && myId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              tripId: tripId.toString(),
              myId: myId,
              partnerId: partnerId,
              partnerName: partnerName,
            ),
          ),
        );
        return;
      }
    }

    // 2. محادثة الدعم الفني
    if (type == 'support_chat' || type == 'support') {
      Navigator.push(
        context,
        SnappyPageRoute(page: const SupportChatPage()),
      );
      return;
    }

    // 3. رحلة حالية للراكب أو الكابتن
    if (type == 'accept_trip' ||
        type == 'ride_accepted' ||
        type == 'delivery_accepted' ||
        type == 'driver_arrived' ||
        type == 'captain_arrived' ||
        type == 'trip_started') {
      if (GlobalState.instance.currentRole == UserRole.rider) {
        Navigator.push(
          context,
          SnappyPageRoute(page: const PassengerRideActivePage()),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DriverHomePage()),
          (route) => false,
        );
      }
      return;
    }

    // 4. طلب رحلة / عرض جديد للكابتن
    if (type == 'new_trip' ||
        type == 'new_ride' ||
        type == 'delivery_request' ||
        type == 'new_offer' ||
        type == 'driver_offer' ||
        type == 'counter_offer') {
      if (GlobalState.instance.currentRole == UserRole.driver) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DriverHomePage()),
          (route) => false,
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    // 5. المحفظة والعمليات المالية
    if (type == 'wallet' ||
        type == 'charge' ||
        type == 'charge_pending' ||
        type == 'payout' ||
        type == 'payment' ||
        type == 'deposit') {
      Navigator.push(
        context,
        SnappyPageRoute(page: const WalletPage()),
      );
      return;
    }

    // 6. روابط خارجية أو عروض
    final urlStr = data['url'] ?? data['link'];
    if (urlStr != null && urlStr.toString().isNotEmpty) {
      final url = Uri.parse(urlStr.toString());
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return;
      }
    }

    if (!context.mounted) return;

    // 7. إذا كان فيه tripId بالبيانات المرفقة -> افتح الرحلة
    if (data['tripId'] != null || data['requestId'] != null) {
      if (GlobalState.instance.currentRole == UserRole.rider) {
        Navigator.push(
          context,
          SnappyPageRoute(page: const PassengerRideActivePage()),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DriverHomePage()),
          (route) => false,
        );
      }
      return;
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
  // Secure Push Notification Dispatching via Backend Server
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
      debugPrint('[Notification] Skipped sending notification to self (id=$recipientId, type=$type). Use forceSelf=true to override.');
      return;
    }

    // Build a unique notifId based on recipient + type + tripId/requestId
    // IMPORTANT: For chat messages, use data['id'] (messageId) so each chat message is treated uniquely and not deduped!
    final String tripRef = (type == 'chat_message' || type == 'new_message' || type == 'support_chat')
        ? (data?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString())
        : (data?['requestId']?.toString() ??
            data?['tripId']?.toString() ??
            data?['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString());
    final String notifId = '${recipientId}_${type}_$tripRef';

    // Clean up stale dedup entries (older than 5 minutes)
    _cleanupDedupCache();

    if (_sentNotificationIds.containsKey(notifId) && !forceSelf) {
      debugPrint('[Notification] Skipped duplicate notification: $notifId (sent at ${_sentNotificationIds[notifId]})');
      return;
    }
    _sentNotificationIds[notifId] = DateTime.now();

    debugPrint('[Notification] Event created: type=$type, recipientId=$recipientId');

    // 1. Save notification in Supabase for recipient in-app history & Realtime stream
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
    debugPrint('[Notification] Recipient identified: recipientId=$recipientId');

    // 2. Fetch active device tokens from user_devices table
    final tokens = await _repository.getActiveDeviceTokens(recipientId);
    debugPrint('[Notification] Active device tokens found: count=${tokens.length}');

    // 3. Dispatch Push Notification via Backend Endpoint with direct OneSignal fallback
    bool pushDelivered = false;
    try {
      final backendUrl = Uri.parse(OneSignalConfig.backendPushUrl);
      final response = await http.post(
        backendUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipientId': recipientId,
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
          'tokens': tokens,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        debugPrint('[Notification] Push notification delivered via backend server');
        pushDelivered = true;
        _addLog({
          'timestamp': DateTime.now().toIso8601String().substring(11, 19),
          'type': type,
          'recipientId': recipientId,
          'tokensCount': tokens.length,
          'via': 'backend',
          'success': true,
        });
      } else {
        debugPrint('[Notification] Backend error (HTTP ${response.statusCode}), trying direct OneSignal REST API...');
      }
    } catch (e) {
      debugPrint('[Notification] Backend unreachable ($e), falling back to direct OneSignal REST API...');
    }

    // Direct fallback if backend call failed or was unreachable
    if (!pushDelivered) {
      pushDelivered = await _dispatchDirectOneSignalPush(
        recipientId: recipientId,
        title: title,
        body: body,
        type: type,
        tokens: tokens,
        data: data,
      );

      _addLog({
        'timestamp': DateTime.now().toIso8601String().substring(11, 19),
        'type': type,
        'recipientId': recipientId,
        'tokensCount': tokens.length,
        'via': 'direct_api',
        'success': pushDelivered,
      });
    }
  }

  /// Direct fallback to OneSignal REST API (api.onesignal.com/notifications)
  Future<bool> _dispatchDirectOneSignalPush({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    required List<String> tokens,
    Map<String, dynamic>? data,
  }) async {
    final Map<String, String> stringifiedData = {};
    if (data != null) {
      data.forEach((key, val) {
        stringifiedData[key] = val.toString();
      });
    }
    stringifiedData['type'] = type;

    // Determine if this is a critical trip notification
    const criticalTypes = {
      'new_trip', 'new_ride', 'delivery_request',
      'accept_trip', 'ride_accepted', 'delivery_accepted',
      'driver_arrived', 'captain_arrived', 'trip_started',
      'new_offer', 'driver_offer', 'counter_offer',
    };
    final isCritical = criticalTypes.contains(type.trim().toLowerCase());

    // Build the OneSignal payload — always include external_id targeting
    // (works even without subscription_ids if user is logged in via OneSignal.login)
    final payload = <String, dynamic>{
      'app_id': OneSignalConfig.appId,
      'target_channel': 'push',
      'headings': {'en': title, 'ar': title},
      'contents': {'en': body, 'ar': body},
      'data': stringifiedData,
      'android_channel_id': 'high_importance_channel',
      'android_accent_color': 'FF1976D2',
      'priority': 10,
      'ttl': 86400,
      'small_icon': 'ic_launcher',
      // Banner-style notification enhancements
      'android_group': 'inride_${type.contains('chat') || type.contains('message') ? 'messages' : 'trips'}',
      'android_group_message': {'en': '\$[notif_count] new notifications', 'ar': '\$[notif_count] إشعارات جديدة'},
      // iOS interruption level for critical notifications
      if (isCritical) 'ios_interruption_level': 'time_sensitive',
    };

    // Always target by external_id (set via OneSignal.login(userId) on device)
    if (recipientId.isNotEmpty) {
      payload['include_aliases'] = {
        'external_id': [recipientId]
      };
    }
    // Also include subscription_ids if available (belt-and-suspenders approach)
    if (tokens.isNotEmpty) {
      payload['include_subscription_ids'] = tokens;
    }

    // IMPORTANT FIX: always include REST API key if set.
    // Old code had: !restApiKey.startsWith('os_v2_app_999') — this was WRONG
    // because it also blocked real keys that might start with that prefix pattern,
    // and the fallback value 'os_v2_app_999...' still needs to be sent as-is
    // (OneSignal returns 401 without any auth, better to try and log the error).
    final String restKey = OneSignalConfig.restApiKey;
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Key $restKey',
    };

    debugPrint('[Notification] Dispatching direct OneSignal push: type=$type, recipientId=$recipientId, tokens=${tokens.length}, hasRealKey=${!restKey.contains('999999')}');

    try {
      final res = await http.post(
        Uri.parse(OneSignalConfig.directOneSignalApiUrl),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      final responseBody = res.body;
      debugPrint('[Notification] Direct OneSignal API response: status=${res.statusCode}, body=$responseBody');
      lastPushSent = payload;

      if (res.statusCode == 401) {
        lastError = 'OneSignal Auth Error (401): REST API Key غير صحيح أو غير مضبوط. تأكد من ONESIGNAL_REST_API_KEY في بيئة التشغيل.';
        debugPrint('[Notification] ⚠️ $lastError');
        return false;
      } else if (res.statusCode == 400) {
        lastError = 'OneSignal Bad Request (400): $responseBody — تحقق من App ID والـ recipient target.';
        debugPrint('[Notification] ⚠️ $lastError');
        return false;
      } else if (res.statusCode != 200 && res.statusCode != 201) {
        lastError = 'HTTP ${res.statusCode}: $responseBody';
        debugPrint('[Notification] ⚠️ OneSignal push failed: $lastError');
        return false;
      }

      lastError = null;
      debugPrint('[Notification] ✅ Direct OneSignal push sent successfully: type=$type → $recipientId');
      return true;
    } catch (e) {
      debugPrint('[Notification] Direct OneSignal API exception: $e');
      lastError = e.toString();
      return false;
    }
  }
}
