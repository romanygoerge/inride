import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../state/global_state.dart';
import '../../main.dart' show navigatorKey;
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/passenger/presentation/pages/passenger_ride_active_page.dart';
import '../../features/passenger/presentation/pages/passenger_ride_matching_page.dart';
import '../../features/driver/presentation/pages/driver_home_page.dart';
import '../../features/driver/presentation/pages/driver_ride_active_page.dart';
import '../../features/driver/presentation/widgets/driver_incoming_ride_modal.dart';
import '../models/ride_request_model.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/snappy_page_route.dart';
import '../../features/common/support_chat_page.dart';
import '../../features/common/notification_details_page.dart';
import '../../features/common/wallet_page.dart';
import '../../shared/widgets/trip_status_sheet.dart';
import '../config/onesignal_config.dart';
import '../utils/vehicle_helper.dart';

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

    // 1. الإشعارات والرسائل والتعميمات الإدارية -> تفتح صفحة تفاصيل الإشعار الأصلية
    final bool isAdminNotification = type == 'admin_notifications' ||
        type == 'admin_announcement' ||
        type == 'system_broadcast' ||
        type == 'offers' ||
        type == 'app_updates' ||
        type == 'broadcast' ||
        type == 'general' ||
        data['adminNotificationId'] != null ||
        data['admin_notification_id'] != null;

    if (isAdminNotification) {
      final notifModel = NotificationModel.fromMap(data);
      Navigator.push(
        context,
        SnappyPageRoute(page: NotificationDetailsPage(notification: notifModel)),
      );
      return;
    }

    // 2. محادثة الدعم الفني المباشرة فقط عند وجود تذكرة أو محادثة دعم حقيقية
    final bool isRealSupportChat = (type == 'support_chat' || type == 'support_message' || type == 'ticket') &&
        (data['conversation_id'] != null || data['message_id'] != null || data['ticket_id'] != null);

    if (isRealSupportChat) {
      Navigator.push(
        context,
        SnappyPageRoute(page: const SupportChatPage()),
      );
      return;
    }

    // 3. رسالة دردشة بين الركاب والسائقين (Direct Passenger/Driver Chat)
    final bool isDirectUserChat = type == 'new_message' ||
        type == 'chat_message' ||
        type == 'chat' ||
        title.contains('رسالة جديدة') ||
        title.contains('new message');

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
        // Fallback: If it's a message without active trip context, show the notification details
        final notifModel = NotificationModel.fromMap(data);
        Navigator.push(
          context,
          SnappyPageRoute(page: NotificationDetailsPage(notification: notifModel)),
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

    // 4. فحص الإشعارات المرتبطة برحلة أو طلب معين (Trip & Ride Events Handler)
    final String reqId = (data['requestId'] ??
            data['request_id'] ??
            data['tripId'] ??
            data['trip_id'] ??
            '')
        .toString()
        .trim();

    final bool isNewTripOrOffer = type == 'new_trip' ||
        type == 'new_ride' ||
        type == 'delivery_request' ||
        type == 'new_offer' ||
        type == 'driver_offer' ||
        type == 'counter_offer' ||
        title.contains('طلب رحلة') ||
        title.contains('مشوار جديد') ||
        title.contains('عرض جديد') ||
        title.contains('رحلة جديدة') ||
        title.contains('توصيل') ||
        title.contains('طرد') ||
        title.contains('ديلفري');

    final bool isRideEvent = isNewTripOrOffer ||
        type == 'accept_trip' ||
        type == 'ride_accepted' ||
        type == 'delivery_accepted' ||
        type == 'driver_arrived' ||
        type == 'captain_arrived' ||
        type == 'trip_started' ||
        type == 'trip_finished' ||
        type == 'cancel_trip' ||
        type == 'ride_expired' ||
        type == 'offer_rejected' ||
        type == 'reject_offer' ||
        type.contains('trip') ||
        type.contains('ride') ||
        title.contains('وصل الكابتن') ||
        title.contains('بدأت الرحلة') ||
        title.contains('تم قبول طلبك') ||
        title.contains('قبول الرحلة') ||
        title.contains('اكتملت') ||
        title.contains('إلغاء') ||
        reqId.isNotEmpty;

    if (isRideEvent) {
      final tripIdToQuery = reqId.isNotEmpty ? reqId : (GlobalState.instance.currentRequestId ?? '');

      if (tripIdToQuery.isNotEmpty) {
        Map<String, dynamic>? tripDoc;
        try {
          final res = await Supabase.instance.client
              .from('ride_requests')
              .select()
              .eq('id', tripIdToQuery)
              .maybeSingle();
          if (res != null) {
            tripDoc = Map<String, dynamic>.from(res);
          }
        } catch (e) {
          debugPrint('[NotificationService] Error querying ride_requests for $tripIdToQuery: $e');
        }

        if (!context.mounted) return;

        if (tripDoc != null) {
          final String status = (tripDoc['status'] ?? '').toString().trim().toLowerCase();
          final String? assignedDriverId = tripDoc['driver_id']?.toString();
          final String? myUid = GlobalState.instance.userUid;

          // أ. إذا كانت الرحلة مكتملة بالفعل -> إظهار نافذة الحالة المكتملة
          if (status == 'completed' || status == 'finished' || status == 'ended') {
            TripStatusSheet.show(context, requestId: tripIdToQuery, initialData: tripDoc);
            return;
          }

          // ب. إذا كانت الرحلة ملغاة -> إظهار تفاصيل الإلغاء
          if (status == 'cancelled' || status == 'canceled') {
            TripStatusSheet.show(context, requestId: tripIdToQuery, initialData: tripDoc);
            return;
          }

          // ج. إذا كانت فترة البحث منتهية -> إظهار انتهاء الطلب
          if (status == 'expired') {
            TripStatusSheet.show(context, requestId: tripIdToQuery, initialData: tripDoc);
            return;
          }

          // د. حالة الكابتن (Driver / Captain):
          if (GlobalState.instance.currentRole == UserRole.driver) {
            final isPendingRequest = status == 'pending' || status == 'searching' || status == 'open' || isNewTripOrOffer;

            if (isPendingRequest) {
              // إذا كان الطلب لا يزال معلقاً ولم يُقبل بعد:
              // لا نفتح شاشة DriverRideActivePage أبداً! بل نعرض تفاصيل الطلب للكابتن ليقرر قبوله أو التفاوض عليه
              final reqModel = RideRequestModel.fromMap(tripDoc, tripIdToQuery);

              // التحقق من تطابق نوع مركبة الكابتن مع فئة الطلب
              final isDelivery = reqModel.serviceType == 'delivery' || reqModel.vehicleType == 'delivery';
              if (!isDelivery) {
                final driverCategory = GlobalState.instance.driverVehicleCategory ?? GlobalState.instance.vehicleName ?? 'car';
                if (!VehicleHelper.isVehicleTypeMatching(driverCategory, reqModel.vehicleType, serviceType: reqModel.serviceType)) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'عفواً، هذا الطلب مخصص لمركبة أخرى (${VehicleHelper.getArabicLabel(reqModel.vehicleType)}) 🚗🏍️',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                  return;
                }
              }

              // 1. الانتقال إلى شاشة الكابتن الرئيسية والتأكد من إغلاق أي حوارات سابقة
              Navigator.of(context).popUntil((route) => route.isFirst);

              // 2. فتح نافذة عرض الطلب الاحترافية DriverIncomingRideModal
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final targetContext = navigatorKey.currentContext;
                if (targetContext != null && targetContext.mounted) {
                  DriverIncomingRideModal.show(targetContext, request: reqModel);
                }
              });
              return;
            }

            // إذا كانت الرحلة مقبولة أو جارية:
            if (status == 'accepted' || status == 'driveronway' || status == 'driverarriving' || status == 'arrived' || status == 'tripstarted' || status == 'in_progress') {
              if (assignedDriverId == myUid) {
                // الكابتن الحالي هو المقبول في الرحلة -> التوجه لشاشة الرحلة النشطة
                GlobalState.instance.currentRequestId = tripIdToQuery;
                GlobalState.instance.currentRideRequest = RideRequestModel.fromMap(tripDoc, tripIdToQuery);
                GlobalState.instance.fromAddress = tripDoc['pickup_address'] ?? tripDoc['pickupAddress'] ?? '';
                GlobalState.instance.toAddress = tripDoc['destination_address'] ?? tripDoc['destinationAddress'] ?? '';
                GlobalState.instance.offeredFare = ((tripDoc['offered_fare'] ?? tripDoc['offeredFare']) as num? ?? 0.0).toDouble();
                GlobalState.instance.activePassengerId = tripDoc['passenger_id'];
                final pPhone = (tripDoc['passenger_phone'] ?? tripDoc['recipient_phone'])?.toString();
                if (pPhone != null && pPhone.isNotEmpty) {
                  GlobalState.instance.activePassengerPhone = pPhone;
                }

                if (status == 'accepted') {
                  GlobalState.instance.rideStatus = RideStatus.driverOnWay;
                } else if (status == 'driverarriving' || status == 'driver_arrived' || status == 'arrived') {
                  GlobalState.instance.rideStatus = RideStatus.arrived;
                } else if (status == 'tripstarted' || status == 'in_progress') {
                  GlobalState.instance.rideStatus = RideStatus.tripStarted;
                }

                Navigator.push(
                  context,
                  SnappyPageRoute(page: const DriverRideActivePage()),
                );
                return;
              } else {
                // الرحلة قبلها كابتن آخر
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'عفواً، هذه الرحلة لم تعد متاحة أو تم قبولها من كابتن آخر 🚖',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.orange.shade800,
                  ),
                );
                return;
              }
            }
          }

          // هـ. حالة الراكب (Rider / Passenger):
          if (GlobalState.instance.currentRole == UserRole.rider) {
            GlobalState.instance.currentRequestId = tripIdToQuery;
            if (status == 'pending' || status == 'searching') {
              Navigator.push(
                context,
                SnappyPageRoute(page: const PassengerRideMatchingPage()),
              );
            } else {
              Navigator.push(
                context,
                SnappyPageRoute(page: const PassengerRideActivePage()),
              );
            }
            return;
          }
        } else {
          // لم توجد الرحلة في قاعدة البيانات ولكن بيانات الإشعار تشير لاكتمالها أو إلغائها
          if (type == 'trip_finished' || type == 'cancel_trip' || type == 'ride_expired' || type == 'offer_rejected') {
            TripStatusSheet.show(context, requestId: tripIdToQuery, initialData: data);
            return;
          }
        }
      } else {
        // لا يوجد معرف رحلة صريح، والحدث منتهي أو ملغى
        if (type == 'trip_finished' || title.contains('اكتملت') || title.contains('إنهاء')) {
          TripStatusSheet.show(context, initialData: data);
          return;
        }
        if (type == 'cancel_trip' || title.contains('إلغاء')) {
          TripStatusSheet.show(context, initialData: data);
          return;
        }
        if (type == 'ride_expired' || title.contains('انتهت')) {
          TripStatusSheet.show(context, initialData: data);
          return;
        }
        if (type == 'offer_rejected' || type == 'reject_offer' || title.contains('رفض')) {
          TripStatusSheet.show(context, initialData: data);
          return;
        }
      }
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

    // 9. إذا وجد معرف رحلة إضافي ولم تتم معالجته أعلاه
    if (reqId.isNotEmpty) {
      TripStatusSheet.show(context, requestId: reqId, initialData: data);
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
    // Strict isolation: block empty or invalid recipient IDs for private notifications
    final cleanRecipient = recipientId.trim();
    if (cleanRecipient.isEmpty || cleanRecipient == 'null' || cleanRecipient == 'undefined') {
      debugPrint('[Notification] ⚠️ BLOCKED: Invalid recipientId "$recipientId" for type: $type. Private notification will not be sent.');
      return;
    }

    final myId = GlobalState.instance.userUid;

    if (cleanRecipient == myId && !forceSelf) {
      debugPrint('[Notification] Skipped sending notification to self (id=$cleanRecipient, type=$type). Use forceSelf=true to override.');
      return;
    }

    // Build a unique notifId based on recipient + type + tripId/requestId
    // IMPORTANT: For chat messages, use data['id'] (messageId) so each chat message is treated uniquely and not deduped!
    // IMPORTANT: For offers and negotiations, include price so each counter-offer or new offer is delivered immediately!
    final bool isOfferOrNegotiation = type == 'counter_offer' ||
        type == 'new_offer' ||
        type == 'driver_offer';
    final String tripRef = (type == 'chat_message' || type == 'new_message' || type == 'support_chat')
        ? (data?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString())
        : isOfferOrNegotiation
            ? '${data?['requestId'] ?? data?['tripId'] ?? ''}_${data?['price'] ?? ''}_${DateTime.now().millisecondsSinceEpoch}'
            : (data?['requestId']?.toString() ??
                data?['tripId']?.toString() ??
                data?['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString());
    final String notifId = '${cleanRecipient}_${type}_$tripRef';

    // Clean up stale dedup entries (older than 5 minutes)
    _cleanupDedupCache();

    if (_sentNotificationIds.containsKey(notifId) && !forceSelf) {
      debugPrint('[Notification] Skipped duplicate notification: $notifId (sent at ${_sentNotificationIds[notifId]})');
      return;
    }
    _sentNotificationIds[notifId] = DateTime.now();

    debugPrint('[Notification] Event created: type=$type, recipientId=$cleanRecipient');

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
    await _repository.saveNotification(cleanRecipient, notification);
    debugPrint('[Notification] Recipient identified: recipientId=$cleanRecipient');

    // 2. Fetch active device tokens from user_devices table
    final tokens = await _repository.getActiveDeviceTokens(cleanRecipient);
    debugPrint('[Notification] Active device tokens found: count=${tokens.length}');

    // 3. Dispatch Push Notification via Secure Backend Push Server (fcm_backend / Vercel API)
    try {
      final backendUrl = Uri.parse(OneSignalConfig.backendPushUrl);
      final secretKey = OneSignalConfig.backendSecretKey;
      final sessionToken = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final authToken = sessionToken.isNotEmpty ? sessionToken : secretKey;
      
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

      final payload = {
        'recipientId': cleanRecipient,
        'target': 'specific', // Explicitly indicate targeted recipient (NOT broadcast)
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

    // 4. Secure logging if delivery failed
    if (lastError != null) {
      debugPrint('[Notification] ⚠️ Push notification delivery failed: $lastError');
    }
  }
}
