import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/snappy_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../shared/widgets/osm_map_widget.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import 'driver_home_page.dart';
import '../../../../shared/widgets/camera_capture_dialog.dart';
import '../../../../shared/widgets/exit_prevention_dialog.dart';
import '../../../../core/DI/injection_container.dart' show sl;
import '../../../../core/services/trip_navigation_manager.dart';
import '../../../../core/controllers/navigation_controller.dart';
import '../../../../core/services/external_navigation_service.dart';
import '../../../../core/DI/injection_container.dart';
import '../../../../core/controllers/navigation_state_manager.dart';
import '../../../../core/services/driver_location_service.dart';
import 'package:latlong2/latlong.dart' show LatLng;

class DriverRideActivePage extends StatefulWidget {
  const DriverRideActivePage({super.key});

  @override
  State<DriverRideActivePage> createState() => _DriverRideActivePageState();
}

class _DriverRideActivePageState extends State<DriverRideActivePage> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();

  RideStatus? _lastRideStatus;
  bool _isPanelCollapsed = false;
  bool _isCompleting = false;
  bool _isSubmittingRating = false;

  String? _passengerName;
  String? _passengerPhone;
  String? _lastPassengerId;

  @override
  void initState() {
    super.initState();
    GlobalState.instance.addListener(_onStateChange);
    sl<NavigationController>().addListener(_onNavigationUpdate);
    _lastRideStatus = GlobalState.instance.rideStatus;
    _fetchPassengerDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartNavigation();
    });
  }

  void _safeNavigateBack({String? message}) {
    if (!mounted) return;

    // Stop driver location service updates
    if (GlobalState.instance.userUid != null) {
      try {
        sl<DriverLocationService>().stopLocationUpdates(GlobalState.instance.userUid!);
      } catch (_) {}
    }

    // Dismiss open modal dialogs / bottom sheets
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
          SnappyPageRoute(page: const DriverHomePage()),
          (route) => false,
        );
      }
    }
  }

  void _fetchPassengerDetails() async {
    final state = GlobalState.instance;
    final pId = state.activePassengerId ?? state.currentRideRequest?.passengerId;
    if (pId != null && pId.isNotEmpty) {
      try {
        final uRes = await Supabase.instance.client
            .from('users')
            .select('name, phone_number, phone')
            .eq('id', pId)
            .maybeSingle();
        if (uRes != null && mounted) {
          setState(() {
            _passengerName = (uRes['name'] ?? '').toString();
            final phone = (uRes['phone_number'] ?? uRes['phone'] ?? '').toString();
            if (phone.isNotEmpty) {
              _passengerPhone = phone;
            }
          });
        }
      } catch (e) {
        debugPrint('[DriverPage] Error fetching passenger details: $e');
      }
    }
    
    if ((_passengerPhone == null || _passengerPhone!.isEmpty) && state.currentRideRequest != null) {
      final reqPhone = state.currentRideRequest?.recipientPhone;
      if (reqPhone != null && reqPhone.isNotEmpty && mounted) {
        setState(() {
          _passengerPhone = reqPhone;
        });
      }
    }
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
        final message = 'أنا كابتن في تطبيق inRide وعلى الطريق حالياً. يمكنك تتبع موقعي المباشر على الخريطة من هنا: $shareUrl';
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

  void _onStateChange() {
    final state = GlobalState.instance;

    // Refetch passenger details if ID changes
    final pId = state.activePassengerId ?? state.currentRideRequest?.passengerId;
    if (pId != _lastPassengerId) {
      _lastPassengerId = pId;
      _fetchPassengerDetails();
    }
    if (state.rideStatus == RideStatus.cancelled) {
      final msg = state.lastCancelReason ?? 'تم إلغاء الرحلة بواسطة العميل';
      _safeNavigateBack(message: msg);
      return;
    }

    if (state.rideStatus == RideStatus.completed || _lastRideStatus == RideStatus.completed || _isSubmittingRating) {
      if (_lastRideStatus != RideStatus.completed && mounted) {
        _lastRideStatus = RideStatus.completed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنهاء الرحلة بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {});
      }
      return;
    }

    if (state.rideStatus != _lastRideStatus) {
      _lastRideStatus = state.rideStatus;
      _checkAndStartNavigation();
    }
    if (mounted) setState(() {});
  }

  void _onNavigationUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _commentController.dispose();
    GlobalState.instance.removeListener(_onStateChange);
    sl<NavigationController>().removeListener(_onNavigationUpdate);
    super.dispose();
  }

  void _checkAndStartNavigation() {
    final state = GlobalState.instance;
    final navManager = sl<TripNavigationManager>();

    if (state.rideStatus == RideStatus.driverOnWay ||
        state.rideStatus == RideStatus.arrived ||
        state.rideStatus == RideStatus.tripStarted) {
      final deviceLoc = MapCoordinatesHelper.deviceLocation;
      final startLatLng = deviceLoc != null
          ? LatLng(deviceLoc.latitude, deviceLoc.longitude)
          : const LatLng(30.0130, 31.2080);
      
      final isHeadingToPickup = state.rideStatus == RideStatus.driverOnWay;
      
      LatLng endLatLng;
      LatLng? finalDestLatLng;

      if (state.currentRideRequest != null) {
        final req = state.currentRideRequest!;
        if (isHeadingToPickup) {
          endLatLng = LatLng(req.pickupLatitude, req.pickupLongitude);
          finalDestLatLng = LatLng(req.destinationLatitude, req.destinationLongitude);
        } else {
          endLatLng = LatLng(req.destinationLatitude, req.destinationLongitude);
        }
      } else {
        // Fallback to text parsing (less accurate)
        final targetAddress = isHeadingToPickup ? state.fromAddress : state.toAddress;
        final targetLoc = MapCoordinatesHelper.getLatLngForAddress(targetAddress);
        endLatLng = LatLng(targetLoc.latitude, targetLoc.longitude);

        if (isHeadingToPickup) {
          final finalDestLoc = MapCoordinatesHelper.getLatLngForAddress(state.toAddress);
          finalDestLatLng = LatLng(finalDestLoc.latitude, finalDestLoc.longitude);
        }
      }

      if (state.currentRequestId != null) {
        // Prevent restarting navigation if we are already navigating to the correct target destination.
        // This ensures the transition from "arrived" to "tripStarted" is seamless and doesn't reload the map.
        final alreadyNavigatingToTarget = navManager.isNavigating &&
            navManager.targetDestination?.latitude == endLatLng.latitude &&
            navManager.targetDestination?.longitude == endLatLng.longitude;

        if (!alreadyNavigatingToTarget) {
          navManager.startTracking(
            rideId: state.currentRequestId!,
            status: state.rideStatus,
            start: startLatLng,
            end: endLatLng,
            finalDestination: finalDestLatLng,
          );
        }
      }
    } else {
      navManager.stopNavigation();
    }
  }

  Widget _buildHeaderCard(GlobalState state) {
    // Status card for tracking mode
    return Card(
      color: state.rideStatus == RideStatus.tripStarted ? AppColors.mediumBlue : Colors.white,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              state.rideStatus == RideStatus.tripStarted ? Icons.navigation : Icons.info_outline,
              color: state.rideStatus == RideStatus.tripStarted ? Colors.white : AppColors.mediumBlue,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(state.rideStatus),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: state.rideStatus == RideStatus.tripStarted ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    state.rideStatus == RideStatus.driverOnWay
                        ? (state.currentServiceType == 'delivery'
                            ? 'اتبع المسار بالخريطة للوصول لنقطة استلام الطرد'
                            : 'اتبع المسار بالخريطة للوصول للراكب')
                        : (state.rideStatus == RideStatus.arrived
                            ? (state.currentServiceType == 'delivery'
                                ? 'استلم الطرد من العميل ثم اضغط بدء التوصيل'
                                : 'انتظر الراكب حتى يركب ثم اضغط بدء')
                            : (state.currentServiceType == 'delivery'
                                ? 'قم بتوصيل الطرد للوجهة المحددة بأمان'
                                : 'قم بإيصال الراكب للوجهة المحددة بأمان')),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: state.rideStatus == RideStatus.tripStarted ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary,
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

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.driverOnWay:
        return 'توجه إلى نقطة الالتقاء بالراكب';
      case RideStatus.arrived:
        return 'لقد وصلت لنقطة الالتقاء!';
      case RideStatus.tripStarted:
        return 'الرحلة جارية الآن إلى الوجهة';
      case RideStatus.completed:
        return 'تم إتمام الرحلة بنجاح!';
      default:
        return 'رحلة نشطة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final isCompleted = state.rideStatus == RideStatus.completed || _lastRideStatus == RideStatus.completed || _isSubmittingRating;

    return PopScope(
      canPop: state.canExitApplication(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          showExitPreventionAlert(context);
        }
      },
      child: Scaffold(
        body: Stack(
        children: [
          // 1. Map Navigation
          const Positioned.fill(
            child: OsmMapWidget(showPOIs: false),
          ),

          // 2. Header Alert Card or Navigation HUD
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildHeaderCard(state),
          ),

          // Street name is now integrated in the NavigationHudWidget info strip

          // 3. Bottom Panel (Actions & Details)
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
                  if (!isCompleted) ...[
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
                                    state.currentServiceType == 'delivery' ? '📦 توصيل الطرد قيد التنفيذ' : '🚗 رحلة نشطة جارية',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.mediumBlue,
                                    ),
                                  ),
                                  Text(
                                    '${state.offeredFare.round()} ج.م',
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
                                if (sl<TripNavigationManager>().isNavigating) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatColumn(
                                        icon: Icons.access_time_rounded,
                                        value: sl<NavigationController>().formattedETA,
                                        label: LocaleController.instance.isArabic ? 'وقت الوصول' : 'ETA',
                                        valueColor: AppColors.mediumBlue,
                                      ),
                                      Container(height: 32, width: 1, color: AppColors.border),
                                      _buildStatColumn(
                                        icon: Icons.navigation_rounded,
                                        value: sl<NavigationController>().formattedRemainingDistance,
                                        label: LocaleController.instance.isArabic ? 'المسافة المتبقية' : 'Remaining',
                                        valueColor: AppColors.darkBlue,
                                      ),
                                      Container(height: 32, width: 1, color: AppColors.border),
                                      _buildStatColumn(
                                        icon: Icons.speed_rounded,
                                        value: '${sl<NavigationController>().speedKmH.round()} ${LocaleController.instance.isArabic ? "كم/س" : "km/h"}',
                                        label: LocaleController.instance.isArabic ? 'السرعة الحالية' : 'Speed',
                                        valueColor: Colors.redAccent,
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24, color: AppColors.border),
                                ],
                                // Rider Info Row
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.background,
                                      child: Icon(Icons.person, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_passengerName ?? (state.currentServiceType == 'delivery' ? (LocaleController.instance.isArabic ? "العميل" : "Customer") : (LocaleController.instance.isArabic ? "الراكب" : "Passenger"))} (${state.currentServiceType == 'delivery' ? (LocaleController.instance.isArabic ? "طلب توصيل" : "Delivery") : (LocaleController.instance.isArabic ? "راكب" : "Rider")})',
                                            style: GoogleFonts.cairo(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (_passengerPhone != null && _passengerPhone!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            GestureDetector(
                                              onTap: () async {
                                                final Uri url = Uri(scheme: 'tel', path: _passengerPhone);
                                                if (await canLaunchUrl(url)) {
                                                  await launchUrl(url);
                                                }
                                              },
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.phone_iphone, size: 14, color: AppColors.mediumBlue),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _passengerPhone!,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.mediumBlue,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else
                                            Row(
                                              children: [
                                                const Icon(Icons.star, color: Colors.orange, size: 12),
                                                const SizedBox(width: 2),
                                                Text(
                                                  state.acceptedOffer?.driver.rating.toStringAsFixed(1) ?? '5.0',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
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
                                        String? phone = state.activePassengerPhone ?? state.currentRideRequest?.recipientPhone;

                                        if (phone == null || phone.isEmpty) {
                                          final pId = state.activePassengerId ?? state.currentRideRequest?.passengerId;
                                          if (pId != null && pId.isNotEmpty) {
                                            try {
                                              final uRes = await Supabase.instance.client.from('users').select('phone_number, phone').eq('id', pId).maybeSingle();
                                              phone = (uRes?['phone_number'] ?? uRes?['phone'] ?? '').toString();
                                            } catch (_) {}
                                          }
                                        }

                                        if (phone != null && phone.isNotEmpty) {
                                          final Uri url = Uri(scheme: 'tel', path: phone);
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        } else {
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  LocaleController.instance.isArabic ? 'رقم العميل غير متوفر حالياً' : 'Customer phone unavailable',
                                                  style: GoogleFonts.cairo(),
                                                ),
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
                                        if (state.currentRequestId != null && state.userUid != null && state.activePassengerId != null) {
                                          Navigator.push(
                                            context,
                                            SnappyPageRoute(
                                              page: ChatPage(
                                                tripId: state.currentRequestId!,
                                                myId: state.userUid!,
                                                partnerId: state.activePassengerId!,
                                                partnerName: _passengerName ?? (LocaleController.instance.isArabic ? 'الراكب' : 'Passenger'),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share_location_outlined, color: Colors.green),
                                      tooltip: LocaleController.instance.isArabic ? 'مشاركة موقعي المباشر' : 'Share Live Location',
                                      onPressed: _shareLiveLocation,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                      tooltip: LocaleController.instance.isArabic ? 'طوارئ النجدة ١٢٢' : 'Emergency SOS 122',
                                      onPressed: _callEmergency,
                                    ),
                                  ],
                                ),
                                const Divider(height: 20, color: AppColors.border),

                                // Route details
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined, color: AppColors.mediumBlue, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${LocaleController.instance.isArabic ? "من:" : "From:"} ${state.fromAddress ?? (LocaleController.instance.isArabic ? "موقع الالتقاء" : "Pickup Location")}',
                                        style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.flag_outlined, color: AppColors.darkBlue, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${LocaleController.instance.isArabic ? "إلى:" : "To:"} ${state.toAddress ?? (LocaleController.instance.isArabic ? "الوجهة" : "Destination")}',
                                        style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.route_outlined, color: AppColors.textSecondary, size: 18),
                                    const SizedBox(width: 8),
                                    Builder(
                                      builder: (context) {
                                        final isUnconfirmed = state.currentServiceType == 'delivery' &&
                                            state.currentRideRequest != null &&
                                            !state.currentRideRequest!.isDeliveryLocationConfirmed;

                                        if (isUnconfirmed) {
                                          return Text(
                                            LocaleController.instance.isArabic ? 'المسافة الكلية: قيد التحديد من المستلم' : 'Total Distance: Pending recipient confirmation',
                                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                          );
                                        }

                                        final activeRoute = sl<NavigationStateManager>().activeRoute;
                                        if (activeRoute != null && activeRoute.distance > 0) {
                                          final distanceKm = activeRoute.distance / 1000;
                                          return Text(
                                            '${LocaleController.instance.isArabic ? "المسافة الكلية:" : "Total Distance:"} ${distanceKm.toStringAsFixed(1)} ${LocaleController.instance.isArabic ? "كم" : "km"}',
                                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                          );
                                        } else {
                                          return Text(
                                            LocaleController.instance.isArabic ? 'المسافة الكلية: جاري الحساب...' : 'Total Distance: Calculating...',
                                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                          );
                                        }
                                      }
                                    ),
                                  ],
                                ),
                                if (state.currentServiceType == 'ride' && state.currentPassengerCount != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.people_outline, color: AppColors.mediumBlue, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${LocaleController.instance.isArabic ? "عدد الأفراد:" : "Passengers:"} ${state.currentPassengerCount}',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (state.currentServiceType == 'delivery') ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkBlue.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.darkBlue.withValues(alpha: 0.15)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📦 ${LocaleController.instance.isArabic ? "طرد التوصيل:" : "Package:"} ${state.currentPackageDescription ?? (LocaleController.instance.isArabic ? "غير محدد" : "Not specified")}',
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkBlue,
                                          ),
                                        ),
                                        if (state.currentDeliveryNotes != null && state.currentDeliveryNotes!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${LocaleController.instance.isArabic ? "تعليمات العميل:" : "Instructions:"} ${state.currentDeliveryNotes}',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (state.currentPickupPhotoUrl != null || state.currentDeliveryPhotoUrl != null) ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              if (state.currentPickupPhotoUrl != null)
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        LocaleController.instance.isArabic ? 'صورة الاستلام:' : 'Pickup Photo:',
                                                        style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
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
                                                        LocaleController.instance.isArabic ? 'صورة التسليم:' : 'Delivery Photo:',
                                                        style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
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
                                      ],
                                    ),
                                  ),
                                ],
                                const Divider(height: 20, color: AppColors.border),

                                // Fare Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          LocaleController.instance.isArabic ? 'طريقة الدفع' : 'Payment Method',
                                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                                        ),
                                        Text(
                                          state.activeRidePaymentMethod ?? (LocaleController.instance.isArabic ? 'كاش' : 'Cash'),
                                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          LocaleController.instance.isArabic ? 'إجمالي الأجرة المتوقعة' : 'Expected Total Fare',
                                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                                        ),
                                        Text(
                                          '${state.offeredFare.round()} ${LocaleController.instance.isArabic ? "ج.م" : "EGP"}',
                                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.mediumBlue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                    ),

                    // Primary State Button (Gradient Blue)
                    Builder(
                      builder: (context) {
                        final bool isLocationUnconfirmed = state.rideStatus == RideStatus.arrived &&
                            state.currentServiceType == 'delivery' &&
                            state.currentRideRequest != null &&
                            !state.currentRideRequest!.isDeliveryLocationConfirmed;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isLocationUnconfirmed) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red[300]!, width: 1.2),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'بانتظار تحديد موقع المستلم. لا يمكنك بدء التوصيل حتى يقوم المستلم بتحديد موقعه الجغرافي.',
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Two External Navigation Buttons
                            Builder(
                              builder: (context) {
                                LatLng? pickupTarget;
                                LatLng? destinationTarget;

                                if (state.currentRideRequest != null) {
                                  pickupTarget = LatLng(state.currentRideRequest!.pickupLatitude, state.currentRideRequest!.pickupLongitude);
                                  destinationTarget = LatLng(state.currentRideRequest!.destinationLatitude, state.currentRideRequest!.destinationLongitude);
                                } else {
                                  final pickupLoc = MapCoordinatesHelper.getLatLngForAddress(state.fromAddress);
                                  final destLoc = MapCoordinatesHelper.getLatLngForAddress(state.toAddress);
                                  pickupTarget = LatLng(pickupLoc.latitude, pickupLoc.longitude);
                                  destinationTarget = LatLng(destLoc.latitude, destLoc.longitude);
                                }

                                final bool isGoingToPickup = state.rideStatus == RideStatus.driverOnWay;
                                final bool isGoingToDestination = state.rideStatus == RideStatus.tripStarted;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: isGoingToPickup ? Colors.green.shade600 : Colors.grey.shade400,
                                          boxShadow: isGoingToPickup
                                              ? [BoxShadow(color: Colors.green.shade200, blurRadius: 8, offset: const Offset(0, 4))]
                                              : [],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: isGoingToPickup
                                              ? () {
                                                  ExternalNavigationService.launchNavigation(context, pickupTarget!.latitude, pickupTarget.longitude, isHeadingToPickup: true);
                                                }
                                              : null,
                                          icon: Icon(Icons.navigation, color: isGoingToPickup ? Colors.white : Colors.white70),
                                          label: Text(
                                            'إلى الراكب',
                                            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: isGoingToPickup ? Colors.white : Colors.white70),
                                            textAlign: TextAlign.center,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            disabledBackgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          color: isGoingToDestination ? Colors.blue.shade600 : Colors.grey.shade400,
                                          boxShadow: isGoingToDestination
                                              ? [BoxShadow(color: Colors.blue.shade200, blurRadius: 8, offset: const Offset(0, 4))]
                                              : [],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: isGoingToDestination
                                              ? () {
                                                  ExternalNavigationService.launchNavigation(context, destinationTarget!.latitude, destinationTarget.longitude, isHeadingToPickup: false);
                                                }
                                              : null,
                                          icon: Icon(Icons.navigation, color: isGoingToDestination ? Colors.white : Colors.white70),
                                          label: Text(
                                            'إلى الوجهة',
                                            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: isGoingToDestination ? Colors.white : Colors.white70),
                                            textAlign: TextAlign.center,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            disabledBackgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: isLocationUnconfirmed
                                      ? null
                                      : const LinearGradient(
                                          colors: AppColors.blueGradient,
                                        ),
                                  color: isLocationUnconfirmed ? Colors.grey[300] : null,
                                ),
                                child: ElevatedButton(
                                  onPressed: isLocationUnconfirmed
                                      ? null
                                      : () async {
                                          if (state.rideStatus == RideStatus.driverOnWay) {
                                            state.arriveAtPickup();
                                          } else if (state.rideStatus == RideStatus.arrived) {
                                            if (state.currentServiceType == 'delivery') {
                                              showDialog<String>(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => const CameraCaptureDialog(
                                                  title: 'تصوير الطرد عند الاستلام 📸',
                                                  isPickup: true,
                                                ),
                                              ).then((photoUrl) async {
                                                if (photoUrl != null && photoUrl.isNotEmpty) {
                                                  await state.submitPickupPhoto(photoUrl);
                                                  await state.startTrip();
                                                }
                                              });
                                            } else {
                                              state.startTrip();
                                            }
                                          } else if (state.rideStatus == RideStatus.tripStarted) {
                                            if (_isCompleting) return;
                                            _isCompleting = true;
                                            if (state.currentServiceType == 'delivery') {
                                              showDialog<String>(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => const CameraCaptureDialog(
                                                  title: 'تصوير الطرد عند التسليم 📸',
                                                  isPickup: false,
                                                ),
                                              ).then((photoUrl) async {
                                                if (photoUrl != null && photoUrl.isNotEmpty) {
                                                  await state.submitDeliveryPhoto(photoUrl);
                                                  await state.completeTrip();
                                                } else {
                                                  _isCompleting = false;
                                                }
                                              });
                                            } else {
                                              await state.completeTrip();
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    disabledForegroundColor: Colors.grey[600],
                                    disabledBackgroundColor: Colors.transparent,
                                  ),
                                  child: Text(
                                    state.rideStatus == RideStatus.driverOnWay
                                        ? (state.currentServiceType == 'delivery'
                                            ? 'أنا هنا (وصلت لموقع الاستلام)'
                                            : 'أنا هنا (وصلت لموقع الراكب)')
                                        : (state.rideStatus == RideStatus.arrived
                                            ? (state.currentServiceType == 'delivery' ? 'بدء التوصيل الآن' : 'بدء الرحلة الآن')
                                            : (state.currentServiceType == 'delivery' ? 'تأكيد تسليم الطرد' : 'إنهاء الرحلة بنجاح')),
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isLocationUnconfirmed ? Colors.grey[600] : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            
                            if (state.rideStatus == RideStatus.driverOnWay || state.rideStatus == RideStatus.arrived || state.rideStatus == RideStatus.tripStarted)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TextButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('إلغاء الرحلة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                        content: Text('هل أنت متأكد من إلغاء الرحلة؟', style: GoogleFonts.cairo()),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text('تراجع', style: GoogleFonts.cairo(color: Colors.grey)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context); // Pop the dialog only
                                              state.cancelRide(cancelledBy: 'driver', reason: 'تم الإلغاء بواسطة الكابتن');
                                            },
                                            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  label: Text('إلغاء الرحلة', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                          ],
                        );
                      }
                    ),
                  ] else ...[
                    // Completed Screen Info & Rating Form
                    const Icon(Icons.check_circle, color: AppColors.success, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      state.currentServiceType == 'delivery' ? 'تم توصيل الطرد بنجاح!' : 'تم إتمام الرحلة بنجاح!',
                      style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final double price = state.offeredFare;
                        final double commission = price * ((state.appSettings['commissionRate'] ?? 20.0) / 100.0);
                        if (state.activeRidePaymentMethod == 'المحفظة') {
                          return Text(
                            state.currentServiceType == 'delivery'
                                ? 'تم إضافة ${(price - commission).round()} ج.م إلى محفظتك بنجاح قيمة التوصيل.'
                                : 'تم إضافة ${(price - commission).round()} ج.م إلى محفظتك بنجاح (بعد خصم العمولة).',
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          );
                        } else {
                          return Text(
                            state.currentServiceType == 'delivery'
                                ? 'يرجى تحصيل ${price.round()} ج.م نقداً من العميل قيمة التوصيل.\n(تم خصم عمولة قدرها ${commission.round()} ج.م من محفظتك)'
                                : 'يرجى تحصيل ${price.round()} ج.م نقداً من الراكب.\n(تم خصم عمولة قدرها ${commission.round()} ج.م من محفظتك)',
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          );
                        }
                      },
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    Text(
                      state.currentServiceType == 'delivery'
                          ? 'كيف كانت تجربتك مع العميل؟'
                          : 'كيف كانت تجربتك مع الراكب؟',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        return IconButton(
                          icon: Icon(
                            _rating >= starIndex ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              _rating = starIndex.toDouble();
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: state.currentServiceType == 'delivery'
                            ? 'اكتب تعليقك عن العميل هنا...'
                            : 'اكتب تعليقك عن الراكب هنا...',
                        hintStyle: GoogleFonts.cairo(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: GoogleFonts.cairo(fontSize: 13),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                        ),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSubmittingRating
                            ? null
                            : () async {
                                setState(() {
                                  _isSubmittingRating = true;
                                });
                                final passId = state.activePassengerId ?? state.currentRideRequest?.passengerId;
                                final navigator = Navigator.of(context);
                                await state.submitRating(
                                  _rating,
                                  _commentController.text,
                                  targetUserId: passId,
                                  targetRole: 'rider',
                                );
                                if (mounted) {
                                  navigator.pushAndRemoveUntil(
                                    SnappyPageRoute(page: const DriverHomePage()),
                                    (route) => false,
                                  );
                                }
                              },
                        child: Text(
                          'إرسال التقييم والبحث عن رحلة أخرى',
                          style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
