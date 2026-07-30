import '../../domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.roomId,
    required super.senderId,
    required super.text,
    super.replyToMessageId,
    super.replyToText,
    super.isDeleted = false,
    required super.createdAt,
    required super.updatedAt,
    super.isRead = false,
    super.attachmentUrl,
    super.attachmentName,
    super.attachmentType,
    super.isSending = false,
    super.isError = false,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    // Reply information is fetched via self-join
    final replyMap = map['reply_to'] as Map<String, dynamic>?;

    // Attachments are fetched via join
    final attachmentsList = map['attachments'] as List<dynamic>?;
    final attachmentMap = attachmentsList != null && attachmentsList.isNotEmpty
        ? attachmentsList.first as Map<String, dynamic>?
        : null;

    // Reads list can be checked to verify if the partner read this message
    final readsList = map['message_reads'] as List<dynamic>?;
    final bool readState = readsList != null && readsList.isNotEmpty;

    return ChatMessageModel(
      id: map['id'] ?? '',
      roomId: map['room_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      text: map['text'] ?? '',
      replyToMessageId: map['reply_to_message_id'],
      replyToText: replyMap?['text'],
      isDeleted: map['is_deleted'] ?? false,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      isRead: readState,
      attachmentUrl: attachmentMap?['file_path'],
      attachmentName: attachmentMap?['file_name'],
      attachmentType: attachmentMap?['mime_type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'text': text,
      'reply_to_message_id': replyToMessageId,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
