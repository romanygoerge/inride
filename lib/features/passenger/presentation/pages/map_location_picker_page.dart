import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/place_location.dart';
import '../../../../core/utils/map_coordinates_helper.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/data/sadat_city_geo_data.dart';
import '../../../../core/services/saved_places_service.dart';

enum MapTileType {
  googleStreets,
  googleSatellite,
  cartoVoyager,
}

class MapLocationPickerPage extends StatefulWidget {
  final ll.LatLng? initialCenter;
  final String title;

  const MapLocationPickerPage({
    super.key,
    this.initialCenter,
    this.title = 'حدد من على الخريطة',
  });

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage>
    with SingleTickerProviderStateMixin {
  final fm.MapController _mapController = fm.MapController();
  late ll.LatLng _currentCenter;
  
  MapTileType _tileType = MapTileType.googleStreets;
  bool _isMoving = false;
  bool _isResolving = false;
  String _resolvedPlaceName = 'جاري فحص الموقع...';
  String _resolvedAddress = 'حرك الخريطة لاختيار النقطة المحددة بدقة';
  Timer? _debounceTimer;
  Timer? _searchDebounceTimer;

  // Inline search
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchResults = false;
  List<PlaceLocation> _searchedPlaces = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialCenter ??
        MapCoordinatesHelper.deviceLocation ??
        SadatCityGeoData.cityCenter;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveCurrentCenterAddress();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String get _tileUrl {
    switch (_tileType) {
      case MapTileType.googleStreets:
        // High-clarity Google Maps Streets
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case MapTileType.googleSatellite:
        // Google Satellite Hybrid (satellite imagery + roads & labels)
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case MapTileType.cartoVoyager:
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
    }
  }

  void _onPositionChanged(fm.MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;
    if (hasGesture) {
      if (!_isMoving) {
        setState(() {
          _isMoving = true;
          _showSearchResults = false;
        });
      }
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _isMoving = false;
          });
          _resolveCurrentCenterAddress();
        }
      });
    }
  }

  Future<void> _resolveCurrentCenterAddress() async {
    setState(() {
      _isResolving = true;
    });

    try {
      final address = await MapCoordinatesHelper.reverseGeocode(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      if (!mounted) return;

      String name = 'موقع على الخريطة';
      if (address.isNotEmpty) {
        final split = address.split('،');
        name = split.first.trim();
      }

      setState(() {
        _resolvedAddress = address.isNotEmpty ? address : 'الموقع المحدد على الخريطة';
        _resolvedPlaceName = name.isNotEmpty ? name : 'موقع على الخريطة';
        _isResolving = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedPlaceName = 'موقع على الخريطة';
          _resolvedAddress = '(${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)})';
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _recenterToUserGps() async {
    final pos = await LocationService.instance.getCurrentLocation();
    if (pos != null && mounted) {
      final userLoc = ll.LatLng(pos.latitude, pos.longitude);
      MapCoordinatesHelper.deviceLocation = userLoc;
      _mapController.move(userLoc, 16.5);
      _currentCenter = userLoc;
      _resolveCurrentCenterAddress();
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchedPlaces = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    // 1. Instant local Sadat index results (0ms)
    final localResults = SadatCityGeoData.searchLocal(
      query: trimmed,
      userLat: _currentCenter.latitude,
      userLng: _currentCenter.longitude,
      limit: 6,
    );

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
      _searchedPlaces = localResults;
    });

    // 2. Debounced multi-tier online search across all places, clinics, shops, and streets in Egypt
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final onlineResults = await PlacesSearchService.instance.searchPlaces(
          query: trimmed,
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
          radiusKm: 100.0,
          limit: 15,
        );

        if (!mounted) return;
        setState(() {
          final combined = <PlaceLocation>[...localResults];
          for (final r in onlineResults) {
            if (!combined.any((item) => item.isDuplicateOf(r))) {
              combined.add(r);
            }
          }
          _searchedPlaces = combined.take(12).toList();
          _isSearching = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectAndReturn(PlaceLocation place) {
    FocusScope.of(context).unfocus();
    final dist = place.distanceKm ?? LocationService.instance.calculateDistance(
      widget.initialCenter?.latitude ?? _currentCenter.latitude,
      widget.initialCenter?.longitude ?? _currentCenter.longitude,
      place.latitude,
      place.longitude,
    );

    final confirmedPlace = place.copyWith(
      distanceKm: dist,
      distanceMeters: dist * 1000.0,
      timestamp: DateTime.now(),
    );

    MapCoordinatesHelper.registerCoordinate(
      confirmedPlace.formattedAddress,
      ll.LatLng(confirmedPlace.latitude, confirmedPlace.longitude),
    );
    if (confirmedPlace.placeName.isNotEmpty) {
      MapCoordinatesHelper.registerCoordinate(
        confirmedPlace.placeName,
        ll.LatLng(confirmedPlace.latitude, confirmedPlace.longitude),
      );
    }

    Navigator.pop(context, confirmedPlace);
  }

  void _jumpToPlace(PlaceLocation place) {
    FocusScope.of(context).unfocus();
    _searchController.text = place.placeName;
    setState(() {
      _showSearchResults = false;
      _currentCenter = ll.LatLng(place.latitude, place.longitude);
      _resolvedPlaceName = place.placeName;
      _resolvedAddress = place.formattedAddress;
    });
    _mapController.move(_currentCenter, 16.5);
  }

  void _confirmSelection() {
    final dist = LocationService.instance.calculateDistance(
      widget.initialCenter?.latitude ?? _currentCenter.latitude,
      widget.initialCenter?.longitude ?? _currentCenter.longitude,
      _currentCenter.latitude,
      _currentCenter.longitude,
    );

    final place = PlaceLocation(
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      placeName: _resolvedPlaceName,
      formattedAddress: _resolvedAddress,
      timestamp: DateTime.now(),
      category: 'map_pin',
      distanceKm: dist,
      distanceMeters: dist * 1000.0,
    );

    MapCoordinatesHelper.registerCoordinate(_resolvedAddress, _currentCenter);
    if (_resolvedPlaceName.isNotEmpty) {
      MapCoordinatesHelper.registerCoordinate(_resolvedPlaceName, _currentCenter);
    }

    Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Full-screen FlutterMap
          Positioned.fill(
            child: fm.FlutterMap(
              mapController: _mapController,
              options: fm.MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 16.0,
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                fm.TileLayer(
                  key: ValueKey(_tileType),
                  urlTemplate: _tileUrl,
                  userAgentPackageName: 'com.inride.app',
                  tileProvider: fm.NetworkTileProvider(),
                ),
              ],
            ),
          ),

          // 2. Interactive Animated Center Pin & Shadow
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Pin
                  AnimatedSlide(
                    offset: _isMoving ? const Offset(0, -0.35) : Offset.zero,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            _isMoving ? 'حدد الموقع بدقة' : 'الموقع هنا 📍',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.location_on_rounded,
                          size: 46,
                          color: Color(0xFFE11D48), // Vivid Uber/Google red
                          shadows: [
                            Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Pin Ground Shadow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _isMoving ? 10 : 16,
                    height: _isMoving ? 4 : 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: _isMoving ? 0.2 : 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Floating Search Bar & Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchQueryChanged,
                          style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن شارع أو معلم في السادات...',
                            hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumBlue),
                            ),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchQueryChanged('');
                          },
                        ),
                    ],
                  ),
                ),

                // Live Search Dropdown Suggestions
                if (_showSearchResults && _searchedPlaces.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _searchedPlaces.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = _searchedPlaces[index];
                        final dist = p.distanceKm ?? LocationService.instance.calculateDistance(
                          _currentCenter.latitude,
                          _currentCenter.longitude,
                          p.latitude,
                          p.longitude,
                        );

                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.mediumBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_rounded, color: AppColors.mediumBlue, size: 18),
                          ),
                          title: Text(
                            p.placeName,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            p.formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dist > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${dist.toStringAsFixed(1)} كم',
                                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.center_focus_strong_rounded, size: 18, color: AppColors.mediumBlue),
                                tooltip: 'معاينة بالدبوس على الخريطة',
                                onPressed: () => _jumpToPlace(p),
                              ),
                            ],
                          ),
                          onTap: () => _selectAndReturn(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. Floating Action Controls (Map Layer Toggle, GPS Recenter, Zoom)
          Positioned(
            right: 16,
            bottom: 190,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Layer Switcher Button (Satellite / Streets)
                FloatingActionButton.small(
                  heroTag: 'layer_toggle',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.mediumBlue,
                  elevation: 4,
                  onPressed: () {
                    setState(() {
                      if (_tileType == MapTileType.googleStreets) {
                        _tileType = MapTileType.googleSatellite;
                      } else {
                        _tileType = MapTileType.googleStreets;
                      }
                    });
                  },
                  child: Icon(
                    _tileType == MapTileType.googleSatellite
                        ? Icons.map_outlined
                        : Icons.satellite_alt_rounded,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),

                // GPS Recenter Button
                FloatingActionButton.small(
                  heroTag: 'gps_recenter',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.mediumBlue,
                  elevation: 4,
                  onPressed: _recenterToUserGps,
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
                const SizedBox(height: 10),

                // Zoom In
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 4,
                  onPressed: () {
                    final newZoom = (_mapController.camera.zoom + 1.0).clamp(3.0, 19.0);
                    _mapController.move(_currentCenter, newZoom);
                  },
                  child: const Icon(Icons.add_rounded, size: 20),
                ),
                const SizedBox(height: 6),

                // Zoom Out
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 4,
                  onPressed: () {
                    final newZoom = (_mapController.camera.zoom - 1.0).clamp(3.0, 19.0);
                    _mapController.move(_currentCenter, newZoom);
                  },
                  child: const Icon(Icons.remove_rounded, size: 20),
                ),
              ],
            ),
          ),

          // 5. Bottom HUD: Address Details and Confirmation Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, -4)),
                ],
              ),
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
                    const SizedBox(height: 16),

                    // Place Address Display Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.mediumBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on_rounded, color: AppColors.mediumBlue, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isResolving ? 'جاري قراءة العنوان...' : _resolvedPlaceName,
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isResolving ? 'لحظة واحدة لتحديد الشارع...' : _resolvedAddress,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (_isResolving)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumBlue),
                              ),
                            )
                          else
                            Builder(
                              builder: (context) {
                                final currentLoc = PlaceLocation(
                                  latitude: _currentCenter.latitude,
                                  longitude: _currentCenter.longitude,
                                  placeName: _resolvedPlaceName,
                                  formattedAddress: _resolvedAddress,
                                  timestamp: DateTime.now(),
                                );
                                final isFav = SavedPlacesService.instance.isSaved(currentLoc);

                                return IconButton(
                                  icon: Icon(
                                    isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    color: isFav ? const Color(0xFFEAB308) : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                  tooltip: isFav ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
                                  onPressed: () async {
                                    final added = await SavedPlacesService.instance.toggleSave(currentLoc);
                                    setState(() {});
                                    if (context.mounted) {
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
                                                added ? 'تمت إضافة هذا الموقع للمفضلة ⭐' : 'تمت الإزالة من المفضلة',
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
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirmation Button (Gradient Blue)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mediumBlue.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _confirmSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'تأكيد هذا المكان 📍',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
