import 'dart:convert';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:fiestaaa_front/src/features/profile/domain/profile_info.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as ip;
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ProfileApi {
  bool failLoad = false,
      failUpdate = false,
      failCheck = false,
      failDelete = false;
  int updates = 0, deletes = 0, uploads = 0, loads = 0;
  String handle = 'qauser';
  List<int>? bytes;
  ProfileInfo get value => ProfileInfo(
    email: 'qa@example.invalid',
    handle: handle,
    expiration: DateTime(2099),
  );
  @override
  Future<ProfileInfo> fetchProfile(String token) async {
    loads++;
    if (failLoad) throw ApiException('unavailable', statusCode: 503);
    return value;
  }

  @override
  Future<bool> checkHandleAvailability(String handle) async {
    if (failCheck) throw ApiException('invalid_handle', code: 'invalid_handle');
    return handle != 'taken';
  }

  @override
  Future<ProfileInfo> updateHandle({
    required String token,
    required String handle,
  }) async {
    updates++;
    if (failUpdate) {
      throw ApiException('handle_taken', code: 'handle_taken', statusCode: 409);
    }
    this.handle = handle;
    return value;
  }

  @override
  Future<void> deleteAccount({required String token}) async {
    deletes++;
    if (failDelete) throw ApiException('unavailable', statusCode: 503);
  }

  @override
  Future<ProfileInfo> uploadAvatar({
    required String token,
    required String filename,
    required List<int> bytes,
  }) async {
    uploads++;
    this.bytes = bytes;
    return value;
  }

  @override
  void dispose() {}
}

class _Picker extends ip.ImagePickerPlatform {
  _Picker(this.mode);
  final String mode;
  @override
  Future<XFile?> getImageFromSource({
    required ip.ImageSource source,
    ip.ImagePickerOptions options = const ip.ImagePickerOptions(),
  }) async {
    if (mode == 'cancel') return null;
    if (mode == 'denied') {
      throw PlatformException(code: 'fixture_permission_denied');
    }
    final bytes = mode == 'large'
        ? Uint8List(8 * 1024 * 1024 + 1)
        : base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aXJkAAAAASUVORK5CYII=',
          );
    return XFile.fromData(bytes, name: 'fixture.png');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Api api, {
  Future<void> Function(SessionData)? updated,
  VoidCallback? logout,
  LocaleService? locale,
  ThemeService? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: ProfilePage(
          api: api,
          session: SessionData(token: 'fixture', email: 'qa@example.invalid'),
          onLogout: logout ?? () {},
          onSessionUpdated: updated,
          localeService: locale,
          themeService: theme,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

S labels(WidgetTester tester) => S.of(tester.element(find.byType(ProfilePage)));
Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('profile load error keeps logout usable', (tester) async {
    final api = _Api()..failLoad = true;
    await _pump(tester, api);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('qa@example.invalid'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'handle availability validates empty, taken and available input',
    (tester) async {
      final api = _Api();
      await _pump(tester, api);
      final l = labels(tester);
      await tap(tester, find.text(l.editProfile));
      await tester.enterText(find.byType(TextField), '');
      await tap(tester, find.text(l.check));
      expect(find.text(l.enterIdentifierToCheck), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'taken');
      await tap(tester, find.text(l.check));
      expect(find.text(l.identifierTaken), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'available');
      await tap(tester, find.text(l.check));
      expect(find.text(l.identifierAvailable), findsOneWidget);
      api.failCheck = true;
      await tap(tester, find.text(l.check));
      expect(find.text('invalid_handle'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'successful handle update trims input and updates the active session',
    (tester) async {
      final api = _Api();
      SessionData? session;
      await _pump(
        tester,
        api,
        updated: (s) async {
          session = s;
        },
      );
      final l = labels(tester);
      await tap(tester, find.text(l.editProfile));
      await tester.enterText(find.byType(TextField), ' newhandle ');
      await tap(tester, find.text(l.update));
      expect(api.updates, 1);
      expect(api.handle, 'newhandle');
      expect(session?.handle, 'newhandle');
      expect(find.text('@newhandle'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('empty or refused profile change keeps the previous identity', (
    tester,
  ) async {
    final api = _Api()..failUpdate = true;
    await _pump(tester, api);
    final l = labels(tester);
    await tap(tester, find.text(l.editProfile));
    await tester.enterText(find.byType(TextField), '');
    await tap(tester, find.text(l.update));
    expect(api.updates, 0);
    await tester.enterText(find.byType(TextField), 'taken');
    await tap(tester, find.text(l.update));
    expect(api.updates, 1);
    expect(api.handle, 'qauser');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('handle_taken'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final mode in ['success', 'cancel', 'denied', 'large']) {
    testWidgets('avatar $mode preserves upload/permission boundaries', (
      tester,
    ) async {
      final original = ip.ImagePickerPlatform.instance;
      ip.ImagePickerPlatform.instance = _Picker(mode);
      addTearDown(() => ip.ImagePickerPlatform.instance = original);
      final api = _Api();
      await _pump(tester, api);
      final l = labels(tester);
      await tap(tester, find.text(l.editProfile));
      final control = find.text(l.changePhoto);
      await tap(tester, control);
      expect(api.uploads, mode == 'success' ? 1 : 0);
      if (mode == 'success') {
        expect(api.bytes, isNotEmpty);
        expect(find.text(l.photoUpdated), findsOneWidget);
      }
      if (mode == 'large') expect(find.text(l.imageTooLarge), findsOneWidget);
      expect(find.text('@qauser'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('preferences update explicit theme and language services', (
    tester,
  ) async {
    final api = _Api();
    final locale = LocaleService();
    final theme = ThemeService();
    await locale.loadSavedLocale();
    await theme.loadSavedTheme();
    await _pump(tester, api, locale: locale, theme: theme);
    final l = labels(tester);
    await tap(tester, find.text(l.changeLanguage));
    await tap(tester, find.text('English'));
    expect(locale.locale?.languageCode, 'en');
    await tap(tester, find.text(l.changeTheme));
    await tap(tester, find.text(l.themeDark));
    expect(theme.mode, ThemeMode.dark);
    await tester.pumpWidget(const SizedBox());
  });
}
