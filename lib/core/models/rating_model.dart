import 'package:flutter/foundation.dart';

@immutable
class RatingModel {
  final String id;
  final String tripId;
  final String fromUserId;
  final String toUserId;
  final String? senderName;
  final String? receiverName;
  final String role; // 'driver' or 'passenger' / 'rider'
  final int rating; // 1 to 5
  final String? review;
  final bool isHidden;
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
    this.senderName,
    this.receiverName,
    required this.role,
    required this.rating,
    this.review,
    this.isHidden = false,
    required this.createdAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id']?.toString() ?? '',
      tripId: json['trip_id']?.toString() ?? '',
      fromUserId: json['from_user_id']?.toString() ?? '',
      toUserId: json['to_user_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString(),
      receiverName: json['receiver_name']?.toString(),
      role: json['role']?.toString() ?? 'rider',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      review: json['review']?.toString(),
      isHidden: json['is_hidden'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'sender_name': senderName,
      'receiver_name': receiverName,
      'role': role,
      'rating': rating,
      'review': review,
      'is_hidden': isHidden,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get hasReview => review != null && review!.trim().isNotEmpty;
}
