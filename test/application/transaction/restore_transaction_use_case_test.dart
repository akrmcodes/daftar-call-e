import 'dart:async';

import 'package:daftar/application/transaction/restore_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository transactionRepository;

  setUp(() {
    transactionRepository = MockTransactionRepository();
  });

  group('RestoreTransactionUseCase', () {
    test('returns success and forwards normalized id', () async {
      final useCase = RestoreTransactionUseCase(transactionRepository);

      when(
        () => transactionRepository.restoreTransaction('txn-1'),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase.execute(
        const RestoreTransactionParams(id: '  txn-1  '),
      );

      final value = await expectRight(result);
      expect(value, unit);

      verify(
        () => transactionRepository.restoreTransaction('txn-1'),
      ).called(1);
    });

    test('returns validation failure for empty id', () async {
      final useCase = RestoreTransactionUseCase(transactionRepository);

      final result = await useCase.execute(
        const RestoreTransactionParams(id: '   '),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<ValidationFailure>());
      verifyNever(() => transactionRepository.restoreTransaction(any()));
    });

    test('maps repository failure as-is', () async {
      final useCase = RestoreTransactionUseCase(transactionRepository);

      when(
        () => transactionRepository.restoreTransaction('txn-1'),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('restore failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        const RestoreTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verify(
        () => transactionRepository.restoreTransaction('txn-1'),
      ).called(1);
    });

    test('maps unexpected exceptions to DatabaseFailure', () async {
      final useCase = RestoreTransactionUseCase(transactionRepository);
      when(() => transactionRepository.restoreTransaction('txn-1')).thenThrow(
        Exception('unexpected'),
      );

      final result = await useCase.execute(
        const RestoreTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      expect(failure.code, 'database_error');
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
