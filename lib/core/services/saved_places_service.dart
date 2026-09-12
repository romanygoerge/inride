import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place_location.dart';

class SavedPlacesService {
  static final SavedPlacesService _instance = SavedPlacesService._internal();
  static SavedPlacesService get instance => _instance;
  SavedPlacesService._internal();

  static const String _storageKey = 'inride_saved_places_v2';
  final List<PlaceLocation> _cachedSavedPlaces = [];
  bool _isInitialized = false;

  /// Notifier to notify UI components whenever a place is saved or removed
  final ValueNotifier<int> versionNotifier = ValueNotifier<int>(0);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(rawJson);
        _cachedSavedPlaces.clear();
        for (final item in decoded) {
          final loc = PlaceLocation.fromJson(Map<String, dynamic>.from(item as Map));
          if (loc.isValid) {
            _cachedSavedPlaces.add(loc.copyWith(isSaved: true));
          }
        }
      }

      // Background sync from Supabase if logged in
      _syncFromSupabase();
    } catch (e) {
      debugPrint('[SavedPlacesService] Error loading saved places: $e');
    }
    _isInitialized = true;
  }

  Future<void> _syncFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('user_saved_places')
          .select()
          .eq('user_id', user.id);

      bool hasNew = false;
      for (final row in response) {
        final loc = PlaceLocation(
          placeId: row['place_id'] as String? ?? row['id'] as String?,
          latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
          placeName: (row['title'] as String?) ?? '',
          formattedAddress: (row['address'] as String?) ?? '',
          timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
          category: (row['icon'] as String?) ?? 'bookmark',
          isSaved: true,
        );

        if (loc.isValid && !isSaved(loc)) {
          _cachedSavedPlaces.add(loc);
          hasNew = true;
        }
      }

      if (hasNew) {
        await _persist();
        versionNotifier.value++;
      }
    } catch (_) {}
  }

  List<PlaceLocation> getSavedPlaces() {
    return List.unmodifiable(_cachedSavedPlaces);
  }

  bool isSaved(PlaceLocation place) {
    if (!place.isValid) return false;
    return _cachedSavedPlaces.any((p) =>
        p.isDuplicateOf(place) ||
        (p.formattedAddress.isNotEmpty &&
            p.formattedAddress.toLowerCase().trim() == place.formattedAddress.toLowerCase().trim()) ||
        (p.placeName.isNotEmpty &&
            p.placeName.toLowerCase().trim() == place.placeName.toLowerCase().trim()));
  }

  /// Toggles saved state. Returns `true` if added to favorites, `false` if removed.
  Future<bool> toggleSave(PlaceLocation place) async {
    await init();
    if (isSaved(place)) {
      await removeSavedPlace(place);
      return false;
    } else {
      await savePlace(place);
      return true;
    }
  }

  Future<void> savePlace(PlaceLocation place) async {
    if (!place.isValid) return;
    await init();

    if (isSaved(place)) return;

    final toSave = place.copyWith(
      isSaved: true,
      timestamp: DateTime.now(),
    );

    _cachedSavedPlaces.insert(0, toSave);
    await _persist();
    versionNotifier.value++;

    // Sync to Supabase in background
    _syncSaveToSupabase(toSave);
  }

  Future<void> removeSavedPlace(PlaceLocation place) async {
    await init();
    _cachedSavedPlaces.removeWhere((p) =>
        p.isDuplicateOf(place) ||
        (p.formattedAddress.isNotEmpty &&
            p.formattedAddress.toLowerCase().trim() == place.formattedAddress.toLowerCase().trim()) ||
        (p.placeName.isNotEmpty &&
            p.placeName.toLowerCase().trim() == place.placeName.toLowerCase().trim()));

    await _persist();
    versionNotifier.value++;

    // Sync delete to Supabase in background
    _syncDeleteFromSupabase(place);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cachedSavedPlaces.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(list));
    } catch (e) {
      debugPrint('[SavedPlacesService] Error persisting saved places: $e');
    }
  }

  void _syncSaveToSupabase(PlaceLocation place) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('user_saved_places').insert({
        'user_id': user.id,
        'title': place.placeName.isNotEmpty ? place.placeName : place.formattedAddress,
        'address': place.formattedAddress,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'icon': place.category ?? 'bookmark',
      });
    } catch (_) {}
  }

  void _syncDeleteFromSupabase(PlaceLocation place) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('user_saved_places')
          .delete()
          .eq('user_id', user.id)
          .eq('address', place.formattedAddress);
    } catch (_) {}
  }
}
