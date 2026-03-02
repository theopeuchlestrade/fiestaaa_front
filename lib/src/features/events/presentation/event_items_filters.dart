import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';

enum EventItemsScope { all, mine, toCover, completed }

extension EventItemsScopeApi on EventItemsScope {
  String get apiValue => switch (this) {
    EventItemsScope.all => 'all',
    EventItemsScope.mine => 'mine',
    EventItemsScope.toCover => 'to_cover',
    EventItemsScope.completed => 'completed',
  };
}

enum EventItemsSort { smart, nameAsc, remainingDesc }

List<EventItemModel> sortBringItems({
  required List<EventItemModel> items,
  required EventItemsSort sort,
  required String currentUserEmail,
}) {
  final sorted = List<EventItemModel>.from(items);
  final normalizedEmail = currentUserEmail.toLowerCase();
  sorted.sort((a, b) {
    switch (sort) {
      case EventItemsSort.smart:
        final aMine =
            (a.createdByEmail?.toLowerCase() ?? '') == normalizedEmail;
        final bMine =
            (b.createdByEmail?.toLowerCase() ?? '') == normalizedEmail;
        if (aMine != bMine) {
          return aMine ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case EventItemsSort.nameAsc:
      case EventItemsSort.remainingDesc:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  });
  return sorted;
}

List<EventItemModel> sortNeedItems({
  required List<EventItemModel> items,
  required EventItemsSort sort,
}) {
  final sorted = List<EventItemModel>.from(items);
  sorted.sort((a, b) {
    switch (sort) {
      case EventItemsSort.smart:
        final aFull = a.remaining <= 0;
        final bFull = b.remaining <= 0;
        if (aFull != bFull) {
          return aFull ? 1 : -1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case EventItemsSort.nameAsc:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case EventItemsSort.remainingDesc:
        final byRemaining = b.remaining.compareTo(a.remaining);
        if (byRemaining != 0) return byRemaining;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  });
  return sorted;
}
