import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place_location.dart';
import '../services/location_service.dart';
import '../services/search_history_service.dart';
import '../utils/map_coordinates_helper.dart';

class PlacesSearchService {
  static final PlacesSearchService _instance = PlacesSearchService._internal();
  static PlacesSearchService get instance => _instance;
  PlacesSearchService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // In-memory caching for query results to minimize redundant API calls
  final Map<String, List<PlaceLocation>> _queryCache = {};
  DateTime? _lastCacheClear;

  void _checkCacheValidity() {
    final now = DateTime.now();
    if (_lastCacheClear == null || now.difference(_lastCacheClear!).inMinutes > 10) {
      _queryCache.clear();
      _lastCacheClear = now;
    }
  }

  /// Searches for places using PostGIS ranking in Supabase.
  /// Combines Arabic/English text relevance, PostGIS geographic distance, popularity, and user history.
  Future<List<PlaceLocation>> searchPlaces({
    required String query,
    required double latitude,
    required double longitude,
    double radiusKm = 150.0,
    int limit = 20,
  }) async {
    _checkCacheValidity();
    final trimmedQuery = query.trim();
    final cacheKey = '$trimmedQuery|${latitude.toStringAsFixed(3)}|${longitude.toStringAsFixed(3)}';

    if (_queryCache.containsKey(cacheKey)) {
      return _queryCache[cacheKey]!;
    }

    final List<PlaceLocation> results = [];
    final Set<String> registeredNames = {};

    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase.rpc(
        'search_places',
        params: {
          'p_query': trimmedQuery,
          'p_lat': latitude,
          'p_lng': longitude,
          'p_radius_km': radiusKm,
          'p_limit': limit,
          'p_user_id': currentUserId,
        },
      ).timeout(const Duration(seconds: 6));

      if (response is List) {
        for (final item in response) {
          if (item is Map) {
            final loc = PlaceLocation.fromJson(Map<String, dynamic>.from(item));
            if (loc.isValid) {
              results.add(loc);
              registeredNames.add(loc.placeName.toLowerCase().trim());
              MapCoordinatesHelper.registerCoordinate(loc.formattedAddress, LatLng(loc.latitude, loc.longitude));
              if (loc.placeName.isNotEmpty) {
                MapCoordinatesHelper.registerCoordinate(loc.placeName, LatLng(loc.latitude, loc.longitude));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PlacesSearchService] Error querying search_places RPC: $e');
    }

    // Fallback & External Search (Nominatim) if query is non-empty and DB returns few results
    if (trimmedQuery.isNotEmpty && results.length < 5) {
      try {
        final osmResults = await _searchNominatimFallback(trimmedQuery, latitude, longitude);
        for (final osmLoc in osmResults) {
          final key = osmLoc.placeName.toLowerCase().trim();
          if (!registeredNames.contains(key) && !results.any((r) => r.isDuplicateOf(osmLoc))) {
            registeredNames.add(key);
            results.add(osmLoc);
          }
        }
      } catch (e) {
        debugPrint('[PlacesSearchService] Fallback search error: $e');
      }
    }

    // Cache the result
    if (results.isNotEmpty) {
      _queryCache[cacheKey] = List.unmodifiable(results);
    }

    return results;
  }

  /// Fallback OSM Geocoding lookup with distance calculation from reference location
  Future<List<PlaceLocation>> _searchNominatimFallback(String query, double userLat, double userLng) async {
    final List<PlaceLocation> list = [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&accept-language=ar&countrycodes=eg&limit=5',
      );
      final response = await http.get(url, headers: {'User-Agent': 'inRideApp/1.0'}).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        for (final item in data) {
          final displayName = item['display_name'] as String? ?? '';
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final placeId = item['place_id']?.toString();

          if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
            final parts = displayName.split(',');
            final title = parts.first.trim();
            final distKm = LocationService.instance.calculateDistance(userLat, userLng, lat, lon);

            final loc = PlaceLocation(
              placeId: placeId,
              latitude: lat,
              longitude: lon,
              placeName: title,
              formattedAddress: displayName,
              timestamp: DateTime.now(),
              category: 'landmark',
              distanceKm: distKm,
              distanceMeters: distKm * 1000,
            );

            MapCoordinatesHelper.registerCoordinate(displayName, LatLng(lat, lon));
            MapCoordinatesHelper.registerCoordinate(title, LatLng(lat, lon));
            list.add(loc);
          }
        }
      }
    } catch (_) {}
    return list;
  }

  /// Records place selection to boost ranking and update search history
  Future<void> recordPlaceSelection(PlaceLocation place, {String query = ''}) async {
    if (!place.isValid) return;

    // 1. Local history cache
    await SearchHistoryService.instance.saveLocation(place);

    // 2. Asynchronously notify Supabase RPC
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      _supabase.rpc('record_place_selection', params: {
        'p_user_id': currentUserId,
        'p_place_id': place.placeId,
        'p_place_name': place.placeName,
        'p_formatted_address': place.formattedAddress,
        'p_latitude': place.latitude,
        'p_longitude': place.longitude,
        'p_query': query,
      }).then((_) {
        _queryCache.clear(); // invalidate cache so next search reflects updated score
      }).catchError((e) {
        debugPrint('[PlacesSearchService] Error recording place selection: $e');
      });
    } catch (e) {
      debugPrint('[PlacesSearchService] Record selection error: $e');
    }
  }

  /// Retrieves user saved places (Home, Work, Starred)
  Future<List<PlaceLocation>> getSavedPlaces() async {
    final List<PlaceLocation> saved = [];
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return saved;

    try {
      final response = await _supabase
          .from('user_saved_places')
          .select()
          .eq('user_id', currentUserId)
          .order('created_at', ascending: true);

      for (final item in response) {
        saved.add(PlaceLocation(
          placeId: item['place_id'] as String? ?? item['id'] as String?,
          latitude: (item['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (item['longitude'] as num?)?.toDouble() ?? 0.0,
          placeName: item['title'] as String? ?? '',
          formattedAddress: item['address'] as String? ?? '',
          timestamp: DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now(),
          category: item['icon'] as String? ?? 'star',
          isSaved: true,
        ));
      }
    } catch (e) {
      debugPrint('[PlacesSearchService] Error getting saved places: $e');
    }
    return saved;
  }

  /// Resolves appropriate IconData based on category string
  static IconData getCategoryIcon(String? category, {bool isSaved = false, bool isHistory = false}) {
    if (isSaved) {
      switch (category?.toLowerCase()) {
        case 'home':
        case 'المنزل':
          return Icons.home_outlined;
        case 'work':
        case 'العمل':
          return Icons.work_outline;
        default:
          return Icons.star_border_rounded;
      }
    }

    if (isHistory) {
      return Icons.history_rounded;
    }

    switch (category?.toLowerCase()) {
      case 'university':
      case 'school':
      case 'جامعة':
      case 'كلية':
      case 'مدرسة':
        return Icons.school_outlined;
      case 'hospital':
      case 'مستشفى':
      case 'عيادة':
        return Icons.local_hospital_outlined;
      case 'mall':
      case 'store':
      case 'مول':
      case 'متجر':
      case 'سوق':
        return Icons.shopping_bag_outlined;
      case 'airport':
      case 'مطار':
        return Icons.flight_takeoff_outlined;
      case 'station':
      case 'موقف':
      case 'محطة':
        return Icons.directions_bus_outlined;
      case 'restaurant':
      case 'مطعم':
        return Icons.restaurant_outlined;
      case 'cafe':
      case 'كافيه':
      case 'مقهى':
        return Icons.local_cafe_outlined;
      case 'government':
      case 'جهاز':
      case 'حكومي':
        return Icons.account_balance_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }
}
