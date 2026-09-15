import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/state/global_state.dart';
import '../../core/utils/snappy_page_route.dart';
import '../../features/common/history_page.dart';
import '../../features/passenger/presentation/pages/passenger_ride_active_page.dart';
import '../../features/driver/presentation/pages/driver_ride_active_page.dart';

class NotificationDetailsPage extends StatefulWidget {
  final NotificationModel notification;

  const NotificationDetailsPage({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailsPage> createState() => _NotificationDetailsPageState();
}

class _NotificationDetailsPageState extends State<NotificationDetailsPage> {
  bool _isLoadingTrip = false;
  Map<String, dynamic>? _tripData;
  String? _tripStatus;

  @override
  void initState() {
    super.initState();
    _checkLiveTripStatus();
  }

  Future<void> _checkLiveTripStatus() async {
    final data = widget.notification.data;
    final reqId = (data['requestId'] ?? data['request_id'] ?? data['tripId'] ?? data['trip_id'])?.toString();

    if (reqId != null && reqId.isNotEmpty) {
      setState(() => _isLoadingTrip = true);
      try {
        final res = await Supabase.instance.client
            .from('ride_requests')
            .select()
            .eq('id', reqId)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (res != null) {
              _tripData = Map<String, dynamic>.from(res);
              _tripStatus = (_tripData!['status'] ?? '').toString().toLowerCase();
            }
            _isLoadingTrip = false;
          });
        }
      } catch (e) {
        debugPrint('[NotificationDetails] Error querying trip: $e');
        if (mounted) setState(() => _isLoadingTrip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleController.instance.isArabic;
    final iconData = _getIconForType(widget.notification.type);
    final iconColor = _getColorForType(widget.notification.type);

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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Main Notification Header Card
              Container(
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.notification.title,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDateTime(widget.notification.createdAt, isAr),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Message Body Card
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'محتوى الإشعار' : 'Message Content',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 10),
                    Text(
                      widget.notification.body,
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Live Trip Status Card (If related to a trip)
              if (_isLoadingTrip) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mediumBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_tripData != null) ...[
                _buildLiveTripStatusCard(isAr),
                const SizedBox(height: 16),
              ],

              // 4. Action Button
              _buildActionButton(context, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveTripStatusCard(bool isAr) {
    final status = _tripStatus ?? '';
    final isCompleted = status == 'completed' || status == 'finished' || status == 'ended';
    final isCancelled = status == 'cancelled' || status == 'canceled';
    final isExpired = status == 'expired';
    final isActive = status == 'pending' || status == 'driverarriving' || status == 'arrived' || status == 'tripstarted' || status == 'accepted';

    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;
    String statusTitle;
    String statusNote;

    if (isCompleted) {
      badgeColor = const Color(0xFF16A34A);
      badgeBg = const Color(0xFFDCFCE7);
      badgeIcon = Icons.check_circle_rounded;
      statusTitle = isAr ? 'الرحلة مكتملة 🟢' : 'Trip Completed';
      statusNote = isAr ? 'هذه الرحلة انتهت وتم تأكيدها واكتمالها بنجاح.' : 'This trip was completed successfully.';
    } else if (isCancelled) {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEE2E2);
      badgeIcon = Icons.cancel_rounded;
      statusTitle = isAr ? 'الرحلة ملغاة 🔴' : 'Trip Cancelled';
      final cancelledBy = (_tripData?['cancelled_by'] ?? '').toString();
      final who = cancelledBy == 'admin' ? 'الإدارة' : (cancelledBy == 'driver' ? 'الكابتن' : (cancelledBy == 'passenger' ? 'الراكب' : ''));
      statusNote = who.isNotEmpty
          ? (cancelledBy == 'admin' ? 'قامت إدارة inRide بإلغاء هذه الرحلة.' : 'قام $who بإلغاء هذه الرحلة.')
          : (isAr ? 'تم إلغاء هذه الرحلة ولا يمكن المتابعة فيها.' : 'This trip has been cancelled.');
    } else if (isExpired) {
      badgeColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFEF3C7);
      badgeIcon = Icons.timer_off_rounded;
      statusTitle = isAr ? 'انتهت صلاحية الطلب ⏱️' : 'Request Expired';
      statusNote = isAr ? 'انتهت فترة البحث عن كابتن لهذه الرحلة.' : 'Search timeout expired for this trip.';
    } else if (isActive) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFDBEAFE);
      badgeIcon = Icons.directions_car_rounded;
      statusTitle = isAr ? 'الرحلة قيد التنفيذ الآن 🔵' : 'Trip In Progress';
      statusNote = isAr ? 'الرحلة نشطة حالياً ويمكنك متابعة مسارها المباشر.' : 'This trip is currently active.';
    } else {
      badgeColor = const Color(0xFF64748B);
      badgeBg = const Color(0xFFF1F5F9);
      badgeIcon = Icons.info_outline_rounded;
      statusTitle = isAr ? 'حالة الرحلة' : 'Trip Status';
      statusNote = status;
    }

    final pickup = (_tripData?['pickup_address'] ?? '').toString();
    final dest = (_tripData?['destination_address'] ?? '').toString();
    final rawFare = _tripData?['final_fare'] ?? _tripData?['offered_fare'];
    final fare = rawFare != null ? (num.tryParse(rawFare.toString())?.round().toString() ?? rawFare.toString()) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'حالة المشوار اللحظية' : 'Live Trip Status',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      statusTitle,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusNote,
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (pickup.isNotEmpty || dest.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),
            if (pickup.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.radio_button_checked, color: Color(0xFF16A34A), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickup,
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (dest.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFDC2626), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dest,
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (fare != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAr ? 'الأجرة المقدرة:' : 'Fare:',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '$fare ج.م',
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isAr) {
    final status = _tripStatus ?? '';
    final isCompleted = status == 'completed' || status == 'finished' || status == 'ended';
    final isCancelled = status == 'cancelled' || status == 'canceled';
    final isExpired = status == 'expired';
    final isActive = status == 'pending' || status == 'driverarriving' || status == 'arrived' || status == 'tripstarted' || status == 'accepted';

    String buttonLabel;
    IconData buttonIcon;
    VoidCallback onPressed;

    if (isCompleted) {
      buttonLabel = isAr ? 'عرض الرحلة في سجل الرحلات' : 'View in Trip History';
      buttonIcon = Icons.history_rounded;
      onPressed = () {
        Navigator.push(
          context,
          SnappyPageRoute(page: const HistoryPage()),
        );
      };
    } else if (isCancelled || isExpired) {
      buttonLabel = isAr ? 'طلب مشوار جديد' : 'Book New Ride';
      buttonIcon = Icons.directions_car_rounded;
      onPressed = () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      };
    } else if (isActive) {
      buttonLabel = isAr ? 'متابعة الرحلة الحية الآن 🚗' : 'Track Active Trip';
      buttonIcon = Icons.navigation_rounded;
      onPressed = () {
        final reqId = (_tripData?['id'] ?? widget.notification.data['requestId'] ?? widget.notification.data['tripId'])?.toString();
        if (reqId != null) {
          GlobalState.instance.currentRequestId = reqId;
        }
        if (GlobalState.instance.currentRole == UserRole.rider) {
          Navigator.push(
            context,
            SnappyPageRoute(page: const PassengerRideActivePage()),
          );
        } else {
          Navigator.push(
            context,
            SnappyPageRoute(page: const DriverRideActivePage()),
          );
        }
      };
    } else {
      buttonLabel = isAr ? 'الانتقال إلى الصفحة المربوطة' : 'Go to Linked Page';
      buttonIcon = Icons.arrow_forward_rounded;
      onPressed = () {
        final clickData = Map<String, dynamic>.from(widget.notification.data);
        clickData['type'] = widget.notification.type;
        clickData['title'] = widget.notification.title;
        clickData['body'] = widget.notification.body;
        clickData['notification_id'] = widget.notification.id;
        NotificationService.instance.handleNotificationClick(clickData);
      };
    }

    return Container(
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
        icon: Icon(buttonIcon, color: Colors.white),
        label: Text(
          buttonLabel,
          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: onPressed,
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_trip':
        return Icons.directions_car_filled_rounded;
      case 'accept_trip':
      case 'ride_accepted':
        return Icons.check_circle_rounded;
      case 'cancel_trip':
        return Icons.cancel_rounded;
      case 'driver_arrived':
      case 'captain_arrived':
        return Icons.pin_drop_rounded;
      case 'new_message':
      case 'chat_message':
        return Icons.chat_bubble_rounded;
      case 'offers':
      case 'new_offer':
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
      case 'ride_accepted':
        return Colors.green;
      case 'cancel_trip':
        return Colors.red;
      case 'driver_arrived':
      case 'captain_arrived':
        return Colors.teal;
      case 'new_message':
      case 'chat_message':
        return Colors.orange;
      case 'offers':
      case 'new_offer':
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
