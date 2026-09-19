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
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/services/support_chat_service.dart';
import '../../../../core/controllers/notification_controller.dart';
import '../../../../core/services/notification_service.dart';

enum ConversationType {
  support,
  tripChat,
  notificationAlert,
}

class UnifiedConversationItem {
  final String id;
  final ConversationType type;
  final String title;
  final String? subtitle;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final String? avatarUrl;
  final String? statusLabel;
  final Color? statusColor;
  final VoidCallback onTap;
  final bool isPinned;

  UnifiedConversationItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    this.avatarUrl,
    this.statusLabel,
    this.statusColor,
    required this.onTap,
    this.isPinned = false,
  });
}

class MessagesCenterPage extends StatefulWidget {
  const MessagesCenterPage({super.key});

  @override
  State<MessagesCenterPage> createState() => _MessagesCenterPageState();
}

class _MessagesCenterPageState extends State<MessagesCenterPage> {
  final ChatRepository _chatRepository = sl<ChatRepository>();
  final NotificationController _notifController = sl<NotificationController>();
  final SupportChatService _supportChatService = SupportChatService.instance;
  late final String _myId;

  @override
  void initState() {
    super.initState();
    _myId = GlobalState.instance.userUid ?? '';
    if (_myId.isNotEmpty) {
      _supportChatService.initializeForUser(_myId);
      _supportChatService.syncMessages();
    }
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

  void _markAllAsRead() async {
    await _notifController.markAllMessagesAsRead();
    await _supportChatService.markAllMessagesAsRead();
    if (_myId.isNotEmpty) {
      try {
        final rooms = await _chatRepository.getChatRoomsStream(_myId).first;
        for (final room in rooms) {
          await _chatRepository.markMessagesAsRead(room.id, _myId);
        }
      } catch (e) {
        debugPrint('[MessagesCenter] Error marking rooms read: $e');
      }
    }
    if (mounted) {
      final isArabic = LocaleController.instance.isArabic;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تم تحديد جميع الرسائل كمقروءة' : 'All messages marked as read',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = LocaleController.instance.isArabic;

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
        elevation: 0,
        title: Text(
          l10n.messagesCenter,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([
              _notifController,
              _supportChatService.unreadCountNotifier,
            ]),
            builder: (context, _) {
              final totalUnread = _notifController.unreadMessagesCount + _supportChatService.unreadCount;
              if (totalUnread <= 0) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.done_all_rounded, color: AppColors.mediumBlue, size: 22),
                tooltip: isArabic ? 'تحديد الكل كمقروء' : 'Mark all as read',
                onPressed: _markAllAsRead,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.mediumBlue,
          onRefresh: () async {
            await _supportChatService.syncMessages();
            setState(() {});
          },
          child: StreamBuilder<List<ChatRoom>>(
            stream: _chatRepository.getChatRoomsStream(_myId),
            builder: (context, snapshot) {
              return ListenableBuilder(
                listenable: Listenable.merge([
                  _notifController,
                  _supportChatService.unreadCountNotifier,
                ]),
                builder: (context, _) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.mediumBlue),
                    );
                  }

                  final rooms = (snapshot.data ?? [])
                      .where((r) => r.type == 'trip')
                      .toList();

                  // 1. Build Support Item (Permanently pinned at top #1)
                  final supportMsgs = _supportChatService.currentMessages;
                  final hasSupportMsgs = supportMsgs.isNotEmpty;
                  final lastSupportMsg = hasSupportMsgs
                      ? supportMsgs.first.message
                      : (isArabic ? 'تواصل مع فريق الدعم الفني لحل استفسارك 24/7' : 'Contact customer support 24/7');
                  final supportTime = hasSupportMsgs ? supportMsgs.first.createdAt : DateTime.now();
                  final supportUnread = _supportChatService.unreadCount;

                  final supportItem = UnifiedConversationItem(
                    id: 'support_channel',
                    type: ConversationType.support,
                    title: isArabic ? 'الدعم الفني inRide' : 'inRide Support',
                    subtitle: isArabic ? 'فريق الدعم والمساعدة' : 'Customer Support Team',
                    lastMessage: lastSupportMsg,
                    timestamp: supportTime,
                    unreadCount: supportUnread,
                    statusLabel: isArabic ? 'خدمة 24/7' : '24/7 Support',
                    statusColor: AppColors.mediumBlue,
                    isPinned: true,
                    onTap: _openSupportChat,
                  );

                  // 2. Build Trip Chat Items
                  final tripChatItems = rooms.map((room) {
                    final partnerName = room.getRoomTitle(_myId);
                    final partnerId = _myId == room.passengerId ? room.driverId : room.passengerId;
                    final tripStatusStr = _getTripStatusLocalized(room.tripStatus, isArabic);
                    final tripStatusColor = _getTripStatusColor(room.tripStatus);

                    // Unread count for this specific room
                    final roomUnreadNotifs = _notifController.messageNotifications.where((n) {
                      if (n.isRead) return false;
                      final rId = n.data['roomId']?.toString() ?? n.data['room_id']?.toString();
                      return rId == room.id;
                    }).length;

                    final totalRoomUnread = roomUnreadNotifs > 0 ? roomUnreadNotifs : room.unreadCount;

                    return UnifiedConversationItem(
                      id: room.id,
                      type: ConversationType.tripChat,
                      title: partnerName,
                      subtitle: '${isArabic ? "الرحلة" : "Trip"}: $tripStatusStr',
                      lastMessage: room.lastMessage.isNotEmpty
                          ? room.lastMessage
                          : (isArabic ? 'تم بدء المحادثة للرحلة' : 'Trip chat started'),
                      timestamp: room.updatedAt,
                      unreadCount: totalRoomUnread,
                      avatarUrl: room.getRoomAvatar(_myId),
                      statusLabel: tripStatusStr,
                      statusColor: tripStatusColor,
                      isPinned: room.isPinned,
                      onTap: () async {
                        await _notifController.markMessagesForRoomAsRead(room.id);
                        await _chatRepository.markMessagesAsRead(room.id, _myId);
                        if (context.mounted) {
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
                        }
                      },
                    );
                  }).toList();

                  // 3. Build Standalone Message Notifications (if not already mapped to a room)
                  final roomIds = rooms.map((r) => r.id).toSet();
                  final standaloneNotifItems = _notifController.messageNotifications.where((n) {
                    final rId = n.data['roomId']?.toString() ?? n.data['room_id']?.toString();
                    if (rId != null && roomIds.contains(rId)) return false;
                    if (n.type.toLowerCase().contains('support')) return false;
                    return true;
                  }).map((notif) {
                    return UnifiedConversationItem(
                      id: notif.id,
                      type: ConversationType.notificationAlert,
                      title: notif.title,
                      subtitle: isArabic ? 'تنبيه رسالة' : 'Message Alert',
                      lastMessage: notif.body,
                      timestamp: notif.createdAt,
                      unreadCount: notif.isRead ? 0 : 1,
                      statusLabel: isArabic ? 'إشعار' : 'Alert',
                      statusColor: AppColors.mediumBlue,
                      isPinned: false,
                      onTap: () {
                        _notifController.markAsRead(notif.id);
                        NotificationService.instance.handleNotificationClick(notif.data);
                      },
                    );
                  }).toList();

                  // 4. Sort other conversations chronologically from newest to oldest
                  final otherItems = <UnifiedConversationItem>[
                    ...tripChatItems,
                    ...standaloneNotifItems,
                  ];

                  otherItems.sort((a, b) {
                    if (a.isPinned != b.isPinned) {
                      return a.isPinned ? -1 : 1;
                    }
                    return b.timestamp.compareTo(a.timestamp);
                  });

                  // 5. Pin Technical Support at the very top (index 0) leading all conversations
                  final allItems = <UnifiedConversationItem>[
                    supportItem,
                    ...otherItems,
                  ];

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: allItems.length,
                    separatorBuilder: (_, index) {
                      // Visual divider between pinned Support chat and subsequent conversations
                      if (index == 0 && otherItems.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'محادثات الرحلات والتنبيهات' : 'Trip Chats & Alerts',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(
                                  color: AppColors.border.withValues(alpha: 0.8),
                                  thickness: 0.8,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      final item = allItems[index];
                      final card = _buildConversationCard(item, isArabic);

                      // If there are no other chats yet, display a subtle friendly note below the support chat
                      if (index == 0 && otherItems.isEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            card,
                            Container(
                              margin: const EdgeInsets.only(top: 36),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.mediumBlue.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.forum_outlined, size: 36, color: AppColors.mediumBlue),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isArabic ? 'لا توجد محادثات رحلات سابقة' : 'No previous trip conversations',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isArabic
                                        ? 'ستظهر محادثاتك مع الكباتن والتنبيهات هنا فور بدئها'
                                        : 'Your trip conversations with drivers and alerts will appear here automatically',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return card;
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(UnifiedConversationItem item, bool isArabic) {
    final hasUnread = item.unreadCount > 0;
    final isPinned = item.isPinned;

    return Container(
      decoration: BoxDecoration(
        color: isPinned ? const Color(0xFFF9FBFF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUnread
              ? AppColors.mediumBlue.withValues(alpha: 0.45)
              : isPinned
                  ? AppColors.mediumBlue.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.7),
          width: (hasUnread || isPinned) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasUnread
                ? AppColors.mediumBlue.withValues(alpha: 0.08)
                : isPinned
                    ? AppColors.mediumBlue.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Badge
                _buildAvatar(item),
                const SizedBox(width: 14),

                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row: Title & Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.title,
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.type == ConversationType.support) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: AppColors.mediumBlue, size: 15),
                                ],
                                if (isPinned) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.mediumBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.push_pin_rounded,
                                          color: AppColors.mediumBlue,
                                          size: 10.5,
                                        ),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          isArabic ? 'مثبتة' : 'Pinned',
                                          style: GoogleFonts.cairo(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.mediumBlue,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(item.timestamp, isArabic),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: hasUnread ? AppColors.mediumBlue : AppColors.textLight,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Status Chip (Trip status or support badge)
                      if (item.statusLabel != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (item.statusColor ?? AppColors.mediumBlue).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.statusLabel!,
                            style: GoogleFonts.cairo(
                              fontSize: 9.5,
                              color: item.statusColor ?? AppColors.mediumBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Last Message Snippet + Unread Counter
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.lastMessage,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              child: Center(
                                child: Text(
                                  item.unreadCount > 99 ? '99+' : '${item.unreadCount}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UnifiedConversationItem item) {
    if (item.type == ConversationType.support) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.support_agent, color: Colors.white, size: 26),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    final avatar = item.avatarUrl ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.background,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(
                  item.title.isNotEmpty ? item.title.substring(0, 1) : 'U',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.type == ConversationType.tripChat ? Icons.directions_car : Icons.chat_bubble_outline,
              size: 11,
              color: AppColors.mediumBlue,
            ),
          ),
        ),
      ],
    );
  }


  String _formatRelativeTime(DateTime time, bool isArabic) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
      return isArabic ? 'الآن' : 'Just now';
    } else if (diff.inMinutes < 60 && diff.inMinutes > 0) {
      return isArabic ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && now.day == time.day && now.month == time.month && now.year == time.year) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = isArabic ? (time.hour >= 12 ? 'م' : 'ص') : (time.hour >= 12 ? 'PM' : 'AM');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    } else if (diff.inDays < 2 && now.day - time.day == 1) {
      return isArabic ? 'أمس' : 'Yesterday';
    } else if (diff.inDays < 7) {
      if (isArabic) {
        const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
        return days[time.weekday - 1];
      } else {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[time.weekday - 1];
      }
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
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
