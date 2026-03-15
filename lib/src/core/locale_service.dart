import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static const List<Locale> supportedLocales = [Locale('fr'), Locale('en')];
  static const Locale fallbackLocale = Locale('en');

  Locale? _locale;

  Locale? get locale => _locale;

  static Locale? normalizeSupportedLocale(Locale? locale) {
    if (locale == null) return null;
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return null;
  }

  static Locale resolveDeviceLocales(List<Locale>? deviceLocales) {
    if (deviceLocales != null) {
      for (final locale in deviceLocales) {
        final supportedLocale = normalizeSupportedLocale(locale);
        if (supportedLocale != null) {
          return supportedLocale;
        }
      }
    }
    return fallbackLocale;
  }

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    final parsedLocale = normalizeSupportedLocale(
      savedLocale == null ? null : Locale(savedLocale),
    );
    if (parsedLocale == null) return;

    _locale = parsedLocale;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final supportedLocale = normalizeSupportedLocale(locale);
    if (supportedLocale == null) return;

    _locale = supportedLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, supportedLocale.languageCode);
    notifyListeners();
  }

  Future<void> clearLocale() async {
    _locale = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);
    notifyListeners();
  }

  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      default:
        return languageCode;
    }
  }
}
