import 'dart:async';

import 'package:daftar/application/transaction/get_autocomplete_suggestions_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/item_suggestion.dart';
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

  group('GetAutocompleteSuggestionsUseCase', () {
    test('trims the query and returns repository suggestions', () async {
      final useCase = GetAutocompleteSuggestionsUseCase(transactionRepository);
      final suggestions = [
        const ItemSuggestion(itemName: 'Lamp', lastAmount: 5000),
        const ItemSuggestion(itemName: 'Laptop', lastAmount: 250000),
        const ItemSuggestion(itemName: 'Latte', lastAmount: 40),
      ];

      when(
        () => transactionRepository.searchRecentItems('la'),
      ).thenAnswer((_) async => Right(suggestions));

      final result = await useCase.execute(
        const GetAutocompleteSuggestionsParams(query: '  la  '),
      );

      final value = await expectRight(result);
      expect(value, suggestions);
      verify(
        () => transactionRepository.searchRecentItems('la'),
      ).called(1);
    });

    test('ignores very short queries', () async {
      final useCase = GetAutocompleteSuggestionsUseCase(transactionRepository);

      final result = await useCase.execute(
        const GetAutocompleteSuggestionsParams(query: ' a '),
      );

      final value = await expectRight(result);
      expect(value, isEmpty);
      verifyNever(() => transactionRepository.searchRecentItems(any()));
    });

    test('returns validation failure for invalid limit', () async {
      final useCase = GetAutocompleteSuggestionsUseCase(transactionRepository);

      final result = await useCase.execute(
        const GetAutocompleteSuggestionsParams(query: 'lamp', limit: 0),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<ValidationFailure>());
      verifyNever(() => transactionRepository.searchRecentItems(any()));
    });

    test('maps repository failure as-is', () async {
      final useCase = GetAutocompleteSuggestionsUseCase(transactionRepository);

      when(
        () => transactionRepository.searchRecentItems('lamp'),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('lookup failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        const GetAutocompleteSuggestionsParams(query: 'lamp'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verify(
        () => transactionRepository.searchRecentItems('lamp'),
      ).called(1);
    });

    test('returns empty suggestions for blank query', () async {
      final useCase = GetAutocompleteSuggestionsUseCase(transactionRepository);

      final result = await useCase.execute(
        const GetAutocompleteSuggestionsParams(query: '   '),
      );

      final value = await expectRight(result);
      expect(value, isEmpty);
      verifyNever(() => transactionRepository.searchRecentItems(any()));
    });

    test('maps unexpected exceptions to DatabaseFailure', () async {
      final useCase = GetAutocompleteSuggestionsUseCase(transactionRepository);
      when(() => transactionRepository.searchRecentItems('lamp')).thenThrow(
        Exception('lookup exploded'),
      );

      final result = await useCase.execute(
        const GetAutocompleteSuggestionsParams(query: 'lamp'),
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
