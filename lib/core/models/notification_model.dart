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
