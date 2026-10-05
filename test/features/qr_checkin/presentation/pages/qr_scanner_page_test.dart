import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/qr_scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _DeniedCamera extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    throw const MobileScannerException(
      errorCode: MobileScannerErrorCode.permissionDenied,
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('camera denial remains readable above scanner decorations', (
    tester,
  ) async {
    final original = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _DeniedCamera();
    addTearDown(() => MobileScannerPlatform.instance = original);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QRScannerPage(
                    eventId: 13,
                    eventName: 'Test',
                    token: 'test',
                    api: QRCheckinApi(
                      client: MockClient(
                        (_) async => http.Response(
                          '{"total_invited":1,"total_checked_in":0,"pending_checkins":1}',
                          200,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(QRScannerPage));
    final message = find.text(S.of(context).cameraPermissionDeniedHelp);
    expect(message, findsOneWidget);
    expect(
      tester.widget<Text>(message).style?.color,
      Theme.of(context).colorScheme.onSurface,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}
