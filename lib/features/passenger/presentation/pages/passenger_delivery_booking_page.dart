import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../core/models/place_location.dart';
import 'package:latlong2/latlong.dart';
import 'passenger_ride_matching_page.dart';
import 'passenger_home_page.dart';


class PassengerDeliveryBookingPage extends StatefulWidget {
  final VoidCallback onCancel;

  const PassengerDeliveryBookingPage({
    super.key,
    required this.onCancel,
  });

  @override
  State<PassengerDeliveryBookingPage> createState() => _PassengerDeliveryBookingPageState();
}

enum DeliveryLocationMode { map, manual, recipient }

class _PassengerDeliveryBookingPageState extends State<PassengerDeliveryBookingPage> {
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();
  final TextEditingController _recipientRegionController = TextEditingController();
  final TextEditingController _recipientStreetController = TextEditingController();
  final TextEditingController _recipientBuildingController = TextEditingController();
  final TextEditingController _recipientFloorController = TextEditingController();
  final TextEditingController _recipientLandmarkController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  
  bool _isReviewMode = false;
  bool _isSubmitting = false;
  DeliveryLocationMode _deliveryLocationMode = DeliveryLocationMode.map;
  bool get _recipientWillSpecifyLocation => _deliveryLocationMode == DeliveryLocationMode.recipient;
  String _selectedPaymentMethod = 'كاش'; // كاش, انستا باي

  String get _fromAddress => GlobalState.instance.fromAddress ?? 'موقعي الحالي';

  String get _toAddress {
    if (_deliveryLocationMode == DeliveryLocationMode.recipient) {
      return 'بانتظار تحديد موقع المستلم';
    }
    if (_deliveryLocationMode == DeliveryLocationMode.manual) {
      final region = _recipientRegionController.text.trim();
      final street = _recipientStreetController.text.trim();
      final building = _recipientBuildingController.text.trim();
      if (region.isNotEmpty || street.isNotEmpty) {
        return '$region، شارع $street${building.isNotEmpty ? '، مبنى $building' : ''}';
      }
    }
    return GlobalState.instance.toAddress ?? '';
  }

  @override
  void dispose() {
    _packageController.dispose();
    _notesController.dispose();
    _recipientPhoneController.dispose();
    _recipientRegionController.dispose();
    _recipientStreetController.dispose();
    _recipientBuildingController.dispose();
    _recipientFloorController.dispose();
    _recipientLandmarkController.dispose();
    super.dispose();
  }

  double _calculateDistance() {
    if (_fromAddress.isEmpty || _toAddress.isEmpty || _fromAddress == 'موقعي الحالي' || _toAddress == 'حدد وجهتك' || _recipientWillSpecifyLocation) {
      return 0.0;
    }
    try {
      final startLatLng = MapCoordinatesHelper.getLatLngForAddress(_fromAddress);
      final endLatLng = MapCoordinatesHelper.getLatLngForAddress(_toAddress);
      return LocationService.instance.calculateDistance(
        startLatLng.latitude,
        startLatLng.longitude,
        endLatLng.latitude,
        endLatLng.longitude,
      );
    } catch (_) {
      return 0.0;
    }
  }

  double _getDeliveryFare() {
    final distance = _calculateDistance();
    if (distance == 0.0) return 20.0;
    
    return GlobalState.instance.calculateEstimatedFare(
      distanceInKm: distance,
      vehicleType: 'motorcycle', // Delivery is performed by motorcycle
      hasAC: false,
    );
  }

  void _openSearchPickup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSearchPage(
          title: 'مكان الاستلام',
          hintText: 'حدد موقع استلام الطرد...',
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSearchPage(
          title: 'مكان التسليم',
          hintText: 'حدد موقع تسليم الطرد...',
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
      setState(() {});
      GlobalState.instance.update();
    }
  }


  void _shareLink(BuildContext context, String link) async {
    // Show user-friendly warning SnackBar to encourage app installation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'لتحديد موقعك بسهولة، يُرجى التأكد من تثبيت التطبيق على جهازك.',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: AppColors.mediumBlue,
        duration: const Duration(seconds: 4),
      ),
    );

    final message = 'لتحديد موقعك بسهولة، يُرجى التأكد من تثبيت التطبيق على جهازك.\n\nمن فضلك اضغط على هذا الرابط لتحديد موقع تسليم الطرد الخاص بك على الخريطة لتسهيل التوصيل: $link';
    
    await showModalBottomSheet(
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
                'مشاركة رابط تحديد الموقع 🔗',
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
                    label: 'واتساب',
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
                    label: 'رسالة نصية',
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
                    label: 'نسخ الرابط',
                    onTap: () async {
                      Navigator.pop(context);
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم نسخ رابط التحديد بنجاح! 📋', style: GoogleFonts.cairo()),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  _buildShareButton(
                    icon: Icons.share_outlined,
                    color: Colors.purple,
                    label: 'مشاركة أخرى',
                    onTap: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(text: message),
                      );
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

  void _submitOrderAndShowShareSheet() async {
    final hasLocPermission = await LocationService.instance.checkPermission();
    if (!mounted) return;
    if (!hasLocPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى السماح بالوصول لموقعك الجغرافي لتتمكن من طلب التوصيل.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_packageController.text.trim().isEmpty) {
      _packageController.text = 'طرد ديلفري';
    }

    setState(() {
      _isSubmitting = true;
    });

    final double fare = _getDeliveryFare();
    final String packageDesc = _packageController.text.trim();
    final String notes = _notesController.text.trim();

    GlobalState.instance.selectedPaymentMethod = _selectedPaymentMethod;

    await GlobalState.instance.startSearchingForDriversWithDetails(
      from: _fromAddress,
      to: _toAddress,
      fare: fare,
      vehicleType: 'delivery',
      serviceType: 'delivery',
      packageDescription: packageDesc,
      deliveryNotes: notes.isNotEmpty ? notes : null,
      isDeliveryLocationConfirmed: false,
      recipientPhone: null,
      recipientRegion: null,
      recipientStreet: null,
      recipientBuilding: null,
      recipientFloor: null,
      recipientLandmark: null,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    final token = GlobalState.instance.currentRecipientToken ?? '';
    final shareLink = 'https://inride.app/confirm-delivery-location?requestId=${GlobalState.instance.currentRequestId}&token=$token';

    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(builder: (context) => const PassengerRideMatchingPage()),
    );
    _shareLink(context, shareLink);
  }

  void _onContinuePressed() {
    if (_deliveryLocationMode == DeliveryLocationMode.map) {
      if (_toAddress.isEmpty || _toAddress == 'حدد وجهتك') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى تحديد مكان التسليم أولاً على الخريطة', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_formKey.currentState!.validate()) {
        setState(() {
          _isReviewMode = true;
        });
      }
    } else if (_deliveryLocationMode == DeliveryLocationMode.manual) {
      if (_recipientPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى إدخال رقم هاتف المستلم لتأكيد الطلب', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_recipientRegionController.text.trim().isEmpty || _recipientStreetController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى إدخال اسم المنطقة والشارع لتحديد عنوان التوصيل', style: GoogleFonts.cairo()),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_formKey.currentState!.validate()) {
        setState(() {
          _isReviewMode = true;
        });
      }
    } else {
      if (_formKey.currentState!.validate()) {
        _submitOrderAndShowShareSheet();
      }
    }
  }

  void _onOrderDeliveryPressed() async {
    final hasLocPermission = await LocationService.instance.checkPermission();
    if (!mounted) return;
    if (!hasLocPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى السماح بالوصول لموقعك الجغرافي لتتمكن من طلب التوصيل.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final double fare = _getDeliveryFare();
    final String packageDesc = _packageController.text.trim();
    final String notes = _notesController.text.trim();

    GlobalState.instance.selectedPaymentMethod = _selectedPaymentMethod;

    await GlobalState.instance.startSearchingForDriversWithDetails(
      from: _fromAddress,
      to: _toAddress,
      fare: fare,
      vehicleType: 'delivery',
      serviceType: 'delivery',
      packageDescription: packageDesc,
      deliveryNotes: notes.isNotEmpty ? notes : null,
      isDeliveryLocationConfirmed: true,
      recipientPhone: _recipientPhoneController.text.trim().isNotEmpty ? _recipientPhoneController.text.trim() : null,
      recipientRegion: _recipientRegionController.text.trim().isNotEmpty ? _recipientRegionController.text.trim() : null,
      recipientStreet: _recipientStreetController.text.trim().isNotEmpty ? _recipientStreetController.text.trim() : null,
      recipientBuilding: _recipientBuildingController.text.trim().isNotEmpty ? _recipientBuildingController.text.trim() : null,
      recipientFloor: _recipientFloorController.text.trim().isNotEmpty ? _recipientFloorController.text.trim() : null,
      recipientLandmark: _recipientLandmarkController.text.trim().isNotEmpty ? _recipientLandmarkController.text.trim() : null,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PassengerRideMatchingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    final fare = _getDeliveryFare();

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
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isReviewMode 
                  ? _buildReviewView(distance, fare)
                  : _buildFormView(distance),
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.85),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.mediumBlue),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(double distance) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('delivery_form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with back button to dashboard
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: 8),
              Text(
                'طلب ديلفري جديد',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pickup and Dropoff fields
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _openSearchPickup,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.mediumBlue, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fromAddress.startsWith('موقعي الحالي') ? 'موقعي الحالي' : _fromAddress,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.my_location, color: AppColors.textLight, size: 18),
                    ],
                  ),
                ),
                if (_deliveryLocationMode == DeliveryLocationMode.map) ...[
                  const Divider(height: 16, color: AppColors.border),
                  GestureDetector(
                    onTap: _openSearchDestination,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.darkBlue, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _toAddress.isEmpty ? 'مكان التسليم (حدد على الخريطة)...' : _toAddress,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: _toAddress.isEmpty ? AppColors.textLight : AppColors.textPrimary,
                              fontWeight: _toAddress.isEmpty ? FontWeight.normal : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.search, color: AppColors.textLight, size: 18),
                      ],
                    ),
                  ),
                ] else if (_deliveryLocationMode == DeliveryLocationMode.recipient) ...[
                  const Divider(height: 16, color: AppColors.border),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.mediumBlue, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'مكان التسليم: بانتظار تحديد موقع المستلم 🔗',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppColors.mediumBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.link, color: AppColors.mediumBlue, size: 18),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Segmented Selection between Map, Manual, and Recipient
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _deliveryLocationMode = DeliveryLocationMode.map;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _deliveryLocationMode == DeliveryLocationMode.map ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _deliveryLocationMode == DeliveryLocationMode.map ? AppColors.mediumBlue : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '📍 على الخريطة',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _deliveryLocationMode == DeliveryLocationMode.map ? AppColors.mediumBlue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _deliveryLocationMode = DeliveryLocationMode.manual;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _deliveryLocationMode == DeliveryLocationMode.manual ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _deliveryLocationMode == DeliveryLocationMode.manual ? AppColors.mediumBlue : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '✍️ إدخال يدوي',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _deliveryLocationMode == DeliveryLocationMode.manual ? AppColors.mediumBlue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _deliveryLocationMode = DeliveryLocationMode.recipient;
                    });
                    // Immediately trigger order placement and sharing sheet
                    _submitOrderAndShowShareSheet();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _deliveryLocationMode == DeliveryLocationMode.recipient ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _deliveryLocationMode == DeliveryLocationMode.recipient ? AppColors.mediumBlue : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🔗 المستلم يحدد',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _deliveryLocationMode == DeliveryLocationMode.recipient ? AppColors.mediumBlue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_deliveryLocationMode == DeliveryLocationMode.manual) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_location_alt_outlined, color: AppColors.mediumBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يرجى إدخال بيانات عنوان المستلم للتوصيل بدقة:',
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Recipient Phone Number
                  TextFormField(
                    controller: _recipientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'رقم هاتف المستلم (إجباري) *',
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.textLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  // Region & Street
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _recipientRegionController,
                          decoration: InputDecoration(
                            hintText: 'اسم المنطقة / الحي *',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _recipientStreetController,
                          decoration: InputDecoration(
                            hintText: 'اسم الشارع / الميدان *',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Building & Floor
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _recipientBuildingController,
                          decoration: InputDecoration(
                            hintText: 'رقم المبنى / العقار',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _recipientFloorController,
                          decoration: InputDecoration(
                            hintText: 'الدور / الشقة',
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                          style: GoogleFonts.cairo(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Landmark
                  TextFormField(
                    controller: _recipientLandmarkController,
                    decoration: InputDecoration(
                      hintText: 'علامة مميزة (مثال: بجانب صيدلية مصر)',
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.textLight),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // What are you sending?
          Text(
            'ماذا سترسل؟',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _packageController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'الرجاء كتابة وصف بسيط للطرد';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'طعام، أوراق، ملابس، طرد، إلخ...',
              fillColor: AppColors.background,
              filled: true,
              prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.textLight),
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
                borderSide: const BorderSide(color: AppColors.mediumBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            style: GoogleFonts.cairo(fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Notes (Optional)
          Text(
            'ملاحظات إضافية (اختياري) 📝',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'اتصل قبل الوصول، الدور الثالث، قابلني عند البوابة...',
              fillColor: AppColors.background,
              filled: true,
              prefixIcon: const Icon(Icons.rate_review_outlined, color: AppColors.textLight),
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
                borderSide: const BorderSide(color: AppColors.mediumBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            style: GoogleFonts.cairo(fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Continue Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: AppColors.blueGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _onContinuePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                'متابعة',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewView(double distance, double fare) {
    return Column(
      key: const ValueKey('delivery_review'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with back to form button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
              onPressed: () {
                setState(() {
                  _isReviewMode = false;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              'مراجعة طلب التوصيل',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary details card
        Card(
          elevation: 0,
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, color: AppColors.mediumBlue, size: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('موقع الاستلام', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight)),
                          Text(
                            _fromAddress.startsWith('موقعي الحالي') ? 'موقعي الحالي' : _fromAddress,
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.border),
                
                // Delivery location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: AppColors.darkBlue, size: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('موقع التسليم', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight)),
                          Text(
                            _toAddress,
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.border),
                
                // Package Description
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المرسل', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight)),
                          Text(
                            _packageController.text,
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_notesController.text.trim().isNotEmpty) ...[
                  const Divider(height: 20, color: AppColors.border),
                  // Notes
                  Row(
                    children: [
                      const Icon(Icons.rate_review_outlined, color: AppColors.textSecondary, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ملاحظات الكابتن', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textLight)),
                            Text(
                              _notesController.text,
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
        ),
        const SizedBox(height: 20),

        // Cost & Distance row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المسافة التقريبية',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  _recipientWillSpecifyLocation
                      ? 'قيد التحديد'
                      : '${distance.toStringAsFixed(1)} كم',
                  style: _recipientWillSpecifyLocation 
                      ? GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)
                      : GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'المدة المتوقعة',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  _recipientWillSpecifyLocation
                      ? 'قيد التحديد'
                      : '~${(distance * 2.0).round().clamp(2, 120)} دقيقة',
                  style: _recipientWillSpecifyLocation
                      ? GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary)
                      : GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'السعر المقترح',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  _recipientWillSpecifyLocation
                      ? '١٥ ج.م (مبدئي)'
                      : '${fare.round()} ج.م',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.mediumBlue),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Payment Method row
        Text(
          'طريقة الدفع',
          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final activeMethods = GlobalState.instance.activePaymentMethods;
            if (activeMethods.isEmpty) {
              return Text(
                'كاش',
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: activeMethods.map((pm) {
                final name = pm['name'] as String? ?? 'كاش';
                final code = pm['code'] as String? ?? 'cash';
                final icon = code == 'instapay'
                    ? Icons.account_balance_outlined
                    : (code == 'vodafone_cash' ? Icons.phone_android_outlined : Icons.money_rounded);
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 60) / 2,
                  child: _buildPaymentOption(name, icon),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 28),

        // Request button
        Container(
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
          child: ElevatedButton(
            onPressed: _onOrderDeliveryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'اطلب ديلفري الآن',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mediumBlue.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.mediumBlue : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.mediumBlue : AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(
              method,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.mediumBlue : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
