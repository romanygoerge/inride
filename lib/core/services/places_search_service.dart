import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/google_maps_config.dart';
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
      if (lat != null && lng != null) {
        final dist = LocationService.instance.calculateDistance(latitude, longitude, lat, lng);
        final loc = PlaceLocation(
          placeId: 'coord_${lat}_$lng',
          latitude: lat,
          longitude: lng,
          placeName: 'إحداثيات محددة ($lat, $lng)',
          formattedAddress: 'موقع محدد',
          timestamp: DateTime.now(),
          category: 'gps',
          distanceKm: dist,
          distanceMeters: dist * 1000,
        );
        addResult(loc);
        return combinedResults;
      }
    }

    // 1. FIRST PRIORITY: Registered local database of Sadat City (Over 6,000 places)
    final sadatMatches = SadatCityGeoData.searchLocal(
      query: trimmedQuery,
      userLat: latitude,
      userLng: longitude,
      limit: limit,
    );
    for (final loc in sadatMatches) {
      addResult(loc);
    }

    // 2. Search Supabase registered Sadat City places table
    try {
      final supabaseResults = await _searchSupabase(trimmedQuery, latitude, longitude, limit: limit);
      for (final loc in supabaseResults) {
        addResult(loc);
      }
    } catch (_) {}

    // 3. SECOND PRIORITY (Fallback): Geographic search across Egypt if local database has few matches
    // Queries Google Places, Photon, & OpenStreetMap Nominatim
    if (combinedResults.length < 5) {
      final googleFuture = _searchGooglePlaces(trimmedQuery, latitude, longitude);
      final photonFuture = _searchPhoton(trimmedQuery, latitude, longitude);
      final nominatimFuture = _searchNominatim(trimmedQuery, latitude, longitude);

      final resultsList = await Future.wait([
        googleFuture.catchError((_) => <PlaceLocation>[]),
        nominatimFuture.catchError((_) => <PlaceLocation>[]),
        photonFuture.catchError((_) => <PlaceLocation>[]),
      ]);

      for (final loc in resultsList[0]) {
        addResult(loc);
      }
      for (final loc in resultsList[1]) {
        addResult(loc);
      }
      for (final loc in resultsList[2]) {
        addResult(loc);
      }
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

    const genericTypeWords = {
      'مطعم', 'مطاعم', 'محل', 'محلات', 'كافيه', 'كافيهات', 'مقهى', 'قهوة',
      'صيدلية', 'صيدليات', 'دكتور', 'عيادة', 'عيادات', 'مستشفى', 'مستشفي',
      'سوبر', 'ماركت', 'سوبرماركت', 'هايبر', 'بقال', 'بقالة',
      'شركة', 'مكتب', 'سنتر', 'مركز', 'مدرسة', 'جامعة', 'كلية', 'معهد',
      'مسجد', 'جامع', 'شارع', 'طريق', 'ميدان', 'حي', 'منطقة', 'المنطقة',
      'فندق', 'بنك', 'بنزينة', 'محطة'
    };

    final List<String> coreTokens = queryTokens.where((t) => !genericTypeWords.contains(t)).toList();

    // If query contains specific identifying tokens (e.g. 'الشامي' in 'مطعم الشامي'),
    // this place MUST match the core token!
    if (coreTokens.isNotEmpty) {
      final hasCoreMatch = coreTokens.any((ct) {
        final ctStem = ct.length > 3 && (ct.endsWith('ي') || ct.endsWith('ه') || ct.endsWith('ة') || ct.endsWith('ا'))
            ? ct.substring(0, ct.length - 1)
            : ct;
        return nameNorm.contains(ct) ||
            nameNorm.contains(ctStem) ||
            phoneticName.contains(ct) ||
            phoneticName.contains(ctStem) ||
            loc.aliases.any((a) {
              final aNorm = SadatCityGeoData.normalizeArabic(a);
              return aNorm.contains(ct) || aNorm.contains(ctStem);
            }) ||
            addrNorm.contains(ct) ||
            addrNorm.contains(ctStem) ||
            SadatCityGeoData.computeTokenScore(queryTokens: [ct], targetTokens: nameNorm.split(' ')) >= 50.0;
      });
      if (!hasCoreMatch) {
        return -1.0; // REJECT: irrelevant place!
      }
    }

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
    } else if (coreTokens.isNotEmpty && coreTokens.every((t) => nameNorm.contains(t) || addrNorm.contains(t) || phoneticName.contains(t))) {
      textScore = 65.0;
    } else if (coreTokens.isNotEmpty && coreTokens.any((t) => nameNorm.contains(t) || phoneticName.contains(t))) {
      textScore = 50.0;
    } else if (addrNorm.contains(cleanQuery)) {
      textScore = 35.0;
    } else if (coreTokens.isEmpty) {
      // Check category intent dictionary ONLY if query has no core tokens
      for (final entry in SadatCityGeoData.categoryIntentKeywords.entries) {
        for (final kw in entry.value) {
          final normKw = SadatCityGeoData.normalizeArabic(kw);
          if (cleanQuery == normKw) {
            if (loc.category == entry.key || loc.subCategory == entry.key) {
              textScore = 80.0;
              break;
            }
          }
        }
        if (textScore > 0) break;
      }
    }

    // STRICT REJECTION: If there is NO text/fuzzy relevance to the query, reject completely!
    if (textScore <= 0.0) {
      return -1.0;
    }

    // Proximity score: places closer to user's current GPS position get a progressive bonus
    final distKm = loc.distanceKm ?? LocationService.instance.calculateDistance(userLat, userLng, loc.latitude, loc.longitude);
    final double proxScore = (distKm <= 35.0) ? (20.0 * (1.0 - (distKm / 35.0))) : 0.0;

    // Sadat City Metropolitan Priority Bonus (+40 points for local Sadat places)
    final bool inSadat = SadatCityGeoData.isInSadatCity(loc.latitude, loc.longitude);
    final double cityBonus = inSadat ? 40.0 : 0.0;

    // User saved/history boost
    final double historyBonus = (loc.isSaved ? 10.0 : 0.0) + (loc.isHistory ? 5.0 : 0.0);

    return textScore + proxScore + cityBonus + historyBonus;
  }

  /// Google Places Search across Egypt via secure Backend Proxy / Supabase Edge Function
  Future<List<PlaceLocation>> _searchGooglePlaces(String query, double userLat, double userLng) async {
    final List<PlaceLocation> list = [];
    final proxyUrl = GoogleMapsConfig.backendPlacesProxyUrl;
    final fallbackKey = GoogleMapsConfig.apiKey;

    try {
      Uri url;
      if (proxyUrl.isNotEmpty) {
        url = Uri.parse(
          '$proxyUrl'
          '?query=${Uri.encodeComponent(query)}'
          '&lat=$userLat'
          '&lng=$userLng'
          '&radius=50000',
        );
      } else if (fallbackKey.isNotEmpty) {
        url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&location=$userLat,$userLng'
          '&radius=50000'
          '&language=ar'
          '&region=eg'
          '&key=$fallbackKey',
        );
      } else {
        return list;
      }

      final headers = {
        'User-Agent': 'inRide-Flutter-App/2.0 (Android; Egypt)',
        'Accept': 'application/json',
      };
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final status = data['status'] as String?;
        if (status == 'OK') {
          final results = data['results'] as List?;
          if (results != null) {
            for (final item in results) {
              final geom = item['geometry']?['location'];
              if (geom != null) {
                final lat = (geom['lat'] as num?)?.toDouble();
                final lng = (geom['lng'] as num?)?.toDouble();
                if (lat != null && lng != null) {
                  final name = item['name'] as String? ?? query;
                  final address = item['formatted_address'] as String? ?? name;
                  final placeId = item['place_id'] as String?;
                  final distKm = LocationService.instance.calculateDistance(userLat, userLng, lat, lng);

                  list.add(PlaceLocation(
                    placeId: placeId != null ? 'google_$placeId' : null,
                    latitude: lat,
                    longitude: lng,
                    placeName: name,
                    formattedAddress: address,
                    timestamp: DateTime.now(),
                    category: 'landmark',
                    distanceKm: distKm,
                    distanceMeters: distKm * 1000,
                  ));
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  /// High-speed Photon (Komoot) Search Engine across Egypt
  Future<List<PlaceLocation>> _searchPhoton(String query, double userLat, double userLng) async {
    final List<PlaceLocation> list = [];
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=$userLat&lon=$userLng&limit=10',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) inRideApp/2.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List?;
        if (features != null) {
          for (final f in features) {
            final geom = f['geometry'] as Map<String, dynamic>?;
            final props = f['properties'] as Map<String, dynamic>?;
            if (geom != null && props != null) {
              final countryCode = (props['countrycode'] as String?)?.toLowerCase();
              if (countryCode != null && countryCode != 'eg') {
                continue; // Only places in Egypt
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

  /// OpenStreetMap Nominatim Search Engine across Egypt
  Future<List<PlaceLocation>> _searchNominatim(String query, double userLat, double userLng) async {
    final List<PlaceLocation> list = [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=jsonv2&addressdetails=1&accept-language=ar,en&countrycodes=eg&limit=10',
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

          if (lat != null && lon != null) {
            final parts = displayName.split(',');
            final title = parts.first.trim();
            final formatted = parts.length > 3
                ? '${parts[0].trim()}، ${parts[1].trim()}، ${parts[2].trim()}'
                : displayName;
            final distKm = LocationService.instance.calculateDistance(userLat, userLng, lat, lon);

            final loc = PlaceLocation(
              placeId: placeId != null ? 'osm_$placeId' : null,
              latitude: lat,
              longitude: lon,
              placeName: title,
              formattedAddress: formatted,
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
              if (loc.isValid && SadatCityGeoData.isInSadatCity(loc.latitude, loc.longitude)) {
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

          // Check if query is an EXACT category intent (e.g. user typed literally "مطعم")
          final normQ = SadatCityGeoData.normalizeArabic(query);
          for (final entry in SadatCityGeoData.categoryIntentKeywords.entries) {
            for (final kw in entry.value) {
              final normKw = SadatCityGeoData.normalizeArabic(kw);
              if (normQ == normKw) {
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
              if (loc.isValid && SadatCityGeoData.isInSadatCity(loc.latitude, loc.longitude)) {
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
          'p_radius_km': 100.0,
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


  /// Retrieves nearby & popular reference landmarks in Sadat City when query is empty
  Future<List<PlaceLocation>> getNearbyAndPopularPlaces({
    required double latitude,
    required double longitude,
    int limit = 15,
  }) async {
    final List<PlaceLocation> results = [];
    final Set<String> seen = {};

    // Prioritize Sadat City places sorted by proximity to user
    final sadatTop = SadatCityGeoData.getTopNearbyPlaces(
      userLat: latitude,
      userLng: longitude,
      limit: limit,
    );
    for (final loc in sadatTop) {
      if (SadatCityGeoData.isInSadatCity(loc.latitude, loc.longitude) && seen.add(loc.placeName)) {
        results.add(loc);
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
}

