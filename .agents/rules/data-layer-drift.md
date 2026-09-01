---
trigger: always_on
description: Rules for the data layer — Drift database, tables, migrations, FTS5 Arabic search, transactions, mappers, and repository implementations.
globs:
  - "**/data/**/*.dart"
  - "**/datasources/**/*.dart"
---

# Data Layer & Drift Database Standards

<layer_boundary>
The data layer implements domain repository interfaces. It contains Drift tables, data sources, mappers, and concrete repository implementations.

PERMITTED IMPORTS:
- lib/domain/ (interfaces, entities, enums, value objects, failures)
- package:drift/*
- package:dio/*, package:retrofit/*
- package:supabase_flutter/*
- package:fpdart/fpdart.dart
- package:path_provider/*, package:path/*
- dart:* libraries

FORBIDDEN IMPORTS — critical defect if present:
- lib/presentation/* — data layer must never know about UI
- lib/application/* — data layer must never know about use cases
- package:riverpod/* — providers are a presentation concern
- package:flutter/material.dart (except for required platform channel types)
</layer_boundary>

## Drift Table Definitions

<table_rules>
Every mutable Drift table MUST include these columns:

```dart
TextColumn get id => text()();         // UUID v4 primary key
DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
IntColumn get syncVersion => integer().withDefault(const Constant(0))();
```

Table naming:
- Table class names: Plural PascalCase (Ledgers, Contacts, Transactions)
- Generated row classes: Drift auto-generates singular forms
- Primary keys: UUID v4 stored as text(). No auto-increment ever.
- Foreign keys: defined with references(OtherTable, #id)
- All monetary columns: IntColumn (smallest currency unit). NEVER RealColumn for money.
</table_rules>

## Transaction Safety — CRITICAL

<transaction_safety>
Any operation that modifies more than one table MUST use a Drift transaction:

```dart
await database.transaction(() async {
  await insertTransaction(txn);
  await updateContactBalance(txn.contactId);
  await appendAuditLog(txn.id, 'CREATE');
});
```

Failure to wrap multi-table writes in a transaction is a CRITICAL DEFECT.
This is non-negotiable for financial data integrity.

Key scenarios requiring transactions:
- Adding a transaction → update ContactBalance + append AuditLog
- Deleting a contact → soft-delete contacts + soft-delete transactions + update balances
- Restoring a backup → replace multiple tables atomically
</transaction_safety>

## Query Performance

<query_rules>
1. Every column used in WHERE, ORDER BY, or JOIN conditions MUST have an explicit Drift index.
2. List queries MUST use LIMIT/OFFSET pagination (default page size: 20).
3. Use Drift's watch() for reactive streams — never manual polling.
4. Use SELECT projections — never SELECT * for large tables.
5. Use ContactBalance (denormalized) for O(1) balance reads — never aggregate from raw transactions at query time.
6. Profile queries on Samsung A03 (or equivalent low-end device).
</query_rules>

## FTS5 for Arabic Search

<fts5>
Contacts use an FTS5 virtual table for Arabic full-text search.

Normalization pipeline before indexing and querying:
Step 1: Strip all diacritics (تشكيل): remove Unicode range U+064B–U+065F
Step 2: Normalize Alef variants: أ إ آ ٱ → ا
Step 3: Normalize Taa Marbuta for search: ة → ه
Step 4: Trim and collapse whitespace

Storage: Both the original name and the normalized form are stored in the database.
FTS5 index uses the normalized form.
Display always uses the original form.
</fts5>

## Schema Migrations

<migrations>
- Every schema change increments the database version.
- Migrations are explicit step-by-step: from1To2, from2To3, etc.
- NEVER use destructive migration (onUpgrade: (db, oldV, newV) => db.deleteAll()).
- Always test migrations on existing data before shipping.
- Built-in currencies (YER, SAR, USD) are seeded on first launch in the migration step.
- Default AppSettings row is created on first launch.
</migrations>

## Mappers — Entity ↔ Drift Companion Converters

<mapper_rules>
Mappers live in lib/data/mappers/ and convert between:
- Drift-generated row objects → Domain entities (toDomain())
- Domain entities → Drift companion objects (toCompanion())

Rules:
- Mappers are extension methods or static functions — NOT classes with state.
- Every mapper must be round-trip safe: entity → companion → entity must produce identical data.
- Mappers are the ONLY place where Drift types and domain types coexist.
- All mapper conversions must handle nullable fields correctly.
- Write unit tests for every mapper verifying round-trip integrity.
</mapper_rules>

## Repository Implementations

<repo_impl_rules>
Repository implementations live in lib/data/repositories/ and implement domain interfaces.

Rules:
1. Catch ALL data-layer exceptions (DriftWrappedException, IOException, SocketException) inside the repository.
2. Map every caught exception to the appropriate Failure subtype.
3. Return Left(Failure) for errors, Right(value) for success — NEVER throw.
4. Append to AuditLog on every write operation (CREATE, UPDATE, DELETE).
5. All queries filter out soft-deleted records (WHERE isDeleted = false) unless explicitly requested.
6. Use Drift's transaction() for any multi-table operation.

Error mapping pattern:
```dart
Future<Either<Failure, Ledger>> create(CreateLedgerParams params) async {
  try {
    final companion = LedgerMapper.toCompanion(params);
    final result = await _localDS.insert(companion);
    await _auditLogDS.append(result.id, 'ledger', 'CREATE');
    return Right(LedgerMapper.toDomain(result));
  } on DriftWrappedException catch (e) {
    return Left(DatabaseFailure('Failed to create ledger: ${e.message}'));
  } catch (e) {
    return Left(DatabaseFailure('Unexpected error: ${e.toString()}'));
  }
}
```
</repo_impl_rules>

## Data Sources

<datasource_rules>
Local data sources (lib/data/datasources/local/):
- One data source class per aggregate root: LedgerLocalDS, ContactLocalDS, etc.
- Contains raw Drift query methods — SELECT, INSERT, UPDATE, DELETE.
- Exposes Stream<List<T>> via Drift watch() for reactive queries.
- No business logic — purely data access.

Remote data sources (lib/data/datasources/remote/):
- Supabase Storage for cloud backup upload/download.
- Supabase Auth for phone OTP authentication.
- Activation API for code validation.
- Use Dio + Retrofit for HTTP calls with interceptors for auth tokens and retry logic.
</datasource_rules>
