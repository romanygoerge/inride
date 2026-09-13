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
import '../../../../core/services/meta_analytics_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../core/utils/snappy_page_route.dart';
import '../../../../core/services/saved_places_service.dart';
import '../../../../core/state/global_state.dart';
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
  List<PlaceLocation> _savedPlaces = [];
  List<PlaceLocation> _recentHistory = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  late LatLng _referenceCoordinates;
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
    // 1. If searching for Destination ("إلى أين؟") and we already have a pickup location in Sadat City:
    // Measuring the distance from the pickup location is what the passenger needs to see (actual ride trip distance)!
    final isSearchingDestination = widget.title.contains('إلى') ||
        widget.title.contains('To') ||
        widget.title.contains('وجهت') ||
        widget.title.contains('الوصول');
    if (isSearchingDestination) {
      final fromLat = GlobalState.instance.fromLat;
      final fromLng = GlobalState.instance.fromLng;
      if (fromLat != null &&
          fromLng != null &&
          fromLat != 0.0 &&
          fromLng != 0.0 &&
          SadatCityGeoData.isInSadatCity(fromLat, fromLng)) {
        _referenceCoordinates = LatLng(fromLat, fromLng);
        return;
      }
    }

    // 2. Initial coordinates passed from parent (e.g. current map camera pin in Sadat City)
    final initial = widget.initialCoordinates;
    if (initial != null &&
        initial.latitude != 0.0 &&
        initial.longitude != 0.0 &&
        !_isDokkiOrInvalid(initial) &&
        SadatCityGeoData.isInSadatCity(initial.latitude, initial.longitude)) {
      _referenceCoordinates = initial;
      return;
    }

    // 3. Device GPS location ONLY IF physically inside Sadat City (prevents 80 km Cairo offset when testing)
    final deviceLoc = MapCoordinatesHelper.deviceLocation;
    if (deviceLoc != null &&
        deviceLoc.latitude != 0.0 &&
        deviceLoc.longitude != 0.0 &&
        !_isDokkiOrInvalid(deviceLoc) &&
        SadatCityGeoData.isInSadatCity(deviceLoc.latitude, deviceLoc.longitude)) {
      _referenceCoordinates = deviceLoc;
      return;
    }

    // 4. Current map camera center if valid and in Sadat City
    final mapCenter = sl<MapController>().currentMapCenter;
    if (mapCenter != null &&
        mapCenter.latitude != 0.0 &&
        mapCenter.longitude != 0.0 &&
        !_isDokkiOrInvalid(mapCenter) &&
        SadatCityGeoData.isInSadatCity(mapCenter.latitude, mapCenter.longitude)) {
      _referenceCoordinates = mapCenter;
      return;
    }

    // 5. Default fallback to Sadat City Center (prevents impossible ~80 km distances)
    _referenceCoordinates = SadatCityGeoData.cityCenter;
  }

  Future<void> _loadInitialPlaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Load local search history & recalculate dynamic distances from reference coordinate
      await SearchHistoryService.instance.init();
      final rawHistory = SearchHistoryService.instance.getHistory();
      _recentHistory = rawHistory
          .where((p) => SadatCityGeoData.isInSadatCity(p.latitude, p.longitude))
          .map((p) {
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
      _savedPlaces = rawSaved
          .where((p) => SadatCityGeoData.isInSadatCity(p.latitude, p.longitude))
          .map((p) {
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
      _checkClipboardForLocation();
    }
  }

  Future<void> _checkClipboardForLocation() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty || text == _lastProcessedClipboard) return;

      final placeInfo = await MapCoordinatesHelper.extractPlaceFromTextOrUrl(text);
      if (placeInfo != null && mounted) {
        _lastProcessedClipboard = text;
        await _handleDetectedPlaceInfo(placeInfo);
      }
    } catch (_) {}
  }

  Future<void> _handleDetectedPlaceInfo(ExtractedPlaceInfo placeInfo) async {
    if (!mounted) return;
    final coords = placeInfo.coordinates;

    // Reject places outside Sadat City
    if (!SadatCityGeoData.isInSadatCity(coords.latitude, coords.longitude)) {
      return;
    }

    final dist = SadatCityGeoData.calculateDistance(
      _referenceCoordinates.latitude,
      _referenceCoordinates.longitude,
      coords.latitude,
      coords.longitude,
    );

    final loc = PlaceLocation(
      latitude: coords.latitude,
      longitude: coords.longitude,
      placeName: placeInfo.placeName,
      formattedAddress: placeInfo.formattedAddress,
      timestamp: DateTime.now(),
      category: 'landmark',
      distanceKm: double.parse(dist.toStringAsFixed(1)),
      distanceMeters: dist * 1000.0,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم تحديد: ${placeInfo.placeName}',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    _selectPlace(loc, isHistory: false);
  }

  void _onSavedPlacesChanged() {
    if (!mounted) return;
    final rawSaved = SavedPlacesService.instance.getSavedPlaces();
    setState(() {
      _savedPlaces = rawSaved
          .where((p) => SadatCityGeoData.isInSadatCity(p.latitude, p.longitude))
          .map((p) {
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
          limit: 25,
        );

        unawaited(MetaAnalyticsService.instance.logSearch(
          query: query,
          resultCount: results.length,
          searchType: 'location',
        ));

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
        final isInsideSadat = SadatCityGeoData.isInSadatCity(pos.latitude, pos.longitude);
        final effectiveLat = isInsideSadat ? pos.latitude : SadatCityGeoData.cityCenter.latitude;
        final effectiveLng = isInsideSadat ? pos.longitude : SadatCityGeoData.cityCenter.longitude;

        if (isInsideSadat) {
          MapCoordinatesHelper.deviceLocation = LatLng(pos.latitude, pos.longitude);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أنت خارج نطاق مدينة السادات. تم تعيين الموقع الافتراضي داخل السادات.',
                      style: GoogleFonts.cairo(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE65100),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }

        final geocodedName = isInsideSadat
            ? await MapCoordinatesHelper.reverseGeocode(pos.latitude, pos.longitude)
            : 'مدينة السادات - وسط المدينة';
        if (!mounted) return;

        final addressString = geocodedName.isNotEmpty
            ? geocodedName
            : '${l10n?.myCurrentLocation ?? "موقعي الحالي"} (${effectiveLat.toStringAsFixed(4)}, ${effectiveLng.toStringAsFixed(4)})';

        final loc = PlaceLocation(
          latitude: effectiveLat,
          longitude: effectiveLng,
          placeName: isInsideSadat ? (l10n?.myCurrentLocation ?? 'موقعي الحالي') : 'مدينة السادات - وسط المدينة',
          formattedAddress: addressString,
          timestamp: DateTime.now(),
          category: 'gps',
        );

        _selectPlace(loc, isHistory: false);
      } else {
        final fallback = (MapCoordinatesHelper.deviceLocation != null &&
                SadatCityGeoData.isInSadatCity(
                    MapCoordinatesHelper.deviceLocation!.latitude,
                    MapCoordinatesHelper.deviceLocation!.longitude))
            ? MapCoordinatesHelper.deviceLocation!
            : _referenceCoordinates;
        final loc = PlaceLocation(
          latitude: fallback.latitude,
          longitude: fallback.longitude,
          placeName: 'موقعي الحالي',
          formattedAddress: 'الموقع الحالي (مدينة السادات)',
          timestamp: DateTime.now(),
          category: 'gps',
        );
        _selectPlace(loc, isHistory: false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final fallback = (MapCoordinatesHelper.deviceLocation != null &&
                SadatCityGeoData.isInSadatCity(
                    MapCoordinatesHelper.deviceLocation!.latitude,
                    MapCoordinatesHelper.deviceLocation!.longitude))
            ? MapCoordinatesHelper.deviceLocation!
            : _referenceCoordinates;
        final loc = PlaceLocation(
          latitude: fallback.latitude,
          longitude: fallback.longitude,
          placeName: 'موقعي الحالي',
          formattedAddress: 'الموقع الحالي (مدينة السادات)',
          timestamp: DateTime.now(),
          category: 'gps',
        );
        _selectPlace(loc, isHistory: false);
      }
    }
  }

  Future<void> _openMapPicker() async {
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
  }

  Future<void> _useCustomQueryAsPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // 1. Try geocoding biased to Sadat City first
    var geocoded = await MapCoordinatesHelper.geocodeAddress(
      '$trimmed، مدينة السادات',
      biasLat: _referenceCoordinates.latitude,
      biasLng: _referenceCoordinates.longitude,
    );

    // 2. If not found in Sadat City, geocode generally across Egypt
    geocoded ??= await MapCoordinatesHelper.geocodeAddress(
      '$trimmed، مصر',
      biasLat: _referenceCoordinates.latitude,
      biasLng: _referenceCoordinates.longitude,
    );

    final rawLat = geocoded?.latitude ?? _referenceCoordinates.latitude;
    final rawLon = geocoded?.longitude ?? _referenceCoordinates.longitude;
    final isInSadat = SadatCityGeoData.isInSadatCity(rawLat, rawLon);
    final dist = LocationService.instance.calculateDistance(_referenceCoordinates.latitude, _referenceCoordinates.longitude, rawLat, rawLon);

    final loc = PlaceLocation(
      latitude: rawLat,
      longitude: rawLon,
      placeName: trimmed,
      formattedAddress: isInSadat && (geocoded != null) ? 'مدينة السادات - $trimmed' : trimmed,
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

            // Top Fast Action Buttons (My GPS Location & Pin on Map)
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

                  // Pick On In-App Map Button (Interactive Map with Pin)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openMapPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.map_outlined, color: AppColors.primary, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تحديد على الخريطة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
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
    final hasSavedOrHistory = _savedPlaces.isNotEmpty || _recentHistory.isNotEmpty;
    if (!hasSavedOrHistory) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.mediumBlue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_rounded, size: 34, color: AppColors.mediumBlue),
              ),
              const SizedBox(height: 16),
              Text(
                'ابحث عن أي وجهة تريدها',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اكتب اسم المكان أو الشارع أعلاه، أو حدد موقعك بدقة بالدبوس على الخريطة',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Saved Places (Home, Work, Favorites)
        if (_savedPlaces.isNotEmpty) ...[
          _buildSectionHeader('الأماكن المحفوظة', Icons.bookmark_rounded),
          ..._savedPlaces.map((p) => _buildPlaceListTile(p, isSaved: true)),
          const SizedBox(height: 12),
        ],

        // 2. Recent Search History
        if (_recentHistory.isNotEmpty) ...[
          _buildSectionHeader('عمليات البحث الأخيرة', Icons.history_rounded),
          ..._recentHistory.take(5).map((p) => _buildPlaceListTile(p, isHistory: true)),
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

    // Ensure distance is always calculated dynamically from the valid reference coordinate in Sadat City
    String distanceStr;
    if (place.latitude != 0.0 && place.longitude != 0.0) {
      final double realDistKm = SadatCityGeoData.calculateDistance(
        _referenceCoordinates.latitude,
        _referenceCoordinates.longitude,
        place.latitude,
        place.longitude,
      );
      if (realDistKm < 1.0) {
        final meters = (realDistKm * 1000).round();
        distanceStr = '$meters م';
      } else {
        distanceStr = '${realDistKm.toStringAsFixed(1)} كم';
      }
    } else {
      distanceStr = place.localizedDistance;
    }

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
