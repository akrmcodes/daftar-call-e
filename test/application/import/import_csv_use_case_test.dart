import 'dart:convert';
import 'dart:typed_data';

import 'package:daftar/application/import/import_csv_use_case.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/duplicate_resolution_strategy.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/bulk_write_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/csv_bulk_persist_batch.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// These verify calls keep the required currency argument explicit in the
// import use-case signatures, so this file intentionally ignores the default
// value redundancy lint for those matcher-heavy expectations.
// ignore_for_file: avoid_redundant_argument_values

class MockContactRepository extends Mock implements ContactRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockBulkWriteRepository extends Mock implements BulkWriteRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

String buildExpectedCurrency() {
  final codeUnits = <int>[89, 69, 82];
  return codeUnits.map(String.fromCharCode).join();
}

CsvBulkPersistBatch expectPersistCalledOnce() {
  final captured =
      verify(() => bulkWriteRepository.persist(captureAny())).captured;
  expect(captured, hasLength(1));
  return captured.single as CsvBulkPersistBatch;
}

late MockContactRepository contactRepository;
late MockLedgerRepository ledgerRepository;
late MockTransactionRepository transactionRepository;
late MockBulkWriteRepository bulkWriteRepository;
late MockActivationRepository activationRepository;

const ledgerId = 'ledger-csv-1';

void stubDefaultImportDependencies() {
  when(() => contactRepository.getActiveCount()).thenAnswer(
    (_) async => const Right(0),
  );
  when(() => transactionRepository.getActiveCount()).thenAnswer(
    (_) async => const Right(0),
  );
  when(() => activationRepository.getEntitlement()).thenAnswer(
    (_) async => Entitlement.forPro(),
  );
  when(() => bulkWriteRepository.persist(any())).thenAnswer(
    (_) async => const Right(unit),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(LedgerType.custom);
    registerFallbackValue(TransactionType.debt);
    registerFallbackValue(DateTime.utc(2000));
    registerFallbackValue('');
    registerFallbackValue(const CsvBulkPersistBatch());
  });

  setUp(() {
    contactRepository = MockContactRepository();
    ledgerRepository = MockLedgerRepository();
    transactionRepository = MockTransactionRepository();
    bulkWriteRepository = MockBulkWriteRepository();
    activationRepository = MockActivationRepository();

    when(() => ledgerRepository.getById(ledgerId)).thenAnswer(
      (_) async => Right(
        Ledger(
          id: ledgerId,
          name: 'دفتر تجريبي',
          type: LedgerType.custom,
          icon: 'wallet',
          color: '#000000',
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 3, 2),
          updatedAt: DateTime.utc(2026, 3, 2),
        ),
      ),
    );
    stubDefaultImportDependencies();
  });

  ImportCsvUseCase buildSut() => ImportCsvUseCase(
    contactRepository: contactRepository,
    ledgerRepository: ledgerRepository,
    transactionRepository: transactionRepository,
    bulkWriteRepository: bulkWriteRepository,
    activationRepository: activationRepository,
  );

  group('ImportCsvUseCase', () {
    test('returns Left when a required column is missing', () async {
      when(
        () => contactRepository.getByLedger(ledgerId),
      ).thenAnswer((_) async => const Right(<Contact>[]));

      const csv =
          'Name,Amount,Type,Date\n'
          'أحمد,1000,debt,2026-01-10\n';
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(csv),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test(
      'imports UTF-8 BOM rows: creates contact then transaction',
      () async {
        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer((_) async => const Right(<Contact>[]));

        const header =
            '\uFEFFName,Phone,Amount,Type,Currency,Date,Description\r\n';
        const row = 'سلطان,+967 77 123 4567,1500,debt,YER,2026-01-15,"أرز"\r\n';
        final sut = buildSut();

        final result = await sut.execute(
          ledgerId: ledgerId,
          duplicateStrategy: DuplicateResolutionStrategy.merge,
          csvBytes: utf8.encode('$header$row'),
        );

        expect(result.isRight(), isTrue);

        final report = result.getRight().toNullable()!;
        expect(report.successCount, 1);
        expect(report.failureCount, 0);
        expect(report.totalRows, 1);

        final batch = expectPersistCalledOnce();
        expect(batch.contacts, hasLength(1));
        final contact = batch.contacts.single;
        expect(contact.ledgerId, ledgerId);
        expect(contact.name, 'سلطان');
        expect(contact.phone, '967771234567');
        expect(batch.transactions, hasLength(1));
        final transaction = batch.transactions.single;
        expect(transaction.contactId, contact.id);
        expect(transaction.type, TransactionType.debt);
        expect(transaction.amount, 1500);
        expect(transaction.currency, DbConstants.currencyYer);
        expect(transaction.description, 'أرز');
        expect(transaction.transactionDate, DateTime.utc(2026, 1, 15));
      },
    );

    test('records malformed amount rows without aborting sibling rows', () async {
      final existing = Contact(
        id: 'contact-existing',
        ledgerId: ledgerId,
        name: 'خليل',
        phone: '967700000003',
        avatarColor: '#26A69A',
        createdAt: DateTime.utc(2026, 1, 10),
        updatedAt: DateTime.utc(2026, 1, 10),
      );

      when(
        () => contactRepository.getByLedger(ledgerId),
      ).thenAnswer((_) async => Right(<Contact>[existing]));

      const csv =
          'Name,Phone,Amount,Type,Currency,Date\r\n'
          'خليل,967700000003,2٬٥٠٠,debt,YER,01/03/2026\r\n'
          'خليل,967700000003,INVALID,debt,YER,02/03/2026\r\n';

      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(csv),
      );

      expect(result.isRight(), isTrue);
      final summary = result.getRight().toNullable()!;
      expect(summary.successCount, 1);
      expect(summary.failureCount, 1);
      expect(summary.errors.first, contains('invalid'));

      final batch = expectPersistCalledOnce();
      expect(batch.contacts, isEmpty);
      expect(batch.transactions, hasLength(1));
      final transaction = batch.transactions.single;
      expect(transaction.contactId, existing.id);
      expect(transaction.type, TransactionType.debt);
      expect(transaction.amount, 2500);
      expect(transaction.currency, DbConstants.currencyYer);

      /// Locks the Gregorian day implied by DD/MM precedence on `01/03/2026`.
      expect(transaction.transactionDate, DateTime.utc(2026, 3, 1));
    });

    test(
      'decodes Windows-1256 bytes before structural parsing succeeds',
      () async {
        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer((_) async => const Right(<Contact>[]));

        const encoder = Windows1256Encoder();
        const rows =
            'Name,Amount,Type,Currency,Date,Phone\r\n'
            'رياض,500,له,YER,2026-02-02,967711111112\r\n';
        final bytes = Uint8List.fromList(encoder.convert(rows));

        final sut = buildSut();

        final result = await sut.execute(
          ledgerId: ledgerId,
          duplicateStrategy: DuplicateResolutionStrategy.merge,
          csvBytes: bytes,
        );

        expect(result.isRight(), isTrue);

        final batch = expectPersistCalledOnce();
        expect(batch.contacts.single.name, 'رياض');
        expect(batch.contacts.single.phone, '967711111112');
        expect(batch.transactions.single.type, TransactionType.payment);
        expect(batch.transactions.single.amount, 500);
      },
    );

    test(
      'imports rows using explicit columnIndicesByCanonicalField when '
      'headers lack synonyms',
      () async {
        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer((_) async => const Right(<Contact>[]));

        const csv =
            'H1,H2,H3,H4,H5,H6\n'
            'Samir,1500,debt,YER,2026-03-01,memo note\n';

        final sut = buildSut();

        final result = await sut.execute(
          ledgerId: ledgerId,
          duplicateStrategy: DuplicateResolutionStrategy.merge,
          csvBytes: utf8.encode(csv),
          columnIndicesByCanonicalField: const {
            CsvImportColumn.nameKey: 0,
            CsvImportColumn.amountKey: 1,
            CsvImportColumn.typeKey: 2,
            CsvImportColumn.currencyKey: 3,
            CsvImportColumn.dateKey: 4,
            CsvImportColumn.descriptionKey: 5,
          },
        );

        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable()!.successCount, 1);

        final batch = expectPersistCalledOnce();
        expect(batch.contacts.single.name, 'Samir');
        expect(batch.transactions.single.amount, 1500);
        expect(batch.transactions.single.description, 'memo note');
      },
    );

    test(
      'manual column map passes itemName to add transaction use case',
      () async {
        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer((_) async => const Right(<Contact>[]));

        const csv =
            'H1,H2,H3,H4,H5,H6,H7\n'
            'Fatima,2000,debt,YER,2026-03-01,,سكر\n';

        final sut = buildSut();

        final result = await sut.execute(
          ledgerId: ledgerId,
          duplicateStrategy: DuplicateResolutionStrategy.merge,
          csvBytes: utf8.encode(csv),
          columnIndicesByCanonicalField: const {
            CsvImportColumn.nameKey: 0,
            CsvImportColumn.amountKey: 1,
            CsvImportColumn.typeKey: 2,
            CsvImportColumn.currencyKey: 3,
            CsvImportColumn.dateKey: 4,
            CsvImportColumn.descriptionKey: 5,
            CsvImportColumn.itemNameKey: 6,
          },
        );

        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable()!.successCount, 1);

        final batch = expectPersistCalledOnce();
        final contact = batch.contacts.single;
        final transaction = batch.transactions.single;
        expect(transaction.contactId, contact.id);
        expect(transaction.type, TransactionType.debt);
        expect(transaction.amount, 2000);
        expect(transaction.currency, DbConstants.currencyYer);
        expect(transaction.description, isNull);
        expect(transaction.itemName, 'سكر');
        expect(transaction.transactionDate, DateTime.utc(2026, 3, 1));
      },
    );

    test(
      'fails ambiguous duplicate names unless phone disambiguates',
      () async {
        final ambiguousA = Contact(
          id: 'dup-a',
          ledgerId: ledgerId,
          name: 'سامي حسن',
          avatarColor: '#000000',
          createdAt: DateTime.utc(2026, 3, 21),
          updatedAt: DateTime.utc(2026, 1, 12),
        );

        final ambiguousB = Contact(
          id: 'dup-b',
          ledgerId: ledgerId,
          name: 'سامي حسن',
          avatarColor: '#FFFFFF',
          createdAt: DateTime.utc(2026, 1, 2),
          updatedAt: DateTime.utc(2026, 1, 13),
        );

        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer((_) async => Right(<Contact>[ambiguousA, ambiguousB]));

        const csv =
            'Name,Amount,Type,Currency,Date\r\n'
            'سامي حسن,1000,debt,YER,2026-03-01\r\n';

        final sut = buildSut();
        final result = await sut.execute(
          ledgerId: ledgerId,
          duplicateStrategy: DuplicateResolutionStrategy.merge,
          csvBytes: utf8.encode(csv),
        );

        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable()!.failureCount, 1);
        verifyNever(() => bulkWriteRepository.persist(any()));
      },
    );

    test(
      'analyzeImport counts mixed new and duplicate contacts without DB writes',
      () async {
        final duplicateByPhone = Contact(
          id: 'analyze-dup-phone',
          ledgerId: ledgerId,
          name: 'خليل',
          phone: '967700000003',
          avatarColor: '#26A69A',
          createdAt: DateTime.utc(2026, 1, 10),
          updatedAt: DateTime.utc(2026, 1, 10),
        );

        final duplicateByName = Contact(
          id: 'analyze-dup-name',
          ledgerId: ledgerId,
          name: 'سامي حسن',
          avatarColor: '#8E24AA',
          createdAt: DateTime.utc(2026, 1, 12),
          updatedAt: DateTime.utc(2026, 1, 12),
        );

        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer(
          (_) async => Right(<Contact>[duplicateByPhone, duplicateByName]),
        );

        const csv =
            'Name,Phone,Amount,Type,Currency,Date\r\n'
            'خليل,967700000003,2500,debt,YER,2026-03-01\r\n'
            'خليل,967700000003,4000,debt,YER,2026-03-02\r\n'
            'سامي حسن,,800,debt,YER,2026-03-03\r\n'
            'فاتورة Apple 15 Pro,967711111111,1250,debt,YER,2026-03-04\r\n'
            'فاتورة Apple 15 Pro,967711111111,2250,debt,YER,2026-03-05\r\n';

        final sut = buildSut();
        final outcome = await sut.analyzeImport(
          ledgerId: ledgerId,
          csvBytes: utf8.encode(csv),
        );

        expect(outcome.isRight(), isTrue);
        final summary = outcome.getRight().toNullable()!;
        expect(summary.duplicateContactsCount, 2);
        expect(summary.newContactsCount, 1);
        expect(summary.validRowsCount, 5);

        verifyZeroInteractions(bulkWriteRepository);
      },
    );

    test(
      'duplicateResolutionStrategy skip keeps fresh rows and skips matched rows',
      () async {
        final expectedCurrency = buildExpectedCurrency();

        final duplicateByPhone = Contact(
          id: 'skip-dup-phone',
          ledgerId: ledgerId,
          name: 'خليل',
          phone: '967700000003',
          avatarColor: '#26A69A',
          createdAt: DateTime.utc(2026, 1, 10),
          updatedAt: DateTime.utc(2026, 1, 10),
        );

        final duplicateByName = Contact(
          id: 'skip-dup-name',
          ledgerId: ledgerId,
          name: 'سامي حسن',
          avatarColor: '#8E24AA',
          createdAt: DateTime.utc(2026, 1, 12),
          updatedAt: DateTime.utc(2026, 1, 12),
        );

        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer(
          (_) async => Right(<Contact>[duplicateByPhone, duplicateByName]),
        );

        const csv =
            'Name,Phone,Amount,Type,Currency,Date\r\n'
            'خليل,967700000003,2500,debt,YER,2026-03-01\r\n'
            'سامي حسن,,800,debt,YER,2026-03-02\r\n'
            'فاتورة Apple 15 Pro,967711111111,1250,debt,YER,2026-03-03\r\n';

        final sut = buildSut();
        final result = await sut.execute(
          ledgerId: ledgerId,
          csvBytes: utf8.encode(csv),
          duplicateStrategy: DuplicateResolutionStrategy.skip,
        );

        expect(result.isRight(), isTrue);
        final summary = result.getRight().toNullable()!;
        expect(summary.successCount, 1);
        expect(summary.skippedDuplicateRows, 2);
        expect(summary.failureCount, 0);

        final batch = expectPersistCalledOnce();
        expect(batch.contacts, hasLength(1));
        expect(batch.contacts.single.name, 'فاتورة Apple 15 Pro');
        expect(batch.contacts.single.phone, '967711111111');
        expect(batch.transactions, hasLength(1));
        final transaction = batch.transactions.single;
        expect(transaction.contactId, batch.contacts.single.id);
        expect(transaction.type, TransactionType.debt);
        expect(transaction.amount, 1250);
        expect(transaction.currency, expectedCurrency);
        expect(transaction.transactionDate, DateTime.utc(2026, 3, 3));
        expect(
          batch.transactions.map((txn) => txn.contactId),
          isNot(contains(duplicateByPhone.id)),
        );
        expect(
          batch.transactions.map((txn) => txn.contactId),
          isNot(contains(duplicateByName.id)),
        );
      },
    );

    test(
      'duplicateResolutionStrategy merge posts transactions onto existing and fresh contacts',
      () async {
        final expectedCurrency = buildExpectedCurrency();

        final duplicateByPhone = Contact(
          id: 'merge-dup-phone',
          ledgerId: ledgerId,
          name: 'خليل',
          phone: '967700000003',
          avatarColor: '#26A69A',
          createdAt: DateTime.utc(2026, 1, 10),
          updatedAt: DateTime.utc(2026, 1, 10),
        );

        final duplicateByName = Contact(
          id: 'merge-dup-name',
          ledgerId: ledgerId,
          name: 'سامي حسن',
          avatarColor: '#8E24AA',
          createdAt: DateTime.utc(2026, 1, 12),
          updatedAt: DateTime.utc(2026, 1, 12),
        );

        when(
          () => contactRepository.getByLedger(ledgerId),
        ).thenAnswer(
          (_) async => Right(<Contact>[duplicateByPhone, duplicateByName]),
        );

        const csv =
            'Name,Phone,Amount,Type,Currency,Date\r\n'
            'خليل,967700000003,2500,debt,YER,2026-03-01\r\n'
            'سامي حسن,,800,debt,YER,2026-03-02\r\n'
            'فاتورة Apple 15 Pro,967711111111,1250,debt,YER,2026-03-03\r\n';

        final sut = buildSut();
        final result = await sut.execute(
          ledgerId: ledgerId,
          csvBytes: utf8.encode(csv),
          duplicateStrategy: DuplicateResolutionStrategy.merge,
        );

        expect(result.isRight(), isTrue);
        final summary = result.getRight().toNullable()!;
        expect(summary.successCount, 3);
        expect(summary.skippedDuplicateRows, 0);
        expect(summary.failureCount, 0);

        final batch = expectPersistCalledOnce();
        expect(batch.contacts, hasLength(1));
        expect(batch.contacts.single.name, 'فاتورة Apple 15 Pro');
        expect(batch.contacts.single.phone, '967711111111');
        expect(batch.transactions, hasLength(3));

        final byContactId = {
          for (final txn in batch.transactions) txn.contactId: txn,
        };
        expect(byContactId[duplicateByPhone.id]!.amount, 2500);
        expect(
          byContactId[duplicateByPhone.id]!.transactionDate,
          DateTime.utc(2026, 3, 1),
        );
        expect(byContactId[duplicateByName.id]!.amount, 800);
        expect(
          byContactId[duplicateByName.id]!.transactionDate,
          DateTime.utc(2026, 3, 2),
        );
        final newContactTxn = byContactId[batch.contacts.single.id]!;
        expect(newContactTxn.amount, 1250);
        expect(newContactTxn.currency, expectedCurrency);
        expect(newContactTxn.transactionDate, DateTime.utc(2026, 3, 3));
      },
    );

    test('returns ValidationFailure when ledger id is empty', () async {
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: '  ',
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode('Name,Amount,Type,Currency,Date\n'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'csv_import_ledger_missing'),
        (_) => fail('expected failure'),
      );
    });

    test('returns ValidationFailure when both csvBytes and csvPath are provided', () async {
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode('Name,Amount,Type,Currency,Date\n'),
        csvPath: '/tmp/import.csv',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'csv_import_source_exclusive'),
        (_) => fail('expected failure'),
      );
    });

    test('returns ValidationFailure when neither csv source is provided', () async {
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'csv_import_source_exclusive'),
        (_) => fail('expected failure'),
      );
    });

    test('returns ledger repository failure during prepare', () async {
      when(() => ledgerRepository.getById(ledgerId)).thenAnswer(
        (_) async => const Left(DatabaseFailure('ledger missing')),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(
          'Name,Amount,Type,Currency,Date\n'
          'Ali,1000,debt,YER,2026-01-10\n',
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('returns contact repository failure during prepare', () async {
      when(() => contactRepository.getByLedger(ledgerId)).thenAnswer(
        (_) async => const Left(DatabaseFailure('contacts failed')),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(
          'Name,Amount,Type,Currency,Date\n'
          'Ali,1000,debt,YER,2026-01-10\n',
        ),
      );

      expect(result.isLeft(), isTrue);
    });

    test('records row error when createContact returns ValidationFailure', () async {
      when(() => contactRepository.getByLedger(ledgerId)).thenAnswer(
        (_) async => const Right(<Contact>[]),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(
          'Name,Amount,Type,Currency,Date\n'
          ',1000,debt,YER,2026-01-10\n',
        ),
      );

      expect(result.isRight(), isTrue);
      final summary = result.getRight().toNullable()!;
      expect(summary.successCount, 0);
      expect(summary.failureCount, 1);
      verifyNever(() => bulkWriteRepository.persist(any()));
    });

    test('records row error when addTransaction fails for fresh contact', () async {
      when(() => contactRepository.getByLedger(ledgerId)).thenAnswer(
        (_) async => const Right(<Contact>[]),
      );
      when(() => bulkWriteRepository.persist(any())).thenAnswer(
        (_) async => const Left(DatabaseFailure('txn write failed')),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(
          'Name,Amount,Type,Currency,Date\n'
          'Ali,1000,debt,YER,2026-01-10\n',
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<DatabaseFailure>()),
        (_) => fail('expected failure'),
      );
      verify(() => bulkWriteRepository.persist(any())).called(1);
    });

    test('retries archived contact creation after LimitExceededFailure', () async {
      when(() => contactRepository.getByLedger(ledgerId)).thenAnswer(
        (_) async => const Right(<Contact>[]),
      );
      when(() => contactRepository.getActiveCount()).thenAnswer(
        (_) async => const Right(50),
      );
      when(() => activationRepository.getEntitlement()).thenAnswer(
        (_) async => Entitlement.defaultFree(),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(
          'Name,Amount,Type,Currency,Date\n'
          'Ali,1000,debt,YER,2026-01-10\n',
        ),
      );

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.successCount, 1);

      final batch = expectPersistCalledOnce();
      expect(batch.contacts, hasLength(1));
      expect(batch.contacts.single.name, 'Ali');
      expect(batch.contacts.single.isArchived, isTrue);
      expect(batch.transactions, hasLength(1));
      expect(batch.transactions.single.isArchived, isTrue);
    });

    test('returns ValidationFailure for unusable CSV structure', () async {
      when(() => contactRepository.getByLedger(ledgerId)).thenAnswer(
        (_) async => const Right(<Contact>[]),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode(''),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('returns ValidationFailure for invalid manual column map', () async {
      when(() => contactRepository.getByLedger(ledgerId)).thenAnswer(
        (_) async => const Right(<Contact>[]),
      );
      final sut = buildSut();

      final result = await sut.execute(
        ledgerId: ledgerId,
        duplicateStrategy: DuplicateResolutionStrategy.merge,
        csvBytes: utf8.encode('H1,H2\nAli,1000\n'),
        columnIndicesByCanonicalField: const {
          CsvImportColumn.nameKey: 0,
          CsvImportColumn.amountKey: 99,
          CsvImportColumn.typeKey: 1,
          CsvImportColumn.currencyKey: 1,
          CsvImportColumn.dateKey: 1,
        },
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'csv_import_manual_map_invalid_amount'),
        (_) => fail('expected failure'),
      );
    });

    test('analyzeImport returns ValidationFailure when ledger id is empty', () async {
      final sut = buildSut();

      final result = await sut.analyzeImport(
        ledgerId: '  ',
        csvBytes: utf8.encode('Name,Amount,Type,Currency,Date\n'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'csv_import_ledger_missing'),
        (_) => fail('expected failure'),
      );
    });
  });
}
