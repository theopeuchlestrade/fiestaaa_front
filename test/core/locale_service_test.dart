import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadSavedLocale restores a persisted locale', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    final service = LocaleService();

    await service.loadSavedLocale();

    expect(service.locale, const Locale('en'));
  });

  test('setLocale ignores unsupported locales', () async {
    final service = LocaleService();

    await service.setLocale(const Locale('es'));

    final prefs = await SharedPreferences.getInstance();
    expect(service.locale, isNull);
    expect(prefs.getString('app_locale'), isNull);
  });

  test('clearLocale resets memory and storage', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
    final service = LocaleService();
    await service.loadSavedLocale();

    await service.clearLocale();

    final prefs = await SharedPreferences.getInstance();
    expect(service.locale, isNull);
    expect(prefs.getString('app_locale'), isNull);
  });
}
