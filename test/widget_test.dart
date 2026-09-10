// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:fiestaaa_front/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/core/pending_token_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  for (final page in ['privacy', 'terms', 'support', 'delete-account']) {
    testWidgets('Public $page route requires no session', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'Fiestaaa',
        packageName: 'com.fiestaaa.fiestaaa',
        version: '0.5.0',
        buildNumber: '5001',
        buildSignature: '',
      );
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/$page';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(const FiestaaaApp());
      await tester.binding.handlePushRoute('/$page');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LegalPage), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
    });
  }
  testWidgets(
    'Incoming invitation waits at sign in without consuming the token',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/link?shareToken=invitation-test';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      addTearDown(
        () => PendingTokenStorage.remove('fiestaaa_pending_share_token'),
      );
      await tester.pumpWidget(const FiestaaaApp());
      await tester.binding.handlePushRoute('/link?shareToken=invitation-test');
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(
        PendingTokenStorage.read('fiestaaa_pending_share_token'),
        'invitation-test',
      );
    },
  );
  testWidgets('L’application se construit', (WidgetTester tester) async {
    await tester.pumpWidget(const FiestaaaApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
