import 'package:fiestaaa_front/src/core/feature_controller.dart';
import 'package:fiestaaa_front/src/features/carpools/data/carpools_api.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';

class CarpoolsController extends FeatureController {
  CarpoolsController({
    required this.token,
    required this.eventId,
    CarpoolsApi? api,
  }) : api = api ?? CarpoolsApi();

  final String token;
  final int eventId;
  final CarpoolsApi api;
  List<CarpoolModel> items = const [];
  String? sortBy;

  @override
  Future<void> load() async {
    items = await api.fetchEventCarpools(
      token: token,
      eventId: eventId,
      sortBy: sortBy,
    );
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
