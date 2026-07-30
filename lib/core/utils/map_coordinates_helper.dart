import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

class MapCoordinatesHelper {
  /// Caches the actual GPS device location
  static LatLng? deviceLocation;

  /// Dynamic cache for searched places and resolved coordinates
  static final Map<String, LatLng> _dynamicCoordinatesCache = {};

  /// Registers a dynamic location and its coordinates
  static void registerCoordinate(String address, LatLng coordinate) {
    _dynamicCoordinatesCache[address.toLowerCase().trim()] = coordinate;
  }

  /// Resolves the address Arabic text into approximate Cairo/Giza coordinates
  static LatLng getLatLngForAddress(String? address) {
    if (address == null || address.trim().isEmpty) {
      return deviceLocation ?? const LatLng(30.0130, 31.2080);
    }

    final addr = address.toLowerCase().trim();

    // 1. Try to parse coordinates if they exist in the string (e.g. "30.0130, 31.2080" or "موقعي الحالي (30.0130, 31.2080)")
    final regExp = RegExp(r'([-+]?[0-9]+\.?[0-9]+),\s*([-+]?[0-9]+\.?[0-9]+)');
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

    // 4. Landmark coordinate mapping
    if (addr.contains('نيل') || addr.contains('nile') || addr.contains('جيزة') || addr.contains('giza')) {
      return const LatLng(30.0130, 31.2080);
    } else if (addr.contains('جامعة القاهرة') || addr.contains('cairo university')) {
      return const LatLng(30.0276, 31.2101);
    } else if (addr.contains('جامعة الدول') || addr.contains('مهندسين') || addr.contains('mohandessin')) {
      return const LatLng(30.0526, 31.2014);
    } else if (addr.contains('تحرير') || addr.contains('tahrir') || addr.contains('وسط البلد')) {
      return const LatLng(30.0444, 31.2357);
    } else if (addr.contains('مول مصر') || addr.contains('mall of egypt')) {
      return const LatLng(29.9722, 31.0152);
    } else if (addr.contains('مطار') || addr.contains('airport') || addr.contains('الدولي')) {
      return const LatLng(30.1219, 31.4056);
    } else if (addr.contains('أكتوبر') || addr.contains('october') || addr.contains('الواحات')) {
      return const LatLng(29.9730, 30.9520);
    } else if (addr.contains('لبنان') || addr.contains('libnan')) {
      return const LatLng(30.0620, 31.1980);
    } else if (addr.contains('السيدة زينب') || addr.contains('sayeda')) {
      return const LatLng(30.0290, 31.2420);
    } else if (addr.contains('العجوزة') || addr.contains('agouza')) {
      return const LatLng(30.0550, 31.2100);
    } else if (addr.contains('جامعة الأمريكية') || addr.contains('auc') || addr.contains('جديدة') || addr.contains('تجمع')) {
      return const LatLng(30.0263, 31.4913);
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

  /// Resolves latitude and longitude coordinates into a human-readable address/city name
  static Future<String> reverseGeocode(double lat, double lng) async {
    // 1. Try Nominatim API (OpenStreetMap)
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar');
      final response = await http.get(url, headers: {'User-Agent': 'inRideApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'];
        if (address != null) {
          final parts = address.split(',');
          if (parts.length > 3) {
            return '${parts[0].trim()}، ${parts[1].trim()}، ${parts[2].trim()}';
          }
          return address;
        }
      }
    } catch (e) {
      debugPrint("Nominatim reverse geocode failed: $e");
    }

    // 2. Fallback to closest Cairo coordinates in our helper list
    double minDistance = double.maxFinite;
    String closestName = "القاهرة، مصر";
    
    final locations = {
      "شارع النيل، الجيزة": const LatLng(30.0130, 31.2080),
      "جامعة القاهرة، الجيزة": const LatLng(30.0276, 31.2101),
      "المهندسين، الجيزة": const LatLng(30.0526, 31.2014),
      "ميدان التحرير، وسط البلد": const LatLng(30.0444, 31.2357),
      "مول مصر، 6 أكتوبر": const LatLng(29.9722, 31.0152),
      "مطار القاهرة الدولي": const LatLng(30.1219, 31.4056),
      "مدينة 6 أكتوبر": const LatLng(29.9730, 30.9520),
      "ميدان لبنان، المهندسين": const LatLng(30.0620, 31.1980),
      "السيدة زينب، القاهرة": const LatLng(30.0290, 31.2420),
      "العجوزة، الجيزة": const LatLng(30.0550, 31.2100),
      "التجمع الخامس، القاهرة الجديدة": const LatLng(30.0263, 31.4913),
    };

    locations.forEach((name, latLng) {
      final dist = LocationService.instance.calculateDistance(lat, lng, latLng.latitude, latLng.longitude);
      if (dist < minDistance) {
        minDistance = dist;
        closestName = name;
      }
    });

    return closestName;
  }
}
