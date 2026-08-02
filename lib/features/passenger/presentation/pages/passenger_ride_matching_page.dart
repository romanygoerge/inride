import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/utils/vehicle_helper.dart';
import '../../../../shared/widgets/osm_map_widget.dart';
import 'passenger_ride_active_page.dart';
import 'passenger_home_page.dart';
import '../../../../generated/app_localizations.dart';


class PassengerRideMatchingPage extends StatefulWidget {
  const PassengerRideMatchingPage({super.key});

  @override
  State<PassengerRideMatchingPage> createState() => _PassengerRideMatchingPageState();
}

class _PassengerRideMatchingPageState extends State<PassengerRideMatchingPage> {
  // Guards to prevent double-navigation and repeated cancel presses
  bool _isCancelling = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    GlobalState.instance.addListener(_onStateChange);
  }

  void _safeNavigateBack({String? message}) {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;

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
          MaterialPageRoute(builder: (context) => const PassengerHomePage()),
          (route) => false,
        );
      }
    }
  }

  void _onStateChange() {
    if (!mounted || _isNavigating) return;

    try {
      setState(() {});
      
      final state = GlobalState.instance;
      if (state.rideStatus == RideStatus.driverOnWay && state.acceptedOffer != null) {
        _isNavigating = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PassengerRideActivePage()),
        );
      } else if (state.rideStatus == RideStatus.cancelled) {
        final l10n = AppLocalizations.of(context)!;
        final msg = state.lastCancelReason ?? l10n.rideCancelled;
        _safeNavigateBack(message: msg);
      } else if (state.rideStatus == RideStatus.expired) {
        if (!_isCancelling) {
          final l10n = AppLocalizations.of(context)!;
          _safeNavigateBack(message: l10n.rideExpiredNoDrivers);
        }
      }
    } catch (e) {
      debugPrint('[RideMatchingPage._onStateChange] Error: $e');
    }
  }

  @override
  void dispose() {
    GlobalState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  /// Handles ride cancellation with proper sequencing and guards
  Future<void> _handleCancelRide() async {
    // Prevent double-tap
    if (_isCancelling || _isNavigating) return;
    
    setState(() {
      _isCancelling = true;
    });

    try {
      debugPrint('[TripLifecycle] Cancel button pressed on PassengerRideMatchingPage');
      final l10n = AppLocalizations.of(context)!;
      await GlobalState.instance.cancelRide(
        cancelledBy: 'passenger',
        reason: l10n.cancelledByCustomer,
      );
      _safeNavigateBack(message: l10n.requestCancelledSuccess);
    } catch (e) {
      debugPrint('[RideMatchingPage] Error during cancel: $e');
      _safeNavigateBack();
    }
  }

  void _shareLink(BuildContext context, String link) {
    final l10n = AppLocalizations.of(context)!;
    // Show user-friendly warning SnackBar to encourage app installation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.shareLocationInstall,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: AppColors.mediumBlue,
        duration: const Duration(seconds: 4),
      ),
    );

    final message = l10n.shareLocationMessage(link);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${l10n.shareLocationLink} 🔗',
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareButton(
                    icon: Icons.chat_bubble_outline,
                    color: Colors.green,
                    label: 'WhatsApp',
                    onTap: () async {
                      Navigator.pop(context);
                      final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        final webUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
                        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  _buildShareButton(
                    icon: Icons.sms_outlined,
                    color: Colors.blue,
                    label: 'SMS',
                    onTap: () async {
                      Navigator.pop(context);
                      final url = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                  ),
                  _buildShareButton(
                    icon: Icons.copy_outlined,
                    color: Colors.grey[700]!,
                    label: l10n.copy,
                    onTap: () async {
                      Navigator.pop(context);
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.linkCopied, style: GoogleFonts.cairo()),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = GlobalState.instance;
    final isSearching = state.rideStatus == RideStatus.searching;

    return PopScope(
      // Allow pop but do NOT call cancelRide() here.
      // The cancel button and back button handler already manage cancellation.
      // Calling cancelRide() here caused triple cancellation (root cause #4).
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // If popped via system back button (not via our cancel button),
        // trigger cancellation only if not already cancelling
        if (didPop && !_isCancelling && !_isNavigating) {
          _isCancelling = true;
          GlobalState.instance.cancelRide();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Custom painted active route map
            const Positioned.fill(
              child: OsmMapWidget(showPOIs: false),
            ),

          // 2. Back button / Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: _handleCancelRide,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward_ios_outlined, color: AppColors.textPrimary, size: 20),
              ),
            ),
          ),

          // 3. Top Info Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.mediumBlue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isSearching
                            ? (state.currentServiceType == 'delivery'
                                ? AppLocalizations.of(context)!.searchingForDrivers
                                : AppLocalizations.of(context)!.searchingForDrivers)
                            : (state.currentServiceType == 'delivery'
                                ? AppLocalizations.of(context)!.offersReceived
                                : AppLocalizations.of(context)!.offersReceived),
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (state.currentServiceType == 'delivery' && state.currentRideRequest != null && !state.currentRideRequest!.isDeliveryLocationConfirmed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 145,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.amber[50],
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.amber, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.share_location_outlined, color: Colors.amber, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.confirmRecipientLocation,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.shareLocationInstall,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final token = state.currentRideRequest?.recipientToken ?? state.currentRecipientToken ?? '';
                                final shareLink = 'https://inride.app/confirm-delivery-location?requestId=${state.currentRequestId}&token=$token';
                                _shareLink(context, shareLink);
                              },
                              icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                              label: Text(
                                AppLocalizations.of(context)!.shareLocationLink,
                                style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mediumBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Bottom panel containing loading or driver list
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
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isSearching) ...[
                    // Pulse Loader & Searching UI
                    const SizedBox(height: 20),
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumBlue),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)!.searchingForDrivers,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.searchingForDrivers,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    // Drivers Bids lists
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppLocalizations.of(context)!.offersReceived} (${state.driverOffers.length})',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.acceptOffer,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Bid list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.driverOffers.length,
                      itemBuilder: (context, index) {
                        final offer = state.driverOffers[index];
                        return _buildDriverOfferCard(context, offer);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Cancel ride button - disabled during cancellation
                  ElevatedButton(
                    onPressed: _isCancelling ? null : _handleCancelRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCancelling
                          ? Colors.grey[200]
                          : AppColors.error.withValues(alpha: 0.05),
                      foregroundColor: _isCancelling ? Colors.grey : AppColors.error,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _isCancelling ? Colors.grey : AppColors.error,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _isCancelling
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(context)!.loading,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            AppLocalizations.of(context)!.cancelRide,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildDriverOfferCard(BuildContext context, DriverOffer offer) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Avatar + Driver Info + Price ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(offer.driver.avatar),
                  backgroundColor: AppColors.background,
                ),
                const SizedBox(width: 10),

                // Driver Name & Vehicle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Rating
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              offer.driver.name,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            '${offer.driver.rating.toStringAsFixed(1)}${offer.driver.ratingCount > 0 ? " (${offer.driver.ratingCount} تقييم)" : ""}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Trips & Deliveries
                      Text(
                        '${offer.driver.completedTrips} رحلة مكتملة',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Vehicle info badge (Car vs Motorcycle vs Scooter)
                      Builder(
                        builder: (context) {
                          final rawType = offer.driver.vehicleType;
                          final vType = VehicleHelper.normalizeVehicleType(rawType);
                          final isCar = vType == 'car';
                          final label = VehicleHelper.getArabicLabel(rawType);
                          final vehicleName = offer.driver.vehicleName;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isCar ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCar ? AppColors.mediumBlue.withValues(alpha: 0.25) : Colors.orange.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCar ? Icons.directions_car_rounded : Icons.two_wheeler_rounded,
                                  size: 13,
                                  color: isCar ? AppColors.mediumBlue : Colors.orange[800],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$label • $vehicleName',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isCar ? AppColors.mediumBlue : Colors.orange[900],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Price + ETA
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${offer.price.round()} ج.م',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.mediumBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: AppColors.success),
                          const SizedBox(width: 3),
                          Text(
                            '${offer.etaMinutes} د',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Divider
            Container(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
            const SizedBox(height: 12),

            // Distance & Time details section
            Builder(
              builder: (context) {
                final req = GlobalState.instance.currentRideRequest;
                final tripDistance = req?.distance ?? 5.0;
                final tripDuration = (tripDistance * 2.0).round().clamp(2, 120);
                
                final driverToPickupDistance = (offer.etaMinutes * 0.6).clamp(0.5, 10.0);
                
                return Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المسافة إليك:',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            '${driverToPickupDistance.toStringAsFixed(1)} كم (يصل خلال ${offer.etaMinutes} د)',
                            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'مسافة الرحلة للوجهة:',
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            '${tripDistance.toStringAsFixed(1)} كم (تستغرق ~$tripDuration د)',
                            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
            ),

            // ── Row 2: Action Buttons (Reject / Counter / Accept) ──
            Row(
              children: [
                // Reject Button
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      // Skip this driver's offer
                      GlobalState.instance.skipDriver(offer.driverId);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        color: AppColors.error.withValues(alpha: 0.05),
                      ),
                      child: Center(
                        child: Text(
                          'رفض',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Counter-Offer Button
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => _showCounterOfferDialog(context, offer),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.4)),
                        color: AppColors.mediumBlue.withValues(alpha: 0.05),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.currency_exchange_rounded, size: 16, color: AppColors.mediumBlue),
                            const SizedBox(width: 4),
                            Text(
                              'تفاوض',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mediumBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Accept Button (Gradient)
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () {
                      GlobalState.instance.acceptDriverOffer(offer);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mediumBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'قبول',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
      ),
    );
  }

  /// Shows a dialog for the passenger to submit a counter-offer price
  void _showCounterOfferDialog(BuildContext context, DriverOffer offer) {
    final controller = TextEditingController(text: offer.price.round().toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'تفاوض على السعر',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'عرض الكابتن ${offer.driver.name} الحالي: ${offer.price.round()} ج.م',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Price Input
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mediumBlue,
                ),
                decoration: InputDecoration(
                  suffixText: 'ج.م',
                  suffixStyle: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                  hintText: 'اكتب السعر',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 16,
                    color: AppColors.textLight,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.mediumBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Quick price adjustment buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <int>[-10, -5, 5, 10].map((int amount) {
                  final bool isNegative = amount < 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        final current = double.tryParse(controller.text) ?? offer.price;
                        final double minFare = (GlobalState.instance.appSettings['minFare'] as num?)?.toDouble() ?? 10.0;
                        final double maxFare = (GlobalState.instance.appSettings['maxFare'] as num?)?.toDouble() ?? 500.0;
                        final newValue = (current + amount).clamp(minFare, maxFare);
                        controller.text = newValue.round().toString();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isNegative
                              ? AppColors.error.withValues(alpha: 0.08)
                              : AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isNegative
                                ? AppColors.error.withValues(alpha: 0.3)
                                : AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${amount > 0 ? "+" : ""}$amount',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isNegative ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    final newPrice = double.tryParse(controller.text);
                    if (newPrice != null && newPrice > 0) {
                      Navigator.pop(ctx);
                      try {
                        // Send counter-offer to Firestore so driver receives it
                        await GlobalState.instance.submitCounterOffer(offer.driverId, newPrice);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم إرسال عرضك: ${newPrice.round()} ج.م للكابتن ${offer.driver.name}',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'فشل إرسال العرض. حاول مرة أخرى.',
                                style: GoogleFonts.cairo(),
                              ),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: AppColors.blueGradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mediumBlue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'إرسال العرض',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
