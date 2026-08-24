import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
      return deviceLocation ?? const LatLng(30.0444, 31.2357);
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

    return deviceLocation ?? const LatLng(30.0444, 31.2357);
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

    final latBias = biasLat ?? deviceLocation?.latitude ?? 30.0444;
    final lngBias = biasLng ?? deviceLocation?.longitude ?? 31.2357;

    // 1. Try Photon Geocoding
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&lat=$latBias&lon=$lngBias&limit=1',
      );
      final response = await http.get(photonUrl, headers: {
        'User-Agent': 'inRideApp/2.0 (contact: support@inride.app)'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final coords = features[0]['geometry']?['coordinates'] as List?;
          if (coords != null && coords.length >= 2) {
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final latLng = LatLng(lat, lon);
            registerCoordinate(trimmed, latLng);
            return latLng;
          }
        }
      }
    } catch (_) {}

    // 2. Try Nominatim Geocoding
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&accept-language=ar,en&limit=1',
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

    return null;
  }
}
