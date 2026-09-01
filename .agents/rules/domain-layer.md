---
trigger: always_on
description: Rules for the pure-Dart domain layer — entities, value objects, enums, repository interfaces, and failures.
globs:
  - "**/domain/**/*.dart"
  - "**/core/errors/**/*.dart"
---

# Domain Layer Standards

<layer_boundary>
The domain layer has ZERO dependencies on Flutter, Drift, Riverpod, or any external package.

PERMITTED IMPORTS:
- dart:core (implicit)
- package:equatable/equatable.dart
- package:freezed_annotation/freezed_annotation.dart
- package:fpdart/fpdart.dart (for Either type definition only)

FORBIDDEN IMPORTS — if you see any of these in a domain file, it is a critical defect:
- package:flutter/*
- package:drift/*
- package:riverpod/*
- package:dio/*
- package:go_router/*
- Any import from lib/data/ or lib/presentation/
</layer_boundary>

## Entities — Freezed Immutable Data Classes

<entity_rules>
- Use @freezed annotation on all domain entities.
- All fields use named parameters in the factory constructor.
- Domain entities do NOT have toJson() — serialization is the data layer's responsibility.
- fromJson() factory only if needed for deserialization at the domain boundary.
- Use copyWith() for modifications — never mutate fields directly.
- Collections returned from any method are unmodifiable views.

Every mutable entity MUST include these fields:
- id (String, UUID v4)
- createdAt (DateTime)
- updatedAt (DateTime)
- isDeleted (bool, default false)
- syncVersion (int, default 0)
</entity_rules>

<entity_template>
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger.freezed.dart';

/// Represents a merchant's debt ledger grouping contacts by category.
///
/// Ledgers are the top-level organizational unit. Each contact belongs
/// to exactly one ledger. Free-tier users are limited to 1 ledger.
@freezed
class Ledger with _$Ledger {
  const factory Ledger({
    required String id,
    required String name,
    required LedgerType type,
    required String icon,
    required String color,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isDeleted,
    @Default(0) int syncVersion,
  }) = _Ledger;
}
```
</entity_template>

## Value Objects — Self-Validating Types

<value_object_rules>
Value objects encapsulate domain validation and business logic:
- Money: amount as int + currencyCode. Arithmetic ops, display formatting via Currency.decimalPlaces.
- PhoneNumber: validation, normalization, WhatsApp deep-link generation.

Value objects are immutable. Factory constructors validate on creation.
Invalid state should be impossible to represent.
</value_object_rules>

## Repository Interfaces — Abstract Contracts

<repository_rules>
- Repository interfaces are abstract classes in lib/domain/repositories/.
- They define the data contract — what operations exist, NOT how they are implemented.
- Return types use Either<Failure, T> for fallible operations.
- Stream return types for reactive queries (watchAll, watchByLedger).
- Interfaces are cohesive — split by aggregate root, never create "God repositories."
- Document behavioral contracts in dartdoc: expected failures, soft-delete filtering, audit log requirements.
</repository_rules>

<repository_template>
```dart
/// Contract for ledger persistence operations.
///
/// Implementations must:
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Exclude soft-deleted records from query results unless specified.
/// - Append to [AuditLog] on every write operation.
abstract class LedgerRepository {
  /// Streams all non-deleted ledgers ordered by [sortOrder].
  Stream<List<Ledger>> watchAll();

  /// Returns a ledger by [id], or [Left(DatabaseFailure)] if not found.
  Future<Either<Failure, Ledger>> getById(String id);

  /// Creates a new ledger. Returns the created entity.
  Future<Either<Failure, Ledger>> create(CreateLedgerParams params);

  /// Soft-deletes a ledger and cascades to child contacts.
  Future<Either<Failure, Unit>> delete(String id);

  /// Returns the count of active (non-deleted) ledgers.
  Future<int> getActiveCount();
}
```
</repository_template>

## Failure Hierarchy — Sealed Error Types

<failure_rules>
All errors in the domain are represented by a sealed Failure class in lib/core/errors/failures.dart:

```dart
sealed class Failure {
  final String message;
  final String? code;
  const Failure(this.message, {this.code});
}

final class DatabaseFailure extends Failure { ... }
final class ValidationFailure extends Failure { ... }
final class NetworkFailure extends Failure { ... }
final class StorageFailure extends Failure { ... }
final class AuthFailure extends Failure { ... }
final class LimitExceededFailure extends Failure {
  final String featureKey;
  final int currentCount;
  final int maxAllowed;
  ...
}
```

Rules:
- Use sealed class + final subclasses for exhaustive pattern matching.
- Raw exceptions MUST NEVER exist in the domain layer — only Failure types.
- Every failure carries a human-readable message (for localization) and optional machine-readable code.
</failure_rules>

## Enums

<enum_rules>
- LedgerType: customers, suppliers, personal, custom
- TransactionType: debt, payment
- BackupType: local, cloud
- PascalCase for the enum type, camelCase for values.
- Use exhaustive switch expressions when matching on enums.
</enum_rules>

## Documentation Requirements

<dartdoc>
All public APIs in the domain layer MUST have /// dartdoc comments:
- Entities: Document the business meaning of each field.
- Value Objects: Document validation rules and invariants.
- Repository Interfaces: Document behavioral contracts, expected failures, and filtering behavior.
- Enums: Document what each value represents in business terms.
- Failures: Document when each failure type is expected to occur.
</dartdoc>
