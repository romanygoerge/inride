import 'dart:convert';
import '../state/global_state.dart' show UserRole;

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data = const {},
  });

  /// Check whether this notification is relevant to the active user role (Rider vs Driver).
  bool matchesRole(UserRole role) {
    // 1. Check explicit target_role in payload data
    final targetRole = (data['target_role'] ?? data['role'] ?? data['user_type'])?.toString().toLowerCase();
    if (targetRole != null && targetRole.isNotEmpty) {
      if (role == UserRole.driver && targetRole == 'rider') return false;
      if (role == UserRole.rider && targetRole == 'driver') return false;
    }

    final t = type.trim().toLowerCase();

    // Notification types intended exclusively for Drivers
    const driverOnlyTypes = {
      'new_ride',
      'new_trip',
      'delivery_request',
      'counter_offer',
      'driver_online',
      'driver_offline',
      'reject_offer',
      'driver_approved',
      'driver_rejected',
    };

    // Notification types intended exclusively for Riders
    const riderOnlyTypes = {
      'new_ride_created',
      'new_offer',
      'driver_offer',
      'driver_bidding',
      'accept_trip',
      'ride_accepted',
      'delivery_accepted',
      'driver_arrived',
      'captain_arrived',
      'trip_started',
      'trip_finished',
      'trip_completed',
      'ride_expired',
    };

    if (role == UserRole.driver) {
      if (riderOnlyTypes.contains(t)) return false;
    } else if (role == UserRole.rider) {
      if (driverOnlyTypes.contains(t)) return false;
    }

    return true;
  }

  /// Returns true if this notification represents a chat or support message
  bool get isMessageNotification {
    final t = type.trim().toLowerCase();
    return t == 'chat_message' ||
        t == 'new_message' ||
        t == 'chat' ||
        t == 'support_chat' ||
        t == 'support_message' ||
        t == 'ticket' ||
        t.contains('chat') ||
        t.contains('message');
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final createdStr = map['created_at'] ?? map['createdAt'];
    DateTime dateObj;
    if (createdStr is String) {
      dateObj = DateTime.tryParse(createdStr) ?? DateTime.now();
    } else if (createdStr is DateTime) {
      dateObj = createdStr;
    } else {
      dateObj = DateTime.now();
    }

    Map<String, dynamic> payloadData = {};
    if (map['data'] is Map) {
      payloadData = Map<String, dynamic>.from(map['data'] as Map);
    } else if (map['data'] is String && (map['data'] as String).trim().startsWith('{')) {
      try {
        payloadData = Map<String, dynamic>.from(jsonDecode(map['data'] as String) as Map);
      } catch (_) {}
    }

    final String type = (map['type'] ?? payloadData['type'] ?? 'admin_notifications').toString();
    payloadData['type'] ??= type;
    if (map['title'] != null) payloadData['title'] ??= map['title'];
    if (map['body'] != null) payloadData['body'] ??= map['body'];
    if (map['trip_id'] != null) payloadData['trip_id'] ??= map['trip_id'];
    if (map['tripId'] != null) payloadData['tripId'] ??= map['tripId'];
    if (map['request_id'] != null) payloadData['request_id'] ??= map['request_id'];
    if (map['requestId'] != null) payloadData['requestId'] ??= map['requestId'];
    if (map['partner_id'] != null) payloadData['partner_id'] ??= map['partner_id'];
    if (map['partnerId'] != null) payloadData['partnerId'] ??= map['partnerId'];
    if (map['partner_name'] != null) payloadData['partner_name'] ??= map['partner_name'];
    if (map['partnerName'] != null) payloadData['partnerName'] ??= map['partnerName'];
    if (map['sender_id'] != null) payloadData['sender_id'] ??= map['sender_id'];
    if (map['senderId'] != null) payloadData['senderId'] ??= map['senderId'];
    if (map['url'] != null) payloadData['url'] ??= map['url'];
    if (map['link'] != null) payloadData['link'] ??= map['link'];
    if (map['target_role'] != null) payloadData['target_role'] ??= map['target_role'];
    if (map['role'] != null) payloadData['role'] ??= map['role'];

    return NotificationModel(
      id: docId ?? map['id']?.toString() ?? '',
      title: (map['title'] ?? payloadData['title'] ?? '').toString(),
      body: (map['body'] ?? payloadData['body'] ?? '').toString(),
      type: type,
      createdAt: dateObj,
      isRead: map['is_read'] == true || map['isRead'] == true,
      data: payloadData,
    );
  }

  factory NotificationModel.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return NotificationModel.fromMap(doc);
    }
    return NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toMap() {
    return toDatabaseMap();
  }

  /// Returns ONLY valid PostgreSQL column names for Supabase `notifications` table
  Map<String, dynamic> toDatabaseMap() {
    final map = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'data': data,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
