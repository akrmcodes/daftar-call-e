import 'package:daftar/application/ledger/get_ledger_balance_summary_use_case.dart';
import 'package:daftar/application/ledger/watch_ledger_balance_summary_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockBalanceRepository extends Mock implements BalanceRepository {}

void main() {
  final now = DateTime.utc(2026, 6);

  Ledger testLedger() {
    return Ledger(
      id: 'ledger-1',
      name: 'Main',
      type: LedgerType.custom,
      icon: 'folder',
      color: '#000000',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  Contact testContact(String id) {
    return Contact(
      id: id,
      ledgerId: 'ledger-1',
      name: 'Contact $id',
      avatarColor: '#5C6BC0',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('GetLedgerBalanceSummaryUseCase', () {
    late MockLedgerRepository ledgerRepository;
    late MockContactRepository contactRepository;
    late MockBalanceRepository balanceRepository;
    late GetLedgerBalanceSummaryUseCase sut;

    setUp(() {
      ledgerRepository = MockLedgerRepository();
      contactRepository = MockContactRepository();
      balanceRepository = MockBalanceRepository();
      sut = GetLedgerBalanceSummaryUseCase(
        ledgerRepository,
        contactRepository,
        balanceRepository,
      );
    });

    test('returns ValidationFailure when ledger id is empty', () async {
      final result = await sut.execute('');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'ledger_id_required'),
        (_) => fail('expected failure'),
      );
    });

    test('returns empty list when ledger has no contacts', () async {
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(testLedger()),
      );
      when(() => contactRepository.getByLedger('ledger-1')).thenAnswer(
        (_) async => const Right(<Contact>[]),
      );

      final result = await sut.execute('ledger-1');

      expect(result, const Right<Failure, List<ContactBalance>>(<ContactBalance>[]));
    });

    test('aggregates balances across contacts by currency', () async {
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(testLedger()),
      );
      when(() => contactRepository.getByLedger('ledger-1')).thenAnswer(
        (_) async => Right([testContact('c-1'), testContact('c-2')]),
      );
      when(() => balanceRepository.getByContact('c-1')).thenAnswer(
        (_) async => Right([
          ContactBalance(
            contactId: 'c-1',
            currencyCode: 'YER',
            totalDebt: 100,
            totalPayment: 0,
            netBalance: 100,
            lastUpdatedAt: now,
          ),
        ]),
      );
      when(() => balanceRepository.getByContact('c-2')).thenAnswer(
        (_) async => Right([
          ContactBalance(
            contactId: 'c-2',
            currencyCode: 'YER',
            totalDebt: 200,
            totalPayment: 50,
            netBalance: 150,
            lastUpdatedAt: now,
          ),
        ]),
      );

      final result = await sut.execute('ledger-1');

      result.fold(
        (_) => fail('expected success'),
        (balances) {
          expect(balances, hasLength(1));
          expect(balances.single.netBalance, 250);
          expect(balances.single.contactId, 'ledger-1');
        },
      );
    });

    test('returns balance repository failure', () async {
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(testLedger()),
      );
      when(() => contactRepository.getByLedger('ledger-1')).thenAnswer(
        (_) async => Right([testContact('c-1')]),
      );
      when(() => balanceRepository.getByContact('c-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('balance read failed')),
      );

      final result = await sut.execute('ledger-1');

      expect(result.isLeft(), isTrue);
    });
  });

  group('WatchLedgerBalanceSummaryUseCase', () {
    late MockBalanceRepository balanceRepository;
    late WatchLedgerBalanceSummaryUseCase sut;

    setUp(() {
      balanceRepository = MockBalanceRepository();
      sut = WatchLedgerBalanceSummaryUseCase(balanceRepository);
    });

    test('returns empty stream for blank ledger id', () async {
      final values = await sut.execute('  ').toList();

      expect(values, [const <ContactBalance>[]]);
      verifyNever(() => balanceRepository.watchBalancesByLedger(any()));
    });

    test('aggregates streamed balances by currency', () async {
      when(() => balanceRepository.watchBalancesByLedger('ledger-1')).thenAnswer(
        (_) => Stream.value([
          ContactBalance(
            contactId: 'c-1',
            currencyCode: 'YER',
            totalDebt: 300,
            totalPayment: 100,
            netBalance: 200,
            lastUpdatedAt: now,
          ),
          ContactBalance(
            contactId: 'c-2',
            currencyCode: 'YER',
            totalDebt: 100,
            totalPayment: 0,
            netBalance: 100,
            lastUpdatedAt: now,
          ),
        ]),
      );

      final values = await sut.execute('ledger-1').toList();

      expect(values.single.single.netBalance, 300);
      expect(values.single.single.contactId, 'ledger-1');
    });
  });
}
