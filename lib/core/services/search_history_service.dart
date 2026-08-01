import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_location.dart';
import '../utils/map_coordinates_helper.dart';

class SearchHistoryService {
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  static SearchHistoryService get instance => _instance;
  SearchHistoryService._internal();

  static const String _storageKey = 'inride_search_history_v2';
  List<PlaceLocation> _cachedHistory = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawJson);
        _cachedHistory = decoded
            .map((item) => PlaceLocation.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((loc) => loc.isValid)
            .toList();

        for (var loc in _cachedHistory) {
          if (loc.isValid) {
            MapCoordinatesHelper.registerCoordinate(loc.formattedAddress, LatLng(loc.latitude, loc.longitude));
            if (loc.placeName.isNotEmpty) {
              MapCoordinatesHelper.registerCoordinate(loc.placeName, LatLng(loc.latitude, loc.longitude));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SearchHistoryService] Error loading history: $e');
      _cachedHistory = [];
    }
    _isInitialized = true;
  }

  /// Returns recent search history list sorted by timestamp descending
  List<PlaceLocation> getHistory() {
    _cachedHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(_cachedHistory);
  }

  /// Adds or updates a location record in Search History (Requirements 1, 9, 10)
  Future<void> saveLocation(PlaceLocation place) async {
    if (!place.isValid) return;
    await init();

    MapCoordinatesHelper.registerCoordinate(place.formattedAddress, LatLng(place.latitude, place.longitude));
    if (place.placeName.isNotEmpty) {
      MapCoordinatesHelper.registerCoordinate(place.placeName, LatLng(place.latitude, place.longitude));
    }

    // Check if an existing location matches (Requirement 9 & 10)
    int existingIndex = -1;
    for (int i = 0; i < _cachedHistory.length; i++) {
      if (_cachedHistory[i].isDuplicateOf(place)) {
        existingIndex = i;
        break;
      }
    }

    if (existingIndex != -1) {
      // Update existing record with updated coordinates and fresh timestamp
      final old = _cachedHistory[existingIndex];
      _cachedHistory[existingIndex] = place.copyWith(
        latitude: place.latitude != 0.0 ? place.latitude : old.latitude,
        longitude: place.longitude != 0.0 ? place.longitude : old.longitude,
        timestamp: DateTime.now(),
      );
    } else {
      // Insert new record at top
      _cachedHistory.insert(0, place);
    }

    // Limit to top 20 items
    if (_cachedHistory.length > 20) {
      _cachedHistory = _cachedHistory.sublist(0, 20);
    }

    await _persist();
  }

  /// Synchronizes places from trip history into search history
  Future<void> syncFromTripHistory(List<Map<String, dynamic>> tripHistory) async {
    await init();
    bool changed = false;

    for (final trip in tripHistory) {
      final toAddress = trip['to'] as String? ?? '';
      final toLat = (trip['toLat'] as num?)?.toDouble() ?? 0.0;
      final toLng = (trip['toLng'] as num?)?.toDouble() ?? 0.0;
      final timestamp = trip['timestamp'] as DateTime? ?? DateTime.now();

      if (toAddress.isNotEmpty && toLat != 0.0 && toLng != 0.0) {
        String title = toAddress;
        if (toAddress.contains('،')) {
          title = toAddress.split('،').first.trim();
        } else if (toAddress.contains(',')) {
          title = toAddress.split(',').first.trim();
        }

        final loc = PlaceLocation(
          latitude: toLat,
          longitude: toLng,
          placeName: title,
          formattedAddress: toAddress,
          timestamp: timestamp,
        );

        if (loc.isValid) {
          int existingIndex = -1;
          for (int i = 0; i < _cachedHistory.length; i++) {
            if (_cachedHistory[i].isDuplicateOf(loc)) {
              existingIndex = i;
              break;
            }
          }

          if (existingIndex == -1) {
            _cachedHistory.add(loc);
            changed = true;
          }
        }
      }
    }

    if (changed) {
      _cachedHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (_cachedHistory.length > 20) {
        _cachedHistory = _cachedHistory.sublist(0, 20);
      }
      await _persist();
    }
  }

  Future<void> clearHistory() async {
    _cachedHistory.clear();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_cachedHistory.map((loc) => loc.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[SearchHistoryService] Error persisting history: $e');
    }
  }
}
