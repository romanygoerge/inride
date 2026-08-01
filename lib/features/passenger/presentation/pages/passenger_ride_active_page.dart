import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../shared/widgets/osm_map_widget.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import 'passenger_home_page.dart';

class PassengerRideActivePage extends StatefulWidget {
  const PassengerRideActivePage({super.key});

  @override
  State<PassengerRideActivePage> createState() => _PassengerRideActivePageState();
}

class _PassengerRideActivePageState extends State<PassengerRideActivePage> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    GlobalState.instance.addListener(_onStateChange);
  }

  void _callEmergency() async {
    final Uri url = Uri(scheme: 'tel', path: '122');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إجراء اتصال الطوارئ بالرقم 122', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _shareLiveLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('جاري جلب إحداثيات موقعك الجغرافي لمشاركته لايف... 📍', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.mediumBlue,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final pos = await LocationService.instance.getCurrentLocation();
      if (pos != null) {
        final shareUrl = 'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
        final message = 'أنا في رحلة حالياً عبر تطبيق inRide. يمكنك تتبع موقعي المباشر على الخريطة من هنا: $shareUrl';
        await SharePlus.instance.share(
          ShareParams(text: message),
        );
      } else {
        throw 'تعذر الحصول على الموقع الجغرافي الحالي. تأكد من تشغيل الـ GPS.';
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _safeNavigateBack({String? message}) {
    if (!mounted) return;

    // Pop any open modal dialogs / bottom sheets
    try {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || route is! PopupRoute);
    } catch (_) {}

    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
    }

    GlobalState.instance.resetRide(silent: true);

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          SnappyPageRoute(page: const PassengerHomePage()),
          (route) => false,
        );
      }
    }
  }

  void _onStateChange() {
    final state = GlobalState.instance;
    if (state.rideStatus == RideStatus.cancelled) {
      final msg = state.lastCancelReason ?? 'تم إلغاء الرحلة';
      _safeNavigateBack(message: msg);
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _commentController.dispose();
    GlobalState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  String _getStatusText(RideStatus status) {
    final isDelivery = GlobalState.instance.currentServiceType == 'delivery';
    switch (status) {
      case RideStatus.driverOnWay:
        return isDelivery ? 'الكابتن في طريقه للاستلام' : 'السائق في الطريق إليك';
      case RideStatus.arrived:
        return isDelivery ? 'وصل الكابتن لاستلام الطرد!' : 'وصل السائق إلى موقعك!';
      case RideStatus.tripStarted:
        return isDelivery ? 'جاري توصيل الطرد...' : 'رحلتك جارية الآن...';
      case RideStatus.completed:
        return isDelivery ? 'تم توصيل الطرد بالسلامة!' : 'وصلت بالسلامة!';
      default:
        return isDelivery ? 'طلب التوصيل النشط' : 'رحلتك النشطة';
    }
  }

  IconData _getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.driverOnWay:
        return Icons.directions_run;
      case RideStatus.arrived:
        return Icons.pin_drop_rounded;
      case RideStatus.tripStarted:
        return Icons.navigation;
      case RideStatus.completed:
        return Icons.check_circle;
      default:
        return Icons.local_taxi;
    }
  }

  String? _cachedRideId;
  Stream<List<Map<String, dynamic>>>? _liveEtaStream;

  /// Builds a StreamBuilder that reads real-time ETA and remaining distance
  /// from the RideRequest document in Firestore (written by driver's NavigationManager).
  Widget _buildLiveETABar(GlobalState state) {
    final rideId = state.currentRequestId;
    if (rideId == null) return const SizedBox.shrink();

    if (_cachedRideId != rideId) {
      _cachedRideId = rideId;
      _liveEtaStream = Supabase.instance.client
          .from('ride_requests')
          .stream(primaryKey: ['id'])
          .eq('id', rideId);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _liveEtaStream,
      builder: (context, snapshot) {
        int etaMinutes = 5;
        double remainingKm = 0.0;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final data = snapshot.data!.first;
          etaMinutes = (data['eta_minutes'] ?? data['etaMinutes'] ?? 5 as num).toInt();
          remainingKm = ((data['remaining_distance_km'] ?? data['remainingDistanceKm'] ?? 0.0) as num).toDouble();
        }



        // Live calculation if driver location is available
        if (state.driverLatitude != null && state.driverLongitude != null) {
          final req = state.currentRideRequest;
          if (state.rideStatus == RideStatus.driverOnWay) {
            final pickupLat = req?.pickupLatitude ?? MapCoordinatesHelper.getLatLngForAddress(state.fromAddress).latitude;
            final pickupLng = req?.pickupLongitude ?? MapCoordinatesHelper.getLatLngForAddress(state.fromAddress).longitude;
            remainingKm = LocationService.instance.calculateDistance(
              state.driverLatitude!,
              state.driverLongitude!,
              pickupLat,
              pickupLng,
            );
            // Estimate ETA: distance / 35 km/h average speed in city * 60 mins
            etaMinutes = ((remainingKm / 35.0) * 60.0).round().clamp(1, 45);
          } else if (state.rideStatus == RideStatus.tripStarted) {
            final destLat = req?.destinationLatitude ?? MapCoordinatesHelper.getLatLngForAddress(state.toAddress).latitude;
            final destLng = req?.destinationLongitude ?? MapCoordinatesHelper.getLatLngForAddress(state.toAddress).longitude;
            remainingKm = LocationService.instance.calculateDistance(
              state.driverLatitude!,
              state.driverLongitude!,
              destLat,
              destLng,
            );
            // Estimate ETA: distance / 40 km/h average speed * 60 mins
            etaMinutes = ((remainingKm / 40.0) * 60.0).round().clamp(1, 60);
          }
        }

        // Format ETA
        String etaText;
        if (etaMinutes < 1) {
          etaText = 'أقل من دقيقة';
        } else if (etaMinutes < 60) {
          etaText = '$etaMinutes د';
        } else {
          final hours = etaMinutes ~/ 60;
          final mins = etaMinutes % 60;
          etaText = mins > 0 ? '$hours س $mins د' : '$hours س';
        }

        // Format remaining distance
        String distText;
        if (remainingKm > 0.1) {
          distText = '${remainingKm.toStringAsFixed(1)} كم';
        } else if (remainingKm > 0) {
          distText = '${(remainingKm * 1000).round()} م';
        } else {
          distText = '--';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ETA
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.mediumBlue),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'وقت الوصول',
                        style: GoogleFonts.cairo(fontSize: 9, color: AppColors.textLight),
                      ),
                      Text(
                        etaText,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(height: 30, width: 1, color: AppColors.border),
              // Distance
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.straighten_rounded, size: 16, color: AppColors.darkBlue),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'المسافة المتبقية',
                        style: GoogleFonts.cairo(fontSize: 9, color: AppColors.textLight),
                      ),
                      Text(
                        distText,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(height: 30, width: 1, color: AppColors.border),
              // Status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.rideStatus == RideStatus.tripStarted ? 'في الطريق' : 'متصل',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final offer = state.acceptedOffer;
    
    if (offer == null) {
      return const Scaffold(body: Center(child: Text('خطأ: لا يوجد سائق مقبول')));
    }

    final isCompleted = state.rideStatus == RideStatus.completed;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && state.rideStatus != RideStatus.completed && state.rideStatus != RideStatus.cancelled) {
          state.cancelRide();
        }
      },
      child: Scaffold(
        body: Stack(
        children: [
          // 1. Navigation Map
          const Positioned.fill(
            child: OsmMapWidget(showPOIs: false),
          ),

          // 2. Header Status Alert
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Card(
              color: state.rideStatus == RideStatus.arrived ? AppColors.success : Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(state.rideStatus),
                      color: state.rideStatus == RideStatus.arrived ? Colors.white : AppColors.mediumBlue,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(state.rideStatus),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: state.rideStatus == RideStatus.arrived ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            state.rideStatus == RideStatus.driverOnWay
                                ? (state.currentServiceType == 'delivery'
                                    ? 'يصل الكابتن قريباً'
                                    : 'يصل السائق قريباً')
                                : (state.rideStatus == RideStatus.arrived
                                    ? (state.currentServiceType == 'delivery'
                                        ? 'يرجى تسليم الطرد للكابتن لبدء التوصيل'
                                        : 'يرجى التوجه إلى مركبة السائق والركوب')
                                    : (state.currentServiceType == 'delivery'
                                        ? 'نتمنى توصيلاً سهلاً وسريعاً مع inRide'
                                        : 'نتمنى لك رحلة سعيدة وآمنة مع inRide')),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: state.rideStatus == RideStatus.arrived ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2.5 Live ETA/Distance bar (during driverOnWay or tripStarted)
          if (state.rideStatus == RideStatus.driverOnWay || state.rideStatus == RideStatus.tripStarted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 16,
              right: 16,
              child: _buildLiveETABar(state),
            ),

          // 3. Bottom Panel (Driver Detail & Controls)
          if (!isCompleted)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Collapsible Drag Handle
                    GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity! > 0) {
                          setState(() {
                            _isPanelCollapsed = true;
                          });
                        } else if (details.primaryVelocity! < 0) {
                          setState(() {
                            _isPanelCollapsed = false;
                          });
                        }
                      },
                      onTap: () {
                        setState(() {
                          _isPanelCollapsed = !_isPanelCollapsed;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isPanelCollapsed
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    state.currentServiceType == 'delivery' ? '📦 تتبع التوصيل النشط' : '🚗 رحلتك جارية الآن',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.mediumBlue,
                                    ),
                                  ),
                                  Text(
                                    '${offer.price.round()} ج.م',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppColors.mediumBlue,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 12),
                                // Driver Info Block
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: CachedNetworkImageProvider(offer.driver.avatar),
                                      backgroundColor: AppColors.background,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            offer.driver.name,
                                            style: GoogleFonts.cairo(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.orange, size: 14),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${offer.driver.rating.toStringAsFixed(1)} (${offer.driver.completedTrips} رحلة • ${offer.driver.completedDeliveries} ديلفري)',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.call, color: AppColors.mediumBlue),
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        String phone = offer.driver.phoneNumber;
                                        if (phone.isEmpty && offer.driverId.isNotEmpty) {
                                          try {
                                            final uRes = await Supabase.instance.client.from('users').select('phone_number, phone').eq('id', offer.driverId).maybeSingle();
                                            phone = (uRes?['phone_number'] ?? uRes?['phone'] ?? '').toString();
                                            if (phone.isEmpty) {
                                              final dRes = await Supabase.instance.client.from('drivers').select('phone_number, phone').eq('id', offer.driverId).maybeSingle();
                                              phone = (dRes?['phone_number'] ?? dRes?['phone'] ?? '').toString();
                                            }
                                          } catch (_) {}
                                        }

                                        if (phone.isNotEmpty) {
                                          final Uri url = Uri(scheme: 'tel', path: phone);
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        } else {
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text('رقم الكابتن غير متوفر حالياً', style: GoogleFonts.cairo()),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.mediumBlue),
                                      onPressed: () {
                                        if (state.currentRequestId != null && state.userUid != null) {
                                          Navigator.push(
                                            context,
                                            SnappyPageRoute(
                                              page: ChatPage(
                                                tripId: state.currentRequestId!,
                                                myId: state.userUid!,
                                                partnerId: offer.driverId,
                                                partnerName: offer.driver.name,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share_location_outlined, color: Colors.green),
                                      tooltip: 'مشاركة موقعي المباشر',
                                      onPressed: _shareLiveLocation,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                      tooltip: 'طوارئ النجدة ١٢٢',
                                      onPressed: _callEmergency,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Vehicle Detail Block
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        offer.driver.vehicleType == 'scooter'
                                            ? Icons.electric_scooter
                                            : offer.driver.vehicleType == 'motorcycle'
                                                ? Icons.motorcycle
                                                : Icons.directions_car_filled,
                                        color: AppColors.mediumBlue,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              offer.driver.vehicleName,
                                              style: GoogleFonts.cairo(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              offer.driver.vehicleColor,
                                              style: GoogleFonts.cairo(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.textPrimary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          offer.driver.licensePlate,
                                          style: GoogleFonts.cairo(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 24, color: AppColors.border),

                                // Cost and Details
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'طريقة الدفع',
                                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
                                        ),
                                        Text(
                                          state.activeRidePaymentMethod ?? 'كاش',
                                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'المسافة المقدرة',
                                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final startLatLng = MapCoordinatesHelper.getLatLngForAddress(state.fromAddress);
                                            final endLatLng = MapCoordinatesHelper.getLatLngForAddress(state.toAddress);
                                            final distance = LocationService.instance.calculateDistance(
                                              startLatLng.latitude,
                                              startLatLng.longitude,
                                              endLatLng.latitude,
                                              endLatLng.longitude,
                                            );
                                            return Text(
                                              '${distance.toStringAsFixed(1)} كم',
                                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            );
                                          }
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          state.currentServiceType == 'delivery' ? 'تكلفة التوصيل' : 'تكلفة الرحلة',
                                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textLight),
                                        ),
                                        Text(
                                          '${offer.price.round()} ج.م',
                                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.mediumBlue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (state.currentServiceType == 'delivery' && (state.currentPickupPhotoUrl != null || state.currentDeliveryPhotoUrl != null)) ...[
                                  const Divider(height: 24, color: AppColors.border),
                                  Text(
                                    'صور طرد التوصيل 📦',
                                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (state.currentPickupPhotoUrl != null)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'عند الاستلام:',
                                                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                                              ),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: state.currentPickupPhotoUrl!,
                                                  height: 80,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (state.currentPickupPhotoUrl != null && state.currentDeliveryPhotoUrl != null)
                                        const SizedBox(width: 12),
                                      if (state.currentDeliveryPhotoUrl != null)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'عند التسليم:',
                                                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                                              ),
                                              const SizedBox(height: 4),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: state.currentDeliveryPhotoUrl!,
                                                  height: 80,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // Option to Cancel
                                if (state.rideStatus == RideStatus.driverOnWay || state.rideStatus == RideStatus.arrived)
                                  ElevatedButton(
                                    onPressed: () {
                                      state.cancelRide(cancelledBy: 'passenger', reason: 'تم الإلغاء بواسطة العميل');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error.withValues(alpha: 0.05),
                                      foregroundColor: AppColors.error,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: AppColors.error),
                                      ),
                                    ),
                                    child: Text(
                                      state.currentServiceType == 'delivery' ? 'إلغاء التوصيل' : 'إلغاء الرحلة',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Rating overlay once completed
          if (isCompleted)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.success,
                            child: Icon(Icons.check, color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            state.currentServiceType == 'delivery' ? 'تم التوصيل بنجاح!' : 'وصلت بالسلامة!',
                            style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            state.activeRidePaymentMethod == 'المحفظة'
                                ? (state.currentServiceType == 'delivery'
                                    ? 'تم خصم قيمة التوصيل ${offer.price.round()} ج.م من محفظتك بنجاح.'
                                    : 'تم خصم ${offer.price.round()} ج.م من محفظتك بنجاح.')
                                : (state.currentServiceType == 'delivery'
                                    ? 'يرجى دفع قيمة التوصيل ${offer.price.round()} ج.م نقداً للكابتن.'
                                    : 'يرجى دفع ${offer.price.round()} ج.م نقداً للسائق.'),
                            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(height: 32),
                          Text(
                            'كيف كانت تجربتك مع ${offer.driver.name}؟',
                            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          
                          // 5 Stars selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < _rating ? Icons.star : Icons.star_border,
                                  color: Colors.orange,
                                  size: 32,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _rating = index + 1.0;
                                  });
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          
                          // Comment field
                          TextField(
                            controller: _commentController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'اكتب تعليقك هنا (اختياري)...',
                              fillColor: AppColors.background,
                            ),
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          
                          // Submit feedback button (Gradient blue)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: AppColors.blueGradient,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final driverId = state.acceptedOffer?.driverId ?? state.currentRideRequest?.driverId;
                                state.submitRating(
                                  _rating,
                                  _commentController.text,
                                  targetUserId: driverId,
                                  targetRole: 'driver',
                                );
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                'إرسال التقييم وإنهاء',
                                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

}
