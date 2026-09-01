---
trigger: always_on
description: Cross-cutting quality standards — security, localization, Arabic text processing, performance targets, coding standards, and SOLID principles.
globs:
  - "**/*.dart"
---

# Quality & Cross-Cutting Standards

<coding_standards>
## Dart Language Features — Mandatory Usage
- Null safety: All types non-nullable by default. Use ? only when a value can genuinely be absent.
- Pattern matching: Use switch expressions with exhaustive patterns on sealed classes and enums.
- Sealed classes: Use for domain failure types, entity types with variant behavior.
- Records: Use for returning multiple values where a named type is overkill.
- Collection literals: Prefer [], {}, <>() over constructor calls.
</coding_standards>

<solid_principles>
## SOLID Principles — Enforced

| Principle | Rule |
|---|---|
| Single Responsibility | One class = one reason to change. Use cases: one public method. Providers: one data concern. |
| Open/Closed | Extend via new classes (new use case, new failure type), not by modifying existing ones. |
| Liskov Substitution | Repository implementations fully substitutable for interfaces in tests. |
| Interface Segregation | Repository interfaces are cohesive — split by aggregate root, no God repositories. |
| Dependency Inversion | All layer boundaries program against abstractions (interfaces), never concretions. |

## Immutability
- Domain entities are ALWAYS immutable (Freezed).
- Use copyWith() for modifications — never mutate fields.
- Collections returned from repositories are unmodifiable views.
</solid_principles>

<documentation>
## Documentation — Dartdoc Requirements
All public APIs MUST have /// dartdoc comments:

```dart
/// Creates a new ledger for the authenticated user.
///
/// Validates [name] is non-empty and unique. Enforces the free-tier limit
/// of [AppConstants.maxFreeLedgers] ledgers for non-premium users.
///
/// Returns [Right<Ledger>] on success, or [Left<Failure>]:
/// - [ValidationFailure] if name is empty or duplicate.
/// - [LimitExceededFailure] if free-tier limit reached.
/// - [DatabaseFailure] if persistence fails.
Future<Either<Failure, Ledger>> call(CreateLedgerParams params);
```

- Entities: Document business meaning of each field.
- Use Cases: Document preconditions, postconditions, all failure modes.
- Repository Interfaces: Document behavioral contracts.
- Private methods: Brief // comment is sufficient.
</documentation>

## Security Standards

<security>
### PIN & Authentication
- PIN hash: SHA-256 with random 16-byte salt. Stored in flutter_secure_storage ONLY — never in Drift DB.
- Biometric: via local_auth. Check availability before offering.
- App lock: trigger on AppLifecycleState.resumed after configurable timeout.
- Failed PIN attempts: max 5 consecutive → force delay (exponential backoff).

### Data Encryption
- Backup files (.daftar): AES-256 encryption. Key from app-generated secret in flutter_secure_storage.
- Cloud uploads: encrypt BEFORE upload. Supabase stores opaque encrypted blobs.
- Database at rest: SQLCipher integration for Drift (Phase 2).

### Sensitive Data Rules
- NEVER log monetary amounts, contact names, or phone numbers.
- NEVER include PII in Firebase Analytics events.
- NEVER store encryption keys, tokens, or PIN hashes in Drift DB or SharedPreferences.
- Respect analyticsEnabled flag in AppSettings — disable Firebase collection when false.
</security>

## Localization & RTL Standards

<localization>
### Arabic-First Design
- Arabic (ar) is the DEFAULT locale. Design every screen in Arabic first, then adapt for English.
- All user-facing strings MUST use ARB localization keys — zero hardcoded strings.
- All layouts MUST render correctly in RTL mode.
- Test swipe gestures in RTL (directions are reversed from LTR).

### Arabic Text Processing Pipeline
When processing Arabic text for search or comparison:
Step 1: Strip all diacritics (تشكيل): remove Unicode range U+064B–U+065F
Step 2: Normalize Alef variants: أ إ آ ٱ → ا
Step 3: Normalize Taa Marbuta for search: ة → ه
Step 4: Trim and collapse whitespace

- Store both original and normalized forms in the database.
- FTS5 index uses the normalized form. Display uses the original form.

### Encoding Handling
- CSV import: auto-detect UTF-8 vs Windows-1256 encoding using BOM/byte analysis.
- Provide manual encoding selector as fallback in import UI.
- Always write/export in UTF-8.

### UI Constraints
- Minimum tap target: 48dp × 48dp on all interactive elements.
- Primary actions within bottom 60% of screen (one-handed reachability).
- Typography: Noto Kufi Arabic for Arabic text, Inter for English text.
- Support Hijri date display alongside Gregorian.
</localization>

## Performance Standards

<performance>
### Main Thread Protection
- PDF generation → Isolate.run()
- CSV/Excel parsing → Isolate.run()
- Backup encryption/decryption → Isolate.run()
- Any computation > 16ms → Move to isolate

### UI Performance Targets
| Metric | Target |
|---|---|
| Cold start | < 2 seconds on Samsung A03 |
| Perceived latency (local ops) | < 100ms |
| List scroll (1000+ items) | 60fps |
| PDF generation (500 txns) | < 5 seconds (in isolate) |
| APK size (per ABI) | < 30MB |
| Memory usage (normal operation) | < 150MB |

### Query Performance
- All Drift list queries MUST use pagination (LIMIT/OFFSET, default 20 items).
- Every WHERE/ORDER BY/JOIN column MUST have an index.
- Use ContactBalance (denormalized) for O(1) balance reads.
- Profile queries on Samsung A03 or equivalent low-end device.
</performance>

## Version Control

<vcs>
- Commits: atomic, one logical change per commit.
- Commit messages: type(scope): description (e.g., feat(ledger): add create use case with free-tier check).
- Types: feat, fix, refactor, test, docs, chore, perf.
</vcs>
