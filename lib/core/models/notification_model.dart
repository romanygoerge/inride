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

    return NotificationModel(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'admin_notifications',
      createdAt: dateObj,
      isRead: map['is_read'] ?? map['isRead'] ?? false,
      data: map['data'] as Map<String, dynamic>? ?? {},
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
