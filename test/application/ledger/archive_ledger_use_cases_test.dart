import 'dart:async';

import 'package:daftar/application/ledger/archive_ledger_use_case.dart';
import 'package:daftar/application/ledger/unarchive_ledger_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:daftar/domain/value_objects/carry_forward_result.dart';
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

  setUpAll(() {
    registerFallbackValue(
      const ArchiveWithCarryForwardParams(
        sourceLedgerId: 'fallback-source',
        targetLedgerId: 'fallback-target',
        operationId: 'fallback-op',
        openingBalanceItemName: 'fallback-item',
        openingBalanceDescription: 'fallback-desc',
      ),
    );
    registerFallbackValue(
      Ledger(
        id: 'fallback-ledger',
        name: 'Fallback',
        type: LedgerType.custom,
        icon: 'folder',
        color: '#000000',
        sortOrder: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
  });

  setUp(() {
    ledgerRepository = MockLedgerRepository();
    contactRepository = MockContactRepository();
    transactionRepository = MockTransactionRepository();
    activationRepository = MockActivationRepository();
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => Entitlement.defaultFree(),
    );
  });

  ArchiveLedgerUseCase buildArchiveUseCase() => ArchiveLedgerUseCase(
    ledgerRepository,
    contactRepository,
    transactionRepository,
    activationRepository,
  );

  UnarchiveLedgerUseCase buildUnarchiveUseCase() => UnarchiveLedgerUseCase(
    ledgerRepository,
    activationRepository,
  );

  Ledger liveLedger(String id, {String name = 'Live Ledger'}) => Ledger(
    id: id,
    name: name,
    type: LedgerType.custom,
    icon: 'folder',
    color: '#424242',
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 3),
    updatedAt: DateTime.utc(2026, 3, 2),
  );

  Ledger archivedLedger(String id) => Ledger(
    id: id,
    name: 'Archived Ledger',
    type: LedgerType.custom,
    icon: 'archive',
    color: '#424242',
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 3),
    updatedAt: DateTime.utc(2026, 3, 2),
    isUserArchived: true,
  );

  const carryForwardPreview = CarryForwardPreview(
    contactCount: 2,
    transactionCount: 2,
    totalsByCurrency: {'YER': -1500},
    sourceLedgerName: 'Source',
    targetLedgerName: 'Target',
  );

  void stubCarryForwardPreflight({
    required String sourceId,
    required String targetId,
    CarryForwardPreview preview = carryForwardPreview,
    int activeContacts = 0,
    int activeTransactions = 0,
  }) {
    when(() => ledgerRepository.getById(sourceId)).thenAnswer(
      (_) async => Right(liveLedger(sourceId, name: 'Source')),
    );
    when(() => ledgerRepository.getById(targetId)).thenAnswer(
      (_) async => Right(liveLedger(targetId, name: 'Target')),
    );
    when(
      () => ledgerRepository.previewCarryForward(
        sourceLedgerId: sourceId,
        targetLedgerId: targetId,
      ),
    ).thenAnswer((_) async => Right(preview));
    when(
      () => contactRepository.getActiveCount(),
    ).thenAnswer((_) async => Right(activeContacts));
    when(
      () => transactionRepository.getActiveCount(),
    ).thenAnswer((_) async => Right(activeTransactions));
  }

  group('ArchiveLedgerUseCase', () {
    test('returns tier lock when ledgerArchiving is locked', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => false);

      final failure = await expectLeft(
        buildArchiveUseCase().execute(ledgerId: 'ledger-1'),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(failure.code, 'ledger_archiving_tier_locked');
      verifyNever(() => ledgerRepository.archiveLedger(any()));
      verifyNever(() => ledgerRepository.archiveWithCarryForward(any()));
    });

    test('archives without carry-forward when params are null', () async {
      const ledgerId = 'ledger-1';
      final ledger = archivedLedger(ledgerId);

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      when(
        () => ledgerRepository.archiveLedger(ledgerId),
      ).thenAnswer((_) async => Right(ledger));

      final result = await expectRight(
        buildArchiveUseCase().execute(ledgerId: ledgerId),
      );

      expect(result, ledger);
      verify(() => ledgerRepository.archiveLedger(ledgerId)).called(1);
      verifyNever(() => ledgerRepository.archiveWithCarryForward(any()));
    });

    test('returns carry_forward_source_mismatch when ids differ', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);

      final failure = await expectLeft(
        buildArchiveUseCase().execute(
          ledgerId: 'ledger-1',
          carryForward: const ArchiveWithCarryForwardParams(
            sourceLedgerId: 'ledger-2',
            targetLedgerId: 'target-1',
            operationId: 'op-1',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'carry_forward_source_mismatch');
      verifyNever(() => ledgerRepository.archiveWithCarryForward(any()));
    });

    test('returns no_balances_to_carry when preview contactCount is zero',
        () async {
      const ledgerId = 'ledger-1';
      const targetId = 'target-1';
      const carryForward = ArchiveWithCarryForwardParams(
        sourceLedgerId: ledgerId,
        targetLedgerId: targetId,
        operationId: 'op-1',
        openingBalanceItemName: 'رصيد افتتاحي',
        openingBalanceDescription: 'ترحيل من المصدر',
      );

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      stubCarryForwardPreflight(
        sourceId: ledgerId,
        targetId: targetId,
        preview: const CarryForwardPreview(
          contactCount: 0,
          transactionCount: 0,
          totalsByCurrency: {},
          sourceLedgerName: 'Source',
          targetLedgerName: 'Target',
        ),
      );

      final failure = await expectLeft(
        buildArchiveUseCase().execute(
          ledgerId: ledgerId,
          carryForward: carryForward,
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'no_balances_to_carry');
      verifyNever(() => ledgerRepository.archiveWithCarryForward(any()));
    });

    test('returns contact limit failure when rollover exceeds capacity', () async {
      const ledgerId = 'ledger-1';
      const targetId = 'target-1';
      const carryForward = ArchiveWithCarryForwardParams(
        sourceLedgerId: ledgerId,
        targetLedgerId: targetId,
        operationId: 'op-1',
        openingBalanceItemName: 'رصيد افتتاحي',
        openingBalanceDescription: 'ترحيل من المصدر',
      );

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      stubCarryForwardPreflight(
        sourceId: ledgerId,
        targetId: targetId,
        preview: const CarryForwardPreview(
          contactCount: 3,
          transactionCount: 3,
          totalsByCurrency: {'YER': -300},
          sourceLedgerName: 'Source',
          targetLedgerName: 'Target',
        ),
        activeContacts: 49,
      );

      final failure = await expectLeft(
        buildArchiveUseCase().execute(
          ledgerId: ledgerId,
          carryForward: carryForward,
        ),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(
        (failure as LimitExceededFailure).featureKey,
        AppConstants.featureUnlimitedContacts,
      );
      verifyNever(() => ledgerRepository.archiveWithCarryForward(any()));
    });

    test('returns transaction limit failure when rollover exceeds capacity',
        () async {
      const ledgerId = 'ledger-1';
      const targetId = 'target-1';
      const carryForward = ArchiveWithCarryForwardParams(
        sourceLedgerId: ledgerId,
        targetLedgerId: targetId,
        operationId: 'op-1',
        openingBalanceItemName: 'رصيد افتتاحي',
        openingBalanceDescription: 'ترحيل من المصدر',
      );

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      stubCarryForwardPreflight(
        sourceId: ledgerId,
        targetId: targetId,
        preview: const CarryForwardPreview(
          contactCount: 1,
          transactionCount: 2,
          totalsByCurrency: {'YER': -100},
          sourceLedgerName: 'Source',
          targetLedgerName: 'Target',
        ),
        activeTransactions: 499,
      );

      final failure = await expectLeft(
        buildArchiveUseCase().execute(
          ledgerId: ledgerId,
          carryForward: carryForward,
        ),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(
        (failure as LimitExceededFailure).featureKey,
        AppConstants.featureUnlimitedTransactions,
      );
      verifyNever(() => ledgerRepository.archiveWithCarryForward(any()));
    });

    test('delegates to archiveWithCarryForward and returns archived ledger',
        () async {
      const ledgerId = 'ledger-1';
      const targetId = 'target-1';
      final ledger = archivedLedger(ledgerId);
      const carryForward = ArchiveWithCarryForwardParams(
        sourceLedgerId: ledgerId,
        targetLedgerId: targetId,
        operationId: 'op-1',
        openingBalanceItemName: 'رصيد افتتاحي',
        openingBalanceDescription: 'ترحيل من المصدر',
      );

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      stubCarryForwardPreflight(sourceId: ledgerId, targetId: targetId);
      when(
        () => ledgerRepository.archiveWithCarryForward(carryForward),
      ).thenAnswer(
        (_) async => Right(
          CarryForwardResult(
            archivedLedger: ledger,
            contactsCreated: 2,
            transactionsCreated: 2,
            targetLedgerId: targetId,
          ),
        ),
      );

      final result = await expectRight(
        buildArchiveUseCase().execute(
          ledgerId: ledgerId,
          carryForward: carryForward,
        ),
      );

      expect(result, ledger);
      verify(() => ledgerRepository.archiveWithCarryForward(carryForward)).called(1);
    });

    test('returns ledger_id_required for empty id', () async {
      final failure = await expectLeft(
        buildArchiveUseCase().execute(ledgerId: '   '),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'ledger_id_required');
      verifyNever(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      );
    });
  });

  group('UnarchiveLedgerUseCase', () {
    test('returns tier lock when ledgerArchiving is locked', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => false);

      final failure = await expectLeft(
        buildUnarchiveUseCase().execute('ledger-1'),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(failure.code, 'ledger_archiving_tier_locked');
      verifyNever(() => ledgerRepository.unarchiveLedger(any()));
    });

    test('unarchives when tier is unlocked', () async {
      const ledgerId = 'ledger-1';
      final ledger = Ledger(
        id: ledgerId,
        name: 'Restored',
        type: LedgerType.custom,
        icon: 'folder',
        color: '#424242',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 3),
        updatedAt: DateTime.utc(2026, 3, 3),
      );

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      when(
        () => ledgerRepository.unarchiveLedger(ledgerId),
      ).thenAnswer((_) async => Right(ledger));

      final result = await expectRight(
        buildUnarchiveUseCase().execute(ledgerId),
      );

      expect(result, ledger);
      verify(() => ledgerRepository.unarchiveLedger(ledgerId)).called(1);
    });
  });
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> resultOrFuture) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}

Future<Failure> expectLeft<T>(
  FutureOr<Either<Failure, T>> resultOrFuture,
) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected Left but got Right($value)'),
  );
}
