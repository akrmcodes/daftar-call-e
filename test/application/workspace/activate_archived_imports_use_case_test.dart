import 'package:daftar/application/workspace/activate_archived_imports_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  late MockLedgerRepository ledgerRepository;
  late MockContactRepository contactRepository;
  late MockTransactionRepository transactionRepository;
  late MockActivationRepository activationRepository;
  late ActivateArchivedImportsUseCase sut;

  setUp(() {
    ledgerRepository = MockLedgerRepository();
    contactRepository = MockContactRepository();
    transactionRepository = MockTransactionRepository();
    activationRepository = MockActivationRepository();
    sut = ActivateArchivedImportsUseCase(
      ledgerRepository,
      contactRepository,
      transactionRepository,
      activationRepository,
    );
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => Entitlement.defaultFree(),
    );
  });

  void stubCounts({
    int ledgerActive = 0,
    int ledgerArchived = 0,
    int contactActive = 0,
    int contactArchived = 0,
    int txnActive = 0,
    int txnArchived = 0,
  }) {
    when(() => ledgerRepository.getActiveCount()).thenAnswer(
      (_) async => Right(ledgerActive),
    );
    when(() => ledgerRepository.getArchivedCount()).thenAnswer(
      (_) async => Right(ledgerArchived),
    );
    when(() => contactRepository.getActiveCount()).thenAnswer(
      (_) async => Right(contactActive),
    );
    when(() => contactRepository.getArchivedCount()).thenAnswer(
      (_) async => Right(contactArchived),
    );
    when(() => transactionRepository.getActiveCount()).thenAnswer(
      (_) async => Right(txnActive),
    );
    when(() => transactionRepository.getArchivedCount()).thenAnswer(
      (_) async => Right(txnArchived),
    );
    when(
      () => ledgerRepository.promoteArchived(limit: any(named: 'limit')),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      return Right(limit);
    });
    when(
      () => contactRepository.promoteArchived(limit: any(named: 'limit')),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      return Right(limit);
    });
    when(
      () => transactionRepository.promoteArchived(limit: any(named: 'limit')),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      return Right(limit);
    });
  }

  group('ActivateArchivedImportsUseCase', () {
    test('returns DatabaseFailure when ledger active count fails', () async {
      when(() => ledgerRepository.getActiveCount()).thenAnswer(
        (_) async => const Left(DatabaseFailure('db error')),
      );

      final result = await sut.execute();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('returns DatabaseFailure when contact archived count fails', () async {
      when(() => ledgerRepository.getActiveCount()).thenAnswer(
        (_) async => const Right(0),
      );
      when(() => contactRepository.getActiveCount()).thenAnswer(
        (_) async => const Right(0),
      );
      when(() => transactionRepository.getActiveCount()).thenAnswer(
        (_) async => const Right(0),
      );
      when(() => ledgerRepository.getArchivedCount()).thenAnswer(
        (_) async => const Right(0),
      );
      when(() => contactRepository.getArchivedCount()).thenAnswer(
        (_) async => const Left(DatabaseFailure('archived contacts failed')),
      );

      final result = await sut.execute();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('halts at free-tier ledger cap with archived rows waiting', () async {
      stubCounts(ledgerActive: 1, ledgerArchived: 3);

      final result = await sut.execute();

      expect(result.isRight(), isTrue);
      final value = result.getRight().toNullable()!;
      expect(value.ledgersActivated, 0);
      expect(value.haltedByLimit, isTrue);
      verifyNever(
        () => ledgerRepository.promoteArchived(limit: any(named: 'limit')),
      );
    });

    test('promotes partial ledgers and sets haltedByLimit on free tier', () async {
      stubCounts(ledgerArchived: 3);

      final result = await sut.execute();

      expect(result.isRight(), isTrue);
      final value = result.getRight().toNullable()!;
      expect(value.ledgersActivated, 1);
      expect(value.haltedByLimit, isTrue);
      verify(
        () => ledgerRepository.promoteArchived(limit: 1),
      ).called(1);
    });

    test('promotes all archived rows on Pro tier', () async {
      when(() => activationRepository.getEntitlement()).thenAnswer(
        (_) async => Entitlement.forPro(),
      );
      stubCounts(
        ledgerActive: 2,
        ledgerArchived: 4,
        contactActive: 10,
        contactArchived: 5,
        txnActive: 100,
        txnArchived: 20,
      );

      final result = await sut.execute();

      expect(result.isRight(), isTrue);
      final value = result.getRight().toNullable()!;
      expect(value.ledgersActivated, 4);
      expect(value.contactsActivated, 5);
      expect(value.transactionsActivated, 20);
      expect(value.haltedByLimit, isFalse);
      expect(value.totalActivated, 29);
    });

    test('returns DatabaseFailure when ledger promotion fails', () async {
      stubCounts(ledgerArchived: 1);
      when(
        () => ledgerRepository.promoteArchived(limit: any(named: 'limit')),
      ).thenAnswer(
        (_) async => const Left(DatabaseFailure('promote failed')),
      );

      final result = await sut.execute();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (_) => fail('expected failure'),
      );
    });
  });
}
