import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/DI/injection_container.dart';
import '../../../common/support_chat_page.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/chat_room.dart';
import 'chat_page.dart';
import '../../../../generated/app_localizations.dart';

class MessagesCenterPage extends StatefulWidget {
  const MessagesCenterPage({super.key});

  @override
  State<MessagesCenterPage> createState() => _MessagesCenterPageState();
}

class _MessagesCenterPageState extends State<MessagesCenterPage> {
  final ChatRepository _chatRepository = sl<ChatRepository>();
  late final String _myId;

  @override
  void initState() {
    super.initState();
    _myId = GlobalState.instance.userUid ?? '';
  }

  void _openSupportChat() {
    final l10n = AppLocalizations.of(context)!;
    if (_myId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authTitle, style: GoogleFonts.cairo()),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SupportChatPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_myId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.messagesCenter, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text(l10n.authTitle, style: GoogleFonts.cairo()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          l10n.messagesCenter,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Support Card Quick Access
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: _openSupportChat,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mediumBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(Icons.support_agent, color: AppColors.mediumBlue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.supportChat,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LocaleController.instance.isArabic ? 'تواصل مع خدمة العملاء لحل مشكلتك 24/7' : 'Contact customer support 24/7',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: AppColors.textLight, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: LocaleController.instance.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  LocaleController.instance.isArabic ? 'محادثات الرحلات النشطة والسابقة' : 'Active & Past Trip Chats',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            // Chat Rooms List
            Expanded(
              child: StreamBuilder<List<ChatRoom>>(
                stream: _chatRepository.getChatRoomsStream(_myId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.mediumBlue),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '${LocaleController.instance.isArabic ? "خطأ في تحميل المحادثات:" : "Error loading chats:"} ${snapshot.error}',
                        style: GoogleFonts.cairo(color: AppColors.error),
                      ),
                    );
                  }

                  // Filter out support type from rooms because it is shown as the Support Card above
                  final rooms = (snapshot.data ?? [])
                      .where((r) => r.type == 'trip')
                      .toList();

                  if (rooms.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textLight),
                            const SizedBox(height: 12),
                            Text(
                              LocaleController.instance.isArabic ? 'لا توجد محادثات رحلات بعد' : 'No trip chats yet',
                              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: rooms.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      final partnerName = room.getRoomTitle(_myId);
                      final partnerId = _myId == room.passengerId ? room.driverId : room.passengerId;
                      final isArabic = LocaleController.instance.isArabic;
                      final tripStatusStr = _getTripStatusLocalized(room.tripStatus, isArabic);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                roomId: room.id,
                                myId: _myId,
                                partnerId: partnerId ?? '',
                                partnerName: partnerName,
                                chatType: 'trip',
                                tripRoom: room,
                              ),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.background,
                          backgroundImage: room.getRoomAvatar(_myId).isNotEmpty
                              ? NetworkImage(room.getRoomAvatar(_myId))
                              : null,
                          child: room.getRoomAvatar(_myId).isEmpty
                              ? Text(
                                  partnerName.isNotEmpty ? partnerName.substring(0, 1) : 'U',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : null,
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                partnerName,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatTime(room.updatedAt),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.lastMessage.isNotEmpty
                                    ? room.lastMessage
                                    : (isArabic ? 'تم بدء المحادثة للرحلة' : 'Trip chat started'),
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: room.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontWeight: room.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getTripStatusColor(room.tripStatus).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${isArabic ? "الرحلة" : "Trip"}: $tripStatusStr',
                                  style: GoogleFonts.cairo(
                                    fontSize: 9,
                                    color: _getTripStatusColor(room.tripStatus),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: room.unreadCount > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.mediumBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${room.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}/${time.year}';
  }

  String _getTripStatusLocalized(String? status, bool isArabic) {
    switch (status) {
      case 'Accepted':
        return isArabic ? 'تم قبول الطلب' : 'Accepted';
      case 'DriverArriving':
        return isArabic ? 'السائق في الطريق' : 'Driver Arriving';
      case 'TripStarted':
        return isArabic ? 'بدأت الرحلة' : 'Trip Started';
      case 'Completed':
        return isArabic ? 'مكتملة' : 'Completed';
      case 'Cancelled':
        return isArabic ? 'ملغاة' : 'Cancelled';
      default:
        return isArabic ? 'نشط' : 'Active';
    }
  }

  Color _getTripStatusColor(String? status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.error;
      case 'TripStarted':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}
