import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../state/global_state.dart';

class NotificationRepository {
  static final NotificationRepository instance = NotificationRepository._internal();
  factory NotificationRepository() => instance;
  NotificationRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream of all notifications for a specific user sorted by date descending
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) {
      final sortedList = List<Map<String, dynamic>>.from(list);
      sortedList.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      return sortedList.map((map) => NotificationModel.fromMap(map)).toList();
    });
  }

  // Stream of unread notification count
  Stream<int> getUnreadCountStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) => list.where((n) => n['is_read'] == false).length);
  }

  // Mark a specific notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId);
  }

  // Delete a specific notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('user_id', userId);
  }

  // Save a new notification to the user's notifications collection
  Future<void> saveNotification(String userId, NotificationModel notification) async {
    final map = notification.toMap();
    map['user_id'] = userId;
    if (map['id'] == null || (map['id'] as String).isEmpty) {
      map.remove('id');
    }
    await _supabase.from('notifications').upsert(map);
  }

  // Save/Update FCM / Push Token across user_devices and Legacy Tables
  Future<void> saveFCMToken(String userId, String token) async {
    if (token.isEmpty) return;
    try {
      if (token == 'default_token') {
        final existing = await _supabase.from('users').select('fcm_token').eq('id', userId).maybeSingle();
        final currentToken = existing?['fcm_token'] as String?;
        if (currentToken != null && currentToken.isNotEmpty && currentToken != 'default_token') {
          debugPrint("[NotificationRepository] Preserving existing token for user $userId ($currentToken)");
          return;
        }
      }

      // Upsert into user_devices table
      try {
        await _supabase.from('user_devices').upsert({
          'user_id': userId,
          'device_token': token,
          'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, device_token');
        debugPrint("[NotificationRepository] Upserted active device token in user_devices table for $userId");
      } catch (e) {
        debugPrint("[NotificationRepository] Warning upserting user_devices: $e");
      }

      // Update legacy columns
      try {
        await _supabase.from('users').update({'fcm_token': token}).eq('id', userId);
      } catch (_) {}
      try {
        await _supabase.from('drivers').update({'fcm_token': token}).eq('id', userId);
      } catch (_) {}
    } catch (e) {
      debugPrint("[NotificationRepository] Error saving push token: $e");
    }
  }

  // Clear/Deactivate Push Token in user_devices table
  Future<void> clearFCMToken(String userId) async {
    try {
      try {
        await _supabase
            .from('user_devices')
            .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
            .eq('user_id', userId);
      } catch (_) {}
      try {
        await _supabase.from('users').update({'fcm_token': ''}).eq('id', userId);
      } catch (_) {}
      try {
        await _supabase.from('drivers').update({'fcm_token': ''}).eq('id', userId);
      } catch (_) {}
      debugPrint("[NotificationRepository] Deactivated device tokens for user $userId");
    } catch (e) {
      debugPrint("[NotificationRepository] Error deactivating tokens: $e");
    }
  }

  // Retrieve active device tokens for a specific user ID
  Future<List<String>> getActiveDeviceTokens(String userId) async {
    try {
      final res = await _supabase
          .from('user_devices')
          .select('device_token')
          .eq('user_id', userId)
          .eq('is_active', true);
      
      final tokens = (res as List)
          .map((row) => row['device_token'] as String?)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isNotEmpty) return tokens;

      // Fallback query users/drivers tables
      final userRes = await _supabase.from('users').select('fcm_token').eq('id', userId).maybeSingle();
      if (userRes != null && userRes['fcm_token'] != null && (userRes['fcm_token'] as String).length > 10) {
        return [(userRes['fcm_token'] as String)];
      }

      final driverRes = await _supabase.from('drivers').select('fcm_token').eq('id', userId).maybeSingle();
      if (driverRes != null && driverRes['fcm_token'] != null && (driverRes['fcm_token'] as String).length > 10) {
        return [(driverRes['fcm_token'] as String)];
      }
    } catch (e) {
      debugPrint("[NotificationRepository] Error getting active device tokens: $e");
    }
    return [];
  }

  // Sync recent admin notifications to user's notifications list
  Future<void> syncAdminNotifications(String userId, UserRole role, String? city) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      
      final queryRes = await _supabase
          .from('admin_notifications')
          .select()
          .gte('created_at', thirtyDaysAgo);

      if ((queryRes as List).isEmpty) return;

      for (var row in (queryRes as List)) {
        final data = Map<String, dynamic>.from(row);
        final notifId = data['id'];
        
        final scheduledAtStr = data['scheduled_at'];
        if (scheduledAtStr != null) {
          final scheduledAt = DateTime.tryParse(scheduledAtStr);
          if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
            continue;
          }
        }

        final target = data['target'] as String?;
        final targetCity = data['target_city'] as String?;
        
        bool isTarget = false;
        if (target == 'all') {
          isTarget = true;
        } else if (target == 'drivers' && role == UserRole.driver) {
          isTarget = true;
        } else if (target == 'riders' && role == UserRole.rider) {
          isTarget = true;
        } else if (target == 'city' && city != null && targetCity != null && city.toLowerCase().contains(targetCity.toLowerCase())) {
          isTarget = true;
        }

        if (!isTarget) continue;

        // Check if user already received/processed this admin notification
        final receiptCheck = await _supabase
            .from('admin_notification_receipts')
            .select()
            .eq('notification_id', notifId)
            .eq('user_id', userId)
            .maybeSingle();

        if (receiptCheck != null) {
          // Already delivered to this user in the past
          continue;
        }

        final userNotifId = 'admin_${notifId}_$userId';

        final checkRes = await _supabase
            .from('notifications')
            .select()
            .eq('id', userNotifId)
            .eq('user_id', userId)
            .maybeSingle();

        if (checkRes == null) {
          await _supabase.from('notifications').upsert({
            'id': userNotifId,
            'user_id': userId,
            'title': data['title'] ?? '',
            'body': data['body'] ?? '',
            'type': data['type'] ?? 'admin_notifications',
            'is_read': false,
            'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
            'data': {
              'id': notifId,
              'adminNotificationId': notifId,
              'type': data['type'] ?? 'admin_notifications',
              'recipientId': userId
            }
          });

          await _supabase.from('admin_notification_receipts').upsert({
            'notification_id': notifId,
            'user_id': userId,
            'device': 'flutter_client_sync'
          });
        }
      }
    } catch (e) {
      debugPrint("Error syncing admin notifications: $e");
    }
  }
}
