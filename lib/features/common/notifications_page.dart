import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/DI/injection_container.dart' show sl;
import '../../core/controllers/notification_controller.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/snappy_page_route.dart';
import '../../generated/app_localizations.dart';
import 'notification_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationController _controller = sl<NotificationController>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final notifications = _controller.notifications;
        final isLoading = _controller.isLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              l10n.notificationsCenter,
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
              if (notifications.isNotEmpty && !isLoading) ...[
                // Mark all read button
                IconButton(
                  icon: const Icon(Icons.done_all_rounded, color: AppColors.mediumBlue, size: 22),
                  tooltip: l10n.markAllRead,
                  onPressed: () => _confirmMarkAllRead(context),
                ),
                // Delete all button
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 22),
                  tooltip: l10n.deleteAllNotifications,
                  onPressed: () => _confirmDeleteAll(context),
                ),
                const SizedBox(width: 8),
              ]
            ],
          ),
          body: SafeArea(
            child: isLoading
                ? _buildShimmerLoading()
                : notifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        color: AppColors.mediumBlue,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            return _buildNotificationCard(notif);
                          },
                        ),
                      ),
          ),
        );
      },
    );
  }

  // Confirm Mark all read dialog
  void _confirmMarkAllRead(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.warning, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(l10n.markAllRead, style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.markAllAsRead();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.confirm, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Confirm Delete all dialog
  void _confirmDeleteAll(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.deleteAllNotifications, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text(l10n.deleteAllNotifications, style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              _controller.deleteAllNotifications();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.delete, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  // Shimmer loading placeholder
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            height: 90,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  // Empty state view
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.mediumBlue.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 80,
                color: AppColors.mediumBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'صندوق الوارد فارغ',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد لديك إشعارات جديدة في الوقت الحالي. سنقوم بتنبيهك بمجرد وجود أي جديد!',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Single Notification Card UI with Swipe-to-Dismiss support
  Widget _buildNotificationCard(NotificationModel notif) {
    final iconData = _getIconForType(notif.type);
    final iconColor = _getColorForType(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _controller.deleteNotification(notif.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الإشعار بنجاح.', style: GoogleFonts.cairo()),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft, // Since dir is RTL, endToStart goes from Right to Left, so delete icon appears on Left
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: notif.isRead ? AppColors.border : AppColors.mediumBlue.withValues(alpha: 0.25),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        color: notif.isRead ? Colors.white : AppColors.mediumBlue.withValues(alpha: 0.02),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // 1. Mark as read
            if (!notif.isRead) {
              _controller.markAsRead(notif.id);
            }
            // 2. Route redirection or details page
            final routingTypes = [
              'new_trip', 'new_ride', 'delivery_request', 'new_offer', 'driver_offer', 'counter_offer',
              'accept_trip', 'ride_accepted', 'delivery_accepted', 'driver_arrived', 'captain_arrived', 'trip_started',
              'cancel_trip', 'trip_finished', 'trip_completed', 'payment',
              'new_message', 'chat_message', 'support_chat', 'support',
              'offers', 'wallet', 'charge', 'charge_pending', 'payout', 'deposit'
            ];
            final hasUrl = notif.data['url'] != null || notif.data['link'] != null;
            final hasTrip = notif.data['tripId'] != null || notif.data['trip_id'] != null || notif.data['requestId'] != null;

            if (routingTypes.contains(notif.type) || hasUrl || hasTrip) {
              NotificationService.instance.handleNotificationClick(notif.data);
            } else {
              Navigator.push(
                context,
                SnappyPageRoute(page: NotificationDetailsPage(notification: notif)),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Bubble
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notif.isRead ? AppColors.background : iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: notif.isRead ? AppColors.textSecondary : iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.mediumBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.body,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTimeAgo(notif.createdAt),
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Small delete button
                          GestureDetector(
                            onTap: () => _controller.deleteNotification(notif.id),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
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

  // Resolve notification icon by type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_trip':
        return Icons.directions_car_filled_rounded;
      case 'accept_trip':
        return Icons.check_circle_rounded;
      case 'cancel_trip':
        return Icons.cancel_rounded;
      case 'driver_arrived':
        return Icons.pin_drop_rounded;
      case 'new_message':
        return Icons.chat_bubble_rounded;
      case 'offers':
        return Icons.local_offer_rounded;
      case 'app_updates':
        return Icons.system_update_alt_rounded;
      case 'admin_notifications':
      default:
        return Icons.campaign_rounded;
    }
  }

  // Resolve notification color by type
  Color _getColorForType(String type) {
    switch (type) {
      case 'new_trip':
        return Colors.blue;
      case 'accept_trip':
        return Colors.green;
      case 'cancel_trip':
        return Colors.red;
      case 'driver_arrived':
        return Colors.teal;
      case 'new_message':
        return Colors.orange;
      case 'offers':
        return Colors.purple;
      case 'app_updates':
        return Colors.blueGrey;
      case 'admin_notifications':
      default:
        return Colors.amber.shade800;
    }
  }

  // Beautiful Arabic relative time helper
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (minutes == 1) return 'منذ دقيقة';
      if (minutes == 2) return 'منذ دقيقتين';
      if (minutes <= 10) return 'منذ $minutes دقائق';
      return 'منذ $minutes دقيقة';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours == 1) return 'منذ ساعة';
      if (hours == 2) return 'منذ ساعتين';
      if (hours <= 10) return 'منذ $hours ساعات';
      return 'منذ $hours ساعة';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      if (days == 1) return 'أمس';
      if (days == 2) return 'منذ يومين';
      return 'منذ $days أيام';
    } else {
      final months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    }
  }
}
