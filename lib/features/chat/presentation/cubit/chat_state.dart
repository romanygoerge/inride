abstract class ChatState {
  const ChatState();
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<Map<String, dynamic>> messages;
  final bool partnerIsTyping;

  const ChatLoaded({required this.messages, this.partnerIsTyping = false});
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);
}
