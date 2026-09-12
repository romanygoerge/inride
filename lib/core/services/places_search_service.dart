import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/sadat_city_geo_data.dart';
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

  /// Primary multi-tier smart search function.
  /// Combines Sadat City Local Geo-Index, Photon, OpenStreetMap Nominatim, and Supabase.
  /// Prioritizes Sadat City and proximity to user's GPS position.
  Future<List<PlaceLocation>> searchPlaces({
    required String query,
    required double latitude,
    required double longitude,
    double radiusKm = 100.0,
    int limit = 20,
  }) async {
    _checkCacheValidity();
    final trimmedQuery = query.trim();

    // If query is empty, return saved places, history, and nearby reference landmarks in Sadat City
    if (trimmedQuery.isEmpty) {
      return getNearbyAndPopularPlaces(latitude: latitude, longitude: longitude);
    }

    final cacheKey = '$trimmedQuery|${latitude.toStringAsFixed(2)}|${longitude.toStringAsFixed(2)}';
    if (_queryCache.containsKey(cacheKey)) {
      return _queryCache[cacheKey]!;
    }

    final List<PlaceLocation> combinedResults = [];
    final Set<String> seenKeys = {};

    void addResult(PlaceLocation loc) {
      if (!loc.isValid) return;
      // Key based on normalized name and rounded coordinates
      final normName = SadatCityGeoData.normalizeArabic(loc.placeName);
      final key = '${normName}_${loc.latitude.toStringAsFixed(3)}_${loc.longitude.toStringAsFixed(3)}';
      if (!seenKeys.contains(key) && !combinedResults.any((r) => r.isDuplicateOf(loc))) {
        seenKeys.add(key);
        combinedResults.add(loc);
        MapCoordinatesHelper.registerCoordinate(loc.formattedAddress, LatLng(loc.latitude, loc.longitude));
        if (loc.placeName.isNotEmpty) {
          MapCoordinatesHelper.registerCoordinate(loc.placeName, LatLng(loc.latitude, loc.longitude));
        }
      }
    }

    // 0. Coordinate pattern check (e.g. "30.123, 31.456")
    final coordMatch = RegExp(r'^([-+]?[0-9]+\.?[0-9]+)[,\s]+([-+]?[0-9]+\.?[0-9]+)$').firstMatch(trimmedQuery);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        final dist = LocationService.instance.calculateDistance(latitude, longitude, lat, lng);
        final loc = PlaceLocation(
          placeId: 'coord_${lat}_$lng',
          latitude: lat,
          longitude: lng,
          placeName: 'إحداثيات محددة ($lat, $lng)',
          formattedAddress: 'الموقع المباشر بالإحداثيات',
          timestamp: DateTime.now(),
          category: 'gps',
          distanceKm: dist,
          distanceMeters: dist * 1000,
        );
        addResult(loc);
        return combinedResults;
      }
    }

    // 1. Instant Layer: High-speed local search in Sadat City Geo-Index
    final sadatMatches = SadatCityGeoData.searchLocal(
      query: trimmedQuery,
      userLat: latitude,
      userLng: longitude,
      limit: limit,
    );
    for (final loc in sadatMatches) {
      addResult(loc);
    }

    // 2. Search local general Egyptian directory as fallback
    final localGeneralMatches = _searchLocalDirectory(trimmedQuery, latitude, longitude);
    for (final loc in localGeneralMatches) {
      addResult(loc);
    }

    // 3. Parallel fetch from External APIs (Nominatim, Photon, Supabase)
    // Only execute external network calls if local results are below threshold
    final photonFuture = _searchPhoton(trimmedQuery, latitude, longitude);
    final nominatimFuture = _searchNominatim(trimmedQuery, latitude, longitude);
    final supabaseFuture = _searchSupabase(trimmedQuery, latitude, longitude, limit: limit);

    final resultsList = await Future.wait([
      nominatimFuture.catchError((_) => <PlaceLocation>[]),
      photonFuture.catchError((_) => <PlaceLocation>[]),
      supabaseFuture.catchError((_) => <PlaceLocation>[]),
    ]);

    // Add Nominatim results (restricted to Egypt & prioritized for Sadat City)
    for (final loc in resultsList[0]) {
      addResult(loc);
    }

    // Add Photon results (verified Egypt only)
    for (final loc in resultsList[1]) {
      addResult(loc);
    }

    // Add Supabase DB & Saved Places results
    for (final loc in resultsList[2]) {
      addResult(loc);
    }

    // 4. Smart Multi-Factor Ranking & Strict Relevance Filtering
    final cleanQuery = SadatCityGeoData.normalizeArabic(trimmedQuery);
    final queryTokens = cleanQuery.split(' ').where((t) => t.length > 1).toList();

    // Filter out places with no text/fuzzy relevance or distant non-matching places
    final filteredResults = combinedResults.where((loc) {
      final score = _computeRankingScore(loc, cleanQuery, queryTokens, latitude, longitude);
      return score > 0.0;
    }).toList();

    filteredResults.sort((a, b) {
      final scoreA = _computeRankingScore(a, cleanQuery, queryTokens, latitude, longitude);
      final scoreB = _computeRankingScore(b, cleanQuery, queryTokens, latitude, longitude);

      if ((scoreB - scoreA).abs() > 3.0) {
        return scoreB.compareTo(scoreA);
      }

      final distA = a.distanceKm ?? 999999.0;
      final distB = b.distanceKm ?? 999999.0;
      return distA.compareTo(distB);
    });

    final finalResults = filteredResults.take(limit).toList();
    if (finalResults.isNotEmpty) {
      _queryCache[cacheKey] = List.unmodifiable(finalResults);
    }

    return finalResults;
  }

  /// Calculates a multi-factor ranking score for place sorting
  double _computeRankingScore(
    PlaceLocation loc,
    String cleanQuery,
    List<String> queryTokens,
    double userLat,
    double userLng,
  ) {
    final nameNorm = SadatCityGeoData.normalizeArabic(loc.placeName);
    final addrNorm = SadatCityGeoData.normalizeArabic(loc.formattedAddress);
    final phoneticName = SadatCityGeoData.phoneticNormalize(loc.placeName);
    final phoneticQuery = SadatCityGeoData.phoneticNormalize(cleanQuery);

    double textScore = 0.0;
    if (loc.finalScore != null && loc.finalScore! > 0) {
      textScore = loc.finalScore!;
    } else if (nameNorm == cleanQuery || phoneticName == phoneticQuery) {
      textScore = 100.0;
    } else if (loc.aliases.any((a) => SadatCityGeoData.normalizeArabic(a) == cleanQuery)) {
      textScore = 95.0;
    } else if (nameNorm.startsWith(cleanQuery) || phoneticName.startsWith(phoneticQuery)) {
      textScore = 85.0;
    } else if (loc.aliases.any((a) => SadatCityGeoData.normalizeArabic(a).contains(cleanQuery))) {
      textScore = 80.0;
    } else if (nameNorm.contains(cleanQuery) || phoneticName.contains(phoneticQuery)) {
      textScore = 70.0;
    } else if (loc.mallName != null && SadatCityGeoData.normalizeArabic(loc.mallName!).contains(cleanQuery)) {
      textScore = 75.0;
    } else if (queryTokens.isNotEmpty && queryTokens.every((t) => nameNorm.contains(t) || addrNorm.contains(t) || phoneticName.contains(t))) {
      textScore = 65.0;
    } else if (queryTokens.isNotEmpty && queryTokens.any((t) => nameNorm.contains(t) || phoneticName.contains(t))) {
      textScore = 45.0;
    } else if (addrNorm.contains(cleanQuery)) {
      textScore = 35.0;
    } else {
      // Check category intent dictionary
      for (final entry in SadatCityGeoData.categoryIntentKeywords.entries) {
        for (final kw in entry.value) {
          final normKw = SadatCityGeoData.normalizeArabic(kw);
          if (cleanQuery == normKw || cleanQuery.startsWith(normKw) || normKw.startsWith(cleanQuery)) {
            if (loc.category == entry.key || loc.subCategory == entry.key) {
              textScore = 80.0;
              break;
            }
          }
        }
        if (textScore > 0) break;
      }

      if (textScore == 0.0) {
        // Fuzzy token similarity check for misspelled queries
        final targetTokens = [
          ...nameNorm.split(' '),
          ...phoneticName.split(' '),
          ...addrNorm.split(' '),
          ...loc.aliases.expand((a) => SadatCityGeoData.normalizeArabic(a).split(' ')),
        ].where((t) => t.length > 1).toList();

        final fScore = SadatCityGeoData.computeTokenScore(
          queryTokens: queryTokens,
          targetTokens: targetTokens,
        );
        if (fScore >= 35.0) {
          textScore = fScore;
        }
      }
    }

    // STRICT REJECTION: If there is NO text/fuzzy relevance to the query, reject completely!
    if (textScore <= 0.0) {
      return -1.0;
    }

    // Proximity score: places closer to user's current GPS position get a progressive bonus
    final distKm = loc.distanceKm ?? LocationService.instance.calculateDistance(userLat, userLng, loc.latitude, loc.longitude);

    // Geographic Fence: When user is in/near Sadat City, discard external places (> 45km away)
    // unless query explicitly targets that city/governorate.
    final isUserInSadat = SadatCityGeoData.isInSadatCity(userLat, userLng) ||
                          LocationService.instance.calculateDistance(userLat, userLng, SadatCityGeoData.cityCenter.latitude, SadatCityGeoData.cityCenter.longitude) < 35.0;
    if (isUserInSadat && distKm > 45.0) {
      final isExplicitExternal = cleanQuery.contains('قاهرة') ||
                                 cleanQuery.contains('جيزة') ||
                                 cleanQuery.contains('اسكندرية') ||
                                 cleanQuery.contains('طنطا') ||
                                 cleanQuery.contains('اكتوبر') ||
                                 cleanQuery.contains('زايد');
      if (!isExplicitExternal) {
        return -1.0;
      }
    }

    final double proxScore = (distKm <= 35.0) ? (25.0 * (1.0 - (distKm / 35.0))) : 0.0;

    // Sadat City Metropolitan Priority Bonus (+30 points)
    final bool inSadat = SadatCityGeoData.isInSadatCity(loc.latitude, loc.longitude);
    final double cityBonus = inSadat ? 30.0 : -10.0;

    // User saved/history boost
    final double historyBonus = (loc.isSaved ? 10.0 : 0.0) + (loc.isHistory ? 5.0 : 0.0);

    return textScore + proxScore + cityBonus + historyBonus;
  }

  /// High-speed Photon (Komoot) Search Engine with location bias and Egypt-only filter
  Future<List<PlaceLocation>> _searchPhoton(String query, double userLat, double userLng) async {
    final List<PlaceLocation> list = [];
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=$userLat&lon=$userLng&limit=12',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List?;
        if (features != null) {
          for (final f in features) {
            final geom = f['geometry'] as Map<String, dynamic>?;
            final props = f['properties'] as Map<String, dynamic>?;
            if (geom != null && props != null) {
              // Strictly ensure result is from Egypt
              final countryCode = props['countrycode']?.toString().toUpperCase() ?? '';
              final countryName = props['country']?.toString() ?? '';
              final isEgypt = countryCode == 'EG' || countryName.contains('مصر') || countryName.toLowerCase() == 'egypt';
              if (!isEgypt && countryCode.isNotEmpty) {
                continue;
              }

              final coords = geom['coordinates'] as List?;
              if (coords != null && coords.length >= 2) {
                final lon = (coords[0] as num).toDouble();
                final lat = (coords[1] as num).toDouble();

                final name = props['name'] as String? ?? '';
                final street = props['street'] as String?;
                final district = props['district'] as String? ?? props['locality'] as String?;
                final city = props['city'] as String?;
                final state = props['state'] as String?;
                final osmValue = props['osm_value'] as String?;

                final title = name.isNotEmpty ? name : (street ?? city ?? query);
                final addressParts = <String>[];
                if (name.isNotEmpty) addressParts.add(name);
                if (street != null && street.isNotEmpty && street != name) addressParts.add(street);
                if (district != null && district.isNotEmpty && district != name) addressParts.add(district);
                if (city != null && city.isNotEmpty && city != district) addressParts.add(city);
                if (state != null && state.isNotEmpty && state != city) addressParts.add(state);

                final fullAddress = addressParts.isNotEmpty ? addressParts.join('، ') : title;
                final distKm = LocationService.instance.calculateDistance(userLat, userLng, lat, lon);

                list.add(PlaceLocation(
                  placeId: 'photon_${props['osm_id'] ?? '${lat}_$lon'}',
                  latitude: lat,
                  longitude: lon,
                  placeName: title,
                  formattedAddress: fullAddress,
                  timestamp: DateTime.now(),
                  category: _mapOsmValueToCategory(osmValue),
                  distanceKm: distKm,
                  distanceMeters: distKm * 1000,
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PlacesSearchService] Photon search error: $e');
    }
    return list;
  }

  /// OpenStreetMap Nominatim Search Engine restricted to Egypt and bounded for Sadat City
  Future<List<PlaceLocation>> _searchNominatim(String query, double userLat, double userLng) async {
    final List<PlaceLocation> list = [];
    try {
      // Bounding box prioritizing Sadat City metropolitan area: [minLon, maxLat, maxLon, minLat]
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=jsonv2&addressdetails=1&accept-language=ar,en&countrycodes=eg&viewbox=30.3200,30.5500,30.7200,30.2200&bounded=0&limit=10',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        for (final item in data) {
          final displayName = item['display_name'] as String? ?? '';
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final placeId = item['place_id']?.toString();
          final type = item['type']?.toString();

          final addressObj = item['address'] as Map<String, dynamic>?;
          final countryCode = addressObj?['country_code']?.toString().toLowerCase() ?? '';
          if (countryCode.isNotEmpty && countryCode != 'eg') {
            continue;
          }

          if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
            final parts = displayName.split(',');
            final title = parts.first.trim();
            final distKm = LocationService.instance.calculateDistance(userLat, userLng, lat, lon);

            final loc = PlaceLocation(
              placeId: placeId != null ? 'osm_$placeId' : null,
              latitude: lat,
              longitude: lon,
              placeName: title,
              formattedAddress: displayName,
              timestamp: DateTime.now(),
              category: _mapOsmValueToCategory(type),
              distanceKm: distKm,
              distanceMeters: distKm * 1000,
            );
            list.add(loc);
          }
        }
      }
    } catch (e) {
      debugPrint('[PlacesSearchService] Nominatim search error: $e');
    }
    return list;
  }

  /// Search Supabase for verified Sadat City places and general places
  Future<List<PlaceLocation>> _searchSupabase(String query, double userLat, double userLng, {int limit = 10}) async {
    final List<PlaceLocation> list = [];
    try {
      // 1. Try dedicated Sadat City RPC first
      try {
        final sadatRpcResp = await _supabase.rpc(
          'search_sadat_places',
          params: {
            'p_query': query,
            'p_lat': userLat,
            'p_lng': userLng,
            'p_limit': limit,
          },
        ).timeout(const Duration(seconds: 3));

        if (sadatRpcResp is List && sadatRpcResp.isNotEmpty) {
          for (final item in sadatRpcResp) {
            if (item is Map) {
              final loc = PlaceLocation.fromJson(Map<String, dynamic>.from(item));
              if (loc.isValid) {
                list.add(loc);
              }
            }
          }
          if (list.isNotEmpty) return list;
        }
      } catch (_) {
        // If RPC not created yet, query sadat_places table directly
        try {
          String orFilter = 'name_ar.ilike.%$query%,normalized_name.ilike.%$query%,address.ilike.%$query%';

          // Check if query matches a known category
          final normQ = SadatCityGeoData.normalizeArabic(query);
          for (final entry in SadatCityGeoData.categoryIntentKeywords.entries) {
            for (final kw in entry.value) {
              final normKw = SadatCityGeoData.normalizeArabic(kw);
              if (normQ == normKw || normQ.startsWith(normKw)) {
                orFilter += ',category.eq.${entry.key}';
                break;
              }
            }
          }
          orFilter += ',mall_name.ilike.%$query%,district.ilike.%$query%';

          final tableResp = await _supabase
              .from('sadat_places')
              .select()
              .eq('is_active', true)
              .or(orFilter)
              .limit(limit)
              .timeout(const Duration(seconds: 3));

          if (tableResp.isNotEmpty) {
            for (final item in tableResp) {
              final loc = PlaceLocation.fromJson(Map<String, dynamic>.from(item));
              if (loc.isValid) {
                list.add(loc);
              }
            }
            if (list.isNotEmpty) return list;
          }
        } catch (_) {}
      }

      // 2. Fallback to general Supabase PostGIS search_places RPC
      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase.rpc(
        'search_places',
        params: {
          'p_query': query,
          'p_lat': userLat,
          'p_lng': userLng,
          'p_radius_km': 50.0,
          'p_limit': limit,
          'p_user_id': currentUserId,
        },
      ).timeout(const Duration(seconds: 3));

      if (response is List) {
        for (final item in response) {
          if (item is Map) {
            final loc = PlaceLocation.fromJson(Map<String, dynamic>.from(item));
            if (loc.isValid) {
              list.add(loc);
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  /// Local comprehensive Egyptian geographic database for zero-latency instant matching
  List<PlaceLocation> _searchLocalDirectory(String query, double userLat, double userLng) {
    final List<PlaceLocation> matches = [];
    final normQuery = _normalizeArabic(query);
    if (normQuery.length < 2) return matches;

    for (final entry in _egyptianHubs) {
      final nameNorm = _normalizeArabic(entry['name'] as String);
      final addressNorm = _normalizeArabic(entry['address'] as String);
      final aliases = (entry['aliases'] as List<String>? ?? []).map(_normalizeArabic);

      if (nameNorm.contains(normQuery) || addressNorm.contains(normQuery) || aliases.any((a) => a.contains(normQuery))) {
        final lat = entry['lat'] as double;
        final lng = entry['lng'] as double;
        final dist = LocationService.instance.calculateDistance(userLat, userLng, lat, lng);

        matches.add(PlaceLocation(
          placeId: 'local_${entry['id']}',
          latitude: lat,
          longitude: lng,
          placeName: entry['name'] as String,
          formattedAddress: entry['address'] as String,
          category: entry['category'] as String? ?? 'landmark',
          timestamp: DateTime.now(),
          distanceKm: dist,
          distanceMeters: dist * 1000,
        ));
      }
    }
    return matches;
  }

  /// Retrieves nearby & popular reference landmarks when query is empty
  Future<List<PlaceLocation>> getNearbyAndPopularPlaces({
    required double latitude,
    required double longitude,
    int limit = 15,
  }) async {
    final List<PlaceLocation> results = [];
    final Set<String> seen = {};

    // 1. Prioritize Sadat City places sorted by proximity to user
    final sadatTop = SadatCityGeoData.getTopNearbyPlaces(
      userLat: latitude,
      userLng: longitude,
      limit: limit,
    );
    for (final loc in sadatTop) {
      if (seen.add(loc.placeName)) {
        results.add(loc);
      }
    }

    // 2. Add local directory reference hubs if needed
    if (results.length < limit) {
      final localCopy = List<Map<String, dynamic>>.from(_egyptianHubs);
      localCopy.sort((a, b) {
        final distA = LocationService.instance.calculateDistance(latitude, longitude, a['lat'] as double, a['lng'] as double);
        final distB = LocationService.instance.calculateDistance(latitude, longitude, b['lat'] as double, b['lng'] as double);
        return distA.compareTo(distB);
      });

      for (final entry in localCopy) {
        final name = entry['name'] as String;
        if (!seen.contains(name)) {
          final lat = entry['lat'] as double;
          final lng = entry['lng'] as double;
          final dist = LocationService.instance.calculateDistance(latitude, longitude, lat, lng);
          final loc = PlaceLocation(
            placeId: 'hub_${entry['id']}',
            latitude: lat,
            longitude: lng,
            placeName: name,
            formattedAddress: entry['address'] as String,
            category: entry['category'] as String? ?? 'landmark',
            timestamp: DateTime.now(),
            distanceKm: dist,
            distanceMeters: dist * 1000,
          );
          seen.add(name);
          results.add(loc);
          if (results.length >= limit) break;
        }
      }
    }

    return results;
  }

  /// Records place selection to boost ranking, update local history, and auto-learn in Supabase
  Future<void> recordPlaceSelection(PlaceLocation place, {String query = ''}) async {
    if (!place.isValid) return;

    // 1. Local history cache
    await SearchHistoryService.instance.saveLocation(place);

    // 2. Asynchronously notify Supabase RPC & upsert in public.places for auto-learning
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
        _queryCache.clear();
      }).catchError((_) {});
    } catch (_) {}
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
    } catch (_) {}
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
      case 'college':
      case 'جامعة':
      case 'كلية':
      case 'مدرسة':
        return Icons.school_outlined;
      case 'hospital':
      case 'clinic':
      case 'pharmacy':
      case 'مستشفى':
      case 'عيادة':
      case 'صيدلية':
        return Icons.local_hospital_outlined;
      case 'mall':
      case 'store':
      case 'supermarket':
      case 'shop':
      case 'مول':
      case 'متجر':
      case 'سوق':
      case 'هايبر':
        return Icons.shopping_bag_outlined;
      case 'airport':
      case 'مطار':
        return Icons.flight_takeoff_outlined;
      case 'station':
      case 'metro':
      case 'train':
      case 'bus':
      case 'محطة':
      case 'مترو':
      case 'قطار':
      case 'موقف':
        return Icons.directions_transit_outlined;
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
      case 'مطعم':
      case 'كافيه':
      case 'مقهى':
        return Icons.restaurant_outlined;
      case 'city':
      case 'town':
      case 'village':
      case 'residential':
      case 'مدينة':
      case 'قرية':
      case 'حي':
      case 'مجاورة':
        return Icons.location_city_outlined;
      case 'gps':
        return Icons.my_location_rounded;
      default:
        return Icons.place_outlined;
    }
  }

  String _mapOsmValueToCategory(String? osmValue) {
    if (osmValue == null) return 'landmark';
    switch (osmValue.toLowerCase()) {
      case 'university':
      case 'college':
      case 'school':
        return 'university';
      case 'hospital':
      case 'clinic':
      case 'pharmacy':
        return 'hospital';
      case 'mall':
      case 'department_store':
      case 'supermarket':
      case 'shop':
        return 'mall';
      case 'aerodrome':
      case 'airport':
        return 'airport';
      case 'station':
      case 'bus_station':
      case 'subway_entrance':
        return 'station';
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return 'restaurant';
      case 'city':
      case 'town':
      case 'village':
      case 'suburb':
      case 'neighbourhood':
      case 'residential':
        return 'residential';
      default:
        return 'landmark';
    }
  }

  String _normalizeArabic(String text) => SadatCityGeoData.normalizeArabic(text);

  // Comprehensive Egyptian Directory of major hubs, cities, landmarks, and zones
  static final List<Map<String, dynamic>> _egyptianHubs = [
    // Sadat City & Menoufia Hubs
    {'id': 'sadat_1', 'name': 'جامعة مدينة السادات', 'address': 'المنطقة الإدارية، مدينة السادات، المنوفية', 'lat': 30.3789, 'lng': 30.5182, 'category': 'university', 'aliases': ['جامعة السادات', 'sadat university']},
    {'id': 'sadat_2', 'name': 'المنطقة المركزية الأولى', 'address': 'المحور المركزي، مدينة السادات، المنوفية', 'lat': 30.3745, 'lng': 30.5050, 'category': 'residential', 'aliases': ['المنطقة الاولى', 'وسط البلد السادات']},
    {'id': 'sadat_3', 'name': 'المنطقة الصناعية - السادات', 'address': 'طريق مصر الإسكندرية الصحراوي، السادات', 'lat': 30.3450, 'lng': 30.5500, 'category': 'landmark', 'aliases': ['صناعية السادات', 'المصانع']},
    {'id': 'sadat_4', 'name': 'مستشفى السادات المركزي', 'address': 'الشارع العام، مدينة السادات، المنوفية', 'lat': 30.3700, 'lng': 30.5120, 'category': 'hospital', 'aliases': ['مستشفى السادات']},
    {'id': 'sadat_5', 'name': 'المجاورة الرابعة - السادات', 'address': 'الحي الثاني، مدينة السادات، المنوفية', 'lat': 30.3800, 'lng': 30.4950, 'category': 'residential', 'aliases': ['المجاورة 4', 'الحي الثاني']},
    {'id': 'sadat_6', 'name': 'المجاورة الحادية عشر - السادات', 'address': 'مدينة السادات، المنوفية', 'lat': 30.3860, 'lng': 30.5250, 'category': 'residential', 'aliases': ['المجاورة 11']},
    {'id': 'sadat_7', 'name': 'قرية كفر داود', 'address': 'مركز السادات، محافظة المنوفية', 'lat': 30.4630, 'lng': 30.6010, 'category': 'residential', 'aliases': ['كفر داود']},
    {'id': 'sadat_8', 'name': 'قرية الخطاطبة', 'address': 'مركز السادات، المنوفية', 'lat': 30.3010, 'lng': 30.6850, 'category': 'residential', 'aliases': ['الخطاطبة']},
    {'id': 'sadat_9', 'name': 'شبين الكوم', 'address': 'عاصمة محافظة المنوفية', 'lat': 30.5596, 'lng': 31.0094, 'category': 'residential', 'aliases': ['شبين', 'shebin el kom']},
    {'id': 'sadat_10', 'name': 'جامعة المنوفية', 'address': 'شارع جمال عبد الناصر، شبين الكوم، المنوفية', 'lat': 30.5620, 'lng': 31.0110, 'category': 'university', 'aliases': ['menoufia university']},

    // 6th of October & Sheikh Zayed Hubs
    {'id': 'oct_1', 'name': 'ميدان الحصري', 'address': 'الحي السابع، مدينة 6 أكتوبر، الجيزة', 'lat': 29.9754, 'lng': 30.9472, 'category': 'landmark', 'aliases': ['جامع الحصري', 'hosary square']},
    {'id': 'oct_2', 'name': 'مول مصر (Mall of Egypt)', 'address': 'طريق الواحات، 6 أكتوبر، الجيزة', 'lat': 29.9722, 'lng': 31.0152, 'category': 'mall', 'aliases': ['مول مصر', 'mall of egypt']},
    {'id': 'oct_3', 'name': 'مول العرب (Mall of Arabia)', 'address': 'ميدان جهينة، محور 26 يوليو، 6 أكتوبر', 'lat': 30.0075, 'lng': 30.9735, 'category': 'mall', 'aliases': ['مول العرب', 'mall of arabia']},
    {'id': 'oct_4', 'name': 'ميدان جهينة', 'address': 'محور 26 يوليو، 6 أكتوبر، الجيزة', 'lat': 30.0110, 'lng': 30.9680, 'category': 'landmark', 'aliases': ['جهينة']},
    {'id': 'oct_5', 'name': 'هايبر وان - الشيخ زايد', 'address': 'مدخل الشيخ زايد 1، طريق مصر الإسكندرية الصحراوي', 'lat': 30.0380, 'lng': 31.0180, 'category': 'mall', 'aliases': ['هايبر وان', 'hyper one']},
    {'id': 'oct_6', 'name': 'أركان بلازا (Arkan Plaza)', 'address': 'شارع البستان، الشيخ زايد، الجيزة', 'lat': 30.0210, 'lng': 30.9990, 'category': 'mall', 'aliases': ['اركان', 'arkan']},
    {'id': 'oct_7', 'name': 'جامعة 6 أكتوبر', 'address': 'المحور المركزي، 6 أكتوبر، الجيزة', 'lat': 29.9780, 'lng': 30.9430, 'category': 'university', 'aliases': ['o6u']},
    {'id': 'oct_8', 'name': 'جامعة MSA (أكتوبر للعلوم الحديثة)', 'address': 'طريق الواحات، 6 أكتوبر، الجيزة', 'lat': 29.9570, 'lng': 30.9850, 'category': 'university', 'aliases': ['msa university']},

    // Greater Cairo & Giza Hubs
    {'id': 'cai_1', 'name': 'ميدان التحرير', 'address': 'وسط البلد، محافظة القاهرة', 'lat': 30.0444, 'lng': 31.2357, 'category': 'landmark', 'aliases': ['التحرير', 'tahrir square']},
    {'id': 'cai_2', 'name': 'مطار القاهرة الدولي', 'address': 'طريق المطار، النزهة، القاهرة', 'lat': 30.1219, 'lng': 31.4056, 'category': 'airport', 'aliases': ['مطار القاهرة', 'cairo airport']},
    {'id': 'cai_3', 'name': 'جامعة القاهرة', 'address': 'شارع ثروت، بين السرايات، الجيزة', 'lat': 30.0276, 'lng': 31.2101, 'category': 'university', 'aliases': ['cairo university']},
    {'id': 'cai_4', 'name': 'شارع جامعة الدول العربية', 'address': 'المهندسين، الجيزة', 'lat': 30.0526, 'lng': 31.2014, 'category': 'landmark', 'aliases': ['جامعة الدول', 'المهندسين']},
    {'id': 'cai_5', 'name': 'شارع شهاب - المهندسين', 'address': 'المهندسين، الجيزة', 'lat': 30.0550, 'lng': 31.1954, 'category': 'landmark', 'aliases': ['شارع شهاب']},
    {'id': 'cai_6', 'name': 'شارع مصدق - الدقي', 'address': 'حي الدقي، الجيزة', 'lat': 30.0410, 'lng': 31.2040, 'category': 'landmark', 'aliases': ['شارع مصدق', 'الدقي']},
    {'id': 'cai_7', 'name': 'شارع عباس العقاد', 'address': 'مدينة نصر، القاهرة', 'lat': 30.0580, 'lng': 31.3420, 'category': 'landmark', 'aliases': ['عباس العقاد', 'مدينة نصر']},
    {'id': 'cai_8', 'name': 'سيتي ستارز مول (Citystars)', 'address': 'شارع عمر بن الخطاب، مدينة نصر، القاهرة', 'lat': 30.0730, 'lng': 31.3460, 'category': 'mall', 'aliases': ['سيتي ستارز', 'city stars']},
    {'id': 'cai_9', 'name': 'كايرو فيستيفال سيتي مول (CFC)', 'address': 'الطريق الدائري، التجمع الخامس، القاهرة الجديدة', 'lat': 30.0310, 'lng': 31.4070, 'category': 'mall', 'aliases': ['كايرو فيستيفال', 'cfc mall']},
    {'id': 'cai_10', 'name': 'شارع التسعين الجنوبي', 'address': 'التجمع الخامس، القاهرة الجديدة', 'lat': 30.0240, 'lng': 31.4650, 'category': 'landmark', 'aliases': ['شارع التسعين', 'التسعين الجنوبي']},
    {'id': 'cai_11', 'name': 'الجامعة الأمريكية بالقاهرة (AUC)', 'address': 'شارع الجامعة الأمريكية، القاهرة الجديدة', 'lat': 30.0263, 'lng': 31.4913, 'category': 'university', 'aliases': ['auc']},
    {'id': 'cai_12', 'name': 'محطة مصر - رمسيس', 'address': 'ميدان رمسيس، القاهرة', 'lat': 30.0626, 'lng': 31.2497, 'category': 'station', 'aliases': ['محطة رمسيس', 'قطار رمسيس']},
    {'id': 'cai_13', 'name': 'المعادي - شارع 9', 'address': 'المعادي، القاهرة', 'lat': 29.9600, 'lng': 31.2780, 'category': 'landmark', 'aliases': ['شارع 9 المعادي', 'maadi street 9']},
    {'id': 'cai_14', 'name': 'الزمالك - شارع 26 يوليو', 'address': 'حي الزمالك، القاهرة', 'lat': 30.0600, 'lng': 31.2210, 'category': 'landmark', 'aliases': ['الزمالك', 'zamalek']},
    {'id': 'cai_15', 'name': 'الأهرامات وأبو الهول', 'address': 'شارع الأهرام، نزلة السمان، الهرم، الجيزة', 'lat': 29.9792, 'lng': 31.1342, 'category': 'landmark', 'aliases': ['الهرم', 'pyramids of giza']},

    // Alexandria Hubs
    {'id': 'alex_1', 'name': 'محطة الرمل', 'address': 'وسط مدينة الإسكندرية', 'lat': 31.2001, 'lng': 29.8999, 'category': 'landmark', 'aliases': ['الرمل', 'raml station']},
    {'id': 'alex_2', 'name': 'مكتبة الإسكندرية', 'address': 'طريق الجيش، الشاطبي، الإسكندرية', 'lat': 31.2089, 'lng': 29.9092, 'category': 'university', 'aliases': ['مكتبة اسكندرية']},
    {'id': 'alex_3', 'name': 'ميدان سيدي جابر', 'address': 'سيدي جابر، الإسكندرية', 'lat': 31.2180, 'lng': 29.9430, 'category': 'station', 'aliases': ['محطة سيدي جابر']},
    {'id': 'alex_4', 'name': 'سان ستيفانو مول', 'address': 'طريق الجيش، سان ستيفانو، الإسكندرية', 'lat': 31.2430, 'lng': 29.9680, 'category': 'mall', 'aliases': ['سان ستيفانو', 'san stefano']},

    // Delta & Egyptian Governorates
    {'id': 'delta_1', 'name': 'طنطا - ميدان المحطة', 'address': 'عاصمة محافظة الغربية', 'lat': 30.7865, 'lng': 31.0004, 'category': 'landmark', 'aliases': ['طنطا', 'tanta']},
    {'id': 'delta_2', 'name': 'المنصورة - ميدان المحافظة', 'address': 'عاصمة محافظة الدقهلية', 'lat': 31.0409, 'lng': 31.3785, 'category': 'landmark', 'aliases': ['المنصورة', 'mansoura']},
    {'id': 'delta_3', 'name': 'الزقازيق', 'address': 'عاصمة محافظة الشرقية', 'lat': 30.5877, 'lng': 31.5020, 'category': 'landmark', 'aliases': ['الزقازيق', 'zagazig']},
    {'id': 'delta_4', 'name': 'دمنهور', 'address': 'عاصمة محافظة البحيرة', 'lat': 31.0364, 'lng': 30.4687, 'category': 'landmark', 'aliases': ['دمنهور', 'damanhur']},
    {'id': 'delta_5', 'name': 'بنها', 'address': 'عاصمة محافظة القليوبية', 'lat': 30.4660, 'lng': 31.1850, 'category': 'landmark', 'aliases': ['بنها', 'banha']},
    {'id': 'delta_6', 'name': 'الإسماعيلية', 'address': 'محافظة الإسماعيلية', 'lat': 30.5965, 'lng': 32.2715, 'category': 'landmark', 'aliases': ['الاسماعيلية', 'ismailia']},
    {'id': 'delta_7', 'name': 'السويس', 'address': 'محافظة السويس', 'lat': 29.9668, 'lng': 32.5498, 'category': 'landmark', 'aliases': ['السويس', 'suez']},
    {'id': 'delta_8', 'name': 'بورسعيد', 'address': 'محافظة بورسعيد', 'lat': 31.2653, 'lng': 32.3019, 'category': 'landmark', 'aliases': ['بورسعيد', 'port said']},
    {'id': 'delta_9', 'name': 'الفيوم', 'address': 'محافظة الفيوم', 'lat': 29.3084, 'lng': 30.8428, 'category': 'landmark', 'aliases': ['الفيوم', 'fayoum']},
    {'id': 'delta_10', 'name': 'بني سويف', 'address': 'محافظة بني سويف', 'lat': 29.0661, 'lng': 31.0994, 'category': 'landmark', 'aliases': ['بني سويف']},
    {'id': 'delta_11', 'name': 'المنيا', 'address': 'محافظة المنيا', 'lat': 28.0871, 'lng': 30.7618, 'category': 'landmark', 'aliases': ['المنيا', 'minya']},
    {'id': 'delta_12', 'name': 'أسيوط', 'address': 'محافظة أسيوط', 'lat': 27.1783, 'lng': 31.1859, 'category': 'landmark', 'aliases': ['اسيوط', 'asyut']},
    {'id': 'delta_13', 'name': 'سوهاج', 'address': 'محافظة سوهاج', 'lat': 26.5569, 'lng': 31.6948, 'category': 'landmark', 'aliases': ['سوهاج', 'sohag']},
    {'id': 'delta_14', 'name': 'قنا', 'address': 'محافظة قنا', 'lat': 26.1551, 'lng': 32.7160, 'category': 'landmark', 'aliases': ['قنا', 'qena']},
    {'id': 'delta_15', 'name': 'الأقصر', 'address': 'محافظة الأقصر', 'lat': 25.6872, 'lng': 32.6396, 'category': 'landmark', 'aliases': ['الاقصر', 'luxor']},
    {'id': 'delta_16', 'name': 'أسوان', 'address': 'محافظة أسوان', 'lat': 24.0889, 'lng': 32.8998, 'category': 'landmark', 'aliases': ['اسوان', 'aswan']},
    {'id': 'delta_17', 'name': 'الغردقة', 'address': 'محافظة البحر الأحمر', 'lat': 27.2579, 'lng': 33.8116, 'category': 'landmark', 'aliases': ['الغردقة', 'hurghada']},
    {'id': 'delta_18', 'name': 'شرم الشيخ', 'address': 'محافظة جنوب سيناء', 'lat': 27.9158, 'lng': 34.3299, 'category': 'landmark', 'aliases': ['شرم الشيخ', 'sharm el sheikh']},
    {'id': 'delta_19', 'name': 'مرسى مطروح', 'address': 'محافظة مطروح', 'lat': 31.3543, 'lng': 27.2373, 'category': 'landmark', 'aliases': ['مطروح', 'marsa matrouh']},
  ];
}
