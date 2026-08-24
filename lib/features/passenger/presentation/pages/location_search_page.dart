import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/DI/injection_container.dart';
import '../../../../core/controllers/map_controller.dart';
import '../../../../core/models/place_location.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/services/search_history_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../generated/app_localizations.dart';

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

class _LocationSearchPageState extends State<LocationSearchPage> {
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

  @override
  void initState() {
    super.initState();
    _determineReferenceCoordinates();
    _loadInitialPlaces();
  }

  void _determineReferenceCoordinates() {
    if (widget.initialCoordinates != null &&
        widget.initialCoordinates!.latitude != 0.0 &&
        widget.initialCoordinates!.longitude != 0.0) {
      _referenceCoordinates = widget.initialCoordinates!;
      _isUsingMapCenter = true;
      return;
    }

    final mapCenter = sl<MapController>().currentMapCenter;
    if (mapCenter != null && mapCenter.latitude != 0.0 && mapCenter.longitude != 0.0) {
      _referenceCoordinates = mapCenter;
      _isUsingMapCenter = true;
      return;
    }

    if (MapCoordinatesHelper.deviceLocation != null) {
      _referenceCoordinates = MapCoordinatesHelper.deviceLocation!;
      _isUsingMapCenter = false;
      return;
    }

    // Default Cairo fallback
    _referenceCoordinates = const LatLng(30.0444, 31.2357);
    _isUsingMapCenter = false;
  }

  Future<void> _loadInitialPlaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Load local search history
      await SearchHistoryService.instance.init();
      _recentHistory = SearchHistoryService.instance.getHistory();

      // 2. Load saved places
      _savedPlaces = await PlacesSearchService.instance.getSavedPlaces();

      // 3. Load nearby reference places
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
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });

    // 250ms debounce for rapid, snappy results
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await PlacesSearchService.instance.searchPlaces(
          query: query,
          latitude: _referenceCoordinates.latitude,
          longitude: _referenceCoordinates.longitude,
          radiusKm: 300.0,
          limit: 20,
        );

        if (mounted) {
          setState(() {
            _searchResults = results;
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

  Future<void> _useMapCenterLocation() async {
    final geocoded = await MapCoordinatesHelper.reverseGeocode(
      _referenceCoordinates.latitude,
      _referenceCoordinates.longitude,
    );

    final loc = PlaceLocation(
      latitude: _referenceCoordinates.latitude,
      longitude: _referenceCoordinates.longitude,
      placeName: geocoded.isNotEmpty ? geocoded.split('،').first.trim() : 'الموقع المحدد على الخريطة',
      formattedAddress: geocoded.isNotEmpty ? geocoded : 'الموقع المحدد على الخريطة',
      timestamp: DateTime.now(),
      category: 'map_pin',
    );

    _selectPlace(loc, isHistory: false);
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

                  // Pick On Map Button
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _useMapCenterLocation,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.map_outlined, color: Color(0xFF16A34A), size: 16),
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
                                    color: const Color(0xFF16A34A),
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
            ],
          ),
        ),
      ),
    );
  }
}
