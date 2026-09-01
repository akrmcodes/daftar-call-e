---
trigger: always_on
description: Rules for the application layer — use cases, business logic orchestration, error handling flow, and free-tier enforcement.
globs:
  - "**/application/**/*.dart"
---

# Application Layer Standards

<layer_boundary>
The application layer contains use cases (interactors) that orchestrate business logic.

PERMITTED IMPORTS:
- Everything in lib/domain/ (entities, enums, value objects, repository interfaces, failures)
- dart:core, dart:async
- package:fpdart/fpdart.dart

FORBIDDEN IMPORTS — critical defect if present:
- package:flutter/*
- package:drift/*
- package:riverpod/*
- Any import from lib/data/
- Any import from lib/presentation/
</layer_boundary>

## Use Case Design

<use_case_rules>
1. One class, one responsibility, one public method: call() or execute().
2. Return type: Future<Either<Failure, T>> using fpdart. NEVER throw exceptions.
3. Constructor injection of repository interfaces (dependency inversion).
4. Use cases MUST NOT use try/catch — they operate on Either values received from repositories.
5. All validation logic lives here — input validation, business rule enforcement, limit checks.
6. Free-tier enforcement happens HERE — not in UI, not in data layer.
</use_case_rules>

<use_case_template>
```dart
import 'package:fpdart/fpdart.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';

/// Creates a new ledger after validating business rules.
///
/// Enforces: non-empty name, uniqueness, free-tier limit.
///
/// Returns [Right<Ledger>] on success, or [Left<Failure>]:
/// - [ValidationFailure] if name is empty or duplicate.
/// - [LimitExceededFailure] if free-tier limit reached.
/// - [DatabaseFailure] if persistence fails.
class CreateLedgerUseCase {
  final LedgerRepository _ledgerRepository;
  final ActivationRepository _activationRepository;

  const CreateLedgerUseCase(this._ledgerRepository, this._activationRepository);

  Future<Either<Failure, Ledger>> call(CreateLedgerParams params) async {
    // 1. Validate input
    if (params.name.trim().isEmpty) {
      return Left(ValidationFailure('Ledger name cannot be empty'));
    }

    // 2. Check free-tier limit
    final isPremium = await _activationRepository.isFeatureUnlocked('unlimitedLedgers');
    if (!isPremium) {
      final count = await _ledgerRepository.getActiveCount();
      if (count >= AppConstants.maxFreeLedgers) {
        return Left(LimitExceededFailure(
          'Ledger limit reached',
          featureKey: 'unlimitedLedgers',
          currentCount: count,
          maxAllowed: AppConstants.maxFreeLedgers,
        ));
      }
    }

    // 3. Create and persist
    return _ledgerRepository.create(params);
  }
}
```
</use_case_template>

## Error Handling Flow

<error_flow>
The error flow across the full architecture is:

Data Layer:    catch Exception → map to Failure → return Left(Failure)
Application:   receive Either<Failure, T> → apply business rules → return Either<Failure, T>
Presentation:  receive Either<Failure, T> → fold() → show UI feedback

In the application layer specifically:
- You receive Either values from repository calls.
- Chain operations using flatMap(), map(), or manual fold().
- Return Left(Failure) for all error conditions — never throw.
- Right(value) for success paths.
- Use pattern matching with switch on sealed Failure types when business logic depends on failure type.
</error_flow>

## Free-Tier Enforcement

<free_tier>
Limits (RAD-003):
| Resource | Free Limit | Premium |
|---|---|---|
| Ledgers | 1 | Unlimited |
| Contacts (total) | 50 | Unlimited |
| Transactions (total) | 500 | Unlimited |

Enforcement rules:
1. Limits are checked in use cases ONLY — never in UI or Data layer.
2. On limit breach, return LimitExceededFailure with featureKey, currentCount, and maxAllowed.
3. Premium status is queried via ActivationRepository.isFeatureUnlocked(featureKey).
4. Premium feature flags: unlimitedLedgers, unlimitedContacts, unlimitedTransactions, cloudBackup, csvImport, creditLimits, whatsappAutomation.
5. Display approaching-limit warnings at 80% threshold (e.g., 40/50 contacts).
</free_tier>

## Chain-of-Thought Protocol

<complex_logic>
When implementing complex business logic in use cases, follow this protocol:

1. State the intent in a brief inline comment: // Algorithm: recalculate contact balance from raw transactions
2. List the steps as numbered comments before writing implementation code.
3. Implement each step directly below its comment.
4. Document edge cases as comments: // Edge case: no transactions exist → balance is zero

This applies to:
- Transaction balance recalculation
- Credit limit checking logic
- Backup encryption/decryption orchestration
- CSV column mapping and import logic
- Multi-step validation chains
</complex_logic>

## Documentation Requirements

<dartdoc>
All use cases MUST have comprehensive /// dartdoc:
- Class-level: Describe what the use case does, what business rules it enforces.
- Method-level: Document preconditions, postconditions, and all possible failure modes.
- List every Failure subtype that can be returned and the condition that triggers it.

Example format:
/// Returns [Right<Ledger>] on success, or [Left<Failure>]:
/// - [ValidationFailure] if name is empty or duplicate.
/// - [LimitExceededFailure] if free-tier limit reached.
/// - [DatabaseFailure] if persistence fails.
</dartdoc>
