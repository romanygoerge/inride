class ChatRoom {
  final String id;
  final String type; // 'trip' or 'support'
  final String? tripId;
  final String? passengerId;
  final String? driverId;
  final String? passengerName;
  final String? driverName;
  final String? passengerAvatar;
  final String? driverAvatar;
  final String status; // 'active', 'closed', 'archived'
  final bool isPinned;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;

  // Embedded Trip Details (Requirement 4)
  final String? tripPickupAddress;
  final String? tripDestinationAddress;
  final String? tripStatus;
  final double? tripPrice;
  final DateTime? tripCreatedAt;
  final DateTime? tripCompletedAt;

  const ChatRoom({
    required this.id,
    required this.type,
    this.tripId,
    this.passengerId,
    this.driverId,
    this.passengerName,
    this.driverName,
    this.passengerAvatar,
    this.driverAvatar,
    required this.status,
    this.isPinned = false,
    this.lastMessage = '',
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.tripPickupAddress,
    this.tripDestinationAddress,
    this.tripStatus,
    this.tripPrice,
    this.tripCreatedAt,
    this.tripCompletedAt,
  });

  String getRoomTitle(String currentUserId) {
    if (type == 'support') {
      return 'الدعم الفني';
    }
    if (currentUserId == passengerId) {
      return driverName ?? 'الكابتن';
    }
    return passengerName ?? 'الراكب';
  }

  String getRoomAvatar(String currentUserId) {
    if (type == 'support') {
      return 'S';
    }
    if (currentUserId == passengerId) {
      return driverAvatar ?? '';
    }
    return passengerAvatar ?? '';
  }
}
