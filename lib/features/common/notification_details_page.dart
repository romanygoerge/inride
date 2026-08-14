import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/localization/locale_controller.dart';

class NotificationDetailsPage extends StatelessWidget {
  final NotificationModel notification;

  const NotificationDetailsPage({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleController.instance.isArabic;
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isAr ? 'تفاصيل الإشعار' : 'Notification Details',
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Card
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Large icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      notification.title,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Date & Time
                    Text(
                      _formatDateTime(notification.createdAt, isAr),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Message content card
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'محتوى الرسالة' : 'Message Content',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),
                    Text(
                      notification.body,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Button if applicable
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: AppColors.blueGradient),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  label: Text(
                    isAr ? 'الانتقال إلى الصفحة المربوطة' : 'Go to Linked Page',
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: () {
                    NotificationService.instance.handleNotificationClick(notification.data);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  String _formatDateTime(DateTime dt, bool isAr) {
    final arMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = isAr ? (dt.hour >= 12 ? 'م' : 'ص') : (dt.hour >= 12 ? 'PM' : 'AM');
    final minute = dt.minute.toString().padLeft(2, '0');
    final monthStr = isAr ? arMonths[dt.month - 1] : enMonths[dt.month - 1];
    return '${dt.day} $monthStr ${dt.year} - $hour:$minute $period';
  }
}
