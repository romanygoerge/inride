import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../core/services/support_chat_service.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupportChatService _chatService = SupportChatService.instance;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    final globalState = GlobalState.instance;
    _userId = globalState.userUid ?? 'anonymous_user';

    if (_userId != 'anonymous_user') {
      _chatService.initializeForUser(_userId);
      _chatService.setChatPageActive(true);
    }
  }

  @override
  void dispose() {
    _chatService.setChatPageActive(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userId == 'anonymous_user') return;

    _messageController.clear();
    await _chatService.sendMessage(text);

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
    if (_userId == 'anonymous_user') {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.supportChat,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: Center(
          child: Text(
            LocaleController.instance.isArabic ? 'يرجى تسجيل الدخول أولاً للتحدث مع الدعم الفني.' : 'Please sign in first to chat with support.',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final isArabic = LocaleController.instance.isArabic;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              isArabic ? 'محادثة الدعم الفني' : 'Technical Support Chat',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            Text(
              isArabic ? 'نحن متصلون لمساعدتك 24/7' : 'We are online 24/7 to help you',
              style: GoogleFonts.cairo(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<SupportChatMessage>>(
                stream: _chatService.messagesStream,
                initialData: _chatService.currentMessages,
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.mediumBlue.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.support_agent_outlined, size: 48, color: AppColors.mediumBlue),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isArabic ? 'ابدأ المحادثة مع الدعم الفني' : 'Start chat with support',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isArabic
                                  ? 'اكتب مشكلتك أو استفسارك هنا وسيقوم فريق الدعم بالرد عليك في أسرع وقت.'
                                  : 'Type your problem or inquiry here and our support team will respond as soon as possible.',
                              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = !msg.isAdmin && msg.senderId == _userId;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),
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
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: l10n.typeMessage,
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
    );
  }

  Widget _buildMessageBubble(SupportChatMessage msg, bool isMe) {
    final timeStr = '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    Widget statusIcon;
    if (msg.status == 'read') {
      statusIcon = const Icon(Icons.done_all, size: 14, color: Color(0xFF64B5F6)); // Blue double tick
    } else if (msg.status == 'delivered' || msg.deliveredAt != null) {
      statusIcon = const Icon(Icons.done_all, size: 14, color: Colors.white70); // White/grey double tick
    } else {
      statusIcon = const Icon(Icons.done, size: 14, color: Colors.white70); // Single tick
    }

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
              msg.message,
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
                  statusIcon,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
