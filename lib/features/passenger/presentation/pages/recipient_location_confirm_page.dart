import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/state/global_state.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/models/ride_request_model.dart';
import '../../../../core/utils/map_coordinates_helper.dart';

enum ConfirmPageState { loading, intro, mapPicker, success, error }

class RecipientLocationConfirmPage extends StatefulWidget {
  final String requestId;
  final String? token;

  const RecipientLocationConfirmPage({
    super.key,
    required this.requestId,
    this.token,
  });

  @override
  State<RecipientLocationConfirmPage> createState() => _RecipientLocationConfirmPageState();
}

class _RecipientLocationConfirmPageState extends State<RecipientLocationConfirmPage> {
  ConfirmPageState _state = ConfirmPageState.loading;
  bool _isSaving = false;
  String? _errorMessage;
  VoidCallback? _retryCallback;

  RideRequestModel? _request;
  String? _customSenderName;
  String get _senderName => _customSenderName ?? (LocaleController.instance.isArabic ? 'مرسل الطرد' : 'Parcel Sender');

  // Map picker variables
  final fm.MapController _mapController = fm.MapController();
  ll.LatLng? _selectedLatLng;
  String _resolvedAddress = LocaleController.instance.isArabic ? 'جاري تحديد إحداثيات الموقع... 📍' : 'Locating coordinates... 📍';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _loadRequestDetails() async {
    final isAr = LocaleController.instance.isArabic;
    setState(() {
      _state = ConfirmPageState.loading;
      _errorMessage = null;
    });

    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        await Supabase.instance.client.auth.signInAnonymously().catchError((_) => AuthResponse());
      }

      final docRes = await Supabase.instance.client.from('ride_requests').select().eq('id', widget.requestId).maybeSingle();

      if (docRes != null) {
        final dataMap = Map<String, dynamic>.from(docRes);
        final req = RideRequestModel.fromMap(dataMap, widget.requestId);
        _request = req;

        if (req.recipientToken != null && req.recipientToken != widget.token) {
          setState(() {
            _errorMessage = isAr ? 'هذا الرابط غير صالح أو غير مصرح لك بالوصول ❌' : 'Invalid link or unauthorized access ❌';
            _state = ConfirmPageState.error;
            _retryCallback = null;
          });
          return;
        }

        if (req.status == 'Completed' || req.status == 'Cancelled' || req.status == 'Expired') {
          setState(() {
            _errorMessage = isAr ? 'انتهت صلاحية هذا الرابط لأن الطلب غير نشط أو مكتمل بالفعل ⚠️' : 'Link expired as request is no longer active ⚠️';
            _state = ConfirmPageState.error;
            _retryCallback = null;
          });
          return;
        }

        final bool updatesAllowed = dataMap['allowLocationUpdate'] == true;
        if (req.isDeliveryLocationConfirmed && !updatesAllowed) {
          setState(() {
            _errorMessage = isAr ? 'تم تحديد وتأكيد الموقع مسبقاً لهذا الطلب ✅' : 'Location has already been confirmed for this order ✅';
            _state = ConfirmPageState.error;
            _retryCallback = null;
          });
          return;
        }

        final passDoc = await Supabase.instance.client.from('users').select('name').eq('id', req.passengerId).maybeSingle();
        final name = passDoc != null ? (passDoc['name'] ?? 'مرسل الطرد') : 'مرسل الطرد';

        setState(() {
          _customSenderName = name;
          _state = ConfirmPageState.intro;
        });
      } else {
        setState(() {
          _errorMessage = 'عذراً، لم يتم العثور على تفاصيل هذا الطلب ❌';
          _state = ConfirmPageState.error;
          _retryCallback = null;
        });
      }
    } catch (e) {
      debugPrint('[loadRequestDetails] Error loading details: $e');
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل بيانات الطلب. يرجى التأكد من اتصالك بالإنترنت.';
        _state = ConfirmPageState.error;
        _retryCallback = _loadRequestDetails;
      });
    }
  }

  // ==========================================
  // GPS Location Sharing
  // ==========================================
  void _shareGpsLocation() async {
    setState(() {
      _isSaving = true;
      _state = ConfirmPageState.loading;
      _errorMessage = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw 'تم رفض صلاحية الوصول للموقع الجغرافي. يرجى تفعيل الصلاحية للمتابعة ⚠️';
        }
      }

      // 2. Fetch coordinates via GPS (with automatic retry up to 3 times)
      Position? position;
      int attempts = 0;
      const int maxAttempts = 3;

      while (position == null && attempts < maxAttempts) {
        attempts++;
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
        } catch (e) {
          debugPrint('[GPS attempt $attempts] Failed: $e');
          if (attempts >= maxAttempts) {
            rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }

      if (position == null) {
        throw 'تعذر جلب موقعك الجغرافي بدقة عالية. يرجى التحقق من تفعيل GPS بجهازك أو التحديد يدوياً.';
      }

      // 3. Save coordinates, accuracy, and timestamp
      await GlobalState.instance.confirmDeliveryLocation(
        widget.requestId,
        position.latitude,
        position.longitude,
        'موقع المستلم (GPS)',
        pickupLat: _request?.pickupLatitude,
        pickupLng: _request?.pickupLongitude,
        accuracy: position.accuracy,
        source: 'gps',
        timestamp: position.timestamp,
      );

      setState(() {
        _isSaving = false;
        _state = ConfirmPageState.success;
      });

    } catch (e) {
      debugPrint('[GPS sharing] Error: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().contains('صلاحية') 
            ? e.toString() 
            : 'فشل جلب موقعك الجغرافي بدقة عالية. يرجى التحقق من إعدادات GPS بجهازك أو تحديد موقعك يدوياً.';
        _state = ConfirmPageState.error;
        _retryCallback = _shareGpsLocation;
      });
    }
  }

  // ==========================================
  // Manual Location Picker (Map view)
  // ==========================================
  void _openManualMapPicker() async {
    setState(() {
      _state = ConfirmPageState.loading;
    });

    // Try to pre-center the map around the user's current coordinates if available
    ll.LatLng initialLoc = const ll.LatLng(30.0444, 31.2357); // Cairo Center
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          initialLoc = ll.LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}

    setState(() {
      _selectedLatLng = initialLoc;
      _state = ConfirmPageState.mapPicker;
    });

    _debounceReverseGeocode(initialLoc);
  }

  void _debounceReverseGeocode(ll.LatLng latLng) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final address = await MapCoordinatesHelper.reverseGeocode(latLng.latitude, latLng.longitude);
      if (mounted && _state == ConfirmPageState.mapPicker) {
        setState(() {
          _resolvedAddress = address;
        });
      }
    });
  }

  void _confirmManualLocation() async {
    if (_selectedLatLng == null) return;
    
    setState(() {
      _isSaving = true;
      _state = ConfirmPageState.loading;
    });

    try {
      await GlobalState.instance.confirmDeliveryLocation(
        widget.requestId,
        _selectedLatLng!.latitude,
        _selectedLatLng!.longitude,
        _resolvedAddress,
        pickupLat: _request?.pickupLatitude,
        pickupLng: _request?.pickupLongitude,
        accuracy: 0.0,
        source: 'manual',
        timestamp: DateTime.now(),
      );

      setState(() {
        _isSaving = false;
        _state = ConfirmPageState.success;
      });
    } catch (e) {
      debugPrint('[Manual Confirmation] Error: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'حدث خطأ أثناء حفظ موقعك المحدد. يرجى المحاولة مرة أخرى.';
        _state = ConfirmPageState.error;
        _retryCallback = _confirmManualLocation;
      });
    }
  }

  // ==========================================
  // Layout views builders
  // ==========================================
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.mediumBlue),
          const SizedBox(height: 20),
          Text(
            _isSaving ? 'جاري تحديث النظام وإخطار الكابتن...' : 'جاري الاتصال بالنظام...',
            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _errorMessage != null && _errorMessage!.contains('✅') 
                    ? Icons.check_circle_outline_rounded 
                    : _errorMessage != null && _errorMessage!.contains('⚠️')
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline_rounded, 
                color: _errorMessage != null && _errorMessage!.contains('✅') 
                    ? Colors.green 
                    : _errorMessage != null && _errorMessage!.contains('⚠️')
                        ? Colors.amber[800]
                        : AppColors.error, 
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage ?? 'حدث خطأ غير متوقع. يرجى المحاولة مجدداً.',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_retryCallback != null) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _retryCallback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mediumBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'إغلاق الصفحة',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.mediumBlue.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining_outlined, size: 72, color: AppColors.mediumBlue),
          ),
          const SizedBox(height: 24),
          Text(
            'يريد ($_senderName) إرسال طرد إليك، اضغط على الزر بالأسفل لمشاركة موقعك الحالي وتسهيل مهمة الكابتن.',
            style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.7),
            textAlign: TextAlign.center,
          ),
          if (_request?.packageDescription != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppColors.mediumBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'وصف الطرد: ${_request!.packageDescription}',
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: AppColors.blueGradient),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mediumBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _shareGpsLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
              label: Text(
                'استخدام موقعي الحالي 📍',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openManualMapPicker,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.mediumBlue, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.map_outlined, color: AppColors.mediumBlue, size: 20),
            label: Text(
              'تحديد الموقع يدويًا على الخريطة',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPickerView() {
    return Stack(
      children: [
        // FlutterMap centered on selected position
        Positioned.fill(
          child: fm.FlutterMap(
            mapController: _mapController,
            options: fm.MapOptions(
              initialCenter: _selectedLatLng ?? const ll.LatLng(30.0444, 31.2357),
              initialZoom: 15.0,
              minZoom: 6,
              maxZoom: 18,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _selectedLatLng = position.center;
                    _resolvedAddress = 'جاري تحديد إحداثيات الموقع... 📍';
                  });
                  _debounceReverseGeocode(position.center);
                }
              },
            ),
            children: [
              fm.TileLayer(
                urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'com.inride.app',
              ),
            ],
          ),
        ),

        // Fixed Pin Icon at the center of screen
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40.0), // Adjust to point exactly at center
            child: Icon(
              Icons.location_on,
              color: AppColors.error,
              size: 46,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
          ),
        ),

        // HUD Address Card and Buttons at the bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: AppColors.mediumBlue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _resolvedAddress,
                          style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(colors: AppColors.blueGradient),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mediumBlue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _confirmManualLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'تأكيد الموقع 📌',
                            style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _state = ConfirmPageState.intro;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'رجوع',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 76,
              ),
              const SizedBox(height: 20),
              Text(
                'تم تحديد موقعك بنجاح! 🎉',
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'شكراً لك، تم حفظ إحداثيات التوصيل وتحديث التكلفة لدى الكابتن تلقائياً. السائق في طريقه إليك الآن.',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mediumBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'إغلاق الصفحة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    switch (_state) {
      case ConfirmPageState.loading:
        bodyContent = _buildLoadingView();
        break;
      case ConfirmPageState.intro:
        bodyContent = _buildIntroView();
        break;
      case ConfirmPageState.mapPicker:
        bodyContent = _buildMapPickerView();
        break;
      case ConfirmPageState.success:
        bodyContent = _buildSuccessView();
        break;
      case ConfirmPageState.error:
        bodyContent = _buildErrorView();
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _state == ConfirmPageState.mapPicker
          ? null
          : AppBar(
              title: Text(
                'تحديد موقع استلام الديلفري',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: bodyContent,
    );
  }
}
