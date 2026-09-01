import 'package:daftar/application/agent/get_closing_day_summary_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  late GetClosingDaySummaryUseCase useCase;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 8, 15));
  });

  setUp(() {
    repository = MockTransactionRepository();
    useCase = GetClosingDaySummaryUseCase(repository);
  });

  Transaction txn({
    required String id,
    required TransactionType type,
    required int amount,
    required DateTime createdAt,
    String currency = 'YER',
    DateTime? transactionDate,
    String? itemName,
    bool isArchived = false,
  }) {
    return Transaction(
      id: id,
      contactId: 'contact-1',
      type: type,
      amount: amount,
      currency: currency,
      transactionDate: transactionDate ?? createdAt,
      createdAt: createdAt,
      updatedAt: createdAt,
      itemName: itemName,
      isArchived: isArchived,
    );
  }

  test('invalid localDay is Left and does not query', () async {
    final result = await useCase.execute(localDay: '15-08-2026');

    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    expect(result.getLeft().toNullable()?.code, 'invalid_local_day');
    verifyNever(
      () => repository.getCreatedOnLocalDay(
        any(),
        now: any(named: 'now'),
      ),
    );
  });

  test('empty day is Right with zero counts', () async {
    when(
      () => repository.getCreatedOnLocalDay(
        '2026-08-15',
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async => const Right([]));

    final result = await useCase.execute(localDay: '2026-08-15');
    final summary = result.getRight().toNullable()!;

    expect(summary.localDay, '2026-08-15');
    expect(summary.debtCount, 0);
    expect(summary.paymentCount, 0);
    expect(summary.totals, isEmpty);
  });

  test('includes quick-add and integer multi-currency totals', () async {
    final created = DateTime.utc(2026, 8, 15, 8);
    when(
      () => repository.getCreatedOnLocalDay(
        '2026-08-15',
        now: any(named: 'now'),
      ),
    ).thenAnswer(
      (_) async => Right([
        txn(
          id: 'quick-add',
          type: TransactionType.debt,
          amount: 1500,
          createdAt: created,
          itemName: 'خبز',
        ),
        txn(
          id: 'pay-yer',
          type: TransactionType.payment,
          amount: 200,
          createdAt: created,
        ),
        txn(
          id: 'debt-sar',
          type: TransactionType.debt,
          amount: 1050,
          createdAt: created,
          currency: 'SAR',
        ),
        txn(
          id: 'archived',
          type: TransactionType.debt,
          amount: 9999,
          createdAt: created,
          isArchived: true,
        ),
      ]),
    );

    final result = await useCase.execute(localDay: '2026-08-15');
    final summary = result.getRight().toNullable()!;

    expect(summary.debtCount, 2);
    expect(summary.paymentCount, 1);
    expect(summary.totals, hasLength(2));
    expect(summary.totals[0].currencyCode, 'SAR');
    expect(summary.totals[0].debtMinor, 1050);
    expect(summary.totals[0].paymentMinor, 0);
    expect(summary.totals[1].currencyCode, 'YER');
    expect(summary.totals[1].debtMinor, 1500);
    expect(summary.totals[1].paymentMinor, 200);
  });
}
