# Daftar — Copilot Instructions

> Offline-first Flutter app replacing paper ledgers for MENA merchants. Arabic-first RTL. Debt tracking with multi-currency, WhatsApp PDF reports, credit limits, encrypted backup.

## CRITICAL INVARIANTS

1. **Offline-First** — every feature works with zero connectivity.
2. **Arabic-First RTL** — Arabic is the default locale. RTL is not an afterthought.
3. **Integer Money** — ALL monetary amounts are `int` (smallest currency unit). NEVER `double`/`num`/`Decimal`/`String`.
4. **Financial Integrity** — ACID transactions, audit logging, soft deletes. Zero tolerance for data loss.

## TECH STACK

| Use | NEVER Use |
|---|---|
| **Riverpod 2.x** + `riverpod_generator` | Bloc, Provider, GetX, MobX |
| **Drift** (SQLite) | Isar, Hive, Floor, sqflite, SharedPreferences (domain data) |
| go_router | auto_route, Navigator 1.0 |
| **fpdart** (`Either<Failure, T>`) | dartz |
| Freezed + `freezed_annotation` | manual data classes |
| Dio + Retrofit | `http` package |
| Riverpod (DI container) | get_it, injectable |
| flutter_secure_storage (secrets) | Drift DB for secrets |
| ARB files + slang | hardcoded strings |
| Supabase (Storage + Auth) | Firebase for data storage |
| Firebase Analytics + Crashlytics | — |
| `int` for money | `double`, `num`, `Decimal` |

## ARCHITECTURE — Clean Architecture (4 Layers)

```
Presentation → Application → Domain ← Data
```

| Layer | Purpose | Can Import | NEVER Import |
|---|---|---|---|
| `lib/domain/` | Entities, value objects, enums, repo interfaces, failures | `dart:core`, equatable, freezed_annotation, fpdart | Flutter, Drift, Riverpod, data/, presentation/ |
| `lib/application/` | Use cases (one class, one `call()` method) | domain/ only | Flutter, Drift, data/, presentation/ |
| `lib/data/` | Drift tables, mappers, data sources, repo impls | domain/ (interfaces), Drift, Dio | presentation/, application/ |
| `lib/presentation/` | Providers, screens, widgets | domain/, application/, Riverpod, Flutter | Drift directly, data/ directly |

**Providers call Use Cases — NEVER call repositories directly.**

## MONEY RULES

- `1500` = 15.00 YER, `350` = 3.50 SAR, `100` = 1.00 USD.
- Use `Money` value object from `lib/domain/value_objects/money.dart`.
- Display conversion: `Currency.decimalPlaces` converts `int` → display string.
- Cross-currency operations are FORBIDDEN.

## ERROR HANDLING

```
Data:         catch Exception → return Left(Failure)
Application:  receive Either → apply rules → return Either (NO try/catch)
Presentation: .fold() or pattern match → show localized UI feedback
```

- Sealed `Failure` class: `DatabaseFailure`, `ValidationFailure`, `NetworkFailure`, `StorageFailure`, `AuthFailure`, `LimitExceededFailure`.
- Raw exceptions NEVER cross layer boundaries.
- All user-facing error messages use ARB localization keys.

## DRIFT DATABASE

- Every table: `id` (UUID v4 text), `createdAt`, `updatedAt`, `isDeleted` (default false), `syncVersion` (default 0).
- No auto-increment. UUID v4 for all PKs.
- All monetary columns: `IntColumn`. NEVER `RealColumn`.
- Multi-table writes MUST use `database.transaction(() async { ... })`.
- Every WHERE/ORDER BY/JOIN column MUST be indexed.
- List queries: `LIMIT/OFFSET` pagination (default 20).
- Use `watch()` for reactive streams, never polling.
- Migrations: explicit step-by-step (`from1To2`, `from2To3`). Never destructive.
- Seed currencies (YER, SAR, USD) on first launch.
- FTS5 for Arabic contact search. Normalize before index/query: strip diacritics → أإآ→ا → ة→ه.

## RIVERPOD

- `@riverpod` annotation (codegen) for ALL providers. Never manual.
- `AsyncNotifier` for CRUD mutations.
- `StreamProvider` for Drift reactive streams.
- `FutureProvider` for one-shot reads.
- Family providers for parameterized data.
- After mutation, streaming providers auto-update. Use `ref.invalidate()` only for non-streaming.
- Providers expose `AsyncValue<T>` → UI uses `.when(loading:, data:, error:)`.

## USE CASES

- One class, one `call()` method, return `Future<Either<Failure, T>>`.
- Constructor injection of repository interfaces.
- NO try/catch — operate on `Either` values from repositories.
- Free-tier enforcement HERE (not UI, not data layer).

## FREE-TIER LIMITS

| Resource | Free | Premium |
|---|---|---|
| Ledgers | 1 | Unlimited |
| Contacts | 50 | Unlimited |
| Transactions | 500 | Unlimited |

- Check in use cases. Return `LimitExceededFailure(featureKey, currentCount, maxAllowed)`.
- 80% threshold warnings (e.g., 40/50 contacts).

## ENTITIES (Freezed)

- `@freezed` with named parameters. Include: `id`, `createdAt`, `updatedAt`, `isDeleted`, `syncVersion`.
- No `toJson()` in domain — serialization is data layer's job.
- Immutable. Use `copyWith()`. Collections are unmodifiable views.

## MAPPERS

- `toDomain()` / `toCompanion()` as extension methods (not stateful classes).
- Round-trip safe: entity → companion → entity = identical.
- Unit test every mapper.

## FILE CONVENTIONS

| Element | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `create_ledger_use_case.dart` |
| Classes | `PascalCase` | `CreateLedgerUseCase` |
| Constants | `camelCase` | `maxFreeContacts` |
| Drift tables | Plural | `Ledgers`, `Contacts` |
| Tests | `{file}_test.dart` | `money_test.dart` |

- Absolute imports only: `import 'package:daftar/...';`
- No relative imports. No barrel files.
- Order: dart: → flutter → packages → daftar (blank line between groups).

## TESTING

- mocktail (NOT mockito). Mock at repository boundary.
- In-memory Drift DB for integration tests.
- Arrange-Act-Assert. Name `sut` for system under test.
- Test both `Right` (success) and `Left` (failure) paths.
- Coverage: domain/application ≥ 90%, mappers = 100%, repos ≥ 80%.

## LOCALIZATION & RTL

- Arabic (`ar`) is the DEFAULT locale.
- All strings: ARB keys. Zero hardcoded strings.
- All layouts must render correctly in RTL.
- Arabic normalization: strip diacritics (U+064B–U+065F) → أإآٱ→ا → ة→ه → trim whitespace.
- Store original + normalized. FTS5 indexes normalized. Display shows original.
- Typography: Noto Kufi Arabic + Inter. Tap targets ≥ 48dp.

## PERFORMANCE

- PDF/CSV/backup encryption → `Isolate.run()`. Any computation > 16ms → isolate.
- `ListView.builder` for dynamic lists (never `ListView(children:)`).
- `const` constructors. `RepaintBoundary` for expensive subtrees.
- Skeleton loading (shimmer) for async data. Never blank screens.
- Cold start < 2s. Local ops < 100ms. Scroll 60fps. APK < 30MB.

## SECURITY

- PIN: SHA-256 + 16-byte salt in `flutter_secure_storage` ONLY.
- Backup: AES-256. Encrypt BEFORE cloud upload.
- NEVER log monetary amounts, names, or phone numbers.
- NEVER store secrets in Drift DB or SharedPreferences.
- Respect `analyticsEnabled` flag.

## SCHEMA PRINCIPLES

1. Integer money. 2. UUID v4 PKs. 3. Soft deletes (`isDeleted`). 4. Sync-ready (`syncVersion`, `updatedAt`). 5. Denormalized `ContactBalance` (atomically updated). 6. Audit log on every write. 7. Multi-table writes in `transaction()`. 8. Indexed query columns. 9. UTC timestamps.

## DOCUMENTATION

- All public APIs: `///` dartdoc. Document failure modes for use cases.
- Use cases: list every `Failure` subtype and trigger condition.
- Repository interfaces: document behavioral contracts.

## HARD BANS — QUICK REFERENCE

| ❌ NEVER | ✅ ALWAYS |
|---|---|
| `double` for money | `int` (smallest unit) |
| Drift in domain layer | Pure Dart in domain |
| Repository from provider | Use case from provider |
| Isar, Hive, sqflite | Drift only |
| Hardcoded Arabic strings | ARB keys |
| Auto-increment IDs | UUID v4 |
| Hard delete | Soft delete (`isDeleted`) |
| `dartz` | `fpdart` |
| Throwing across layers | `Left(Failure)` via Either |
| Manual providers | `@riverpod` codegen |
| Relative imports | `package:daftar/...` |
| `ListView(children:)` | `ListView.builder()` |
| CPU work on main thread | `Isolate.run()` |
| Secrets in Drift | `flutter_secure_storage` |
| Multi-table write without txn | `database.transaction()` |
