import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/DI/injection_container.dart';
import '../../../../core/controllers/map_controller.dart';
import '../../../../core/data/sadat_city_geo_data.dart';
import '../../../../core/models/place_location.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/services/search_history_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../core/services/saved_places_service.dart';
import 'map_location_picker_page.dart';

class SearchResultItem {
  final PlaceLocation location;
  final bool isHistory;

  const SearchResultItem({required this.location, required this.isHistory});
}

class LocationSearchPage extends StatefulWidget {
  final String title;
  final String hintText;
  final LatLng? initialCoordinates;

  const LocationSearchPage({
    super.key,
    required this.title,
    required this.hintText,
    this.initialCoordinates,
  });

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PlaceLocation> _searchResults = [];
  List<PlaceLocation> _nearbyPlaces = [];
  List<PlaceLocation> _savedPlaces = [];
  List<PlaceLocation> _recentHistory = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  late LatLng _referenceCoordinates;
  bool _isUsingMapCenter = false;
  bool _isWaitingForMapsReturn = false;
  String? _lastProcessedClipboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determineReferenceCoordinates();
    _loadInitialPlaces();
    SavedPlacesService.instance.versionNotifier.addListener(_onSavedPlacesChanged);
  }

  bool _isDokkiOrInvalid(LatLng coord) {
    return (coord.latitude - 30.0130).abs() < 0.01 && (coord.longitude - 31.2080).abs() < 0.01;
  }

  void _determineReferenceCoordinates() {
    // 1. If GPS device location is available and valid, prioritize it for accurate distances to user
    final deviceLoc = MapCoordinatesHelper.deviceLocation;
    if (deviceLoc != null &&
        deviceLoc.latitude != 0.0 &&
        deviceLoc.longitude != 0.0 &&
        !_isDokkiOrInvalid(deviceLoc)) {
      _referenceCoordinates = deviceLoc;
      _isUsingMapCenter = false;
      return;
    }

    // 2. Initial coordinates passed from parent (if user moved the map)
    final initial = widget.initialCoordinates;
    if (initial != null &&
        initial.latitude != 0.0 &&
        initial.longitude != 0.0 &&
        !_isDokkiOrInvalid(initial)) {
      _referenceCoordinates = initial;
      _isUsingMapCenter = true;
      return;
    }

    // 3. Current map camera center if valid and not Dokki fallback
    final mapCenter = sl<MapController>().currentMapCenter;
    if (mapCenter != null &&
        mapCenter.latitude != 0.0 &&
        mapCenter.longitude != 0.0 &&
        !_isDokkiOrInvalid(mapCenter)) {
      _referenceCoordinates = mapCenter;
      _isUsingMapCenter = true;
      return;
    }

    // 4. Default to Sadat City Center
    _referenceCoordinates = SadatCityGeoData.cityCenter;
    _isUsingMapCenter = false;
  }

  Future<void> _loadInitialPlaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Load local search history & recalculate dynamic distances from reference coordinate
      await SearchHistoryService.instance.init();
      final rawHistory = SearchHistoryService.instance.getHistory();
      _recentHistory = rawHistory.map((p) {
        final dist = SadatCityGeoData.calculateDistance(
          _referenceCoordinates.latitude,
          _referenceCoordinates.longitude,
          p.latitude,
          p.longitude,
        );
        return p.copyWith(
          distanceKm: double.parse(dist.toStringAsFixed(1)),
          distanceMeters: dist * 1000.0,
        );
      }).toList();

      // 2. Load saved places & recalculate dynamic distances
      await SavedPlacesService.instance.init();
      final rawSaved = SavedPlacesService.instance.getSavedPlaces();
      _savedPlaces = rawSaved.map((p) {
        final dist = SadatCityGeoData.calculateDistance(
          _referenceCoordinates.latitude,
          _referenceCoordinates.longitude,
          p.latitude,
          p.longitude,
        );
        return p.copyWith(
          distanceKm: double.parse(dist.toStringAsFixed(1)),
          distanceMeters: dist * 1000.0,
        );
      }).toList();

      // 3. Load nearby reference places in Sadat City
      _nearbyPlaces = await PlacesSearchService.instance.getNearbyAndPopularPlaces(
        latitude: _referenceCoordinates.latitude,
        longitude: _referenceCoordinates.longitude,
        limit: 15,
      );
    } catch (e) {
      debugPrint('[LocationSearchPage] Error loading initial places: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SavedPlacesService.instance.versionNotifier.removeListener(_onSavedPlacesChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForLocation(autoSelectIfWaiting: true);
    }
  }

  Future<void> _checkClipboardForLocation({bool autoSelectIfWaiting = false, bool manualTrigger = false}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (manualTrigger && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'الحافظة فارغة! حدد المكان في خرائط جوجل واضغط مشاركة أو نسخ الرابط أولاً 📋',
                style: GoogleFonts.cairo(fontSize: 12.5),
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }

      if (text == _lastProcessedClipboard && !manualTrigger) return;

      final coords = await MapCoordinatesHelper.extractCoordinatesFromText(text);
      if (coords != null && mounted) {
        if (autoSelectIfWaiting || _isWaitingForMapsReturn || manualTrigger) {
          if (mounted) {
            setState(() {
              _isWaitingForMapsReturn = false;
            });
          }
        }
        _lastProcessedClipboard = text;
        await _handleDetectedCoordinatesFromMaps(coords);
      } else if (manualTrigger && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يتم العثور على رابط أو إحداثيات صالحة في الحافظة. تأكد من نسخ رابط المكان من الخريطة.',
              style: GoogleFonts.cairo(fontSize: 12.5),
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleDetectedCoordinatesFromMaps(LatLng coords) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              'تم التقاط الموقع من خرائط جوجل 📍، جاري المعالجة...',
              style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppColors.mediumBlue,
        duration: const Duration(seconds: 2),
      ),
    );

    final address = await MapCoordinatesHelper.reverseGeocode(coords.latitude, coords.longitude);
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final loc = PlaceLocation(
      latitude: coords.latitude,
      longitude: coords.longitude,
      placeName: address.isNotEmpty ? address.split('،').first.trim() : 'موقع من خرائط جوجل',
      formattedAddress: address.isNotEmpty ? address : 'موقع محدد من خرائط جوجل (${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)})',
      timestamp: DateTime.now(),
      category: 'google_maps',
    );

    _selectPlace(loc, isHistory: false);
  }

  void _onSavedPlacesChanged() {
    if (!mounted) return;
    final rawSaved = SavedPlacesService.instance.getSavedPlaces();
    setState(() {
      _savedPlaces = rawSaved.map((p) {
        final dist = SadatCityGeoData.calculateDistance(
          _referenceCoordinates.latitude,
          _referenceCoordinates.longitude,
          p.latitude,
          p.longitude,
        );
        return p.copyWith(
          distanceKm: double.parse(dist.toStringAsFixed(1)),
          distanceMeters: dist * 1000.0,
        );
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    // 1. Instant 0ms response: match immediately against Sadat City Local Geo-Index
    final instantLocalMatches = SadatCityGeoData.searchLocal(
      query: trimmed,
      userLat: _referenceCoordinates.latitude,
      userLng: _referenceCoordinates.longitude,
      limit: 15,
    );

    setState(() {
      _searchQuery = query;
      _searchResults = instantLocalMatches;
      // Show loading indicator only if we need external background enrichment
      _isLoading = instantLocalMatches.isEmpty;
    });

    // 2. Debounce (400ms) for background multi-tier search (Nominatim / Photon / DB)
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        if (!mounted) return;
        setState(() {
          _isLoading = true;
        });

        final results = await PlacesSearchService.instance.searchPlaces(
          query: query,
          latitude: _referenceCoordinates.latitude,
          longitude: _referenceCoordinates.longitude,
          radiusKm: 100.0,
          limit: 20,
        );

        if (mounted) {
          setState(() {
            _searchResults = results.isNotEmpty ? results : instantLocalMatches;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('[LocationSearchPage] Error searching places: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  void _selectPlace(PlaceLocation place, {bool isHistory = false}) async {
    // Record selection asynchronously to update popularity and user search history
    PlacesSearchService.instance.recordPlaceSelection(place, query: _searchQuery);

    if (place.isValid) {
      MapCoordinatesHelper.registerCoordinate(place.formattedAddress, LatLng(place.latitude, place.longitude));
      if (place.placeName.isNotEmpty) {
        MapCoordinatesHelper.registerCoordinate(place.placeName, LatLng(place.latitude, place.longitude));
      }
    }

    Navigator.pop(context, SearchResultItem(location: place, isHistory: isHistory));
  }

  Future<void> _useCurrentGpsLocation() async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Text(
              l10n?.detectingLocation ?? 'جاري تحديد موقعك الحالي...',
              style: GoogleFonts.cairo(fontSize: 13),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.mediumBlue,
      ),
    );

    try {
      final pos = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (pos != null) {
        MapCoordinatesHelper.deviceLocation = LatLng(pos.latitude, pos.longitude);
        final geocodedName = await MapCoordinatesHelper.reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) return;

        final addressString = geocodedName.isNotEmpty
            ? geocodedName
            : '${l10n?.myCurrentLocation ?? "موقعي الحالي"} (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';

        final loc = PlaceLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          placeName: l10n?.myCurrentLocation ?? 'موقعي الحالي',
          formattedAddress: addressString,
          timestamp: DateTime.now(),
          category: 'gps',
        );

        _selectPlace(loc, isHistory: false);
      } else {
        final fallback = MapCoordinatesHelper.deviceLocation ?? _referenceCoordinates;
        final loc = PlaceLocation(
          latitude: fallback.latitude,
          longitude: fallback.longitude,
          placeName: 'موقعي الحالي',
          formattedAddress: 'الموقع الحالي',
          timestamp: DateTime.now(),
          category: 'gps',
        );
        _selectPlace(loc, isHistory: false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final fallback = MapCoordinatesHelper.deviceLocation ?? _referenceCoordinates;
        final loc = PlaceLocation(
          latitude: fallback.latitude,
          longitude: fallback.longitude,
          placeName: 'موقعي الحالي',
          formattedAddress: 'الموقع الحالي',
          timestamp: DateTime.now(),
          category: 'gps',
        );
        _selectPlace(loc, isHistory: false);
      }
    }
  }

  void _openMapPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final mapName = isIOS ? 'خرائط آبل أو جوجل' : 'تطبيق خرائط جوجل (Google Maps)';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mediumBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.map_rounded, color: AppColors.mediumBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'تحديد الموقع عبر الخريطة',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Option 1: Open external Google Maps / Apple Maps
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _launchGoogleMapsAndListen();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.explore_rounded, color: Color(0xFF16A34A), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'فتح في $mapName',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'حدد مكانك بدقة، واضغط "مشاركة" أو "نسخ الرابط" ثم ارجع للتطبيق وسيلتقطه فوراً 🚀',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.5,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF16A34A)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option 2: Open In-App Interactive Map
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final pickedPlace = await Navigator.push<PlaceLocation>(
                          context,
                          SnappyPageRoute(
                            page: MapLocationPickerPage(
                              initialCenter: _referenceCoordinates,
                              title: widget.title,
                            ),
                          ),
                        );
                        if (pickedPlace != null && mounted) {
                          _selectPlace(pickedPlace, isHistory: false);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.satellite_alt_rounded, color: AppColors.mediumBlue, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'خريطة inRide التفاعلية (مع الأقمار الصناعية)',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'حدد الموقع بالدبوس مباشرة داخل التطبيق دون مغادرته 📍',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option 3: Quick Paste from Clipboard
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _checkClipboardForLocation(autoSelectIfWaiting: false);
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 18, color: AppColors.mediumBlue),
                  label: Text(
                    'لصق رابط أو إحداثيات تم نسخها مسبقاً من الخريطة',
                    style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.mediumBlue),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchGoogleMapsAndListen() async {
    if (mounted) {
      setState(() {
        _isWaitingForMapsReturn = true;
      });
    }

    final lat = _referenceCoordinates.latitude;
    final lng = _referenceCoordinates.longitude;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.share_location_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'في الخريطة: حدد مكانك واضغط "مشاركة" أو "نسخ الرابط" ثم ارجع هنا 📍',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF15803D),
      ),
    );

    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isIOS) {
      final googleMapsUri = Uri.parse('comgooglemaps://?q=$lat,$lng&center=$lat,$lng');
      final appleMapsUri = Uri.parse('http://maps.apple.com/?ll=$lat,$lng&q=$lat,$lng');
      try {
        if (await canLaunchUrl(googleMapsUri)) {
          await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
      try {
        await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {
        await launchUrl(
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
          mode: LaunchMode.externalApplication,
        );
        return;
      }
    } else {
      final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      try {
        final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _useCustomQueryAsPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Try high-speed geocoding first
    final geocoded = await MapCoordinatesHelper.geocodeAddress(
      trimmed,
      biasLat: _referenceCoordinates.latitude,
      biasLng: _referenceCoordinates.longitude,
    );

    final lat = geocoded?.latitude ?? _referenceCoordinates.latitude;
    final lon = geocoded?.longitude ?? _referenceCoordinates.longitude;
    final dist = LocationService.instance.calculateDistance(_referenceCoordinates.latitude, _referenceCoordinates.longitude, lat, lon);

    final loc = PlaceLocation(
      latitude: lat,
      longitude: lon,
      placeName: trimmed,
      formattedAddress: trimmed,
      timestamp: DateTime.now(),
      category: 'landmark',
      distanceKm: dist,
      distanceMeters: dist * 1000,
    );

    _selectPlace(loc, isHistory: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isQueryEmpty = _searchQuery.trim().isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
            // Search Input Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? AppColors.mediumBlue.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) async {
                    if (value.trim().isNotEmpty) {
                      if (_searchResults.isNotEmpty) {
                        _selectPlace(_searchResults.first);
                      } else {
                        _useCustomQueryAsPlace(value);
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.mediumBlue, size: 22),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: AppColors.mediumBlue,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : (_searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
            ),

            // Top Fast Action Buttons (My GPS Location & Pick On Map)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // GPS Location Button
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _useCurrentGpsLocation,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.mediumBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.mediumBlue.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.my_location_rounded, color: AppColors.mediumBlue, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n?.myCurrentLocation ?? 'موقعي الحالي',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.mediumBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pick On Map Button (Directly opens Google Maps / Apple Maps)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _launchGoogleMapsAndListen,
                        onLongPress: _openMapPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.explore_rounded, color: Color(0xFF16A34A), size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'حدد من على الخريطة',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                    Text(
                                      'Google / Apple Maps',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF15803D),
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
                  ),
                ],
              ),
            ),

            // Active Google Maps / Apple Maps capture helper banner
            if (_isWaitingForMapsReturn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'بانتظار تحديد الموقع من الخريطة... انسخ الرابط ثم اضغط تطبيق 📍',
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _isWaitingForMapsReturn = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _checkClipboardForLocation(autoSelectIfWaiting: true, manualTrigger: true);
                              },
                              icon: const Icon(Icons.content_paste_rounded, size: 15, color: Colors.white),
                              label: Text(
                                'تطبيق الموقع المنسوخ',
                                style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _launchGoogleMapsAndListen,
                            icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF16A34A)),
                            label: Text(
                              'إعادة فتح الخريطة',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF16A34A)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Reference indicator if map was moved
            if (_isUsingMapCenter && isQueryEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.center_focus_strong_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'عرض الأماكن القريبة من المركز المحدد على الخريطة',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content List
            Expanded(
              child: isQueryEmpty
                  ? _buildEmptyQueryContent()
                  : _buildSearchResultsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsContent() {
    if (_searchResults.isEmpty && !_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 20),
          Icon(Icons.search_off_rounded, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(
            'لم نجد نتائج مطابقة تماماً لـ "$_searchQuery"',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'يمكنك تعيين هذا الاسم مباشرة كوجهة مخصصة أو تحديده على الخريطة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _useCustomQueryAsPlace(_searchQuery),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              'استخدام "$_searchQuery" كوجهة مباشرة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length + (_searchQuery.trim().isNotEmpty ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          // Bottom action to use exact query
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: InkWell(
              onTap: () => _useCustomQueryAsPlace(_searchQuery),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_location_alt_outlined, color: AppColors.mediumBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'استخدام "$_searchQuery" كعنوان مخصص',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mediumBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final place = _searchResults[index];
        return _buildPlaceListTile(place);
      },
    );
  }

  Widget _buildEmptyQueryContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Saved Places (Home, Work, etc.)
        if (_savedPlaces.isNotEmpty) ...[
          _buildSectionHeader('الأماكن المحفوظة', Icons.bookmark_outline_rounded),
          ..._savedPlaces.map((p) => _buildPlaceListTile(p, isSaved: true)),
          const SizedBox(height: 12),
        ],

        // 2. Recent Search History
        if (_recentHistory.isNotEmpty) ...[
          _buildSectionHeader('عمليات البحث الأخيرة', Icons.history_rounded),
          ..._recentHistory.take(5).map((p) => _buildPlaceListTile(p, isHistory: true)),
          const SizedBox(height: 12),
        ],

        // 3. Nearby Reference Places
        if (_nearbyPlaces.isNotEmpty) ...[
          _buildSectionHeader(
            _isUsingMapCenter ? 'أماكن قريبة من مركز الخريطة' : 'أماكن مقترحة قريبة منك',
            Icons.near_me_outlined,
          ),
          ..._nearbyPlaces.map((p) => _buildPlaceListTile(p)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, right: 4, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceListTile(PlaceLocation place, {bool isSaved = false, bool isHistory = false}) {
    final iconData = PlacesSearchService.getCategoryIcon(
      place.category,
      isSaved: isSaved || place.isSaved,
      isHistory: isHistory || place.isHistory,
    );

    final distanceStr = place.localizedDistance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectPlace(place, isHistory: isHistory || place.isHistory),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              // Category Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Icon(iconData, color: AppColors.mediumBlue, size: 20),
              ),
              const SizedBox(width: 12),

              // Title and Address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.placeName.isNotEmpty ? place.placeName : place.formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (distanceStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.mediumBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car_filled_outlined, size: 10, color: AppColors.mediumBlue),
                                const SizedBox(width: 3),
                                Text(
                                  distanceStr,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mediumBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (place.formattedAddress.isNotEmpty && place.formattedAddress != place.placeName) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.formattedAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Favorite / Bookmark Icon Button
              IconButton(
                icon: Icon(
                  SavedPlacesService.instance.isSaved(place)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: SavedPlacesService.instance.isSaved(place)
                      ? const Color(0xFFEAB308) // Amber / Gold
                      : AppColors.textSecondary.withValues(alpha: 0.4),
                  size: 22,
                ),
                tooltip: SavedPlacesService.instance.isSaved(place) ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
                onPressed: () async {
                  final added = await SavedPlacesService.instance.toggleSave(place);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              added ? Icons.bookmark_added_rounded : Icons.bookmark_remove_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              added ? 'تمت إضافة المكان إلى المفضلة ⭐' : 'تمت الإزالة من المفضلة',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: added ? const Color(0xFF15803D) : Colors.black87,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
