import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static final LocaleController instance = LocaleController._internal();
  factory LocaleController() => instance;
  LocaleController._internal();

  static const String _prefKey = 'selected_language_code';

  Locale _locale = const Locale('ar', 'EG');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isEnglish => _locale.languageCode == 'en';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null && savedCode.isNotEmpty) {
        if (savedCode == 'en') {
          _locale = const Locale('en', 'US');
        } else {
          _locale = const Locale('ar', 'EG');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LocaleController] Error loading saved locale: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale.languageCode == newLocale.languageCode) return;

    _locale = newLocale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newLocale.languageCode);
    } catch (e) {
      debugPrint('[LocaleController] Error saving locale preference: $e');
    }
  }

  Future<void> toggleLanguage() async {
    if (isArabic) {
      await setLocale(const Locale('en', 'US'));
    } else {
      await setLocale(const Locale('ar', 'EG'));
    }
  }
}
