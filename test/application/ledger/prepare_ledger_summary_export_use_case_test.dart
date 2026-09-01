import 'package:daftar/application/ledger/prepare_ledger_summary_export_use_case.dart';
import 'package:daftar/application/ledger/select_contact_net_balance.dart';
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
  late MockLedgerRepository ledgerRepository;
  late MockContactRepository contactRepository;
  late MockBalanceRepository balanceRepository;
  late PrepareLedgerSummaryExportUseCase sut;

  final now = DateTime.utc(2026, 6);

  Ledger testLedger() {
    return Ledger(
      id: 'ledger-1',
      name: 'حسابات',
      type: LedgerType.custom,
      icon: 'folder',
      color: '#000000',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  Contact contact({
    required String id,
    required String name,
    String? phone,
    String? creditCurrency,
  }) {
    return Contact(
      id: id,
      ledgerId: 'ledger-1',
      name: name,
      phone: phone,
      creditCurrency: creditCurrency,
      avatarColor: '#5C6BC0',
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    ledgerRepository = MockLedgerRepository();
    contactRepository = MockContactRepository();
    balanceRepository = MockBalanceRepository();
    sut = PrepareLedgerSummaryExportUseCase(
      ledgerRepository,
      contactRepository,
      balanceRepository,
    );
  });

  group('PrepareLedgerSummaryExportUseCase', () {
    test('returns ValidationFailure when ledger id is empty', () async {
      final result = await sut.execute('   ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(failure.code, 'ledger_id_required');
        },
        (_) => fail('expected failure'),
      );
    });

    test('returns ledger repository failure', () async {
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('ledger missing')),
      );

      final result = await sut.execute('ledger-1');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('returns contact repository failure', () async {
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(testLedger()),
      );
      when(() => contactRepository.getByLedger('ledger-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('contacts failed')),
      );

      final result = await sut.execute('ledger-1');

      expect(result.isLeft(), isTrue);
    });

    test('returns balance repository failure for a contact', () async {
      final contacts = [contact(id: 'c-1', name: 'بدر')];
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(testLedger()),
      );
      when(() => contactRepository.getByLedger('ledger-1')).thenAnswer(
        (_) async => Right(contacts),
      );
      when(() => balanceRepository.getByContact('c-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('balance failed')),
      );

      final result = await sut.execute('ledger-1');

      expect(result.isLeft(), isTrue);
    });

    test('returns sorted contacts with aggregated ledger totals', () async {
      final contacts = [
        contact(id: 'c-2', name: 'ياسر', phone: '  '),
        contact(id: 'c-1', name: 'أحمد', phone: '+967712345678', creditCurrency: 'yer'),
      ];
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(testLedger()),
      );
      when(() => contactRepository.getByLedger('ledger-1')).thenAnswer(
        (_) async => Right(contacts),
      );
      when(() => balanceRepository.getByContact('c-1')).thenAnswer(
        (_) async => Right([
          ContactBalance(
            contactId: 'c-1',
            currencyCode: 'YER',
            totalDebt: 1000,
            totalPayment: 200,
            netBalance: 800,
            lastUpdatedAt: now,
          ),
        ]),
      );
      when(() => balanceRepository.getByContact('c-2')).thenAnswer(
        (_) async => Right([
          ContactBalance(
            contactId: 'c-2',
            currencyCode: 'YER',
            totalDebt: 500,
            totalPayment: 0,
            netBalance: 500,
            lastUpdatedAt: now,
          ),
        ]),
      );

      final result = await sut.execute('ledger-1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected success'),
        (data) {
          expect(data.ledgerName, 'حسابات');
          expect(data.contacts.map((row) => row.name), ['أحمد', 'ياسر']);
          expect(data.contacts.first.netBalance, 800);
          expect(data.contacts.first.phone, '+967712345678');
          expect(data.contacts.last.phone, isNull);
          expect(data.ledgerTotals.single.netBalance, 1300);
        },
      );
    });
  });

  group('selectContactNetBalance', () {
    test('returns zero for empty balances', () {
      final c = contact(id: 'c-1', name: 'Ali');

      expect(selectContactNetBalance(c, const []), 0);
      expect(selectContactDisplayCurrency(c, const []), '');
    });

    test('prefers credit currency when set', () {
      final c = contact(id: 'c-1', name: 'Ali', creditCurrency: 'usd');
      final balances = [
        ContactBalance(
          contactId: 'c-1',
          currencyCode: 'YER',
          totalDebt: 100,
          totalPayment: 0,
          netBalance: 100,
          lastUpdatedAt: now,
        ),
        ContactBalance(
          contactId: 'c-1',
          currencyCode: 'USD',
          totalDebt: 50,
          totalPayment: 0,
          netBalance: 50,
          lastUpdatedAt: now,
        ),
      ];

      expect(selectContactNetBalance(c, balances), 50);
      expect(selectContactDisplayCurrency(c, balances), 'USD');
    });
  });
}
