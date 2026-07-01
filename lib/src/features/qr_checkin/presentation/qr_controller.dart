import 'package:fiestaaa_front/src/core/feature_controller.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';

class QrController extends FeatureController {
  QrController({required this.token, required this.eventId, QRCheckinApi? api})
    : api = api ?? QRCheckinApi();

  final String token;
  final int eventId;
  final QRCheckinApi api;
  QRCodeData? code;
  QRScanStats? stats;

  @override
  Future<void> load() async {
    code = await api.fetchMyQRCode(token: token, eventId: eventId);
  }

  Future<void> loadStats() async {
    stats = await api.fetchScanStats(token: token, eventId: eventId);
    notifySafely();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
