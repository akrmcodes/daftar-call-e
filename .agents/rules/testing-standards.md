---
trigger: always_on
description: Testing standards — coverage requirements, mocking strategy, test structure, and naming conventions for Dart tests.
globs:
  - "**/test/**/*.dart"
  - "**/*_test.dart"
---

# Testing Standards

<coverage_requirements>
## Minimum Coverage by Layer

| Layer | Minimum Coverage | Test Type |
|---|---|---|
| Domain (entities, value objects) | 90% | Unit tests |
| Application (use cases) | 90% | Unit tests (mocked repositories) |
| Data (mappers) | 100% | Unit tests (round-trip: entity → companion → entity) |
| Data (repositories) | 80% | Integration tests (in-memory Drift DB) |
| Presentation (critical widgets) | 70% | Widget tests |
| End-to-end flows | Key flows | Integration tests |
</coverage_requirements>

## Test File Organization

<file_naming>
- Test files mirror the lib/ structure under test/.
- File name: {source_file}_test.dart in the corresponding directory.
- Example: lib/domain/value_objects/money.dart → test/domain/value_objects/money_test.dart
- Keep test files focused — one test file per source file.
</file_naming>

## Mocking Strategy

<mocking>
- Use mocktail for mocking (NOT mockito).
- Mock at the repository interface boundary for use case tests.
- Use in-memory Drift database for data layer integration tests.
- Never mock the class under test.
- Use setUp() and tearDown() for test lifecycle management.
- Create mock classes as: class MockLedgerRepository extends Mock implements LedgerRepository {}
</mocking>

## Test Structure Template

<test_template>
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:daftar/application/ledger/create_ledger_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';

class MockLedgerRepository extends Mock implements LedgerRepository {}

void main() {
  group('CreateLedgerUseCase', () {
    late CreateLedgerUseCase sut; // System Under Test
    late MockLedgerRepository mockRepo;

    setUp(() {
      mockRepo = MockLedgerRepository();
      sut = CreateLedgerUseCase(mockRepo);
    });

    test('returns ValidationFailure when name is empty', () async {
      // Arrange — no mock setup needed for input validation

      // Act
      final result = await sut(CreateLedgerParams(name: ''));

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns LimitExceededFailure when free-tier limit reached', () async {
      // Arrange
      when(() => mockRepo.getActiveCount()).thenAnswer((_) async => 1);

      // Act
      final result = await sut(CreateLedgerParams(name: 'Test'));

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<LimitExceededFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
```
</test_template>

## Test Conventions

<conventions>
1. Use the Arrange-Act-Assert pattern for all tests.
2. Name test functions descriptively: 'returns X when Y' or 'throws X given Y'.
3. Use group() to organize tests by class or feature.
4. Use late for setUp() variables.
5. Name the system under test as sut (System Under Test).
6. Test both success (Right) and failure (Left) paths for every use case.
7. Test edge cases explicitly: empty inputs, zero amounts, maximum limits, null optional fields.
8. For Either results, always use fold() or isLeft()/isRight() — never force-unwrap.
</conventions>

## Critical Test Scenarios

<critical_tests>
These scenarios MUST have test coverage:

Domain:
- Money arithmetic: addition, subtraction, comparison across same currency
- Money edge cases: zero amount, maximum int values, different currencies (should fail)
- PhoneNumber normalization: Yemeni formats (+967), Saudi (+966), with/without country code
- Arabic text normalization: diacritics stripping, Alef/Taa Marbuta variants

Application:
- Free-tier limit enforcement at exact boundary (1/1 ledger, 50/50 contacts, 500/500 transactions)
- Credit limit warning at 80% and 100% thresholds
- Balance recalculation after transaction add/edit/delete

Data:
- Mapper round-trip integrity for every entity
- CRUD lifecycle: Ledger → Contact → Transaction → Balance verification
- Backup create → restore → data integrity check
- FTS5 Arabic search with normalized queries

Presentation:
- Balance card displays correctly with zero, positive, and negative balances
- Transaction sheet validates input before submission
- Lock screen handles PIN validation and biometric fallback
</critical_tests>
