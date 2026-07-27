import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../shared/widgets/app_drawer.dart';

import '../../../../shared/widgets/scale_button.dart';
import '../../../../shared/widgets/osm_map_widget.dart';
import '../../../../shared/widgets/exit_prevention_dialog.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../core/DI/injection_container.dart' show sl;
import '../../../../core/controllers/notification_controller.dart';
import 'passenger_ride_matching_page.dart';
import 'passenger_delivery_booking_page.dart';
import '../../../common/notifications_page.dart';

enum PassengerMode { dashboard, rideBooking, deliveryBooking }

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  PassengerMode _mode = PassengerMode.dashboard;
  bool _showVehicleSelection = false;

  // Locations input
  String get _fromText => GlobalState.instance.fromAddress ?? '';
  String get _toText => GlobalState.instance.toAddress ?? '';
  
  // Fare input
  final TextEditingController _fareController = TextEditingController(text: '15');

  // Selected vehicle details
  String _selectedVehicle = 'motorcycle'; // motorcycle only now
  
  int _passengerCount = 1;

  @override
  void initState() {
    super.initState();
    GlobalState.instance.addListener(_onStateChange);
    // Request location permissions and cache current position early
    _initializeLocation();
    // Initialize default pickup and destination in GlobalState if they are null
    GlobalState.instance.fromAddress ??= 'موقعي الحالي';
    GlobalState.instance.toAddress ??= '';
  }

  void _initializeLocation() async {
    final hasPermission = await LocationService.instance.checkPermission();
    if (hasPermission) {
      await LocationService.instance.getCurrentLocation();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fareController.dispose();
    GlobalState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  double _getDefaultFare(String vehicle) {
    if (_fromText.isNotEmpty && _toText.isNotEmpty && _fromText != 'موقعي الحالي' && _toText != 'حدد وجهتك') {
      final startLatLng = MapCoordinatesHelper.getLatLngForAddress(_fromText);
      final endLatLng = MapCoordinatesHelper.getLatLngForAddress(_toText);
      final distance = LocationService.instance.calculateDistance(
        startLatLng.latitude,
        startLatLng.longitude,
        endLatLng.latitude,
        endLatLng.longitude,
      );
      return GlobalState.instance.calculateEstimatedFare(
        distanceInKm: distance,
        vehicleType: vehicle,
        hasAC: vehicle == 'car', // Car gets AC fare by default in estimates
      );
    }

    final settings = GlobalState.instance.appSettings;
    switch (vehicle) {
      case 'scooter':
        return (settings['defaultFareScooter'] ?? 20.0).toDouble();
      case 'motorcycle':
        return (settings['defaultFareMotorcycle'] ?? 15.0).toDouble();
      case 'car':
      default:
        return (settings['defaultFareCar'] ?? 45.0).toDouble();
    }
  }

  void _onVehicleSelected(String type) {
    setState(() {
      _selectedVehicle = type;
      _fareController.text = _getDefaultFare(type).round().toString();
      _passengerCount = 1;
    });
  }

  void _openSearchPickup() async {
    final result = await Navigator.push(
      context,
      SnappyPageRoute(
        page: const LocationSearchPage(
          title: 'من أين؟',
          hintText: 'حدد موقع الركوب...',
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        GlobalState.instance.fromAddress = result;
        _fareController.text = _getDefaultFare(_selectedVehicle).round().toString();
      });
      GlobalState.instance.update();
    }
  }

  void _openSearchDestination() async {
    final result = await Navigator.push(
      context,
      SnappyPageRoute(
        page: const LocationSearchPage(
          title: 'إلى أين؟',
          hintText: 'ابحث عن وجهة أو موقع...',
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        GlobalState.instance.toAddress = result;
        _fareController.text = _getDefaultFare(_selectedVehicle).round().toString();
      });
      GlobalState.instance.update();
    }
  }

  void _requestRide() async {
    final hasLocPermission = await LocationService.instance.checkPermission();
    if (!mounted) return;
    if (!hasLocPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى السماح بالوصول لموقعك الجغرافي لتتمكن من حجز رحلة.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_toText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى تحديد وجهة أولاً للبدء',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Block Scooter requests with "will be available soon" message
    if (_selectedVehicle == 'scooter') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'عذراً، خدمة الاسكوتر ستتوفر قريباً! يرجى اختيار الموتوسيكل أو السيارة حالياً.',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.mediumBlue,
        ),
      );
      return;
    }

    final double fare = double.tryParse(_fareController.text) ?? 30.0;
    
    // Start searching in global state
    GlobalState.instance.startSearchingForDrivers(
      _fromText,
      _toText,
      fare,
      _selectedVehicle,
      passengerCount: _passengerCount,
    );

    // Open matching screen
    Navigator.push(
      context,
      SnappyPageRoute(page: const PassengerRideMatchingPage()),
    );
  }

  double get _dynamicBottomPadding {
    if (_mode == PassengerMode.dashboard) {
      return _showVehicleSelection ? 270.0 : 190.0;
    } else if (_mode == PassengerMode.rideBooking) {
      return _toText.isEmpty ? 220.0 : 380.0;
    } else {
      return 120.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: GlobalState.instance.canExitApplication(),
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
          Positioned.fill(
            child: RepaintBoundary(
              child: OsmMapWidget(bottomPadding: _dynamicBottomPadding),
            ),
          ),

          // 2. Custom App Bar Overlays
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hamburger Menu Button
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

          // 3. Routing Input Card (Only for Ride booking mode)
          if (_mode == PassengerMode.rideBooking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Header Row with back to dashboard button
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _mode = PassengerMode.dashboard;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedVehicle == 'car' ? 'طلب رحلة ملاكي' : 'طلب رحلة بايك',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Start Location Field
                      GestureDetector(
                        onTap: _openSearchPickup,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.mediumBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  String displayText = _fromText;
                                  if (displayText.startsWith('موقعي الحالي')) {
                                    displayText = 'موقعي الحالي';
                                  }
                                  return Text(
                                    displayText.isEmpty ? 'من أين تريد الركوب؟' : displayText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      color: displayText.isEmpty ? AppColors.textLight : AppColors.textPrimary,
                                      fontWeight: displayText.isEmpty ? FontWeight.normal : FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }
                              ),
                            ),
                            const Icon(Icons.my_location, color: AppColors.textLight, size: 20),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Divider(height: 20, color: AppColors.border),
                      ),
                      // Destination Location Field
                      GestureDetector(
                        onTap: _openSearchDestination,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.darkBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _toText.isEmpty ? 'أين تريد الذهاب؟' : _toText,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: _toText.isEmpty ? AppColors.textLight : AppColors.textPrimary,
                                  fontWeight: _toText.isEmpty ? FontWeight.normal : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.search, color: AppColors.textLight, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Bottom Request Board (Only for Ride booking mode)
          if (_mode == PassengerMode.rideBooking)
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_toText.isEmpty) ...[
                      // Destination not chosen yet - prompt the user professionally
                      const SizedBox(height: 8),
                      const Icon(Icons.route_outlined, color: AppColors.mediumBlue, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'حدد وجهتك للبدء في طلب رحلة',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اختر مكاناً تود الذهاب إليه من حقل البحث في الأعلى لمعرفة التكلفة والبدء في طلب الرحلة.',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                       // Heading
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             'اختر سعر الرحلة المقترح',
                             style: GoogleFonts.cairo(
                               fontSize: 14,
                               fontWeight: FontWeight.bold,
                               color: AppColors.textPrimary,
                             ),
                           ),
                           Builder(
                             builder: (context) {
                               final startLatLng = MapCoordinatesHelper.getLatLngForAddress(_fromText);
                               final endLatLng = MapCoordinatesHelper.getLatLngForAddress(_toText);
                               final distance = LocationService.instance.calculateDistance(
                                 startLatLng.latitude,
                                 startLatLng.longitude,
                                 endLatLng.latitude,
                                 endLatLng.longitude,
                               );
                               return Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: AppColors.mediumBlue.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(8),
                                 ),
                                 child: Text(
                                   '${distance.toStringAsFixed(1)} كم',
                                   style: GoogleFonts.outfit(
                                     fontSize: 12,
                                     fontWeight: FontWeight.bold,
                                     color: AppColors.mediumBlue,
                                   ),
                                 ),
                               );
                             }
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),

                      Builder(
                        builder: (context) {
                          final startLatLng = MapCoordinatesHelper.getLatLngForAddress(_fromText);
                          final endLatLng = MapCoordinatesHelper.getLatLngForAddress(_toText);
                          final distance = LocationService.instance.calculateDistance(
                            startLatLng.latitude,
                            startLatLng.longitude,
                            endLatLng.latitude,
                            endLatLng.longitude,
                          );
                          final durationMotorcycle = (distance * 1.8).round().clamp(2, 120);
                          final durationCar = (distance * 2.5).round().clamp(2, 120);
                          return Row(
                            children: [
                              _buildVehicleOption(
                                type: 'car',
                                title: 'سيارة ملاكي',
                                eta: '~$durationCar دقيقة',
                                baseFare: '${_getDefaultFare('car').round()} ج.م',
                                icon: Icons.directions_car,
                              ),
                              const SizedBox(width: 12),
                              _buildVehicleOption(
                                type: 'motorcycle',
                                title: 'موتوسيكل / بايك',
                                eta: '~$durationMotorcycle دقيقة',
                                baseFare: '${_getDefaultFare('motorcycle').round()} ج.م',
                                icon: Icons.motorcycle,
                              ),
                            ],
                          );
                        }
                      ),
                      // Passenger Count Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline, color: AppColors.mediumBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'عدد الأفراد / الركاب',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16, color: AppColors.textLight),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    if (_passengerCount > 1) {
                                      setState(() {
                                        _passengerCount--;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_passengerCount',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16, color: AppColors.mediumBlue),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    if (_passengerCount < 4) {
                                      setState(() {
                                        _passengerCount++;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Offer Fare Input
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: AppColors.mediumBlue),
                              onPressed: () {
                                int val = int.tryParse(_fareController.text) ?? 20;
                                setState(() {
                                  _fareController.text = (val + 5).toString();
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _fareController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  suffixText: 'ج.م ',
                                  fillColor: Colors.transparent,
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: AppColors.textLight),
                              onPressed: () {
                                int val = int.tryParse(_fareController.text) ?? 20;
                                if (val > 5) {
                                  setState(() {
                                    _fareController.text = (val - 5).toString();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Confirm button (Gradient Blue)
                      ScaleButton(
                        onTap: _requestRide,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: AppColors.blueGradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.mediumBlue.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'طلب رحلة الآن',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 5. Dashboard Overlay
          if (_mode == PassengerMode.dashboard)
            _buildDashboardOverlay(),

          // 6. Delivery Booking Overlay
          if (_mode == PassengerMode.deliveryBooking)
            PassengerDeliveryBookingPage(
              onCancel: () {
                setState(() {
                  _mode = PassengerMode.dashboard;
                });
              },
            ),
        ],
      ),
    ),
  );
}

Widget _buildDashboardOverlay() {
  final state = GlobalState.instance;
  final name = state.userName ?? 'عميلنا العزيز';
  final balance = state.walletBalance;

  return Positioned(
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showVehicleSelection) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 16, color: AppColors.textPrimary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _showVehicleSelection = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اختر نوع المركبة للرحلة',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'حدد نوع المركبة لبدء رحلتك',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.textSecondary,
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
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.mediumBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: AppColors.mediumBlue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${balance.round()} ج.م',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _VehicleSelectionCard(
                    title: 'سيارة ملاكي (Car)',
                    description: 'رحلة مريحة وآمنة بالسيارة الملاكي الخاصة',
                    icon: Icons.directions_car_rounded,
                    iconColor: AppColors.mediumBlue,
                    isSelected: _selectedVehicle == 'car',
                    onTap: () {
                      setState(() {
                        _showVehicleSelection = false;
                        _mode = PassengerMode.rideBooking;
                        _selectedVehicle = 'car';
                        _fareController.text = _getDefaultFare('car').round().toString();
                        _passengerCount = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _VehicleSelectionCard(
                    title: 'بايك (Motorcycle)',
                    description: 'رحلة سريعة وآمنة لتفادي زحام المرور بالدراجة',
                    icon: Icons.motorcycle_rounded,
                    iconColor: AppColors.mediumBlue,
                    isSelected: _selectedVehicle == 'motorcycle',
                    onTap: () {
                      setState(() {
                        _showVehicleSelection = false;
                        _mode = PassengerMode.rideBooking;
                        _selectedVehicle = 'motorcycle';
                        _fareController.text = _getDefaultFare('motorcycle').round().toString();
                        _passengerCount = 1;
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً بك، $name',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'اختر الخدمة للبدء فوراً',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.mediumBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: AppColors.mediumBlue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${balance.round()} ج.م',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DashboardServiceCard(
                    title: 'رحلة (Ride)',
                    description: 'رحلتك بالسيارة أو البايك سريعة وآمنة بأسعارك المقترحة',
                    icon: Icons.directions_car_rounded,
                    iconColor: AppColors.mediumBlue,
                    backgroundColor: AppColors.mediumBlue.withValues(alpha: 0.08),
                    borderColor: AppColors.mediumBlue.withValues(alpha: 0.15),
                    onTap: () {
                      setState(() {
                        _showVehicleSelection = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DashboardServiceCard(
                    title: 'ديلفري (Delivery)',
                    description: 'أرسل طرودك وهداياك بضغطة زر مع بايكر سريع',
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.darkBlue,
                    backgroundColor: AppColors.darkBlue.withValues(alpha: 0.06),
                    borderColor: AppColors.darkBlue.withValues(alpha: 0.15),
                    onTap: () {
                      setState(() {
                        _mode = PassengerMode.deliveryBooking;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
      ),
    );
  }

  Widget _buildVehicleOption({
    required String type,
    required String title,
    required String eta,
    required String baseFare,
    required IconData icon,
  }) {
    bool isSelected = _selectedVehicle == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onVehicleSelected(type),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.mediumBlue : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                eta,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Location Search Page (In Arabic)
// ----------------------------------------------------
class LocationSearchPage extends StatefulWidget {
  final String title;
  final String hintText;

  const LocationSearchPage({
    super.key,
    required this.title,
    required this.hintText,
  });

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingApi = false;
  Timer? _debounceTimer;

  // Dynamic visited places with fallback to Cairo/Giza popular landmarks
  List<Map<String, dynamic>> get _allPlaces {
    final history = GlobalState.instance.tripHistory;
    final List<Map<String, dynamic>> visited = [];
    final Set<String> uniqueAddresses = {};

    for (var trip in history) {
      final toAddress = trip['to'] as String? ?? '';
      final toLat = trip['toLat'] as double? ?? 0.0;
      final toLng = trip['toLng'] as double? ?? 0.0;

      if (toAddress.isNotEmpty && toLat != 0.0 && !uniqueAddresses.contains(toAddress.toLowerCase().trim())) {
        uniqueAddresses.add(toAddress.toLowerCase().trim());
        
        String title = toAddress;
        if (toAddress.contains('،')) {
          title = toAddress.split('،').first.trim();
        } else if (toAddress.contains(',')) {
          title = toAddress.split(',').first.trim();
        }
        
        visited.add({
          'title': title,
          'address': toAddress,
          'icon': Icons.history, // History icon for visited places
          'lat': toLat,
          'lon': toLng,
        });
      }
      
      final fromAddress = trip['from'] as String? ?? '';
      final fromLat = trip['fromLat'] as double? ?? 0.0;
      final fromLng = trip['fromLng'] as double? ?? 0.0;

      if (fromAddress.isNotEmpty && fromLat != 0.0 && fromAddress != 'موقعي الحالي' && !uniqueAddresses.contains(fromAddress.toLowerCase().trim())) {
        uniqueAddresses.add(fromAddress.toLowerCase().trim());
        
        String title = fromAddress;
        if (fromAddress.contains('،')) {
          title = fromAddress.split('،').first.trim();
        } else if (fromAddress.contains(',')) {
          title = fromAddress.split(',').first.trim();
        }
        
        visited.add({
          'title': title,
          'address': fromAddress,
          'icon': Icons.history,
          'lat': fromLat,
          'lon': fromLng,
        });
      }
    }
    
    // Cairo/Giza popular places for fallback if history has less than 5 items
    final List<Map<String, dynamic>> defaults = [
      {
        'title': 'المنزل',
        'address': 'شارع النيل، الجيزة',
        'icon': Icons.home_outlined,
        'lat': 30.0130,
        'lon': 31.2080,
      },
      {
        'title': 'العمل',
        'address': 'شارع جامعة الدول العربية، المهندسين',
        'icon': Icons.work_outline,
        'lat': 30.0526,
        'lon': 31.2014,
      },
      {
        'title': 'ميدان التحرير',
        'address': 'وسط البلد، القاهرة',
        'icon': Icons.star_border,
        'lat': 30.0444,
        'lon': 31.2357,
      },
      {
        'title': 'الجامعة الأمريكية بالقاهرة',
        'address': 'القاهرة الجديدة',
        'icon': Icons.school_outlined,
        'lat': 30.0263,
        'lon': 31.4913,
      },
      {
        'title': 'مول مصر',
        'address': 'طريق الواحات، 6 أكتوبر',
        'icon': Icons.shopping_bag_outlined,
        'lat': 29.9722,
        'lon': 31.0152,
      },
    ];

    for (var defaultPlace in defaults) {
      final address = defaultPlace['address'] as String;
      if (!uniqueAddresses.contains(address.toLowerCase().trim())) {
        visited.add(defaultPlace);
      }
    }

    return visited;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingApi = false;
      });
      return;
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      setState(() {
        _isSearchingApi = true;
      });
      
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&accept-language=ar&countrycodes=eg&limit=8'
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'inRideApp/1.0',
        }).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<Map<String, dynamic>> results = [];
          for (var item in data) {
            final displayName = item['display_name'] as String;
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            
            if (lat != null && lon != null) {
              final parts = displayName.split(',');
              final title = parts.first.trim();
              
              results.add({
                'title': title,
                'address': displayName,
                'lat': lat,
                'lon': lon,
                'icon': Icons.location_on_outlined,
              });
            }
          }
          
          if (mounted) {
            setState(() {
              _searchResults = results;
              _isSearchingApi = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isSearchingApi = false;
            });
          }
        }
      } catch (e) {
        debugPrint('Error searching Nominatim API: $e');
        if (mounted) {
          setState(() {
            _isSearchingApi = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter places based on search query
    final filteredPlaces = _searchQuery.trim().isEmpty
        ? _allPlaces.take(5).toList() // Show top 5 recent/saved places when empty
        : (_searchResults.isNotEmpty 
            ? _searchResults 
            : _allPlaces.where((place) {
                final titleMatch = place['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                final addressMatch = place['address'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                return titleMatch || addressMatch;
              }).toList());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _onSearchChanged(value);
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.pop(context, value.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search, color: AppColors.mediumBlue),
                  suffixIcon: _isSearchingApi
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: AppColors.mediumBlue,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : null,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),

            if (_searchQuery.trim().isNotEmpty && filteredPlaces.isEmpty && !_isSearchingApi)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'لم نتمكن من العثور على "$_searchQuery"',
                  style: GoogleFonts.cairo(color: AppColors.textSecondary),
                ),
              ),

            // My Current Location Option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Card(
                elevation: 0,
                color: AppColors.mediumBlue.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppColors.mediumBlue.withValues(alpha: 0.15),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location, color: AppColors.mediumBlue, size: 20),
                  ),
                  title: Text(
                    'موقعي الحالي',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mediumBlue,
                    ),
                  ),
                  subtitle: Text(
                    'تحديد موقع الركوب تلقائياً بناءً على موقعك',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () async {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              const SizedBox(width: 16),
                              Text('جاري تحديد موقعك...', style: GoogleFonts.cairo(fontSize: 14)),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.mediumBlue,
                        ),
                      );
                    }
                    try {
                      final pos = await LocationService.instance.getCurrentLocation();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        if (pos != null) {
                          final addressString = 'موقعي الحالي (${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)})';
                          MapCoordinatesHelper.registerCoordinate(addressString, LatLng(pos.latitude, pos.longitude));
                          Navigator.pop(context, addressString);
                        } else {
                          Navigator.pop(context, 'موقعي الحالي');
                        }
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.pop(context, 'موقعي الحالي');
                      }
                    }
                  },
                ),
              ),
            ),
            
            // Saved places / Suggestions heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _searchQuery.trim().isEmpty ? 'الأماكن المحفوظة' : 'نتائج البحث',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            // Suggestions list items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filteredPlaces.length,
                itemBuilder: (context, index) {
                  final place = filteredPlaces[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(place['icon'] as IconData, color: AppColors.mediumBlue, size: 20),
                    ),
                    title: Text(
                      place['title'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      place['address'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      if (place.containsKey('lat') && place.containsKey('lon')) {
                        final latLng = LatLng(place['lat'] as double, place['lon'] as double);
                        MapCoordinatesHelper.registerCoordinate(place['address'] as String, latLng);
                        MapCoordinatesHelper.registerCoordinate(place['title'] as String, latLng);
                      }
                      Navigator.pop(context, place['address']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardServiceCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _DashboardServiceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_DashboardServiceCard> createState() => _DashboardServiceCardState();
}

class _DashboardServiceCardState extends State<_DashboardServiceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.iconColor.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 28,
                ),
              ),
              
              // Text Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleSelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleSelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? iconColor : AppColors.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? iconColor.withValues(alpha: 0.15)
                    : iconColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
