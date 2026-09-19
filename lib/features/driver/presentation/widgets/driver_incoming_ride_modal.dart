import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/ride_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/models/ride_request_model.dart';
import '../../../../core/services/ride_sound_service.dart';
import '../../../../core/DI/injection_container.dart' show sl;
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../pages/driver_ride_active_page.dart';

class DriverIncomingRideModal extends StatefulWidget {
  final RideRequestModel request;
  final VoidCallback? onDismissed;

  const DriverIncomingRideModal({
    super.key,
    required this.request,
    this.onDismissed,
  });

  /// Static helper method to display this modal bottom sheet from anywhere
  static Future<void> show(
    BuildContext context, {
    required RideRequestModel request,
    VoidCallback? onDismissed,
  }) async {
    // Dismiss any existing open popups / dialogs first
    try {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || route is! PopupRoute);
    } catch (_) {}

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) => DriverIncomingRideModal(
        request: request,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<DriverIncomingRideModal> createState() => _DriverIncomingRideModalState();
}

class _DriverIncomingRideModalState extends State<DriverIncomingRideModal> with SingleTickerProviderStateMixin {
  late Timer _countdownTimer;
  int _secondsLeft = 120;
  bool _isSubmitting = false;
  bool _hasSentOffer = false;
  double _currentOfferFare = 0.0;
  Map<String, dynamic>? _passengerData;
  late AnimationController _pulseController;
  StreamSubscription<RideRequestModel?>? _requestSub;

  @override
  void initState() {
    super.initState();
    _currentOfferFare = widget.request.offeredFare;
    _calculateSecondsLeft();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _calculateSecondsLeft();
      if (_secondsLeft <= 0) {
        timer.cancel();
        _dismiss();
      } else {
        setState(() {});
      }
    });

    _fetchPassengerInfo();

    // Listen to real-time status and counter-offers while modal is open
    _requestSub = RideRepository.instance.streamRideRequest(widget.request.requestId).listen((updatedReq) {
      if (!mounted) return;
      if (updatedReq == null) {
        _dismiss();
        return;
      }
      final st = updatedReq.status.trim().toLowerCase();
      final myUid = GlobalState.instance.userUid ?? Supabase.instance.client.auth.currentUser?.id;
      if (st == 'cancelled' || st == 'completed' || 
          (st == 'accepted' && updatedReq.driverId != null && updatedReq.driverId != myUid)) {
        debugPrint('[DriverIncomingRideModal] Ride ${widget.request.requestId} is $st, dismissing modal immediately');
        final isAr = LocaleController.instance.isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              st == 'cancelled' 
                  ? (isAr ? 'تم إلغاء الطلب من قِبل العميل ❌' : 'Ride request cancelled by passenger ❌')
                  : (isAr ? 'تم قبول الطلب من كابتن آخر 🚗' : 'Ride accepted by another driver 🚗'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
        _dismiss();
        return;
      }

      if (myUid != null && updatedReq.lastCounterDriverId == myUid) {
        if (updatedReq.offeredFare != _currentOfferFare) {
          setState(() {
            _currentOfferFare = updatedReq.offeredFare;
            _hasSentOffer = false; // Allow captain to accept or counter again!
          });
          sl<RideSoundService>().playNegotiationAlert();
          final isAr = LocaleController.instance.isArabic;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isAr ? 'اقترح العميل سعراً جديداً: ${updatedReq.offeredFare.round()} ج.م 💰' : 'Passenger proposed a new fare: ${updatedReq.offeredFare.round()} EGP 💰',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.amber.shade900,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  void _calculateSecondsLeft() {
    final diff = DateTime.now().difference(widget.request.createdAt);
    _secondsLeft = 120 - diff.inSeconds;
    if (_secondsLeft < 0) _secondsLeft = 0;
  }

  Future<void> _fetchPassengerInfo() async {
    final pId = widget.request.passengerId;
    if (pId.isEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('name, full_name, avatar_url, rating, completed_trips')
          .eq('id', pId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _passengerData = res;
        });
      }
    } catch (_) {}
  }

  void _dismiss() {
    try {
      sl<RideSoundService>().stopIncomingRide();
    } catch (_) {}
    widget.onDismissed?.call();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _acceptRide() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      try {
        sl<RideSoundService>().stopIncomingRide();
      } catch (_) {}

      // Atomic acceptance via Supabase PostgreSQL transaction
      await GlobalState.instance.driverAcceptRide(
        widget.request.requestId,
        widget.request.offeredFare,
      );

      if (!mounted) return;

      // Close modal sheet
      Navigator.pop(context);

      // Safe transition to active ride screen
      Navigator.push(
        context,
        SnappyPageRoute(page: const DriverRideActivePage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final isAr = LocaleController.instance.isArabic;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg.isNotEmpty ? errorMsg : (isAr ? 'عفواً، تم قبول الرحلة بواسطة كابتن آخر' : 'Ride already accepted by another captain'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      _dismiss();
    }
  }

  Future<void> _sendCounterOffer(double extraFare) async {
    if (_isSubmitting || _hasSentOffer) return;

    final minAllowed = GlobalState.instance.minFare;
    final calculatedFare = widget.request.offeredFare + extraFare;
    final targetFare = calculatedFare < minAllowed ? minAllowed : calculatedFare;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _currentOfferFare = targetFare;
    });

    try {
      await GlobalState.instance.driverSubmitBid(
        widget.request.requestId,
        targetFare,
        passengerId: widget.request.passengerId,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _hasSentOffer = true;
      });

      final isAr = LocaleController.instance.isArabic;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم إرسال عرضك بنجاح (${targetFare.round()} ج.م) بانتظار موافقة العميل ⏳' : 'Offer sent (${targetFare.round()} EGP). Waiting for passenger ⏳',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.cairo()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showCustomPriceDialog() {
    final isAr = LocaleController.instance.isArabic;
    final controller = TextEditingController(text: widget.request.offeredFare.round().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAr ? 'عرض سعر مخصص' : 'Custom Price Offer',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr ? 'حدد السعر المناسب لك لإرساله كعرض للعميل:' : 'Enter your proposed price for this ride:',
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
              decoration: InputDecoration(
                suffixText: isAr ? 'ج.م' : 'EGP',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              final minAllowed = GlobalState.instance.minFare;
              if (val != null && val < minAllowed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAr
                          ? 'الحد الأدنى لأي عرض سعر هو ${minAllowed.round()} ج.م'
                          : 'Minimum offer price is ${minAllowed.round()} EGP',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                controller.text = minAllowed.round().toString();
                return;
              }
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                _sendCounterOffer(val - widget.request.offeredFare);
              }
            },
            child: Text(isAr ? 'إرسال العرض' : 'Send Offer', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _pulseController.dispose();
    _requestSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = LocaleController.instance.isArabic;
    final isDelivery = widget.request.serviceType == 'delivery';
    final pName = _passengerData?['name'] ?? _passengerData?['full_name'] ?? (isDelivery ? (isAr ? 'مرسل الطرد' : 'Package Sender') : (isAr ? 'الراكب' : 'Passenger'));
    final pRating = ((_passengerData?['rating'] as num?) ?? 5.0).toDouble();
    final pAvatar = _passengerData?['avatar_url'] as String?;
    final completedCount = ((_passengerData?['completed_trips'] as num?) ?? 0).toInt();

    final etaMinutes = (widget.request.distance * 1.5 + 2).round();
    final progressPercent = (_secondsLeft / 120.0).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drag Handle
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
          const SizedBox(height: 14),

          // 2. Header Bar: Service Badge & Countdown Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Service badge with pulsing indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDelivery
                          ? Colors.orange.shade50
                          : AppColors.mediumBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDelivery
                            ? Colors.orange.withValues(alpha: 0.4 + 0.3 * _pulseController.value)
                            : AppColors.mediumBlue.withValues(alpha: 0.4 + 0.3 * _pulseController.value),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDelivery ? Icons.local_shipping_rounded : Icons.local_taxi_rounded,
                          size: 16,
                          color: isDelivery ? Colors.orange.shade800 : AppColors.mediumBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDelivery ? (isAr ? 'طلب توصيل جديد 📦' : 'New Delivery 📦') : (isAr ? 'طلب مشوار جديد 🚖' : 'New Ride Request 🚖'),
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDelivery ? Colors.orange.shade900 : AppColors.mediumBlue,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Countdown timer badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _secondsLeft < 30 ? Colors.red.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _secondsLeft < 30 ? Colors.red.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: _secondsLeft < 30 ? Colors.red : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_secondsLeft}s',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _secondsLeft < 30 ? Colors.red : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Countdown Linear Progress Bar
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsLeft < 30 ? Colors.red : AppColors.mediumBlue,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Passenger Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.mediumBlue.withValues(alpha: 0.1),
                  backgroundImage: (pAvatar != null && pAvatar.isNotEmpty)
                      ? CachedNetworkImageProvider(pAvatar)
                      : null,
                  child: (pAvatar == null || pAvatar.isEmpty)
                      ? Text(
                          pName.isNotEmpty ? pName[0] : 'U',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pName,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            pRating.toStringAsFixed(1),
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          if (completedCount > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• $completedCount ${isAr ? "رحلة" : "trips"}',
                              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Trip Distance & Time Chip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation_outlined, size: 12, color: AppColors.mediumBlue),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.request.distance.toStringAsFixed(1)} ${isAr ? "كم" : "km"}',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '~ $etaMinutes ${isAr ? "دقائق" : "mins"}',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Route Addresses Card (Pickup & Destination)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'نقطة الانطلاق (استلام)' : 'Pickup Location',
                            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textLight),
                          ),
                          Text(
                            widget.request.pickupAddress,
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 2, height: 16, color: Colors.grey.shade300),
                    ],
                  ),
                ),
                // Destination
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'الوجهة المحددة' : 'Destination',
                            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textLight),
                          ),
                          Text(
                            widget.request.destinationAddress,
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
          const SizedBox(height: 14),

          // 5. Fare Highlight Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.mediumBlue.withValues(alpha: 0.08),
                  AppColors.darkBlue.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'الأجرة المقترحة من العميل:' : 'Offered Fare:',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      widget.request.paymentMethod == 'wallet'
                          ? (isAr ? '💳 خصم من المحفظة' : '💳 In-App Wallet')
                          : (isAr ? '💵 نقداً (كاش)' : '💵 Cash'),
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  '${widget.request.offeredFare.round()} ${isAr ? "ج.م" : "EGP"}',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.mediumBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 6. Quick Counter-Offer Bar (إذا لم يرسل عرضاً بعد)
          if (!_hasSentOffer) ...[
            Row(
              children: [
                Text(
                  isAr ? 'تفاوض سريع:' : 'Counter-Offer:',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCounterChip('+5 ج.م', 5.0),
                        const SizedBox(width: 6),
                        _buildCounterChip('+10 ج.م', 10.0),
                        const SizedBox(width: 6),
                        _buildCounterChip('+15 ج.م', 15.0),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _showCustomPriceDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined, size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? 'سعر آخر' : 'Custom',
                                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'تم تقديم عرضك (${_currentOfferFare.round()} ج.م). بانتظار موافقة العميل...'
                          : 'Your counter-offer (${_currentOfferFare.round()} EGP) was sent. Waiting for passenger...',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 7. Action Buttons (Accept vs Decline)
          Row(
            children: [
              // Decline Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    onPressed: _isSubmitting ? null : _dismiss,
                    child: Text(
                      isAr ? 'تجاهل ❌' : 'Decline ❌',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Accept Button (or waiting indicator)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)], // Vibrant Emerald Green
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSubmitting ? null : _acceptRide,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  isAr ? 'قبول المشوار ✅' : 'Accept Ride ✅',
                                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterChip(String label, double extra) {
    return InkWell(
      onTap: _isSubmitting ? null : () => _sendCounterOffer(extra),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.mediumBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.mediumBlue,
          ),
        ),
      ),
    );
  }
}
