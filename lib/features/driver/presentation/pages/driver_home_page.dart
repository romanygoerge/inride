import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/repositories/ride_repository.dart';
import '../../../../core/models/ride_request_model.dart';
import '../../../../core/models/ride_offer.dart';
import '../../../../core/utils/vehicle_helper.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/osm_map_widget.dart';
import '../../../../shared/widgets/exit_prevention_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../core/DI/injection_container.dart' show sl;
import '../../../../core/controllers/notification_controller.dart';
import '../../../../core/services/ride_sound_service.dart';
import 'driver_ride_active_page.dart';
import '../../../common/wallet_page.dart';
import '../../../common/notifications_page.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../core/localization/locale_controller.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool get _isOnline => GlobalState.instance.isDriverOnline;
  List<RideRequestModel> _activeRequests = [];
  StreamSubscription<List<RideRequestModel>>? _requestsSubscription;
  Timer? _staleRequestsTimer;

  final Set<String> _sentOffersRequests = {};
  final Set<String> _dismissedRequestIds = {};
  final Map<String, Future<Map<String, dynamic>?>> _passengerFutures = {};
  final GlobalKey _panelKey = GlobalKey();
  double _panelHeight = 260.0;
  bool _isPanelCollapsed = false;
  bool _isNavigatingToActivePage = false;
  bool _isAcceptingRide = false;

  void _measurePanelHeight() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _panelKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        if ((height - _panelHeight).abs() > 1.0) {
          setState(() {
            _panelHeight = height;
          });
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _getPassengerFuture(String passengerId) {
    return _passengerFutures.putIfAbsent(
      passengerId,
      () => Supabase.instance.client.from('users').select().eq('id', passengerId).maybeSingle(),
    );
  }

  @override
  void initState() {
    super.initState();
    GlobalState.instance.addListener(_onStateChange);
    // Start active if online
    if (_isOnline) {
      _startTracking();
    }
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
      
      final state = GlobalState.instance;
      final isActiveRide = state.rideStatus == RideStatus.driverOnWay ||
                           state.rideStatus == RideStatus.arrived ||
                           state.rideStatus == RideStatus.tripStarted;
      
      // Only navigate if not already navigating AND we are not in the middle of accepting
      // (acceptance flow handles its own navigation after dialog dismissal)
      if (isActiveRide && !_isNavigatingToActivePage && !_isAcceptingRide) {
        final currentRoute = ModalRoute.of(context);
        if (currentRoute != null && currentRoute.isCurrent) {
          _isNavigatingToActivePage = true;
          Navigator.push(
            context,
            SnappyPageRoute(page: const DriverRideActivePage()),
          ).then((_) {
            _isNavigatingToActivePage = false;
          });
        }
      }
    }
  }

  void _updateIncomingRideSound() {
    if (!mounted) return;
    final incomingRequests = _activeRequests.where((req) {
      return !_dismissedRequestIds.contains(req.requestId) && 
             !_sentOffersRequests.contains(req.requestId);
    }).toList();

    if (_isOnline && incomingRequests.isNotEmpty) {
      sl<RideSoundService>().playIncomingRide();
    } else {
      sl<RideSoundService>().stopIncomingRide();
    }
  }

  void _startTracking() async {
    final state = GlobalState.instance;
    if (state.userUid == null) return;

    // Check location permission
    final hasLocPermission = await LocationService.instance.checkPermission();
    if (!hasLocPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى تفعيل صلاحيات الموقع للبدء بالعمل.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Set online and start tracking in GlobalState
    await state.startDriverLocationTracking();

    // 1. Initial immediate REST fetch of pending requests
    try {
      final initialRequests = await RideRepository.instance.fetchPendingRequests();
      if (mounted) {
        _processIncomingRequests(initialRequests);
      }
    } catch (e) {
      debugPrint('[DriverHomePage] Initial fetch error: $e');
    }

    // 2. Stream pending requests via Realtime WebSocket
    debugPrint('[Ride] Listening for new rides...');
    _requestsSubscription?.cancel();
    _requestsSubscription = RideRepository.instance.streamPendingRequests().listen((requests) {
      if (mounted) {
        _processIncomingRequests(requests);
      }
    }, onError: (err) {
      debugPrint('[Ride] Realtime stream error on DriverHomePage: $err');
    });

    // 3. Periodic fallback timer (every 12 seconds) to ensure fresh polling & clear stale
    _staleRequestsTimer?.cancel();
    _staleRequestsTimer = Timer.periodic(const Duration(seconds: 12), (timer) async {
      if (mounted && _isOnline) {
        try {
          final fetched = await RideRepository.instance.fetchPendingRequests();
          if (mounted) {
            _processIncomingRequests(fetched);
          }
        } catch (_) {}
      }
    });
  }

  void _processIncomingRequests(List<RideRequestModel> requests) {
    if (!mounted) return;
    final state = GlobalState.instance;
    final double? myLat = state.driverLatitude ?? MapCoordinatesHelper.deviceLocation?.latitude;
    final double? myLng = state.driverLongitude ?? MapCoordinatesHelper.deviceLocation?.longitude;
    final String rawVehicleType = state.driverVehicleCategory ?? state.vehicleName ?? 'car';
    final String driverVehicleType = VehicleHelper.normalizeVehicleType(rawVehicleType);

    AppLogger.rideLog('DriverHome', 'Processing ${requests.length} incoming pending requests for driver vehicle: $driverVehicleType (raw: $rawVehicleType)');

    final filteredRequests = requests.where((req) {
      // Check vehicle type compatibility
      if (!VehicleHelper.isVehicleTypeMatching(driverVehicleType, req.vehicleType)) {
        AppLogger.rideLog('DriverHomeFilter', 'Filtered out request ${req.requestId} due to vehicle mismatch ($driverVehicleType vs ${req.vehicleType})');
        return false;
      }

      // Check distance radius if coordinates are available
      if (myLat != null && myLng != null) {
        if (req.pickupLatitude == 0.0 || req.pickupLongitude == 0.0) {
          return true; // Don't drop requests if pickup location is 0,0
        }
        final dist = LocationService.instance.calculateDistance(
          req.pickupLatitude, 
          req.pickupLongitude, 
          myLat, 
          myLng
        );
        final bool inRange = dist <= 50.0;
        if (!inRange) {
          AppLogger.rideLog('DriverHomeFilter', 'Filtered out request ${req.requestId} due to distance ($dist km > 50 km)');
        }
        return inRange; // 50 km search radius
      }
      return true; // Don't drop requests while driver location fix is initializing
    }).toList();

    AppLogger.rideLog('DriverHome', 'Filtered to ${filteredRequests.length} matching requests for driver vehicle: $driverVehicleType');

    for (var req in filteredRequests) {
      debugPrint('[Ride] New ride received: ride_id=${req.requestId}');
    }

    final newIds = filteredRequests.map((r) => '${r.requestId}_${r.offeredFare}_${r.status}').join(',');
    final currentIds = _activeRequests.map((r) => '${r.requestId}_${r.offeredFare}_${r.status}').join(',');
    if (newIds != currentIds) {
      setState(() {
        _activeRequests = filteredRequests;
        final activeIds = filteredRequests.map((r) => r.requestId).toSet();
        _sentOffersRequests.retainAll(activeIds);
      });
      _updateIncomingRideSound();
    }
  }

  void _stopTracking() async {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _staleRequestsTimer?.cancel();
    _staleRequestsTimer = null;
    sl<RideSoundService>().stopIncomingRide();
    
    final state = GlobalState.instance;
    await state.stopDriverLocationTracking();
    
    if (mounted) {
      setState(() {
        _activeRequests.clear();
      });
    }
  }

  void _toggleOnlineOffline() {
    final l10n = AppLocalizations.of(context)!;
    if (_isOnline) {
      _stopTracking();
    } else {
      if (GlobalState.instance.isCreditLimitReached) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.creditLimitReached,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      _startTracking();
    }
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _staleRequestsTimer?.cancel();
    GlobalState.instance.removeListener(_onStateChange);
    sl<RideSoundService>().stopIncomingRide();
    super.dispose();
  }

  void _submitBidInline(RideRequestModel req, double fare) async {
    final l10n = AppLocalizations.of(context)!;
    final isCounter = (fare - req.offeredFare).abs() > 0.01;
    
    if (isCounter) {
      // Inline status for counter offers
      setState(() {
        _sentOffersRequests.add(req.requestId);
      });
      _updateIncomingRideSound();
      try {
        await GlobalState.instance.driverSubmitBid(req.requestId, fare, passengerId: req.passengerId);
      } catch (e) {
        setState(() {
          _sentOffersRequests.remove(req.requestId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorSendingOffer(e.toString()), style: GoogleFonts.cairo()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      // Direct accept: atomic RPC call with loading indicator
      BuildContext? dialogContext;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.mediumBlue),
                const SizedBox(height: 20),
                Text(
                  l10n.bookingRide,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      bool acceptSuccess = false;
      try {
        _isAcceptingRide = true;
        // Atomic acceptance using PostgreSQL RPC transaction
        await GlobalState.instance.driverAcceptRide(req.requestId, fare);
        acceptSuccess = true;
      } catch (e) {
        AppLogger.error('DriverAccept', 'Accept error in UI', e);
        if (mounted) {
          final String errorMsg = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        _isAcceptingRide = false;
        // Pop the loading dialog safely
        if (dialogContext != null && dialogContext!.mounted) {
          try {
            Navigator.of(dialogContext!).pop();
          } catch (err) {
            AppLogger.error('DriverAccept', 'Error popping accept dialog context', err);
          }
        }
        // Navigate to active ride page AFTER dialog is dismissed, using postFrameCallback
        // to ensure the widget tree is stable before navigating
        if (acceptSuccess && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isNavigatingToActivePage) return;
            final currentRoute = ModalRoute.of(context);
            if (currentRoute != null && currentRoute.isCurrent) {
              _isNavigatingToActivePage = true;
              Navigator.push(
                context,
                SnappyPageRoute(page: const DriverRideActivePage()),
              ).then((_) {
                _isNavigatingToActivePage = false;
              });
            }
          });
        }
      }
    }
  }

  void _acceptRequest(RideRequestModel req) {
    if (_isAcceptingRide) return;
    _submitBidInline(req, req.offeredFare);
  }

  void _counterOffer(RideRequestModel req, double extra) {
    _submitBidInline(req, req.offeredFare + extra);
  }

  void _showCustomFareDialog(RideRequestModel req) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController customFareController = TextEditingController(text: req.offeredFare.round().toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            l10n.customPriceOffer,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: TextField(
            controller: customFareController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: l10n.egp,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.mediumBlue,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final double? newFare = double.tryParse(customFareController.text);
                if (newFare != null && newFare > 0) {
                  Navigator.pop(context);
                  _submitBidInline(req, newFare);
                }
              },
              child: Text(l10n.sendOffer, style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _measurePanelHeight();
    final state = GlobalState.instance;
    final displayRequests = _activeRequests
        .where((req) => !_dismissedRequestIds.contains(req.requestId))
        .toList();
    return PopScope(
      canPop: state.canExitApplication(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          showExitPreventionAlert(context);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // 1. Map Background
          Positioned.fill(
            child: RepaintBoundary(
              child: OsmMapWidget(bottomPadding: _panelHeight + 16),
            ),
          ),

          if (GlobalState.instance.isOffline)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.amber.shade800,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'لا يوجد اتصال بالإنترنت - الوضع غير المتصل',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Custom App Bar Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + (GlobalState.instance.isOffline ? 36 : 12),
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Drawer Menu Trigger
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
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
                    child: const Icon(Icons.menu, color: AppColors.textPrimary),
                  ),
                ),

                // Online/Offline Toggle Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isOnline ? AppLocalizations.of(context)!.onlineForWork : AppLocalizations.of(context)!.offlineStatus,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: _isOnline,
                        onChanged: (_) => _toggleOnlineOffline(),
                        activeThumbColor: AppColors.success,
                        activeTrackColor: AppColors.success.withValues(alpha: 0.3),
                        inactiveThumbColor: AppColors.textLight,
                        inactiveTrackColor: AppColors.border,
                      ),
                    ],
                  ),
                ),

                // Notifications Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      SnappyPageRoute(page: const NotificationsPage()),
                    );
                  },
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
                    child: ListenableBuilder(
                      listenable: sl<NotificationController>(),
                      builder: (context, _) {
                        final unreadCount = sl<NotificationController>().unreadCount;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_none_outlined,
                              color: AppColors.mediumBlue,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$unreadCount',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Driver Requests Board Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isPanelCollapsed ? -(_panelHeight - 40) : 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! > 5 && !_isPanelCollapsed) {
                  setState(() => _isPanelCollapsed = true);
                } else if (details.primaryDelta! < -5 && _isPanelCollapsed) {
                  setState(() => _isPanelCollapsed = false);
                }
              },
              onTap: () {
                if (_isPanelCollapsed) {
                  setState(() => _isPanelCollapsed = false);
                }
              },
              child: Container(
                key: _panelKey,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isOnline ? AppLocalizations.of(context)!.availableRequestsAround : AppLocalizations.of(context)!.offlineMode,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_isOnline)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (!_isOnline) ...[
                    // Offline screen placeholder
                    const SizedBox(height: 20),
                    const Icon(Icons.notifications_off_outlined, color: AppColors.textLight, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.youAreInactive,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      AppLocalizations.of(context)!.activateToReceive,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ] else if (state.walletBalance <= -100.0) ...[
                    // Warning for negative balance
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.requestsPaused,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.debtLimitMessage,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                SnappyPageRoute(page: const WalletPage()),
                              );
                            },
                            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                            label: Text(
                              AppLocalizations.of(context)!.goToWallet,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mediumBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // List of Requests
                    displayRequests.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30.0),
                            child: Text(
                              'لا توجد طلبات رحلات حالياً في منطقتك...',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: AppColors.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.55,
                            ),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: displayRequests.length,
                                    itemBuilder: (context, index) {
                                      final req = displayRequests[index];
                                      final hasSentOffer = _sentOffersRequests.contains(req.requestId);
                                      return RequestCardWidget(
                                        request: req,
                                        hasSentOffer: hasSentOffer,
                                        onAccept: (r) => _acceptRequest(r),
                                        onDecline: (r) {
                                          setState(() {
                                            _dismissedRequestIds.add(r.requestId);
                                          });
                                          _updateIncomingRideSound();
                                        },
                                        onCounterOffer: (r, addAmount) => _counterOffer(r, addAmount),
                                        onCustomFare: (r) => _showCustomFareDialog(r),
                                        passengerFuture: _getPassengerFuture(req.passengerId),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ],
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

class RequestCardWidget extends StatefulWidget {
  final RideRequestModel request;
  final bool hasSentOffer;
  final Function(RideRequestModel) onAccept;
  final Function(RideRequestModel) onDecline;
  final Function(RideRequestModel, double) onCounterOffer;
  final Function(RideRequestModel) onCustomFare;
  final Future<Map<String, dynamic>?> passengerFuture;

  const RequestCardWidget({
    super.key,
    required this.request,
    required this.hasSentOffer,
    required this.onAccept,
    required this.onDecline,
    required this.onCounterOffer,
    required this.onCustomFare,
    required this.passengerFuture,
  });

  @override
  State<RequestCardWidget> createState() => _RequestCardWidgetState();
}

class _RequestCardWidgetState extends State<RequestCardWidget> {
  late Timer _timer;
  int _secondsLeft = 120;
  late Stream<RideOffer?> _myOfferStream;

  @override
  void initState() {
    super.initState();
    _calculateSecondsLeft();
    _myOfferStream = _streamMyOffer(widget.request.requestId);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateSecondsLeft();
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(RequestCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.requestId != widget.request.requestId) {
      _myOfferStream = _streamMyOffer(widget.request.requestId);
    }
  }

  void _calculateSecondsLeft() {
    final difference = DateTime.now().difference(widget.request.createdAt);
    _secondsLeft = 120 - difference.inSeconds;
    if (_secondsLeft < 0) _secondsLeft = 0;
  }

  Stream<RideOffer?> _streamMyOffer(String requestId) {
    final myId = GlobalState.instance.userUid;
    if (myId == null || myId.isEmpty) return Stream.value(null);
    return Supabase.instance.client
        .from('ride_offers')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .map((list) {
          final myItems = list.where((item) => (item['driver_id'] ?? item['driverId']) == myId).toList();
          if (myItems.isEmpty) return null;
          return RideOffer.fromMap(Map<String, dynamic>.from(myItems.first));
        });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDelivery = req.serviceType == 'delivery';
    final hasSent = widget.hasSentOffer;

    final etaMinutes = (req.distance * 1.5 + 2).round();

    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.passengerFuture,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        String pName = isDelivery ? l10n.packageSender : l10n.passenger;
        double pRating = 5.0;
        String? pAvatar;
        int completedCount = 0;
        
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          pName = data['name'] ?? (isDelivery ? l10n.packageSender : l10n.passenger);
          pRating = ((data['rating'] as num?) ?? 5.0).toDouble();
          pAvatar = data['avatar_url'] ?? data['avatarUrl'] as String?;
          completedCount = ((data['completed_trips'] ?? data['completedTrips'] ?? data['total_trips']) as num? ?? 0).toInt();
        }

        final isNewUser = completedCount < 5;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Badges & Countdown)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Service Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDelivery 
                                ? Colors.orange[50] 
                                : AppColors.mediumBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDelivery 
                                  ? Colors.orange[300]! 
                                  : AppColors.mediumBlue.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isDelivery ? '📦 ${l10n.deliveryOption}' : '🚗 ${l10n.rideOption}',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDelivery ? Colors.orange[800] : AppColors.mediumBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Payment Method Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            req.paymentMethod == 'المحفظة' ? l10n.walletPaymentShort : l10n.cashPaymentShort,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Countdown Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _secondsLeft > 15 
                            ? Colors.amber[50] 
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _secondsLeft > 15 
                              ? Colors.amber[300]! 
                              : Colors.red[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined, 
                            size: 13, 
                            color: _secondsLeft > 15 
                                ? Colors.amber[800] 
                                : Colors.red[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _secondsLeft > 0 ? l10n.timeRemaining(_secondsLeft) : l10n.expired,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _secondsLeft > 15 
                                  ? Colors.amber[800] 
                                  : Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 12, color: AppColors.border),

              // 2. Passenger / Sender Profile details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: pAvatar != null && pAvatar.isNotEmpty 
                          ? CachedNetworkImageProvider(pAvatar) as ImageProvider
                          : null,
                      backgroundColor: AppColors.background,
                      child: pAvatar == null || pAvatar.isEmpty
                          ? const Icon(Icons.person, color: AppColors.textSecondary, size: 24)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pName,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isNewUser) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.newUser,
                                    style: GoogleFonts.cairo(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.orange, size: 13),
                              const SizedBox(width: 2),
                              Text(
                                pRating.toStringAsFixed(1),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•  $completedCount ${isDelivery ? (LocaleController.instance.isArabic ? "طلبات مكتملة" : "completed orders") : (LocaleController.instance.isArabic ? "رحلات مكتملة" : "completed trips")}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
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

              const Divider(height: 12, color: AppColors.border),

              // 3. Pickup / Dropoff details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const Icon(
                          Icons.location_on, 
                          color: AppColors.error, 
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.pickupAddress,
                            style: GoogleFonts.cairo(
                              fontSize: 13, 
                              color: AppColors.textPrimary, 
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            req.destinationAddress,
                            style: GoogleFonts.cairo(
                              fontSize: 13, 
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Distance & ETA Badge
              Builder(
                builder: (context) {
                  final deviceLoc = MapCoordinatesHelper.deviceLocation;
                  final driverLat = deviceLoc?.latitude ?? GlobalState.instance.driverLatitude;
                  final driverLng = deviceLoc?.longitude ?? GlobalState.instance.driverLongitude;

                  double driverToCustomerDistance;
                  bool isFallback = false;
                  
                  if (driverLat != null && driverLng != null) {
                    driverToCustomerDistance = LocationService.instance.calculateDistance(
                      driverLat,
                      driverLng,
                      req.pickupLatitude,
                      req.pickupLongitude,
                    );
                  } else {
                    // Cairo default fallback
                    driverToCustomerDistance = LocationService.instance.calculateDistance(
                      30.0444,
                      31.2357,
                      req.pickupLatitude,
                      req.pickupLongitude,
                    );
                    isFallback = true;
                  }

                  String distText;
                  if (isFallback && driverToCustomerDistance == 0.0) {
                    distText = '1.2 كم';
                  } else if (driverToCustomerDistance > 0.1) {
                    distText = '${driverToCustomerDistance.toStringAsFixed(1)} كم';
                  } else {
                    distText = '${(driverToCustomerDistance * 1000).round()} م';
                  }

                  // Calculate live ETA to reach passenger based on driverToCustomerDistance (average speed 35 km/h)
                  final etaToCustomer = isFallback
                      ? etaMinutes
                      : ((driverToCustomerDistance / 35.0) * 60.0).round().clamp(1, 120);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation_outlined, color: AppColors.mediumBlue, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.distanceToPassenger(
                                distText,
                                req.distance.toStringAsFixed(1),
                                '$etaToCustomer',
                              ),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mediumBlue,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),

              // 4. Delivery Details Container (if Delivery)
              if (isDelivery) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50]!.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: Colors.purple[800], size: 16),
                            const SizedBox(width: 8),
                            Text(
                              l10n.packageDetails,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.packageContent(req.packageDescription ?? l10n.notSpecified),
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        if (req.deliveryNotes != null && req.deliveryNotes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.deliveryInstructions(req.deliveryNotes!),
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.border),

              // 5. Price & Bid Shortcuts & Action Buttons
              StreamBuilder<RideOffer?>(
                stream: _myOfferStream,
                builder: (context, offerSnapshot) {
                  final myOffer = offerSnapshot.data;
                  final bool isCountered = (myOffer?.status == OfferStatus.countered) ||
                      (req.lastCounterDriverId == GlobalState.instance.userUid);
                  final double currentFare = isCountered ? (myOffer?.price ?? req.offeredFare) : req.offeredFare;
                  final activeReq = isCountered ? req.copyWith(offeredFare: currentFare) : req;
                  final bool isSentState = hasSent && !isCountered;

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (!isSentState) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCountered ? l10n.customerCounterOffer : l10n.suggestedFare,
                                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight),
                                  ),
                                  Text(
                                    '${currentFare.round()} ${l10n.egp}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: isCountered ? AppColors.mediumBlue : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _buildCounterOfferButton('+5', 5),
                                  const SizedBox(width: 6),
                                  _buildCounterOfferButton('+10', 10),
                                  const SizedBox(width: 6),
                                  _buildCounterOfferButton('+15', 15),
                                  const SizedBox(width: 6),
                                  
                                  // Custom Fare Button
                                  GestureDetector(
                                    onTap: () => widget.onCustomFare(activeReq),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: const Icon(
                                        Icons.edit, 
                                        size: 16, 
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action Buttons (Accept vs Decline / Sent Offer state)
                        isCountered
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.mediumBlue.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.info_outline, color: AppColors.mediumBlue, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                          l10n.customerSuggestedFare(currentFare.round()),
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.mediumBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Decline Button
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          onPressed: () => widget.onDecline(activeReq),
                                          icon: const Icon(Icons.close_rounded, size: 16),
                                          label: Text(
                                            l10n.skipAction,
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Accept Button
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            gradient: const LinearGradient(
                                              colors: AppColors.blueGradient,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.mediumBlue.withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () => widget.onAccept(activeReq),
                                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                            label: Text(
                                              l10n.acceptNegotiation,
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : (isSentState
                                ? Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          l10n.offerSentWaiting,
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Row(
                                    children: [
                                      // Decline Button
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          onPressed: () => widget.onDecline(activeReq),
                                          icon: const Icon(Icons.close_rounded, size: 16),
                                          label: Text(
                                            l10n.skipAction,
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Accept Button
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            gradient: const LinearGradient(
                                              colors: AppColors.blueGradient,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.mediumBlue.withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () => widget.onAccept(activeReq),
                                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                            label: Text(
                                              l10n.acceptFare,
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildCounterOfferButton(String label, double addAmount) {
    return GestureDetector(
      onTap: () => widget.onCounterOffer(widget.request, addAmount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.mediumBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.15)),
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
