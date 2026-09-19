import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/state/global_state.dart';
import '../../core/utils/snappy_page_route.dart';
import '../../features/common/history_page.dart';
import '../../features/passenger/presentation/pages/passenger_ride_active_page.dart';
import '../../features/driver/presentation/pages/driver_ride_active_page.dart';
import '../../core/services/notification_service.dart';

enum TripStatusDisplayType {
  completed,
  cancelled,
  expired,
  active,
  notFound,
}

class TripStatusSheet extends StatefulWidget {
  final String? requestId;
  final Map<String, dynamic>? initialData;

  const TripStatusSheet({
    super.key,
    this.requestId,
    this.initialData,
  });

  /// Opens the TripStatusSheet modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    String? requestId,
    Map<String, dynamic>? initialData,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripStatusSheet(
        requestId: requestId,
        initialData: initialData,
      ),
    );
  }

  @override
  State<TripStatusSheet> createState() => _TripStatusSheetState();
}

class _TripStatusSheetState extends State<TripStatusSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _tripData;
  TripStatusDisplayType _statusType = TripStatusDisplayType.notFound;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _tripData = widget.initialData;
      _statusType = _resolveStatus(_tripData!['status']?.toString());
      _isLoading = false;
    } else if (widget.requestId != null && widget.requestId!.isNotEmpty) {
      _fetchTripData(widget.requestId!);
    } else {
      _isLoading = false;
      _statusType = TripStatusDisplayType.notFound;
    }
  }

  Future<void> _fetchTripData(String reqId) async {
    try {
      final res = await Supabase.instance.client
          .from('ride_requests')
          .select()
          .eq('id', reqId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _tripData = res != null ? Map<String, dynamic>.from(res) : null;
          if (_tripData != null) {
            _statusType = _resolveStatus(_tripData!['status']?.toString());
          } else {
            _statusType = TripStatusDisplayType.notFound;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[TripStatusSheet] Error fetching trip: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusType = TripStatusDisplayType.notFound;
        });
      }
    }
  }

  TripStatusDisplayType _resolveStatus(String? status) {
    if (status == null) return TripStatusDisplayType.notFound;
    final s = status.trim().toLowerCase();
    if (s == 'completed' || s == 'finished' || s == 'ended') {
      return TripStatusDisplayType.completed;
    }
    if (s == 'cancelled' || s == 'canceled') {
      return TripStatusDisplayType.cancelled;
    }
    if (s == 'expired') {
      return TripStatusDisplayType.expired;
    }
    if (s == 'pending' || s == 'driverarriving' || s == 'arrived' || s == 'tripstarted' || s == 'accepted') {
      return TripStatusDisplayType.active;
    }
    return TripStatusDisplayType.completed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.mediumBlue),
                ),
              )
            else
              _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final data = _tripData ?? {};
    final pickup = (data['pickup_address'] ?? data['pickupAddress'] ?? 'نقطة الانطلاق').toString();
    final dest = (data['destination_address'] ?? data['destinationAddress'] ?? 'نقطة الوصول').toString();
    final rawFare = data['final_fare'] ?? data['offered_fare'] ?? data['offeredFare'] ?? data['fare'] ?? data['price'];
    final fare = rawFare != null ? (num.tryParse(rawFare.toString())?.round().toString() ?? rawFare.toString()) : null;
    final paymentMethod = (data['payment_method'] ?? data['paymentMethod'] ?? 'كاش').toString();
    final cancelledBy = (data['cancelled_by'] ?? data['cancelledBy'] ?? '').toString().toLowerCase();
    final cancelReason = (data['cancel_reason'] ?? data['cancellation_reason'] ?? data['reason'] ?? '').toString();
    final createdAtStr = (data['created_at'] ?? data['createdAt'] ?? '').toString();

    // Visual attributes based on status
    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;
    String statusTitle;
    String statusSubtitle;

    switch (_statusType) {
      case TripStatusDisplayType.completed:
        badgeColor = const Color(0xFF16A34A); // Emerald green
        badgeBg = const Color(0xFFDCFCE7);
        badgeIcon = Icons.check_circle_rounded;
        statusTitle = 'هذه الرحلة مكتملة';
        statusSubtitle = 'تم إنهاء وتأكيد هذه الرحلة بنجاح في وقت سابق.';
        break;
      case TripStatusDisplayType.cancelled:
        badgeColor = const Color(0xFFDC2626); // Crimson red
        badgeBg = const Color(0xFFFEE2E2);
        badgeIcon = Icons.cancel_rounded;
        statusTitle = 'هذه الرحلة ملغاة';
        final who = cancelledBy == 'admin' ? 'الإدارة' : (cancelledBy == 'driver' ? 'الكابتن' : (cancelledBy == 'passenger' ? 'الراكب' : ''));
        statusSubtitle = who.isNotEmpty
            ? (cancelledBy == 'admin' ? 'قامت إدارة inRide بإلغاء هذه الرحلة ولا يمكن المتابعة فيها.' : 'قام $who بإلغاء هذه الرحلة ولا يمكن المتابعة فيها.')
            : 'تم إلغاء هذه الرحلة ولا يمكن المتابعة فيها.';
        break;
      case TripStatusDisplayType.expired:
        badgeColor = const Color(0xFFD97706); // Amber
        badgeBg = const Color(0xFFFEF3C7);
        badgeIcon = Icons.timer_off_rounded;
        statusTitle = 'انتهت صلاحية الطلب';
        statusSubtitle = 'انتهت فترة البحث عن كابتن لهذا المشوار دون تطابق.';
        break;
      case TripStatusDisplayType.active:
        badgeColor = const Color(0xFF2563EB); // Royal Blue
        badgeBg = const Color(0xFFDBEAFE);
        badgeIcon = Icons.directions_car_rounded;
        statusTitle = 'الرحلة جارية حالياً';
        statusSubtitle = 'هذه الرحلة نشطة ويمكنك متابعة مسارها المباشر الآن.';
        break;
      case TripStatusDisplayType.notFound:
        badgeColor = const Color(0xFF64748B);
        badgeBg = const Color(0xFFF1F5F9);
        badgeIcon = Icons.info_outline_rounded;
        statusTitle = 'تفاصيل الرحلة غير متوفرة';
        statusSubtitle = 'قد تكون هذه الرحلة قديمة جداً أو تمت أرشفتها.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Icon & Status Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusTitle,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Subtitle note
        Text(
          statusSubtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),

        // Trip Route Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Pickup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.radio_button_checked, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نقطة الانطلاق',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          pickup,
                          style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Container(width: 2, height: 18, color: Colors.grey.shade300),
                  ],
                ),
              ),
              // Destination
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.location_on, color: Color(0xFFDC2626), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وجهة الوصول',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          dest,
                          style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Metadata grid (Fare, Date, Cancellation Reason)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              if (fare != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الأجرة:', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      '$fare ج.م ($paymentMethod)',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const Divider(height: 16, color: AppColors.border),
              ],
              if (createdAtStr.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تاريخ الطلب:', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      _formatDate(createdAtStr),
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ],
              if (_statusType == TripStatusDisplayType.cancelled && cancelReason.isNotEmpty) ...[
                const Divider(height: 16, color: AppColors.border),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('سبب الإلغاء:', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.error)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cancelReason,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (_statusType == TripStatusDisplayType.active) {
      final isDriver = GlobalState.instance.currentRole == UserRole.driver;
      final rawStatus = (_tripData?['status'] ?? '').toString().trim().toLowerCase();
      final isPending = rawStatus == 'pending' || rawStatus == 'searching';
      final myUid = GlobalState.instance.userUid;
      final assignedDriverId = _tripData?['driver_id']?.toString();

      String buttonLabel = 'متابعة الرحلة الحية الآن 🚗';
      IconData buttonIcon = Icons.navigation_rounded;
      VoidCallback onPressed = () {
        Navigator.pop(context);
        final reqId = widget.requestId ?? _tripData?['id']?.toString();
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

      if (isDriver && isPending) {
        buttonLabel = 'عرض تفاصيل الطلب وتقديم عرض 🚖';
        buttonIcon = Icons.local_taxi_rounded;
        onPressed = () {
          Navigator.pop(context);
          final reqId = widget.requestId ?? _tripData?['id']?.toString();
          if (reqId != null) {
            NotificationService.instance.handleNotificationClick({
              'requestId': reqId,
              'type': 'new_trip',
            });
          }
        };
      } else if (isDriver && assignedDriverId != myUid) {
        buttonLabel = 'تم قبول المشوار لكابتن آخر 🚖';
        buttonIcon = Icons.info_outline;
        onPressed = () {
          Navigator.pop(context);
        };
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    if (_statusType == TripStatusDisplayType.completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              label: Text(
                'عرض في سجل الرحلات',
                style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  SnappyPageRoute(page: const HistoryPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.mediumBlue, size: 18),
            label: Text(
              'طلب رحلة جديدة',
              style: GoogleFonts.cairo(color: AppColors.mediumBlue, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      );
    }

    // Cancelled or Expired or NotFound
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
            icon: const Icon(Icons.directions_car_rounded, color: Colors.white),
            label: Text(
              'طلب مشوار جديد',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إغلاق',
            style: GoogleFonts.cairo(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final arMonths = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${arMonths[dt.month - 1]} ${dt.year} - $hour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }
}
