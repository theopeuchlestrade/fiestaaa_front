import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_personal_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel event({
  bool finished = false,
  List<String> features = const [eventFeatureItems, eventFeaturePolls],
}) => EventModel(
  id: 1,
  name: 'Dinner',
  description: 'Friends',
  date: DateTime(2099),
  startTime: const Duration(hours: 20),
  endDate: null,
  endTime: null,
  address: 'Paris',
  latitude: null,
  longitude: null,
  paymentProviderId: null,
  paymentIdentifier: null,
  paymentRequestedAmount: null,
  paymentPerPerson: false,
  ownerEmail: 'owner@example.com',
  playlistUrl: null,
  playlistProvider: null,
  enabledFeatures: features,
  lifecycleStatus: finished ? 'finished' : 'upcoming',
);
PollModel poll({bool voted = false, bool expired = false}) => PollModel(
  id: 1,
  eventId: 1,
  question: 'Which dessert?',
  allowMultiple: false,
  expiresAt: DateTime(2099),
  createdAt: DateTime(2026),
  createdByEmail: 'owner@example.com',
  options: [],
  myVotes: voted ? [1] : [],
  totalVotes: 0,
  hasExpired: expired,
);
Widget summary({
  bool owner = false,
  bool accepted = true,
  bool waiting = false,
  bool known = true,
  bool finished = false,
  List<String> features = const [eventFeatureItems, eventFeaturePolls],
  List<EventItemModel>? items = const [],
  List<ItemContributionModel>? contributions = const [],
  List<PollModel>? polls = const [],
  VoidCallback? onItems,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: S.localizationsDelegates,
  supportedLocales: S.supportedLocales,
  home: Scaffold(
    body: EventPersonalSummary(
      event: event(finished: finished, features: features),
      email: 'me@example.com',
      owner: owner,
      accepted: accepted,
      waiting: waiting,
      invitationKnown: known,
      items: items,
      contributions: contributions,
      polls: polls,
      onInvitation: () {},
      onItems: onItems ?? () {},
      onPolls: () {},
      onRetry: () {},
    ),
  ),
);
void main() {
  testWidgets('missing data never reports caught up', (tester) async {
    await tester.pumpWidget(summary(items: null));
    await tester.pumpAndSettle();
    expect(find.text('Information unavailable'), findsOneWidget);
    expect(find.text('You’re all caught up'), findsNothing);
  });
  testWidgets('waiting guests see invitation, not restricted modules', (
    tester,
  ) async {
    await tester.pumpWidget(
      summary(accepted: false, waiting: true, polls: [poll()]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Respond to invitation'), findsOneWidget);
    expect(find.text('Which dessert?'), findsNothing);
  });
  testWidgets('only active unanswered polls require action', (tester) async {
    await tester.pumpWidget(
      summary(polls: [poll(voted: true), poll(expired: true)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    await tester.pumpWidget(summary(polls: [poll()]));
    await tester.pumpAndSettle();
    expect(find.text('Which dessert?'), findsOneWidget);
  });
  testWidgets('finished and disabled modules do not request action', (
    tester,
  ) async {
    await tester.pumpWidget(summary(finished: true));
    await tester.pumpAndSettle();
    expect(find.text('For you'), findsNothing);
    await tester.pumpWidget(summary(features: [], items: null, polls: null));
    await tester.pumpAndSettle();
    expect(find.text('Information unavailable'), findsNothing);
  });
  testWidgets('personal quantities open the item module', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      summary(
        contributions: [
          ItemContributionModel(
            itemId: 1,
            quantity: 2,
            email: 'ME@example.com',
          ),
          ItemContributionModel(
            itemId: 2,
            quantity: 7,
            email: 'other@example.com',
          ),
        ],
        onItems: () => opened = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('7'), findsNothing);
    await tester.tap(find.text('Your items to bring'));
    expect(opened, isTrue);
  });
}
