import '../../domain/entities/chat_room.dart';

class ChatRoomModel extends ChatRoom {
  const ChatRoomModel({
    required super.id,
    required super.type,
    super.tripId,
    super.passengerId,
    super.driverId,
    super.passengerName,
    super.driverName,
    super.passengerAvatar,
    super.driverAvatar,
    required super.status,
    super.isPinned = false,
    super.lastMessage = '',
    required super.createdAt,
    required super.updatedAt,
    super.unreadCount = 0,
    super.tripPickupAddress,
    super.tripDestinationAddress,
    super.tripStatus,
    super.tripPrice,
    super.tripCreatedAt,
    super.tripCompletedAt,
  });

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    // Relationships are fetched via joins: passenger(*), driver(*), trip(*)
    final passengerMap = map['passenger'] as Map<String, dynamic>?;
    final driverMap = map['driver'] as Map<String, dynamic>?;
    final tripMap = map['trip'] as Map<String, dynamic>?;

    return ChatRoomModel(
      id: map['id'] ?? '',
      type: map['type'] ?? 'trip',
      tripId: map['trip_id'],
      passengerId: map['passenger_id'],
      driverId: map['driver_id'],
      passengerName: passengerMap?['name'] ?? 'مستخدم inRide',
      driverName: driverMap?['name'] ?? 'كابتن inRide',
      passengerAvatar: passengerMap?['avatar_url'],
      driverAvatar: driverMap?['avatar_url'],
      status: map['status'] ?? 'active',
      isPinned: map['is_pinned'] ?? false,
      lastMessage: map['last_message'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      tripPickupAddress: tripMap?['pickup_address'] ?? '',
      tripDestinationAddress: tripMap?['destination_address'] ?? '',
      tripStatus: tripMap?['status'] ?? '',
      tripPrice: tripMap?['offered_fare'] != null ? (tripMap!['offered_fare'] as num).toDouble() : null,
      tripCreatedAt: tripMap?['created_at'] != null ? DateTime.tryParse(tripMap!['created_at']) : null,
      tripCompletedAt: tripMap?['updated_at'] != null ? DateTime.tryParse(tripMap!['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'trip_id': tripId,
      'passenger_id': passengerId,
      'driver_id': driverId,
      'status': status,
      'is_pinned': isPinned,
      'last_message': lastMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
