import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../data/sadat_city_geo_data.dart';

class MapCoordinatesHelper {
  /// Caches the actual GPS device location
  static LatLng? deviceLocation;

  /// Dynamic cache for searched places and resolved coordinates
  static final Map<String, LatLng> _dynamicCoordinatesCache = {};

  /// Registers a dynamic location and its coordinates
  static void registerCoordinate(String address, LatLng coordinate) {
    if (address.trim().isEmpty) return;
    _dynamicCoordinatesCache[address.toLowerCase().trim()] = coordinate;
  }

  /// Resolves the address text into real coordinates
  static LatLng getLatLngForAddress(String? address) {
    final hasValidSadatDeviceLoc = deviceLocation != null &&
        SadatCityGeoData.isInSadatCity(deviceLocation!.latitude, deviceLocation!.longitude);

    if (address == null || address.trim().isEmpty) {
      return hasValidSadatDeviceLoc ? deviceLocation! : SadatCityGeoData.cityCenter;
    }

    final addr = address.toLowerCase().trim();

    // 1. Try to parse coordinates if they exist in the string (e.g. "30.0130, 31.2080" or "(30.0130, 31.2080)")
    final regExp = RegExp(r'([-+]?[0-9]+\.?[0-9]+)[,\s]+([-+]?[0-9]+\.?[0-9]+)');
    final match = regExp.firstMatch(address);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        return LatLng(lat, lng);
      }
    }

    // 2. Check dynamic coordinates cache first
    if (_dynamicCoordinatesCache.containsKey(addr)) {
      return _dynamicCoordinatesCache[addr]!;
    }

    // 3. Resolve "my location" / "الموقع الحالي" / "موقعي الحالي" to actual cached GPS coordinates in Sadat City
    if (addr.contains('موقع') || 
        addr.contains('location') || 
        addr.contains('موقعي الحالي') || 
        addr.contains('الموقع الحالي') ||
        addr.contains('موقعي')) {
      if (hasValidSadatDeviceLoc) {
        return deviceLocation!;
      }
      return SadatCityGeoData.cityCenter;
    }

    // 4. Check local Sadat City index
    final sadatMatches = SadatCityGeoData.searchLocal(
      query: address,
      userLat: hasValidSadatDeviceLoc ? deviceLocation!.latitude : SadatCityGeoData.cityCenter.latitude,
      userLng: hasValidSadatDeviceLoc ? deviceLocation!.longitude : SadatCityGeoData.cityCenter.longitude,
      limit: 1,
    );
    if (sadatMatches.isNotEmpty && (sadatMatches.first.finalScore ?? 0) >= 65.0) {
      final coord = LatLng(sadatMatches.first.latitude, sadatMatches.first.longitude);
      registerCoordinate(address, coord);
      return coord;
    }

    return hasValidSadatDeviceLoc ? deviceLocation! : SadatCityGeoData.cityCenter;
  }

  /// Interpolates coordinates between a start and end LatLng based on a progress [0.0 - 1.0]
  static LatLng interpolate(LatLng start, LatLng end, double progress) {
    if (progress <= 0.0) return start;
    if (progress >= 1.0) return end;
    
    double lat = start.latitude + (end.latitude - start.latitude) * progress;
    double lng = start.longitude + (end.longitude - start.longitude) * progress;
    
    return LatLng(lat, lng);
  }

  /// Strictly checks if a coordinate pair falls within the borders of Egypt
  static bool isValidEgyptCoordinate(double lat, double lng) {
    return lat >= 22.0 && lat <= 32.5 && lng >= 24.0 && lng <= 37.5;
  }

  /// Resolves latitude and longitude coordinates into a human-readable address/place name
  static Future<String> reverseGeocode(double lat, double lng) async {
    // 0. If in Sadat City, check local Sadat City index
    if (SadatCityGeoData.isInSadatCity(lat, lng)) {
      final sadatMatches = SadatCityGeoData.searchLocal(
        query: '',
        userLat: lat,
        userLng: lng,
        limit: 1,
      );
      if (sadatMatches.isNotEmpty && (sadatMatches.first.distanceKm ?? 999.0) < 0.35) {
        final match = sadatMatches.first;
        final name = match.placeName;
        final addr = match.formattedAddress;
        return addr.isNotEmpty ? addr : name;
      }
    }

    // 1. Try Photon (Komoot) high-speed reverse geocoding with Arabic priority
    try {
      final photonUrl = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lng');
      final response = await http.get(photonUrl, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features[0]['properties'] as Map<String, dynamic>?;
          if (props != null) {
            final name = props['name'] as String?;
            final street = props['street'] as String?;
            final district = props['district'] as String? ?? props['locality'] as String?;
            final city = props['city'] as String?;
            final state = props['state'] as String?;

            final parts = <String>[];
            if (name != null && name.isNotEmpty) parts.add(name);
            if (street != null && street.isNotEmpty && street != name) parts.add(street);
            if (district != null && district.isNotEmpty) parts.add(district);
            if (city != null && city.isNotEmpty && city != district) parts.add(city);
            if (state != null && state.isNotEmpty && state != city) parts.add(state);

            if (parts.isNotEmpty) {
              final result = parts.take(3).join('، ');
              registerCoordinate(result, LatLng(lat, lng));
              return result;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Try OpenStreetMap Nominatim
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar,en');
      final response = await http.get(url, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final address = data['display_name'] as String?;
        if (address != null && address.isNotEmpty) {
          final parts = address.split(',');
          if (parts.length > 3) {
            final formatted = '${parts[0].trim()}، ${parts[1].trim()}، ${parts[2].trim()}';
            registerCoordinate(formatted, LatLng(lat, lng));
            return formatted;
          }
          registerCoordinate(address, LatLng(lat, lng));
          return address;
        }
      }
    } catch (_) {}

    // 3. Fallback to clean friendly location description
    if (SadatCityGeoData.isInSadatCity(lat, lng)) {
      return 'موقع في مدينة السادات';
    }
    return 'موقع على الخريطة (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  /// Performs a high-accuracy geocoding lookup for an address string
  static Future<LatLng?> geocodeAddress(String query, {double? biasLat, double? biasLng}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (_dynamicCoordinatesCache.containsKey(lower)) {
      return _dynamicCoordinatesCache[lower];
    }

    final hasValidSadatDeviceLoc = deviceLocation != null &&
        SadatCityGeoData.isInSadatCity(deviceLocation!.latitude, deviceLocation!.longitude);
    final latBias = biasLat ?? (hasValidSadatDeviceLoc ? deviceLocation!.latitude : SadatCityGeoData.cityCenter.latitude);
    final lngBias = biasLng ?? (hasValidSadatDeviceLoc ? deviceLocation!.longitude : SadatCityGeoData.cityCenter.longitude);

    // 0. Check local Sadat City index first (0ms instant lookup)
    final sadatMatches = SadatCityGeoData.searchLocal(
      query: trimmed,
      userLat: latBias,
      userLng: lngBias,
      limit: 1,
    );
    if (sadatMatches.isNotEmpty && (sadatMatches.first.finalScore ?? 0) >= 65.0) {
      final latLng = LatLng(sadatMatches.first.latitude, sadatMatches.first.longitude);
      registerCoordinate(trimmed, latLng);
      return latLng;
    }

    // 1. Try Nominatim Geocoding restricted to Egypt & bounded to Sadat City
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&accept-language=ar,en&countrycodes=eg&viewbox=30.3200,30.5500,30.7200,30.2200&bounded=0&limit=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
          final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
          if (lat != null && lon != null && isValidEgyptCoordinate(lat, lon)) {
            final latLng = LatLng(lat, lon);
            registerCoordinate(trimmed, latLng);
            return latLng;
          }
        }
      }
    } catch (_) {}

    // 2. Try Photon Geocoding with user bias and Egypt verification
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&lat=$latBias&lon=$lngBias&limit=3',
      );
      final response = await http.get(photonUrl, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          for (final feat in features) {
            final props = feat['properties'] as Map<String, dynamic>?;
            final countryCode = props?['countrycode']?.toString().toUpperCase() ?? '';
            final countryName = props?['country']?.toString() ?? '';
            final isEgypt = countryCode == 'EG' || countryName.contains('مصر') || countryName.toLowerCase() == 'egypt';
            if (!isEgypt && countryCode.isNotEmpty) continue;

            final coords = feat['geometry']?['coordinates'] as List?;
            if (coords != null && coords.length >= 2) {
              final lon = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              if (isValidEgyptCoordinate(lat, lon)) {
                final latLng = LatLng(lat, lon);
                registerCoordinate(trimmed, latLng);
                return latLng;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Cleans typical Google Maps share wrapper text
  static String cleanPlaceTitle(String line) {
    var t = line.trim();
    t = t.replaceFirst(RegExp(r'^(?:اطّلع على|اطلع على|شاهد|Check out)\s+', caseSensitive: false), '');
    t = t.replaceFirst(RegExp(r'\s+(?:على خرائط Google|على خرائط جوجل|on Google Maps).*$', caseSensitive: false), '');
    if (RegExp(r'^(?:Dropped pin|موقع تم إسقاطه|دبوس تم إسقاطه|موقع محدد|موقع جغرافي|Unnamed Road)', caseSensitive: false).hasMatch(t)) {
      return '';
    }
    return t.trim();
  }

  /// Extracts place name from Google Maps or Apple Maps URL
  static String? _extractNameFromUrl(String url) {
    try {
      final decoded = Uri.decodeFull(url);
      final placeMatch = RegExp(r'/place/([^/@?]+)', caseSensitive: false).firstMatch(decoded);
      if (placeMatch != null) {
        final raw = placeMatch.group(1)!.replaceAll('+', ' ').trim();
        if (raw.isNotEmpty && !RegExp(r'^[-+0-9.,\s()]+$').hasMatch(raw)) {
          return raw;
        }
      }
      final qMatch = RegExp(r'[?&](?:q|query)=([^&]+)', caseSensitive: false).firstMatch(decoded);
      if (qMatch != null) {
        final rawQ = Uri.decodeComponent(qMatch.group(1)!.replaceAll('+', ' ')).trim();
        if (rawQ.isNotEmpty && !RegExp(r'^[-+0-9.,\s()]+$').hasMatch(rawQ)) {
          return rawQ;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolves Google short URLs (maps.app.goo.gl or goo.gl/maps) to extract both coordinates and the Arabic place name
  static Future<_GoogleShortUrlResult> _resolveGoogleShortUrl(String rawText) async {
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(rawText);
    if (urlMatch == null) return const _GoogleShortUrlResult();
    final rawUrl = urlMatch.group(0)!;

    final client = http.Client();
    try {
      var currentUri = Uri.parse(rawUrl);
      String? lastRedirectUrl;
      LatLng? extractedCoords;
      String? extractedName;

      for (int hop = 0; hop < 5; hop++) {
        final req = http.Request('GET', currentUri)..followRedirects = false;
        req.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
        final streamed = await client.send(req).timeout(const Duration(seconds: 4));
        final locHeader = streamed.headers['location'];
        if (locHeader != null && locHeader.isNotEmpty) {
          lastRedirectUrl = locHeader;
          final nextUri = Uri.parse(
              locHeader.startsWith('http') ? locHeader : currentUri.resolve(locHeader).toString());

          final name = _extractNameFromUrl(nextUri.toString());
          if (name != null && name.isNotEmpty) {
            extractedName ??= name;
          }
          final coords = await extractCoordinatesFromText(nextUri.toString());
          if (coords != null) {
            extractedCoords = coords;
          }
          currentUri = nextUri;
        } else {
          final bodyBytes = await streamed.stream.toBytes();
          final bodyString = utf8.decode(bodyBytes, allowMalformed: true);

          final titleMatch = RegExp(r'<title>([^<]+) - Google Maps</title>', caseSensitive: false)
              .firstMatch(bodyString);
          if (titleMatch != null) {
            final title = titleMatch.group(1)!.trim();
            if (title.isNotEmpty && !title.contains('Google Maps')) {
              extractedName ??= title;
            }
          }

          final coords = await extractCoordinatesFromText(bodyString);
          if (coords != null) {
            extractedCoords ??= coords;
          }
          break;
        }
      }

      return _GoogleShortUrlResult(
        coordinates: extractedCoords,
        redirectUrl: lastRedirectUrl ?? currentUri.toString(),
        placeName: extractedName,
      );
    } catch (_) {
      return const _GoogleShortUrlResult();
    } finally {
      client.close();
    }
  }

  /// Extracts comprehensive place information (name, address, coordinates) from arbitrary text,
  /// clipboard contents, or shared links from Google Maps / Apple Maps.
  static Future<ExtractedPlaceInfo?> extractPlaceFromTextOrUrl(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    String? detectedTitle;
    String? resolvedRedirectUrl;

    // 1. Clean non-URL lines (Google Maps share text)
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final line in lines) {
      if (!line.startsWith('http://') && !line.startsWith('https://') && !line.startsWith('geo:')) {
        final cleaned = cleanPlaceTitle(line);
        if (cleaned.isNotEmpty && detectedTitle == null) {
          detectedTitle = cleaned;
          break;
        }
      }
    }

    // 2. Resolve short URL redirects (maps.app.goo.gl or goo.gl/maps)
    LatLng? coords;
    if (text.contains('maps.app.goo.gl') || text.contains('goo.gl/maps')) {
      final res = await _resolveGoogleShortUrl(text);
      coords = res.coordinates;
      resolvedRedirectUrl = res.redirectUrl;
      if (detectedTitle == null && res.placeName != null && res.placeName!.isNotEmpty) {
        detectedTitle = res.placeName;
      }
    }

    // 3. If coords not found yet from short link, extract from text directly
    coords ??= await extractCoordinatesFromText(text);
    if (coords == null && resolvedRedirectUrl != null) {
      coords = await extractCoordinatesFromText(resolvedRedirectUrl);
    }
    if (coords == null) return null;

    // 4. Try extracting name from resolvedRedirectUrl or text (/place/NAME or q=NAME)
    if (detectedTitle == null || detectedTitle.isEmpty) {
      detectedTitle = _extractNameFromUrl(resolvedRedirectUrl ?? text);
    }

    // 5. If title is still empty or looks like numbers/coordinates, reverse geocode to real Arabic address
    String formattedAddress = '';
    if (detectedTitle == null ||
        detectedTitle.isEmpty ||
        RegExp(r'^[-+0-9.,\s()]+$').hasMatch(detectedTitle) ||
        detectedTitle.toLowerCase().contains('unnamed')) {
      final geocoded = await reverseGeocode(coords.latitude, coords.longitude);
      final firstPart = geocoded.split('،').first.trim();
      detectedTitle = firstPart.isNotEmpty ? firstPart : 'موقع في مدينة السادات';
      formattedAddress = geocoded;
    } else {
      formattedAddress = detectedTitle;
    }

    return ExtractedPlaceInfo(
      coordinates: coords,
      placeName: detectedTitle,
      formattedAddress: formattedAddress,
    );
  }

  /// Extracts coordinates from arbitrary text (Google Maps link, Apple Maps link, coordinates, short URL)
  /// Guaranteed to enforce Egyptian bounds and prevent arbitrary parameter false-positives.
  static Future<LatLng?> extractCoordinatesFromText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    // Decode URL if encoded
    String decoded = text;
    try {
      decoded = Uri.decodeFull(text);
    } catch (_) {}

    // Priority 1: Short URL (maps.app.goo.gl or goo.gl/maps) -> resolve redirect first before greedy regex!
    if (decoded.contains('maps.app.goo.gl') || decoded.contains('goo.gl/maps')) {
      final res = await _resolveGoogleShortUrl(decoded);
      if (res.coordinates != null) return res.coordinates;
    }

    // Priority 2: Google Maps Protobuf !3dlat!4dlng pattern (most exact pin coordinate on Google Maps)
    final protoMatch = RegExp(r'!3d([-+]?[0-9]+\.[0-9]+)!4d([-+]?[0-9]+\.[0-9]+)').firstMatch(decoded);
    if (protoMatch != null) {
      final lat = double.tryParse(protoMatch.group(1)!);
      final lng = double.tryParse(protoMatch.group(2)!);
      if (lat != null && lng != null && isValidEgyptCoordinate(lat, lng)) {
        return LatLng(lat, lng);
      }
    }

    // Priority 3: Query param q=lat,lng or ll=lat,lng or sll=lat,lng or center=lat,lng (Google Maps & Apple Maps)
    final qMatch = RegExp(
      r'[?&](?:q|ll|sll|query|destination|daddr|saddr|center)=([-+]?[0-9]+\.[0-9]+)[,%2C\s]+([-+]?[0-9]+\.[0-9]+)',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (qMatch != null) {
      final lat = double.tryParse(qMatch.group(1)!);
      final lng = double.tryParse(qMatch.group(2)!);
      if (lat != null && lng != null && isValidEgyptCoordinate(lat, lng)) {
        return LatLng(lat, lng);
      }
    }

    // Priority 4: Google Maps @lat,lng pattern (e.g. /@30.38521,30.51234,17z/)
    final atMatch = RegExp(r'@([-+]?[0-9]+\.[0-9]+),([-+]?[0-9]+\.[0-9]+)').firstMatch(decoded);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null && isValidEgyptCoordinate(lat, lng)) {
        return LatLng(lat, lng);
      }
    }

    // Priority 5: DMS notation (Degrees-Minutes-Seconds from Google Maps pin info)
    final dmsRegex = RegExp(
      r'''(\d+)[°\s]+(\d+)['\s]+([0-9.]+)["]?\s*([NSEWnsew])[,\s]+(\d+)[°\s]+(\d+)['\s]+([0-9.]+)["]?\s*([NSEWnsew])''',
    );
    final dmsMatch = dmsRegex.firstMatch(decoded);
    if (dmsMatch != null) {
      final deg1 = double.tryParse(dmsMatch.group(1)!) ?? 0;
      final min1 = double.tryParse(dmsMatch.group(2)!) ?? 0;
      final sec1 = double.tryParse(dmsMatch.group(3)!) ?? 0;
      final dir1 = dmsMatch.group(4)!.toUpperCase();

      final deg2 = double.tryParse(dmsMatch.group(5)!) ?? 0;
      final min2 = double.tryParse(dmsMatch.group(6)!) ?? 0;
      final sec2 = double.tryParse(dmsMatch.group(7)!) ?? 0;
      final dir2 = dmsMatch.group(8)!.toUpperCase();

      double latVal = deg1 + (min1 / 60.0) + (sec1 / 3600.0);
      if (dir1 == 'S') latVal = -latVal;

      double lngVal = deg2 + (min2 / 60.0) + (sec2 / 3600.0);
      if (dir2 == 'W') lngVal = -lngVal;

      if (dir1 == 'E' || dir1 == 'W') {
        final temp = latVal;
        latVal = lngVal;
        lngVal = temp;
      }

      if (isValidEgyptCoordinate(latVal, lngVal)) {
        return LatLng(latVal, lngVal);
      }
    }

    // Priority 6: Explicit LatLng regex (e.g. "30.3852, 30.5123") - MUST satisfy Egypt boundaries
    final coordMatch = RegExp(r'([-+]?[0-9]{1,2}\.[0-9]{3,})[,\s]+([-+]?[0-9]{1,2}\.[0-9]{3,})').firstMatch(decoded);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null && isValidEgyptCoordinate(lat, lng)) {
        return LatLng(lat, lng);
      }
    }

    return null;
  }
}

/// Extracted place data structure with name, formatted address, and coordinates
class ExtractedPlaceInfo {
  final LatLng coordinates;
  final String placeName;
  final String formattedAddress;

  const ExtractedPlaceInfo({
    required this.coordinates,
    required this.placeName,
    required this.formattedAddress,
  });
}

class _GoogleShortUrlResult {
  final LatLng? coordinates;
  final String? redirectUrl;
  final String? placeName;

  const _GoogleShortUrlResult({
    this.coordinates,
    this.redirectUrl,
    this.placeName,
  });
}
