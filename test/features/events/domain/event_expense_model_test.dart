import 'package:fiestaaa_front/src/features/events/domain/event_expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EventExpenseModel parses payer and participants', () {
    final expense = EventExpenseModel.fromJson({
      'expense_id': 42,
      'event_id': 7,
      'paid_by_user_id': 12,
      'paid_by_handle': 'bob',
      'paid_by_avatar_url': 'https://example.com/bob.png',
      'title': 'Courses',
      'amount_cents': 1299,
      'note': 'Pour le week-end',
      'expense_date': '2030-05-04T10:00:00Z',
      'created_at': '2030-05-04T10:05:00Z',
      'participants': [
        {
          'user_id': 11,
          'handle': 'alice',
          'avatar_url': 'https://example.com/alice.png',
        },
        {
          'user_id': 12,
          'handle': 'bob',
          'avatar_url': 'https://example.com/bob.png',
        },
      ],
    });

    expect(expense.id, 42);
    expect(expense.paidByUserId, 12);
    expect(expense.paidByHandle, 'bob');
    expect(expense.amountEuros, 12.99);
    expect(expense.participants.map((item) => item.userId), [11, 12]);
    expect(expense.participants.first.avatarUrl, isNotEmpty);
  });

  test('EventExpensesSummaryModel parses balances and settlements', () {
    final summary = EventExpensesSummaryModel.fromJson({
      'currency': 'EUR',
      'total_expenses_cents': 900,
      'balances': [
        {
          'user_id': 11,
          'handle': 'alice',
          'avatar_url': null,
          'paid_cents': 0,
          'owed_cents': 450,
          'balance_cents': -450,
        },
        {
          'user_id': 12,
          'handle': 'bob',
          'avatar_url': 'https://example.com/bob.png',
          'paid_cents': 900,
          'owed_cents': 450,
          'balance_cents': 450,
        },
      ],
      'settlements': [
        {
          'from_user_id': 11,
          'from_handle': 'alice',
          'to_user_id': 12,
          'to_handle': 'bob',
          'amount_cents': 450,
        },
      ],
    });

    expect(summary.currency, 'EUR');
    expect(summary.totalExpensesCents, 900);
    expect(summary.balances, hasLength(2));
    expect(summary.balances.last.paidCents, 900);
    expect(summary.settlements, hasLength(1));
    expect(summary.settlements.single.toUserId, 12);
    expect(summary.settlements.single.amountCents, 450);
  });
}
