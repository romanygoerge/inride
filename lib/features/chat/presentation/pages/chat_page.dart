import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/chat_state.dart';

class ChatPage extends StatefulWidget {
  final String tripId;
  final String myId;
  final String partnerId;
  final String partnerName;

  const ChatPage({
    super.key,
    required this.tripId,
    required this.myId,
    required this.partnerId,
    required this.partnerName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatCubit _chatCubit;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _chatCubit = ChatCubit();
    _chatCubit.loadChatRoom(widget.tripId, widget.myId, widget.partnerId);
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      _isTyping = hasText;
      _chatCubit.updateTypingStatus(widget.tripId, widget.myId, _isTyping);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _chatCubit.leaveChatRoom(widget.tripId, widget.myId);
    _chatCubit.close();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _chatCubit.sendMessage(widget.tripId, widget.myId, text);
      _messageController.clear();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatCubit,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.partnerName,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
              ),
              BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoaded && state.partnerIsTyping) {
                    return Text(
                      'يكتب الآن...',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                    );
                  }
                  return Text(
                    'متصل بالرحلة',
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                  );
                },
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Messages List
              Expanded(
                child: BlocBuilder<ChatCubit, ChatState>(
                  builder: (context, state) {
                    if (state is ChatLoading) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue));
                    } else if (state is ChatError) {
                      return Center(child: Text(state.message, style: GoogleFonts.cairo()));
                    } else if (state is ChatLoaded) {
                      final list = state.messages;
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline_outlined, size: 48, color: AppColors.textLight),
                              const SizedBox(height: 12),
                              Text('أرسل رسالة لبدء التنسيق المباشر', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final msg = list[index];
                          final isMe = msg['senderId'] == widget.myId;
                          return _buildMessageBubble(msg, isMe);
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              // Bottom Input bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك هنا...',
                            hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textLight),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.mediumBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final date = msg['createdAt'] as DateTime;
    final timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.mediumBlue : AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? Radius.zero : const Radius.circular(16),
            bottomRight: isMe ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['text'] as String,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: isMe ? Colors.white70 : AppColors.textLight,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg['isSeen'] as bool
                        ? Icons.done_all_rounded
                        : (msg['isDelivered'] as bool ? Icons.done_all_rounded : Icons.done_rounded),
                    color: msg['isSeen'] as bool ? Colors.lightBlueAccent : Colors.white60,
                    size: 14,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
