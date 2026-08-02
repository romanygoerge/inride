import 'package:flutter/foundation.dart';

@immutable
class RatingModel {
  final String id;
  final String? requestId;
  final String senderId;
  final String receiverId;
  final String receiverRole; // 'driver' or 'rider'
  final double rating; // 1.0 to 5.0
  final String? comment;
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    this.requestId,
    required this.senderId,
    required this.receiverId,
    required this.receiverRole,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString(),
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      receiverRole: json['receiver_role']?.toString() ?? 'rider',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'receiver_role': receiverRole,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get hasComment => comment != null && comment!.trim().isNotEmpty && comment != 'بدون تعليق';
}
