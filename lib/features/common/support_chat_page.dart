import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  late final String _userId;
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    final globalState = GlobalState.instance;
    _userId = globalState.userUid ?? 'anonymous_user';

    if (_userId != 'anonymous_user') {
      _messagesStream = _supabase
          .from('support_messages')
          .stream(primaryKey: ['id'])
          .eq('user_id', _userId)
          .map((list) {
        final sorted = List<Map<String, dynamic>>.from(list);
        sorted.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          final bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        return sorted;
      });
    } else {
      _messagesStream = const Stream.empty();
    }

    _markChatAsRead();
  }

  void _markChatAsRead() {
    if (_userId != 'anonymous_user') {
      _supabase.from('support_chats').upsert({
        'id': _userId,
        'status': 'open',
        'updated_at': DateTime.now().toIso8601String(),
      }).catchError((e) {
        debugPrint('Error marking support chat read: $e');
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userId == 'anonymous_user') return;

    _messageController.clear();

    try {
      await _supabase.from('support_chats').upsert({
        'id': _userId,
        'status': 'open',
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _supabase.from('support_messages').insert({
        'user_id': _userId,
        'sender_id': _userId,
        'text': text,
        'is_admin': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending support message: $e');
    }

    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == 'anonymous_user') {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'الدعم الفني المباشر',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: Center(
          child: Text(
            'يرجى تسجيل الدخول أولاً للتحدث مع الدعم الفني.',
            style: GoogleFonts.cairo(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'محادثة الدعم الفني',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            ),
            Text(
              'نحن متصلون لمساعدتك 24/7',
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
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ أثناء تحميل الرسائل.',
                        style: GoogleFonts.cairo(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  final docs = snapshot.data ?? [];
                  
                  if (docs.isEmpty) {
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
                              'ابدأ المحادثة مع الدعم الفني',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اكتب مشكلتك أو استفسارك هنا وسيقوم فريق الدعم بالرد عليك في أسرع وقت.',
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
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final isMe = (data['sender_id'] ?? data['senderId']) == _userId;
                      return _buildMessageBubble(data, isMe);
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
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final date = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
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
              msg['text'] ?? '',
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
