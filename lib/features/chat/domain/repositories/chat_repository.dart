import '../entities/chat_room.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  Stream<List<ChatRoom>> getChatRoomsStream(String userId);
  Stream<List<ChatMessage>> getMessagesStream(String roomId);
  Future<String> getOrCreateSupportRoom(String userId);
  Future<String> getRoomIdForTrip(String tripId);
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
    String? replyToMessageId,
  });
  Future<void> sendAttachment({
    required String roomId,
    required String senderId,
    required String text,
    required String filePath,
    required String fileName,
    String? replyToMessageId,
  });
  Future<void> markMessagesAsRead(String roomId, String userId);
  Future<void> updateTypingStatus(String roomId, String userId, bool isTyping);
  Stream<bool> getTypingIndicatorStream(String roomId, String partnerId);
  Future<void> deleteMessage(String messageId);
  Future<void> archiveRoom(String roomId);
  Future<void> closeRoom(String roomId);
}
