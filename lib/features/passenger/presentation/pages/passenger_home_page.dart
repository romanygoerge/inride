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
import '../../../../core/models/place_location.dart';
import '../../../../core/services/search_history_service.dart';
import 'passenger_ride_matching_page.dart';
import 'passenger_delivery_booking_page.dart';
import '../../../common/notifications_page.dart';
import '../../../common/wallet_page.dart';
import '../../../../generated/app_localizations.dart';




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
      final pos = await LocationService.instance.getCurrentLocation();
      if (pos != null) {
        MapCoordinatesHelper.deviceLocation = LatLng(pos.latitude, pos.longitude);
        final geocoded = await MapCoordinatesHelper.reverseGeocode(pos.latitude, pos.longitude);
        if (geocoded.isNotEmpty && (GlobalState.instance.fromAddress == null || GlobalState.instance.fromAddress == 'موقعي الحالي' || GlobalState.instance.fromAddress == 'الموقع الحالي')) {
          GlobalState.instance.fromAddress = geocoded;
        }
      }
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
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.push(
      context,
      SnappyPageRoute(
        page: LocationSearchPage(
          title: l10n.whereFrom,
          hintText: l10n.setPickupHint,
        ),
      ),
    );

    if (result != null) {
      PlaceLocation loc;
      if (result is SearchResultItem) {
        loc = result.location;
      } else if (result is PlaceLocation) {
        loc = result;
      } else if (result is String && result.isNotEmpty) {
        final geocoded = MapCoordinatesHelper.getLatLngForAddress(result);
        loc = PlaceLocation(
          latitude: geocoded.latitude,
          longitude: geocoded.longitude,
          placeName: result,
          formattedAddress: result,
          timestamp: DateTime.now(),
        );
      } else {
        return;
      }

      setState(() {
        GlobalState.instance.fromAddress = loc.formattedAddress;
        GlobalState.instance.fromLat = loc.latitude;
        GlobalState.instance.fromLng = loc.longitude;
      });
      MapCoordinatesHelper.registerCoordinate(loc.formattedAddress, LatLng(loc.latitude, loc.longitude));

      if (GlobalState.instance.selectedDestinationLocation != null) {
        final source = GlobalState.instance.selectedDestinationLocation!.placeId != null ? 'Search History' : 'Fresh Search';
        await GlobalState.instance.selectDestination(GlobalState.instance.selectedDestinationLocation!, selectionSource: source);
      }
      GlobalState.instance.update();
    }
  }

  void _openSearchDestination() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.push(
      context,
      SnappyPageRoute(
        page: LocationSearchPage(
          title: l10n.whereTo,
          hintText: l10n.searchDestinationHint,
        ),
      ),
    );

    if (result != null) {
      PlaceLocation place;
      String source = 'Fresh Search';

      if (result is SearchResultItem) {
        place = result.location;
        source = result.isHistory ? 'Search History' : 'Fresh Search';
      } else if (result is PlaceLocation) {
        place = result;
      } else if (result is String && result.isNotEmpty) {
        final geocoded = MapCoordinatesHelper.getLatLngForAddress(result);
        place = PlaceLocation(
          latitude: geocoded.latitude,
          longitude: geocoded.longitude,
          placeName: result,
          formattedAddress: result,
          timestamp: DateTime.now(),
        );
      } else {
        return;
      }

      await GlobalState.instance.selectDestination(place, selectionSource: source);

      setState(() {
        if (GlobalState.instance.calculatedRouteFare != null) {
          _fareController.text = GlobalState.instance.calculatedRouteFare!.round().toString();
        } else {
          _fareController.text = _getDefaultFare(_selectedVehicle).round().toString();
        }
      });
      GlobalState.instance.update();
    }
  }


  void _requestRide() async {
    final l10n = AppLocalizations.of(context)!;
    final hasLocPermission = await LocationService.instance.checkPermission();
    if (!mounted) return;
    if (!hasLocPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.locationPermissionRide,
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
            l10n.selectDestinationFirst,
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
            l10n.scooterComingSoon,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.warning,
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
      return _showVehicleSelection ? 300.0 : 240.0;
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

          // 2. Custom App Bar Overlays
          Positioned(
            top: MediaQuery.of(context).padding.top + (GlobalState.instance.isOffline ? 36 : 12),
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
                            _selectedVehicle == 'car' ? AppLocalizations.of(context)!.requestCarRide : AppLocalizations.of(context)!.requestBikeRide,
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
                                  return Text(
                                    displayText.isEmpty ? AppLocalizations.of(context)!.whereToRide : displayText,
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
                                _toText.isEmpty ? AppLocalizations.of(context)!.whereToGoShort : _toText,
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
                        AppLocalizations.of(context)!.setDestinationToStart,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.chooseDestinationFromSearch,
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
                             AppLocalizations.of(context)!.chooseFare,
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
                                   AppLocalizations.of(context)!.distanceKm(distance.toStringAsFixed(1)),
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
                          final l10n = AppLocalizations.of(context)!;
                          return Row(
                            children: [
                              _buildVehicleOption(
                                type: 'car',
                                title: l10n.privateCar,
                                eta: '~${l10n.durationMinutes(durationCar)}',
                                baseFare: '${_getDefaultFare('car').round()} ${l10n.egp}',
                                icon: Icons.directions_car,
                                imageAsset: 'assets/images/ride_3d.png',
                              ),
                              const SizedBox(width: 12),
                              _buildVehicleOption(
                                type: 'motorcycle',
                                title: l10n.motorcycleBike,
                                eta: '~${l10n.durationMinutes(durationMotorcycle)}',
                                baseFare: '${_getDefaultFare('motorcycle').round()} ${l10n.egp}',
                                icon: Icons.motorcycle,
                                imageAsset: 'assets/images/bike_3d.png',
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
                                AppLocalizations.of(context)!.passengerCount,
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
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  suffixText: '${AppLocalizations.of(context)!.egp} ',
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
                            AppLocalizations.of(context)!.requestRideNow,
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
    final l10n = AppLocalizations.of(context)!;
    final name = state.userName ?? l10n.dearCustomer;
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
                              l10n.selectVehicleForRide,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.selectVehicleToStart,
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
                InkWell(
                  onTap: () {
                    Navigator.push(context, SnappyPageRoute(page: const WalletPage()));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
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
                          '${balance.round()} ${l10n.egp}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mediumBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _VehicleSelectionCard(
                    title: l10n.privateCarOption,
                    description: l10n.privateCarDesc,
                    icon: Icons.directions_car_rounded,
                    imageAsset: 'assets/images/ride_3d.png',
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
                    title: l10n.bikeOption,
                    description: l10n.bikeDesc,
                    icon: Icons.motorcycle_rounded,
                    imageAsset: 'assets/images/bike_3d.png',
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
                        l10n.welcomeUser(name),
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.chooseServiceToStart,
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
                InkWell(
                  onTap: () {
                    Navigator.push(context, SnappyPageRoute(page: const WalletPage()));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
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
                          '${balance.round()} ${l10n.egp}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mediumBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DashboardServiceCard(
                    title: l10n.rideOption,
                    description: l10n.rideDesc,
                    icon: Icons.directions_car_rounded,
                    imageAsset: 'assets/images/ride_3d.png',
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
                    title: l10n.deliveryOption,
                    description: l10n.deliveryDesc,
                    icon: Icons.inventory_2_outlined,
                    imageAsset: 'assets/images/delivery_3d.png',
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
    String? imageAsset,
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
              if (imageAsset != null)
                Image.asset(
                  imageAsset,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    icon,
                    color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary,
                    size: 28,
                  ),
                )
              else
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
// Search Result Item Wrapper
// ----------------------------------------------------
class SearchResultItem {
  final PlaceLocation location;
  final bool isHistory;

  const SearchResultItem({required this.location, required this.isHistory});
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

  @override
  void initState() {
    super.initState();
    SearchHistoryService.instance.init();
  }

  // Dynamic visited places with fallback to Cairo/Giza popular landmarks
  List<Map<String, dynamic>> get _allPlaces {
    final historyPlaces = SearchHistoryService.instance.getHistory();
    final List<Map<String, dynamic>> visited = [];
    final Set<String> uniqueAddresses = {};

    for (var loc in historyPlaces) {
      if (loc.isValid && !uniqueAddresses.contains(loc.formattedAddress.toLowerCase().trim())) {
        uniqueAddresses.add(loc.formattedAddress.toLowerCase().trim());
        visited.add({
          'placeId': loc.placeId,
          'title': loc.placeName.isNotEmpty ? loc.placeName : loc.formattedAddress,
          'address': loc.formattedAddress,
          'icon': Icons.history,
          'lat': loc.latitude,
          'lon': loc.longitude,
          'isHistory': true,
        });
      }
    }

    if (visited.isEmpty) {
      final history = GlobalState.instance.tripHistory;
      for (var trip in history) {
        final toAddress = trip['to'] as String? ?? '';
        final toLat = (trip['toLat'] as num?)?.toDouble() ?? 0.0;
        final toLng = (trip['toLng'] as num?)?.toDouble() ?? 0.0;

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
            'icon': Icons.history,
            'lat': toLat,
            'lon': toLng,
            'isHistory': true,
          });
        }
      }
    }
    
    // Cairo/Giza popular places for fallback
    final List<Map<String, dynamic>> defaults = [
      {
        'title': 'المنزل',
        'address': 'شارع النيل، الجيزة',
        'icon': Icons.home_outlined,
        'lat': 30.0130,
        'lon': 31.2080,
        'isHistory': false,
      },
      {
        'title': 'العمل',
        'address': 'شارع جامعة الدول العربية، المهندسين',
        'icon': Icons.work_outline,
        'lat': 30.0526,
        'lon': 31.2014,
        'isHistory': false,
      },
      {
        'title': 'ميدان التحرير',
        'address': 'وسط البلد، القاهرة',
        'icon': Icons.star_border,
        'lat': 30.0444,
        'lon': 31.2357,
        'isHistory': false,
      },
      {
        'title': 'الجامعة الأمريكية بالقاهرة',
        'address': 'القاهرة الجديدة',
        'icon': Icons.school_outlined,
        'lat': 30.0263,
        'lon': 31.4913,
        'isHistory': false,
      },
      {
        'title': 'مول مصر',
        'address': 'طريق الواحات، 6 أكتوبر',
        'icon': Icons.shopping_bag_outlined,
        'lat': 29.9722,
        'lon': 31.0152,
        'isHistory': false,
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
            final placeId = item['place_id']?.toString();
            
            if (lat != null && lon != null) {
              final parts = displayName.split(',');
              final title = parts.first.trim();
              
              results.add({
                'placeId': placeId,
                'title': title,
                'address': displayName,
                'lat': lat,
                'lon': lon,
                'icon': Icons.location_on_outlined,
                'isHistory': false,
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
    final filteredPlaces = _searchQuery.trim().isEmpty
        ? _allPlaces.take(5).toList()
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
                onSubmitted: (value) async {
                  final query = value.trim();
                  if (query.isNotEmpty) {
                    final geocoded = await MapCoordinatesHelper.geocodeAddress(query);
                    final lat = geocoded?.latitude ?? 0.0;
                    final lon = geocoded?.longitude ?? 0.0;
                    final loc = PlaceLocation(
                      latitude: lat,
                      longitude: lon,
                      placeName: query,
                      formattedAddress: query,
                      timestamp: DateTime.now(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context, SearchResultItem(location: loc, isHistory: false));
                    }
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
                  AppLocalizations.of(context)!.noResultsFor(_searchQuery),
                  style: GoogleFonts.cairo(color: AppColors.textSecondary),
                ),
              ),

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
                    AppLocalizations.of(context)!.myCurrentLocation,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mediumBlue,
                    ),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.setPickupAuto,
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
                              Text(AppLocalizations.of(context)!.detectingLocation, style: GoogleFonts.cairo(fontSize: 14)),
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
                          MapCoordinatesHelper.deviceLocation = LatLng(pos.latitude, pos.longitude);
                          final geocodedName = await MapCoordinatesHelper.reverseGeocode(pos.latitude, pos.longitude);
                          if (!context.mounted) return;
                          final addressString = geocodedName.isNotEmpty ? geocodedName : '${AppLocalizations.of(context)!.myCurrentLocation} (${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)})';
                          final loc = PlaceLocation(
                            latitude: pos.latitude,
                            longitude: pos.longitude,
                            placeName: AppLocalizations.of(context)!.myCurrentLocation,
                            formattedAddress: addressString,
                            timestamp: DateTime.now(),
                          );
                          MapCoordinatesHelper.registerCoordinate(addressString, LatLng(pos.latitude, pos.longitude));
                          Navigator.pop(context, SearchResultItem(location: loc, isHistory: false));
                        } else {
                          final defaultPos = MapCoordinatesHelper.deviceLocation ?? const LatLng(30.0130, 31.2080);
                          final loc = PlaceLocation(
                            latitude: defaultPos.latitude,
                            longitude: defaultPos.longitude,
                            placeName: 'موقعي الحالي',
                            formattedAddress: 'الموقع الحالي',
                            timestamp: DateTime.now(),
                          );
                          Navigator.pop(context, SearchResultItem(location: loc, isHistory: false));
                        }
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        final defaultPos = MapCoordinatesHelper.deviceLocation ?? const LatLng(30.0130, 31.2080);
                        final loc = PlaceLocation(
                          latitude: defaultPos.latitude,
                          longitude: defaultPos.longitude,
                          placeName: 'موقعي الحالي',
                          formattedAddress: 'الموقع الحالي',
                          timestamp: DateTime.now(),
                        );
                        Navigator.pop(context, SearchResultItem(location: loc, isHistory: false));
                      }
                    }
                  },
                ),
              ),
            ),
            
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

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filteredPlaces.length,
                itemBuilder: (context, index) {
                  final place = filteredPlaces[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
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
                      final lat = (place['lat'] as num?)?.toDouble() ?? 0.0;
                      final lon = (place['lon'] as num?)?.toDouble() ?? 0.0;
                      final title = place['title'] as String? ?? '';
                      final address = place['address'] as String? ?? title;
                      final isHistory = place['isHistory'] == true;

                      final placeLocation = PlaceLocation(
                        placeId: place['placeId'] as String?,
                        latitude: lat,
                        longitude: lon,
                        placeName: title,
                        formattedAddress: address,
                        timestamp: DateTime.now(),
                      );

                      if (lat != 0.0 && lon != 0.0) {
                        MapCoordinatesHelper.registerCoordinate(address, LatLng(lat, lon));
                        if (title.isNotEmpty) {
                          MapCoordinatesHelper.registerCoordinate(title, LatLng(lat, lon));
                        }
                      }
                      Navigator.pop(
                        context,
                        SearchResultItem(location: placeLocation, isHistory: isHistory),
                      );
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
  final String? imageAsset;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _DashboardServiceCard({
    required this.title,
    required this.description,
    required this.icon,
    this.imageAsset,
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
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.borderColor, width: 1.8),
            boxShadow: [
              BoxShadow(
                color: widget.iconColor.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Large Floating 3D Image Graphic
              Expanded(
                child: Center(
                  child: widget.imageAsset != null
                      ? Image.asset(
                          widget.imageAsset!,
                          height: 95,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: 48,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 48,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              // Text Content with Badge Styling
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: widget.iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description,
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      height: 1.2,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
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
  final String? imageAsset;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleSelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    this.imageAsset,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 195,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? iconColor : AppColors.border,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              spreadRadius: isSelected ? 1 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Large 3D Vehicle Graphic
            Expanded(
              child: Center(
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset!,
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon,
                          color: iconColor,
                          size: 44,
                        ),
                      )
                    : Icon(
                        icon,
                        color: iconColor,
                        size: 44,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? iconColor.withValues(alpha: 0.15)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? iconColor : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    height: 1.2,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
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
