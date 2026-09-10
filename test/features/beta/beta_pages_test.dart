import 'dart:convert';
import 'package:fiestaaa_front/src/features/beta_api.dart';
import 'package:fiestaaa_front/src/features/beta_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('Blocking and unblocking update the private list', (
    tester,
  ) async {
    var blocked = false;
    final api = BetaApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/safety/user')) {
          expect(request.url.queryParameters['handle'], 'test_person');
          return http.Response(
            '{"public_id":"target-id","handle":"test_person"}',
            200,
          );
        }
        if (request.method == 'POST') {
          expect(jsonDecode(request.body)['public_id'], 'target-id');
          blocked = true;
        } else if (request.method == 'DELETE') {
          expect(request.url.path, endsWith('/me/blocks/target-id'));
          blocked = false;
        }
        return http.Response(
          request.method == 'GET'
              ? (blocked
                    ? '[{"public_id":"target-id","handle":"test_person"}]'
                    : '[]')
              : '{}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyPage(token: 'session', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'test_person');
    await tester.tap(find.text('Block direct contact'));
    await tester.pumpAndSettle();
    expect(blocked, isTrue);
    await tester.ensureVisible(find.text('Unblock'));
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(blocked, isFalse);
    expect(find.text('Unblock'), findsNothing);
  });
  testWidgets('Recovery sends generic request and presents provider guidance', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    final api = BetaApi(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/auth/password-reset/request'));
        calls.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"status":"recovery_requested"}', 202);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: PasswordResetPage(api: api)));
    await tester.enterText(find.byType(TextField), 'test@example.test');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(calls.single['email'], 'test@example.test');
    expect(
      find.textContaining('If this account uses a password'),
      findsOneWidget,
    );
    api.close();
  });
  testWidgets(
    'Confirmation mismatch never calls server; successful reset clears fields',
    (tester) async {
      var calls = 0;
      final api = BetaApi(
        client: MockClient((request) async {
          calls++;
          expect(jsonDecode(request.body)['token'], 'a' * 64);
          return http.Response('{"status":"password_reset"}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordResetPage(token: 'a' * 64, api: api),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'ChangedPassword2!');
      await tester.enterText(
        find.byType(TextField).last,
        'DifferentPassword2!',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(calls, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'ChangedPassword2!');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(TextField), findsNothing);
      api.close();
    },
  );
  testWidgets(
    'Public support is accessible without a session and shows build',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'Fiestaaa',
        packageName: 'com.fiestaaa.fiestaaa',
        version: '0.5.0',
        buildNumber: '5001',
        buildSignature: 'test',
      );
      await tester.pumpWidget(
        const MaterialApp(home: LegalPage(page: 'support')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Help and feedback'), findsOneWidget);
      expect(find.textContaining('0.5.0 (5001)'), findsOneWidget);
    },
  );
}
