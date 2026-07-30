import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/DI/injection_container.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_room.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/chat_state.dart';
import '../widgets/typing_indicator.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  final String? tripId;
  final String myId;
  final String partnerId;
  final String partnerName;
  final String chatType; // 'trip' or 'support'
  final ChatRoom? tripRoom;

  const ChatPage({
    super.key,
    this.roomId = '',
    this.tripId,
    required this.myId,
    required this.partnerId,
    required this.partnerName,
    this.chatType = 'trip',
    this.tripRoom,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatCubit _chatCubit;
  bool _isTyping = false;
  bool _showTripBanner = true;
  
  // Reply State
  ChatMessage? _replyingTo;

  String _currentRoomId = '';

  @override
  void initState() {
    super.initState();
    _currentRoomId = widget.roomId;
    _chatCubit = sl<ChatCubit>();
    _initChat();
    _messageController.addListener(_onTextChanged);
  }

  Future<void> _initChat() async {
    if (_currentRoomId.isEmpty && widget.tripId != null && widget.tripId!.isNotEmpty) {
      try {
        _currentRoomId = await sl<ChatRepository>().getRoomIdForTrip(widget.tripId!);
      } catch (e) {
        _currentRoomId = widget.tripId!;
      }
    }
    if (_currentRoomId.isNotEmpty) {
      _chatCubit.loadChatRoom(_currentRoomId, widget.myId, widget.partnerId);
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _isTyping && _currentRoomId.isNotEmpty) {
      _isTyping = hasText;
      _chatCubit.updateTyping(_currentRoomId, widget.myId, _isTyping);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    if (_currentRoomId.isNotEmpty) {
      _chatCubit.leaveChatRoom(_currentRoomId, widget.myId);
    }
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if ((text.isNotEmpty || _replyingTo != null) && _currentRoomId.isNotEmpty) {
      _chatCubit.sendMessage(
        roomId: _currentRoomId,
        senderId: widget.myId,
        text: text,
        replyToMessageId: _replyingTo?.id,
        replyToText: _replyingTo?.text,
      );
      _messageController.clear();
      setState(() {
        _replyingTo = null;
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    // Compress image before upload using maxWidth/maxHeight and imageQuality (Requirement 7)
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );

    if (pickedFile != null && _currentRoomId.isNotEmpty) {
      final fileName = pickedFile.name;
      final filePath = pickedFile.path;

      _chatCubit.sendAttachment(
        roomId: _currentRoomId,
        senderId: widget.myId,
        text: '📷 صورة',
        filePath: filePath,
        fileName: fileName,
        replyToMessageId: _replyingTo?.id,
        replyToText: _replyingTo?.text,
      );

      setState(() {
        _replyingTo = null;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.partnerName,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
              BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoaded && state.partnerIsTyping) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'يكتب الآن',
                          style: GoogleFonts.cairo(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const TypingIndicator(),
                      ],
                    );
                  }
                  return Text(
                    widget.chatType == 'support' ? 'الدعم الفني المباشر' : 'محادثة الرحلة نشطة',
                    style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textLight),
                  );
                },
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: widget.chatType == 'trip'
              ? [
                  IconButton(
                    icon: Icon(
                      _showTripBanner ? Icons.info : Icons.info_outline,
                      color: AppColors.mediumBlue,
                    ),
                    onPressed: () {
                      setState(() {
                        _showTripBanner = !_showTripBanner;
                      });
                    },
                  )
                ]
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Trip Info Banner (Requirement 4)
              if (widget.chatType == 'trip' && widget.tripRoom != null && _showTripBanner)
                _buildTripBanner(widget.tripRoom!),

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
                              const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textLight),
                              const SizedBox(height: 12),
                              Text('أرسل رسالة لبدء التنسيق المباشر', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final msg = list[index];
                          final isMe = msg.senderId == widget.myId;

                          // Date separator rendering logic
                          bool showDateSeparator = false;
                          if (index == list.length - 1) {
                            showDateSeparator = true;
                          } else {
                            final prevMsg = list[index + 1];
                            if (msg.createdAt.day != prevMsg.createdAt.day ||
                                msg.createdAt.month != prevMsg.createdAt.month ||
                                msg.createdAt.year != prevMsg.createdAt.year) {
                              showDateSeparator = true;
                            }
                          }

                          return Column(
                            children: [
                              if (showDateSeparator) _buildDateSeparator(msg.createdAt),
                              _buildMessageBubble(msg, isMe),
                            ],
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              // Reply Preview Widget
              if (_replyingTo != null) _buildReplyPreview(),

              // Bottom Input bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    // Image picker action
                    GestureDetector(
                      onTap: _pickAndSendImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildTripBanner(ChatRoom room) {
    final dateStr = '${room.tripCreatedAt?.day}/${room.tripCreatedAt?.month}/${room.tripCreatedAt?.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تفاصيل المشوار (الرحلة)',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
              ),
              if (room.tripPrice != null)
                Text(
                  '${room.tripPrice} ج.م',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.mediumBlue),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.green, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.tripPickupAddress ?? 'شارع البداية',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.tripDestinationAddress ?? 'شارع النهاية',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الرمز: #${room.tripId?.substring(0, 8)}',
                style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textLight),
              ),
              Text(
                'التاريخ: $dateStr',
                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String dayText = '${date.day}/${date.month}/${date.year}';
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      dayText = 'اليوم';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      dayText = 'أمس';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          dayText,
          style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: AppColors.mediumBlue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الرد على الرسالة:',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                ),
                Text(
                  _replyingTo!.text,
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textLight),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final timeStr = '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.mediumBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? Radius.zero : const Radius.circular(16),
            bottomRight: isMe ? const Radius.circular(16) : Radius.zero,
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Citing reply if present
             if (msg.replyToText != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withValues(alpha: 0.12) : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(right: BorderSide(color: isMe ? Colors.white : AppColors.mediumBlue, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رسالة سابقة',
                      style: GoogleFonts.cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : AppColors.mediumBlue,
                      ),
                    ),
                    Text(
                      msg.replyToText!,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

            // Render Attachment Image if present (Requirement 8)
            if (msg.attachmentUrl != null)
              GestureDetector(
                onTap: () => _showImageFullscreen(msg.attachmentUrl!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  height: 160,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: msg.attachmentUrl!.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: msg.attachmentUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey.shade200,
                              highlightColor: Colors.grey.shade100,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                          )
                        : Image.file(
                            File(msg.attachmentUrl!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),

            // Message text
            if (msg.text.isNotEmpty && msg.attachmentUrl == null)
              Text(
                msg.text,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                ),
              ),

            const SizedBox(height: 4),

            // Message status and timestamp details (Requirement 8)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textLight,
                  ),
                ),
                const SizedBox(width: 6),
                if (isMe) ...[
                  if (msg.isSending)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white70,
                      ),
                    )
                  else if (msg.isError)
                    const Icon(Icons.error_outline, color: Colors.orange, size: 13)
                  else
                    Icon(
                      Icons.done_all,
                      size: 13,
                      color: msg.isRead ? Colors.lightBlueAccent : Colors.white60,
                    ),
                ],
                // Reply Quick Button
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _replyingTo = msg;
                    });
                  },
                  child: Icon(
                    Icons.reply_outlined,
                    size: 14,
                    color: isMe ? Colors.white70 : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFullscreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: url.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                    )
                  : Image.file(
                      File(url),
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
