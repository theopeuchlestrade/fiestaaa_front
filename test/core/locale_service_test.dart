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

  test('loadSavedLocale ignores invalid persisted values', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'es'});
    final service = LocaleService();

    await service.loadSavedLocale();

    expect(service.locale, isNull);
  });

  test('setLocale ignores unsupported locales', () async {
    final service = LocaleService();

    await service.setLocale(const Locale('es'));

    final prefs = await SharedPreferences.getInstance();
    expect(service.locale, isNull);
    expect(prefs.getString('app_locale'), isNull);
  });

  test('resolveDeviceLocales returns the first supported system locale', () {
    final resolved = LocaleService.resolveDeviceLocales(const [
      Locale('es'),
      Locale('fr', 'FR'),
    ]);

    expect(resolved, const Locale('fr'));
  });

  test(
    'resolveDeviceLocales falls back to english for unsupported systems',
    () {
      final resolved = LocaleService.resolveDeviceLocales(const [
        Locale('es'),
        Locale('de'),
      ]);

      expect(resolved, const Locale('en'));
    },
  );

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
