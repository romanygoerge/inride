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
    if (address == null || address.trim().isEmpty) {
      return deviceLocation ?? SadatCityGeoData.cityCenter;
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

    // 3. Resolve "my location" / "الموقع الحالي" / "موقعي الحالي" to actual cached GPS coordinates
    if (addr.contains('موقع') || 
        addr.contains('location') || 
        addr.contains('موقعي الحالي') || 
        addr.contains('الموقع الحالي') ||
        addr.contains('موقعي')) {
      if (deviceLocation != null) {
        return deviceLocation!;
      }
    }

    // 4. Check local Sadat City index
    final sadatMatches = SadatCityGeoData.searchLocal(
      query: address,
      userLat: deviceLocation?.latitude ?? SadatCityGeoData.cityCenter.latitude,
      userLng: deviceLocation?.longitude ?? SadatCityGeoData.cityCenter.longitude,
      limit: 1,
    );
    if (sadatMatches.isNotEmpty && (sadatMatches.first.finalScore ?? 0) >= 65.0) {
      final coord = LatLng(sadatMatches.first.latitude, sadatMatches.first.longitude);
      registerCoordinate(address, coord);
      return coord;
    }

    return deviceLocation ?? SadatCityGeoData.cityCenter;
  }

  /// Interpolates coordinates between a start and end LatLng based on a progress [0.0 - 1.0]
  static LatLng interpolate(LatLng start, LatLng end, double progress) {
    if (progress <= 0.0) return start;
    if (progress >= 1.0) return end;
    
    double lat = start.latitude + (end.latitude - start.latitude) * progress;
    double lng = start.longitude + (end.longitude - start.longitude) * progress;
    
    return LatLng(lat, lng);
  }

  /// Resolves latitude and longitude coordinates into a human-readable address/place name
  static Future<String> reverseGeocode(double lat, double lng) async {
    // 1. Try Photon (Komoot) high-speed reverse geocoding
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

    // 3. Fallback to clean coordinate string
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

    final latBias = biasLat ?? deviceLocation?.latitude ?? SadatCityGeoData.cityCenter.latitude;
    final lngBias = biasLng ?? deviceLocation?.longitude ?? SadatCityGeoData.cityCenter.longitude;

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
          if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
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
              final latLng = LatLng(lat, lon);
              registerCoordinate(trimmed, latLng);
              return latLng;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Extracts coordinates from arbitrary text (Google Maps link, Apple Maps link, coordinates, short URL)
  static Future<LatLng?> extractCoordinatesFromText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    // Decode URL if encoded
    String decoded = text;
    try {
      decoded = Uri.decodeFull(text);
    } catch (_) {}

    // 1. Direct Coordinates regex (e.g. "30.3852, 30.5123" or "30.3852 30.5123")
    final coordMatch = RegExp(r'([-+]?[0-9]+\.[0-9]+)[,\s]+([-+]?[0-9]+\.[0-9]+)').firstMatch(decoded);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90.0 && lng.abs() <= 180.0 && lat != 0.0 && lng != 0.0) {
        return LatLng(lat, lng);
      }
    }

    // 2. DMS notation (Degrees-Minutes-Seconds from Google Maps pin info)
    // e.g. 30°23'06.7"N 30°30'44.3"E or 30°23'06.7" N, 30°30'44.3" E
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

      if (latVal.abs() <= 90.0 && lngVal.abs() <= 180.0 && latVal != 0.0 && lngVal != 0.0) {
        return LatLng(latVal, lngVal);
      }
    }

    // 3. Google Maps @lat,lng pattern (e.g. /@30.38521,30.51234,17z/)
    final atMatch = RegExp(r'@([-+]?[0-9]+\.[0-9]+),([-+]?[0-9]+\.[0-9]+)').firstMatch(decoded);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90.0 && lng.abs() <= 180.0) {
        return LatLng(lat, lng);
      }
    }

    // 4. Google Maps Protobuf !3dlat!4dlng pattern (e.g. !3d30.38521!4d30.51234)
    final protoMatch = RegExp(r'!3d([-+]?[0-9]+\.[0-9]+)!4d([-+]?[0-9]+\.[0-9]+)').firstMatch(decoded);
    if (protoMatch != null) {
      final lat = double.tryParse(protoMatch.group(1)!);
      final lng = double.tryParse(protoMatch.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90.0 && lng.abs() <= 180.0) {
        return LatLng(lat, lng);
      }
    }

    // 5. Query param q=lat,lng or ll=lat,lng or center=lat,lng (Google Maps & Apple Maps)
    final qMatch = RegExp(
      r'[?&](?:q|ll|query|destination|daddr|saddr|center)=([-+]?[0-9]+\.[0-9]+)[,%2C\s]+([-+]?[0-9]+\.[0-9]+)',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (qMatch != null) {
      final lat = double.tryParse(qMatch.group(1)!);
      final lng = double.tryParse(qMatch.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90.0 && lng.abs() <= 180.0) {
        return LatLng(lat, lng);
      }
    }

    // 6. Short URL (maps.app.goo.gl or goo.gl/maps) -> resolve redirect with multi-hop support
    if (decoded.contains('maps.app.goo.gl') || decoded.contains('goo.gl/maps')) {
      try {
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(decoded);
        if (urlMatch != null) {
          final rawUrl = urlMatch.group(0)!;
          // Step A: First try with followRedirects = false to capture the 302 Location header directly
          final client = http.Client();
          try {
            var currentUri = Uri.parse(rawUrl);
            for (int hop = 0; hop < 4; hop++) {
              final req = http.Request('GET', currentUri)..followRedirects = false;
              req.headers['User-Agent'] = 'Mozilla/5.0 (Mobile; Android; inRideApp)';
              final streamed = await client.send(req).timeout(const Duration(seconds: 4));
              final locHeader = streamed.headers['location'];
              if (locHeader != null && locHeader.isNotEmpty) {
                final resolvedCoords = await extractCoordinatesFromText(locHeader);
                if (resolvedCoords != null) return resolvedCoords;
                currentUri = Uri.parse(locHeader.startsWith('http') ? locHeader : currentUri.resolve(locHeader).toString());
              } else {
                // If final destination reached, check streamed body or response
                final bodyBytes = await streamed.stream.toBytes();
                final bodyString = utf8.decode(bodyBytes, allowMalformed: true);
                final bodyCoords = await extractCoordinatesFromText(bodyString);
                if (bodyCoords != null) return bodyCoords;
                break;
              }
            }
          } finally {
            client.close();
          }

          // Step B: Fallback to full standard get
          final fullResp = await http.get(Uri.parse(rawUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (Mobile; inRideApp)',
          }).timeout(const Duration(seconds: 4));

          final finalUrl = fullResp.request?.url.toString();
          if (finalUrl != null && finalUrl.isNotEmpty && finalUrl != rawUrl) {
            final fromFinalUrl = await extractCoordinatesFromText(finalUrl);
            if (fromFinalUrl != null) return fromFinalUrl;
          }

          if (fullResp.body.isNotEmpty) {
            final fromBody = await extractCoordinatesFromText(fullResp.body);
            if (fromBody != null) return fromBody;
          }
        }
      } catch (_) {}
    }

    return null;
  }
}
