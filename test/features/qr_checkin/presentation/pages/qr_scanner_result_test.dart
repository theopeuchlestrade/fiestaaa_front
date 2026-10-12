import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/qr_scanner_page.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Camera extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(320, 480),
        numberOfCameras: 2,
      );
  @override
  Widget buildCameraView() => const SizedBox();
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  for (final status in [200, 409, 404, 503]) {
    testWidgets(
      'scanner $status stops after a result and only scans again on request',
      (tester) async {
        final original = MobileScannerPlatform.instance;
        MobileScannerPlatform.instance = _Camera();
        addTearDown(() => MobileScannerPlatform.instance = original);
        var scans = 0, stats = 0;
        final api = QRCheckinApi(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/qr-scan-stats')) {
              stats++;
              return http.Response(
                '{"total_invited":2,"total_checked_in":1,"pending_checkins":1}',
                200,
              );
            }
            scans++;
            return http.Response(
              status == 200 || status == 409
                  ? '{"success":${status == 200},"status":"${status == 200 ? 'checked_in' : 'already_scanned'}","message":"Fixture result","user_email":"guest@example.invalid","user_handle":"@guest"}'
                  : '{"error":"qr_not_found"}',
              status,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: QRScannerPage(
              eventId: 7,
              eventName: 'Fixture',
              token: 'fixture',
              api: api,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final detect = tester
            .widget<MobileScanner>(find.byType(MobileScanner))
            .onDetect!;
        detect(BarcodeCapture(barcodes: const []));
        await tester.pump();
        expect(scans, 0);
        final capture = BarcodeCapture(
          barcodes: const [Barcode(rawValue: 'fixture-ticket')],
        );
        detect(capture);
        await tester.pumpAndSettle();
        expect(scans, 1);
        expect(stats, status == 200 ? 2 : 1);
        final context = tester.element(find.byType(QRScannerPage));
        expect(
          find.text(
            status == 200
                ? S.of(context).accessGranted
                : S.of(context).accessDenied,
          ),
          findsOneWidget,
        );
        detect(capture);
        await tester.pump();
        expect(scans, 1);
        await tester.ensureVisible(find.text(S.of(context).scanNext));
        await tester.tap(find.text(S.of(context).scanNext));
        await tester.pumpAndSettle();
        detect(capture);
        await tester.pumpAndSettle();
        expect(scans, 2);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
