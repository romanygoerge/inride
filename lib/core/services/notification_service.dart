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
import '../../features/driver/presentation/pages/driver_ride_active_page.dart';
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
    final String type = (data['type'] ?? data['notification_type'] ?? '').toString().trim().toLowerCase();
    final String title = (data['title'] ?? '').toString().toLowerCase();
    final String body = (data['body'] ?? '').toString().toLowerCase();
    final String targetRoleStr = (data['target_role'] ?? data['role'] ?? data['user_type'] ?? '').toString().toLowerCase();

    debugPrint('[NotificationService] Handling tap type: $type, targetRole: $targetRoleStr, title: $title, body: $body, data: $data');

    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('[NotificationService] Context not available');
      return;
    }

    // Automatic role switching for dual-role users when tapping notification
    if (targetRoleStr.isNotEmpty) {
      if (targetRoleStr == 'driver' && GlobalState.instance.currentRole != UserRole.driver) {
        debugPrint('[NotificationService] Switching mode to driver for notification');
        await GlobalState.instance.selectRole(UserRole.driver);
      } else if (targetRoleStr == 'rider' && GlobalState.instance.currentRole != UserRole.rider) {
        debugPrint('[NotificationService] Switching mode to rider for notification');
        await GlobalState.instance.selectRole(UserRole.rider);
      }
    }

    if (!context.mounted) return;

    // 1. الدعم الفني ومحادثات الإدارة (Support Chat / Admin Messages)
    final bool isSupportOrAdminChat = type == 'support_chat' ||
        type == 'support' ||
        type == 'admin_chat' ||
        type == 'communication' ||
        type == 'support_message' ||
        type == 'ticket' ||
        data['sender_id'] == 'admin' ||
        data['senderId'] == 'admin' ||
        title.contains('الدعم') ||
        title.contains('support') ||
        title.contains('خدمة العملاء');

    if (isSupportOrAdminChat) {
      Navigator.push(
        context,
        SnappyPageRoute(page: const SupportChatPage()),
      );
      return;
    }

    // 2. رسالة دردشة بين الركاب والسائقين (Direct Passenger/Driver Chat)
    final bool isDirectUserChat = type == 'new_message' ||
        type == 'chat_message' ||
        type == 'chat' ||
        title.contains('رسالة جديدة') ||
        title.contains('new message') ||
        title.contains('محادثة');

    if (isDirectUserChat) {
      final tripId = data['tripId'] ?? data['trip_id'] ?? data['requestId'] ?? data['request_id'] ?? GlobalState.instance.currentRequestId;
      String partnerId = (data['partnerId'] ?? data['partner_id'] ?? data['senderId'] ?? data['sender_id'] ?? '').toString();
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
      } else {
        // Fallback: If it's a message without active trip context, open support chat
        Navigator.push(
          context,
          SnappyPageRoute(page: const SupportChatPage()),
        );
        return;
      }
    }

    // 3. المحفظة والعمليات المالية والشحن (Wallet & Top-up)
    final bool isWalletOrPayment = type == 'wallet' ||
        type == 'charge' ||
        type == 'charge_pending' ||
        type == 'charge_approved' ||
        type == 'charge_rejected' ||
        type == 'payout' ||
        type == 'payment' ||
        type == 'deposit' ||
        type == 'wallet_recharge' ||
        type == 'wallet_receipt' ||
        type == 'wallet_approved' ||
        type == 'wallet_rejected' ||
        type == 'refund' ||
        title.contains('محفظ') ||
        title.contains('شحن') ||
        title.contains('رصيد') ||
        title.contains('wallet') ||
        title.contains('payment') ||
        title.contains('instapay');

    if (isWalletOrPayment) {
      Navigator.push(
        context,
        SnappyPageRoute(page: const WalletPage()),
      );
      return;
    }

    // 4. رحلة حالية قيد التنفيذ (Active Ride)
    final bool isRideActive = type == 'accept_trip' ||
        type == 'ride_accepted' ||
        type == 'delivery_accepted' ||
        type == 'driver_arrived' ||
        type == 'captain_arrived' ||
        type == 'trip_started' ||
        title.contains('وصل الكابتن') ||
        title.contains('بدأت الرحلة') ||
        title.contains('تم قبول طلبك') ||
        title.contains('قبول الرحلة');

    if (isRideActive) {
      if (GlobalState.instance.currentRole == UserRole.rider) {
        Navigator.push(
          context,
          SnappyPageRoute(page: const PassengerRideActivePage()),
        );
      } else {
        final reqId = data['requestId']?.toString() ?? data['request_id']?.toString() ?? data['tripId']?.toString() ?? data['trip_id']?.toString();
        if (reqId != null && reqId.isNotEmpty) {
          GlobalState.instance.currentRequestId = reqId;
        }
        Navigator.push(
          context,
          SnappyPageRoute(page: const DriverRideActivePage()),
        );
      }
      return;
    }

    // 5. طلب رحلة / عرض جديد (New Trip / Request / Offer)
    final bool isNewTripOrOffer = type == 'new_trip' ||
        type == 'new_ride' ||
        type == 'delivery_request' ||
        type == 'new_offer' ||
        type == 'driver_offer' ||
        type == 'counter_offer' ||
        title.contains('طلب رحلة') ||
        title.contains('عرض جديد') ||
        title.contains('مشوار جديد');

    if (isNewTripOrOffer) {
      if (GlobalState.instance.currentRole == UserRole.driver) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DriverHomePage()),
          (route) => false,
        );
      } else {
        if (GlobalState.instance.currentRequestId != null) {
          Navigator.push(
            context,
            SnappyPageRoute(page: const PassengerRideActivePage()),
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
      return;
    }

    // 6. توثيق واعتماد الكابتن (Driver Approved / Verified)
    if (type == 'driver_approved' || type == 'driver_verified' || title.contains('تم اعتماد') || title.contains('قبول حساب الكابتن')) {
      await GlobalState.instance.selectRole(UserRole.driver);
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomePage()),
        (route) => false,
      );
      return;
    }

    // 7. رفض طلب الكابتن أو تغيير حالة الحساب (Rejected / Status Update)
    if (type == 'driver_rejected' || type == 'account_status' || title.contains('رفض') || title.contains('حسابك')) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // 8. روابط خارجية أو عروض (External Links / URL)
    final urlStr = data['url'] ?? data['link'];
    if (urlStr != null && urlStr.toString().isNotEmpty) {
      final url = Uri.parse(urlStr.toString());
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return;
      }
    }

    if (!context.mounted) return;

    // 9. إذا وجد معرف رحلة في البيانات -> فتح شاشة الرحلة
    if (data['tripId'] != null || data['trip_id'] != null || data['requestId'] != null || data['request_id'] != null) {
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

    // 3. Dispatch Push Notification via Secure Backend Push Server (fcm_backend / Vercel API)
    try {
      final backendUrl = Uri.parse(OneSignalConfig.backendPushUrl);
      final secretKey = OneSignalConfig.backendSecretKey;
      
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        if (secretKey.isNotEmpty) 'Authorization': 'Bearer $secretKey',
      };

      final payload = {
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'tokens': tokens,
      };

      final response = await http.post(
        backendUrl,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[Notification] ✅ Push notification delivered successfully via secure backend server');
        lastError = null;
        lastPushSent = payload;
        _addLog({
          'timestamp': DateTime.now().toIso8601String().substring(11, 19),
          'type': type,
          'recipientId': recipientId,
          'tokensCount': tokens.length,
          'via': 'backend',
          'success': true,
        });
      } else {
        lastError = 'Backend error (HTTP ${response.statusCode}): ${response.body}';
        debugPrint('[Notification] ⚠️ $lastError');
        _addLog({
          'timestamp': DateTime.now().toIso8601String().substring(11, 19),
          'type': type,
          'recipientId': recipientId,
          'tokensCount': tokens.length,
          'via': 'backend',
          'success': false,
        });
      }
    } catch (e) {
      lastError = 'Backend unreachable ($e)';
      debugPrint('[Notification] ⚠️ Push notification delivery exception: $e');
      _addLog({
        'timestamp': DateTime.now().toIso8601String().substring(11, 19),
        'type': type,
        'recipientId': recipientId,
        'tokensCount': tokens.length,
        'via': 'backend',
        'success': false,
      });
    }
  }
}
