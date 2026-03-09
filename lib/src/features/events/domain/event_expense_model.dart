import 'package:intl/intl.dart';

class EventExpenseParticipantModel {
  EventExpenseParticipantModel({
    required this.userId,
    required this.handle,
    required this.avatarUrl,
  });

  final int userId;
  final String? handle;
  final String? avatarUrl;

  factory EventExpenseParticipantModel.fromJson(Map<String, dynamic> json) {
    return EventExpenseParticipantModel(
      userId: (json['user_id'] as num).toInt(),
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class EventExpenseModel {
  EventExpenseModel({
    required this.id,
    required this.eventId,
    required this.paidByUserId,
    required this.paidByHandle,
    required this.paidByAvatarUrl,
    required this.title,
    required this.amountCents,
    required this.note,
    required this.expenseDate,
    required this.createdAt,
    required this.participants,
  });

  final int id;
  final int eventId;
  final int paidByUserId;
  final String? paidByHandle;
  final String? paidByAvatarUrl;
  final String title;
  final int amountCents;
  final String? note;
  final DateTime expenseDate;
  final DateTime createdAt;
  final List<EventExpenseParticipantModel> participants;

  double get amountEuros => amountCents / 100;

  String get formattedAmount =>
      NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amountEuros);

  factory EventExpenseModel.fromJson(Map<String, dynamic> json) {
    final participantsJson = json['participants'] as List<dynamic>? ?? const [];
    return EventExpenseModel(
      id: (json['expense_id'] as num).toInt(),
      eventId: (json['event_id'] as num).toInt(),
      paidByUserId: (json['paid_by_user_id'] as num).toInt(),
      paidByHandle: json['paid_by_handle'] as String?,
      paidByAvatarUrl: json['paid_by_avatar_url'] as String?,
      title: json['title'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      note: json['note'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: participantsJson
          .map(
            (raw) => EventExpenseParticipantModel.fromJson(
              raw as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class EventExpenseBalanceModel {
  EventExpenseBalanceModel({
    required this.userId,
    required this.handle,
    required this.avatarUrl,
    required this.paidCents,
    required this.owedCents,
    required this.balanceCents,
  });

  final int userId;
  final String? handle;
  final String? avatarUrl;
  final int paidCents;
  final int owedCents;
  final int balanceCents;

  String formatCents(int value) {
    return NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
    ).format(value / 100);
  }

  String get formattedPaid => formatCents(paidCents);
  String get formattedOwed => formatCents(owedCents);
  String get formattedBalance => formatCents(balanceCents);

  factory EventExpenseBalanceModel.fromJson(Map<String, dynamic> json) {
    return EventExpenseBalanceModel(
      userId: (json['user_id'] as num).toInt(),
      handle: json['handle'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      paidCents: (json['paid_cents'] as num).toInt(),
      owedCents: (json['owed_cents'] as num).toInt(),
      balanceCents: (json['balance_cents'] as num).toInt(),
    );
  }
}

class EventExpenseSettlementModel {
  EventExpenseSettlementModel({
    required this.fromUserId,
    required this.fromHandle,
    required this.toUserId,
    required this.toHandle,
    required this.amountCents,
  });

  final int fromUserId;
  final String? fromHandle;
  final int toUserId;
  final String? toHandle;
  final int amountCents;

  String get formattedAmount => NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
  ).format(amountCents / 100);

  factory EventExpenseSettlementModel.fromJson(Map<String, dynamic> json) {
    return EventExpenseSettlementModel(
      fromUserId: (json['from_user_id'] as num).toInt(),
      fromHandle: json['from_handle'] as String?,
      toUserId: (json['to_user_id'] as num).toInt(),
      toHandle: json['to_handle'] as String?,
      amountCents: (json['amount_cents'] as num).toInt(),
    );
  }
}

class EventExpensesSummaryModel {
  EventExpensesSummaryModel({
    required this.currency,
    required this.totalExpensesCents,
    required this.balances,
    required this.settlements,
  });

  final String currency;
  final int totalExpensesCents;
  final List<EventExpenseBalanceModel> balances;
  final List<EventExpenseSettlementModel> settlements;

  String get formattedTotal => NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
  ).format(totalExpensesCents / 100);

  factory EventExpensesSummaryModel.fromJson(Map<String, dynamic> json) {
    final balancesJson = json['balances'] as List<dynamic>? ?? const [];
    final settlementsJson = json['settlements'] as List<dynamic>? ?? const [];
    return EventExpensesSummaryModel(
      currency: json['currency'] as String? ?? 'EUR',
      totalExpensesCents: (json['total_expenses_cents'] as num?)?.toInt() ?? 0,
      balances: balancesJson
          .map(
            (raw) =>
                EventExpenseBalanceModel.fromJson(raw as Map<String, dynamic>),
          )
          .toList(),
      settlements: settlementsJson
          .map(
            (raw) => EventExpenseSettlementModel.fromJson(
              raw as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
