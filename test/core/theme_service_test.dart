import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadSavedTheme restores a persisted theme mode', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    final service = ThemeService();

    await service.loadSavedTheme();

    expect(service.mode, ThemeMode.dark);
  });

  test('loadSavedTheme ignores invalid persisted values', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'sepia'});
    final service = ThemeService();

    await service.loadSavedTheme();

    expect(service.mode, ThemeMode.system);
  });

  test('setMode persists the selected theme mode', () async {
    final service = ThemeService();

    await service.setMode(ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(service.mode, ThemeMode.light);
    expect(prefs.getString('app_theme_mode'), 'light');
  });
}
