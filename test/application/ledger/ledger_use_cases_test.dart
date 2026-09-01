import 'dart:async';

import 'package:daftar/application/ledger/create_ledger_use_case.dart';
import 'package:daftar/application/ledger/delete_ledger_use_case.dart';
import 'package:daftar/application/ledger/get_ledgers_use_case.dart';
import 'package:daftar/application/ledger/restore_ledger_use_case.dart';
import 'package:daftar/application/ledger/update_ledger_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  late MockLedgerRepository repository;
  late MockActivationRepository activationRepository;

  setUpAll(() {
    registerFallbackValue(
      const CreateLedgerParams(
        name: 'Fallback Ledger',
        type: LedgerType.custom,
        icon: 'folder',
        color: '#000000',
      ),
    );
    registerFallbackValue(
      const UpdateLedgerParams(
        id: 'fallback-ledger-id',
      ),
    );
    registerFallbackValue(
      Ledger(
        id: 'fallback-ledger-id',
        name: 'Fallback Ledger',
        type: LedgerType.custom,
        icon: 'folder',
        color: '#000000',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      ),
    );
  });

  setUp(() {
    repository = MockLedgerRepository();
    activationRepository = MockActivationRepository();
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => Entitlement.defaultFree(),
    );
  });

  CreateLedgerUseCase buildCreateLedgerUseCase() => CreateLedgerUseCase(
    repository,
    activationRepository,
  );

  group('CreateLedgerUseCase', () {
    test('returns success and forwards normalized params', () async {
      final useCase = buildCreateLedgerUseCase();
      final createdLedger = Ledger(
        id: 'ledger-1',
        name: 'حسابات المتجر',
        type: LedgerType.custom,
        icon: 'store',
        color: '#1565C0',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      );

      when(() => repository.getActiveCount()).thenAnswer((_) async => const Right(0));
      when(
        () => repository.create(any<CreateLedgerParams>()),
      ).thenAnswer((_) async => Right(createdLedger));

      final result = await useCase.execute(
        name: '  حسابات المتجر  ',
        type: LedgerType.custom,
        icon: 'store ',
        color: 0xFF1565C0,
      );

      final ledger = await expectRight(result);
      expect(ledger, createdLedger);

      verify(() => repository.getActiveCount()).called(1);
      final captured =
          verify(
                () => repository.create(captureAny<CreateLedgerParams>()),
              ).captured.single
              as CreateLedgerParams;
      expect(captured.name, 'حسابات المتجر');
      expect(captured.type, LedgerType.custom);
      expect(captured.icon, 'store');
      expect(captured.color, '#1565C0');
    });

    test('returns validation failure for empty name', () async {
      final useCase = buildCreateLedgerUseCase();

      final result = await useCase.execute(
        name: '   ',
        type: LedgerType.custom,
        icon: 'store',
        color: 0xFF1565C0,
      );

      final failure = await expectLeft(result);
      expect(failure, isA<ValidationFailure>());
      verifyNever(() => repository.getActiveCount());
      verifyNever(() => repository.create(any<CreateLedgerParams>()));
    });

    test('returns limit exceeded failure when free limit is reached', () async {
      final useCase = buildCreateLedgerUseCase();

      when(
        () => repository.getActiveCount(),
      ).thenAnswer((_) async => const Right(AppConstants.maxFreeLedgers));

      final result = await useCase.execute(
        name: 'حسابات إضافية',
        type: LedgerType.custom,
        icon: 'folder',
        color: 0xFF424242,
      );

      final failure = await expectLeft(result);
      expect(failure, isA<LimitExceededFailure>());
      final limitFailure = failure as LimitExceededFailure;
      expect(limitFailure.featureKey, AppConstants.featureUnlimitedLedgers);
      expect(limitFailure.currentCount, AppConstants.maxFreeLedgers);
      expect(limitFailure.maxAllowed, AppConstants.maxFreeLedgers);
      verify(() => repository.getActiveCount()).called(1);
      verifyNever(() => repository.create(any<CreateLedgerParams>()));
    });

    test('returns database failure when the count query fails', () async {
      final useCase = buildCreateLedgerUseCase();

      when(
        () => repository.getActiveCount(),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('count failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        name: 'حسابات إضافية',
        type: LedgerType.custom,
        icon: 'folder',
        color: 0xFF424242,
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());

      verify(() => repository.getActiveCount()).called(1);
      verifyNever(() => repository.create(any<CreateLedgerParams>()));
    });
  });

  group('GetLedgersUseCase', () {
    test('returns repository stream', () async {
      final useCase = GetLedgersUseCase(repository);
      final ledger = Ledger(
        id: 'ledger-1',
        name: 'حسابات المتجر',
        type: LedgerType.custom,
        icon: 'store',
        color: '#1565C0',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      );

      when(
        () => repository.watchAll(),
      ).thenAnswer((_) => Stream.value([ledger]));

      await expectLater(useCase.execute(), emits([ledger]));
      verify(() => repository.watchAll()).called(1);
    });
  });

  group('UpdateLedgerUseCase', () {
    test('updates the ledger successfully', () async {
      final useCase = UpdateLedgerUseCase(repository);
      final inputLedger = Ledger(
        id: 'ledger-1',
        name: '  حسابات المتجر الرئيسية  ',
        type: LedgerType.custom,
        icon: 'storefront',
        color: '#0D47A1',
        sortOrder: 7,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      );
      final updatedLedger = inputLedger.copyWith(
        name: 'حسابات المتجر الرئيسية',
        updatedAt: DateTime.utc(2026, 2, 5),
        syncVersion: 1,
      );

      when(
        () => repository.getById(inputLedger.id),
      ).thenAnswer((_) async => Right(inputLedger));
      when(
        () => repository.update(any<UpdateLedgerParams>()),
      ).thenAnswer((_) async => Right(updatedLedger));

      final result = await useCase.execute(inputLedger);

      final ledger = await expectRight(result);
      expect(ledger, updatedLedger);

      final captured =
          verify(
                () => repository.update(captureAny<UpdateLedgerParams>()),
              ).captured.single
              as UpdateLedgerParams;
      expect(captured.id, inputLedger.id);
      expect(captured.name, 'حسابات المتجر الرئيسية');
      expect(captured.icon, 'storefront');
      expect(captured.color, '#0D47A1');
      expect(captured.sortOrder, 7);
    });
  });

  group('DeleteLedgerUseCase', () {
    test('soft-deletes the ledger after loading it', () async {
      final useCase = DeleteLedgerUseCase(repository);
      final existingLedger = Ledger(
        id: 'ledger-1',
        name: 'حسابات المتجر',
        type: LedgerType.custom,
        icon: 'store',
        color: '#1565C0',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      );

      when(
        () => repository.getById(existingLedger.id),
      ).thenAnswer((_) async => Right(existingLedger));
      when(
        () => repository.delete(existingLedger.id),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase.execute(existingLedger.id);

      final deletedLedger = await expectRight(result);
      expect(deletedLedger.id, existingLedger.id);
      expect(deletedLedger.isDeleted, isTrue);
      expect(deletedLedger.syncVersion, existingLedger.syncVersion + 1);
      expect(deletedLedger.updatedAt.isAfter(existingLedger.updatedAt), isTrue);

      verify(() => repository.getById(existingLedger.id)).called(1);
      verify(() => repository.delete(existingLedger.id)).called(1);
    });
  });

  group('RestoreLedgerUseCase', () {
    test('restores the ledger through the repository', () async {
      final useCase = RestoreLedgerUseCase(repository);
      final restoredLedger = Ledger(
        id: 'ledger-1',
        name: 'حسابات المتجر',
        type: LedgerType.custom,
        icon: 'store',
        color: '#1565C0',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 5),
        syncVersion: 2,
      );

      when(
        () => repository.restore(restoredLedger.id),
      ).thenAnswer((_) async => Right(restoredLedger));

      final result = await useCase.execute(restoredLedger.id);

      final ledger = await expectRight(result);
      expect(ledger, restoredLedger);

      verify(() => repository.restore(restoredLedger.id)).called(1);
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
