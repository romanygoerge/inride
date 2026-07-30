class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final String? replyToMessageId;
  final String? replyToText;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead;

  // Attachment Details
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType; // 'image', 'document', etc.

  // UI Helper States (Optimistic UI)
  final bool isSending;
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    this.replyToMessageId,
    this.replyToText,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.isSending = false,
    this.isError = false,
  });

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? text,
    String? replyToMessageId,
    String? replyToText,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRead,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    bool? isSending,
    bool? isError,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentType: attachmentType ?? this.attachmentType,
      isSending: isSending ?? this.isSending,
      isError: isError ?? this.isError,
    );
  }
}
