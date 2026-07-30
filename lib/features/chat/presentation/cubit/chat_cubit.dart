import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final GetMessagesStream _getMessagesStream;
  final SendChatMessage _sendChatMessage;
  final SendChatAttachment _sendChatAttachment;
  final MarkMessagesAsRead _markMessagesAsRead;
  final UpdateTypingStatus _updateTypingStatus;
  final GetTypingIndicator _getTypingIndicator;

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;

  ChatCubit({
    required GetMessagesStream getMessagesStream,
    required SendChatMessage sendChatMessage,
    required SendChatAttachment sendChatAttachment,
    required MarkMessagesAsRead markMessagesAsRead,
    required UpdateTypingStatus updateTypingStatus,
    required GetTypingIndicator getTypingIndicator,
  })  : _getMessagesStream = getMessagesStream,
        _sendChatMessage = sendChatMessage,
        _sendChatAttachment = sendChatAttachment,
        _markMessagesAsRead = markMessagesAsRead,
        _updateTypingStatus = updateTypingStatus,
        _getTypingIndicator = getTypingIndicator,
        super(ChatInitial());

  void loadChatRoom(String roomId, String myId, String partnerId) {
    emit(ChatLoading());
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();

    // 1. Mark existing messages as read
    _markMessagesAsRead(roomId, myId);

    // 2. Subscribe to messages stream
    _messagesSubscription = _getMessagesStream(roomId).listen(
      (msgList) {
        final isPartnerTyping = state is ChatLoaded ? (state as ChatLoaded).partnerIsTyping : false;
        emit(ChatLoaded(messages: msgList, partnerIsTyping: isPartnerTyping));
        
        // Auto mark new messages as read when they arrive and chat page is open
        _markMessagesAsRead(roomId, myId);
      },
      onError: (e) {
        emit(ChatError(e.toString()));
      },
    );

    // 3. Subscribe to partner's typing status
    _typingSubscription = _getTypingIndicator(roomId, partnerId).listen(
      (isTyping) {
        if (state is ChatLoaded) {
          final current = state as ChatLoaded;
          emit(ChatLoaded(messages: current.messages, partnerIsTyping: isTyping));
        }
      },
    );
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // Optimistic UI Update (Requirement 10)
    final optimisticMsg = ChatMessage(
      id: tempId,
      roomId: roomId,
      senderId: senderId,
      text: text,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      createdAt: now,
      updatedAt: now,
      isSending: true,
    );

    List<ChatMessage> currentMessages = [];
    if (state is ChatLoaded) {
      currentMessages = List<ChatMessage>.from((state as ChatLoaded).messages);
    }
    
    emit(ChatLoaded(
      messages: [optimisticMsg, ...currentMessages],
      partnerIsTyping: state is ChatLoaded ? (state as ChatLoaded).partnerIsTyping : false,
    ));

    try {
      await _sendChatMessage(
        roomId: roomId,
        senderId: senderId,
        text: text,
        replyToMessageId: replyToMessageId,
      );
    } catch (e) {
      // Mark optimistic message as failed
      if (state is ChatLoaded) {
        final updatedMsgs = (state as ChatLoaded).messages.map((msg) {
          if (msg.id == tempId) {
            return msg.copyWith(isSending: false, isError: true);
          }
          return msg;
        }).toList();
        emit(ChatLoaded(
          messages: updatedMsgs,
          partnerIsTyping: (state as ChatLoaded).partnerIsTyping,
        ));
      }
    }
  }

  Future<void> sendAttachment({
    required String roomId,
    required String senderId,
    required String text,
    required String filePath,
    required String fileName,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final String tempId = 'temp_file_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // Optimistic UI update with attachment placeholder
    final optimisticMsg = ChatMessage(
      id: tempId,
      roomId: roomId,
      senderId: senderId,
      text: text,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      createdAt: now,
      updatedAt: now,
      isSending: true,
      attachmentUrl: filePath, // local file path for immediate preview
      attachmentName: fileName,
      attachmentType: 'image',
    );

    List<ChatMessage> currentMessages = [];
    if (state is ChatLoaded) {
      currentMessages = List<ChatMessage>.from((state as ChatLoaded).messages);
    }

    emit(ChatLoaded(
      messages: [optimisticMsg, ...currentMessages],
      partnerIsTyping: state is ChatLoaded ? (state as ChatLoaded).partnerIsTyping : false,
    ));

    try {
      await _sendChatAttachment(
        roomId: roomId,
        senderId: senderId,
        text: text,
        filePath: filePath,
        fileName: fileName,
        replyToMessageId: replyToMessageId,
      );
    } catch (e) {
      if (state is ChatLoaded) {
        final updatedMsgs = (state as ChatLoaded).messages.map((msg) {
          if (msg.id == tempId) {
            return msg.copyWith(isSending: false, isError: true);
          }
          return msg;
        }).toList();
        emit(ChatLoaded(
          messages: updatedMsgs,
          partnerIsTyping: (state as ChatLoaded).partnerIsTyping,
        ));
      }
    }
  }

  void updateTyping(String roomId, String myId, bool isTyping) {
    _updateTypingStatus(roomId, myId, isTyping);
  }

  void leaveChatRoom(String roomId, String myId) {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    updateTyping(roomId, myId, false);
    emit(ChatInitial());
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    return super.close();
  }
}
