import '../../domain/entities/chat_message.dart';

abstract class ChatState {
  const ChatState();
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool partnerIsTyping;

  const ChatLoaded({
    required this.messages,
    this.partnerIsTyping = false,
  });

  ChatLoaded copyWith({
    List<ChatMessage>? messages,
    bool? partnerIsTyping,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      partnerIsTyping: partnerIsTyping ?? this.partnerIsTyping,
    );
  }
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);
}
