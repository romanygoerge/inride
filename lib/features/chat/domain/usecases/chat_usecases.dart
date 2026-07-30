import '../entities/chat_room.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class GetChatRooms {
  final ChatRepository repository;
  GetChatRooms(this.repository);

  Stream<List<ChatRoom>> call(String userId) {
    return repository.getChatRoomsStream(userId);
  }
}

class GetMessagesStream {
  final ChatRepository repository;
  GetMessagesStream(this.repository);

  Stream<List<ChatMessage>> call(String roomId) {
    return repository.getMessagesStream(roomId);
  }
}

class GetOrCreateSupportRoom {
  final ChatRepository repository;
  GetOrCreateSupportRoom(this.repository);

  Future<String> call(String userId) {
    return repository.getOrCreateSupportRoom(userId);
  }
}

class SendChatMessage {
  final ChatRepository repository;
  SendChatMessage(this.repository);

  Future<void> call({
    required String roomId,
    required String senderId,
    required String text,
    String? replyToMessageId,
  }) {
    return repository.sendMessage(
      roomId: roomId,
      senderId: senderId,
      text: text,
      replyToMessageId: replyToMessageId,
    );
  }
}

class SendChatAttachment {
  final ChatRepository repository;
  SendChatAttachment(this.repository);

  Future<void> call({
    required String roomId,
    required String senderId,
    required String text,
    required String filePath,
    required String fileName,
    String? replyToMessageId,
  }) {
    return repository.sendAttachment(
      roomId: roomId,
      senderId: senderId,
      text: text,
      filePath: filePath,
      fileName: fileName,
      replyToMessageId: replyToMessageId,
    );
  }
}

class MarkMessagesAsRead {
  final ChatRepository repository;
  MarkMessagesAsRead(this.repository);

  Future<void> call(String roomId, String userId) {
    return repository.markMessagesAsRead(roomId, userId);
  }
}

class UpdateTypingStatus {
  final ChatRepository repository;
  UpdateTypingStatus(this.repository);

  Future<void> call(String roomId, String userId, bool isTyping) {
    return repository.updateTypingStatus(roomId, userId, isTyping);
  }
}

class GetTypingIndicator {
  final ChatRepository repository;
  GetTypingIndicator(this.repository);

  Stream<bool> call(String roomId, String partnerId) {
    return repository.getTypingIndicatorStream(roomId, partnerId);
  }
}

class DeleteChatMessage {
  final ChatRepository repository;
  DeleteChatMessage(this.repository);

  Future<void> call(String messageId) {
    return repository.deleteMessage(messageId);
  }
}
