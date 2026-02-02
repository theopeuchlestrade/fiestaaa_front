import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static const List<Locale> supportedLocales = [Locale('fr'), Locale('en')];

  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale != null) {
      _locale = Locale(savedLocale);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(Locale(locale.languageCode))) {
      return;
    }
    _locale = Locale(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
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
