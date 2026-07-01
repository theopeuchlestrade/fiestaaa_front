import 'package:fiestaaa_front/src/core/feature_controller.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_expense_model.dart';

class EventExpensesController extends FeatureController {
  EventExpensesController({
    required this.token,
    required this.eventId,
    EventsApi? api,
  }) : api = api ?? EventsApi();

  final String token;
  final int eventId;
  final EventsApi api;
  List<EventExpenseModel> expenses = const [];
  EventExpensesSummaryModel? summary;

  @override
  Future<void> load() async {
    final values = await Future.wait([
      api.fetchEventExpenses(token: token, eventId: eventId),
      api.fetchEventExpensesSummary(token: token, eventId: eventId),
    ]);
    expenses = values[0] as List<EventExpenseModel>;
    summary = values[1] as EventExpensesSummaryModel;
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }
}
