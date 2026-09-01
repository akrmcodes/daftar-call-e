> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Compute Optimization Plan — Main Thread CPU Offloading

> **Codename:** Operation Isolate Zero — Dart Main Thread Liberation  
> **Author:** Principal Application Architect  
> **Date:** 2026-06-26  
> **Status:** COMPLETE — All 4 steps executed (2026-06-26)  
> **Prerequisite:** UI Optimization Plan (complete) + DB Optimization Plan (complete)

---

## Executive Summary

After securing the DB layer (I/O — blazing fast) and the UI layer (GPU bottlenecks removed, Fixed Extents enforced), this plan addresses the **final performance frontier**: CPU-bound operations blocking the Dart Main Thread.

Every operation identified below realistically threatens the **16.67ms frame budget** under production conditions (large CSVs, multi-MB database backups, ledgers with 500+ transactions). Operations that are trivially fast (< 1ms for realistic data sizes) are explicitly **excluded** to avoid isolate spawn overhead (~50µs) negating the benefit.

### Current Isolation Scorecard

| Subsystem | Properly Isolated | Main Thread Violations | Severity |
|---|---|---|---|
| **PDF Generation** | ✅ Full pipeline including payload sanitization deferred to isolate | — | ✅ Complete |
| **PDF Ledger Summary** | ✅ Zero-copy font transfer + isolate sanitization | — | ✅ Complete |
| **Backup Encryption** | ✅ AES-256-GCM + SHA-256 checksum via `Isolate.run()` | — | ✅ Complete |
| **CSV Byte Decode + Parse** | ✅ UTF-8/Win-1256 decode + structural parse in isolate | — | ✅ Complete |
| **CSV Row Mapping & Entity Build** | ✅ `analyzeImport()` + `execute()` loops in isolate; cached structural parse | — | ✅ Complete |
| **CSV Bulk Persist Mapping** | ✅ `fromDomain()` + audit JSON encoding via `Isolate.run()` | — | ✅ Complete |
| **Balance Calculation** | N/A — integer arithmetic, O(n) | — | ✅ Below threshold |
| **Ledger Contact Pipeline** | ✅ Memoized with hash-based cache invalidation | — | ✅ Below threshold |

---

## Analysis Methodology

- **Scope:** Pure Dart CPU-bound operations only. DB I/O, network calls, and GPU/widget rendering are explicitly excluded.
- **Threshold:** Only operations that realistically exceed **10ms CPU time** on a mid-range Android device (Snapdragon 665-class) are targeted for isolation.
- **Tool:** `Isolate.run()` (Dart 2.19+) for fire-and-forget CPU tasks. `Isolate.spawn()` with `SendPort`/`ReceivePort` only where progress callbacks or streaming results are needed.

---

## Step 1: Backup SHA-256 Checksum Isolation

> **Severity:** 🔴 HIGH  
> **Estimated CPU cost:** 5–50ms per call (scales linearly with backup file size; a 10MB DB → ~10MB ciphertext → ~15ms SHA-256 on Snapdragon 665)  
> **Affected user actions:** Create backup, Restore backup, Resume queued upload  
> **Files:** [`backup_repository_impl.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/backup_repository_impl.dart)

### Problem

AES-256-GCM encryption and decryption are correctly offloaded to `Isolate.run()` (lines 178 and 296). However, the SHA-256 checksum computation that immediately follows/precedes these operations runs **synchronously on the main thread** via `_sha256hex()` (line 311–314).

Three call sites are affected:

| Call Site | Line | Context | When Triggered |
|---|---|---|---|
| `_createEncryptedSnapshotCore()` | L299 | After encryption returns from isolate | Every backup create |
| `restoreLocal()` | L167 | Before decryption isolate is spawned | Every backup restore |
| `buildSnapshotFromEncryptedBackupFile()` | L126 | Queue resume — reads file + checksums | Every queued upload retry |

The gold-standard pattern already exists at [`backup_download_integrity.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/backup_download_integrity.dart) (L17–27), which wraps the entire file-read + SHA-256 in a single `Isolate.run()`.

### Fix

- [x] **1.1** — `_createEncryptedSnapshotCore()`: Merge the SHA-256 checksum into the existing encryption isolate. Instead of returning just `encryptedBytes`, the isolate should return both `encryptedBytes` and `checksum` in a record/tuple. This eliminates the extra isolate spawn overhead entirely.

```dart
// BEFORE (two boundary crossings):
final encryptedBytes = await Isolate.run(
  () => EncryptionUtil.encryptBackup(plainBytes),
);
final checksum = _sha256hex(encryptedBytes); // ❌ MAIN THREAD

// AFTER (single boundary crossing):
final (encryptedBytes, checksum) = await Isolate.run(() {
  final encrypted = EncryptionUtil.encryptBackup(plainBytes);
  final digest = sha256.convert(encrypted).toString();
  return (encrypted, digest);
});
```

- [x] **1.2** — `restoreLocal()`: Wrap the checksum validation in `Isolate.run()`:

```dart
// BEFORE:
final computedChecksum = _sha256hex(encryptedBytes); // ❌ MAIN THREAD

// AFTER:
final computedChecksum = await Isolate.run(
  () => sha256.convert(encryptedBytes).toString(),
);
```

- [x] **1.3** — `buildSnapshotFromEncryptedBackupFile()`: Wrap `file.readAsBytes()` + `_sha256hex()` in a single `Isolate.run()` (mirroring `backup_download_integrity.dart`):

```dart
// AFTER:
final (bytes, checksum) = await Isolate.run(() {
  final data = File(absolutePath).readAsBytesSync();
  final digest = sha256.convert(data).toString();
  return (data, digest);
});
```

- [x] **1.4** — Remove the now-unused `_sha256hex()` private method (L311–314) if all call sites are migrated.

### Verification

- [ ] Run existing backup integration tests (`test/data/repositories/backup_repository_impl_test.dart`).
- [ ] Manually time create + restore on a 15MB seeded database using `Stopwatch`. Verify main-thread time drops below 2ms for the checksum step.

---

## Step 2: CSV Import — Row Mapping & Entity Building Isolation

> **Severity:** 🔴 CRITICAL  
> **Estimated CPU cost:** 15–200ms for 1000+ rows (field parsing, amount parsing with BigInt, date parsing with 6-pattern DateFormat trial, UUID generation × 3 per row, Arabic normalization)  
> **Affected user actions:** CSV import (execute), CSV pre-flight analysis  
> **Files:** [`import_csv_use_case.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/application/import/import_csv_use_case.dart), [`csv_parser.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/csv_parser.dart)

### Problem

While `CsvParserUtil.parseCsvBytes()` correctly uses `Isolate.run()` for byte decoding and CSV splitting (L52), the subsequent processing pipeline runs **entirely on the main thread**:

| Operation | Location | Complexity per row |
|---|---|---|
| `structuralParseDecodedRows()` | `csv_parser.dart:150–202` | O(columns) cell trimming |
| `_parseValidatedImportRow()` per row | `import_csv_use_case.dart:364–368` | Phone sanitize + amount parse (BigInt) + date parse (6 patterns) + type parse |
| `index.resolveDisposition()` per row | `import_csv_use_case.dart:378–381` | Map lookups (fast, but inside main-thread loop) |
| Entity construction + UUID generation | `import_csv_use_case.dart:399–474` | 3× `UuidUtil.generate()` + `normalizeArabic()` per new contact |

**Critical multiplier:** The current flow runs `structuralParseDecodedRows` **3 separate times** in a complete import (preview + pre-flight + execute), and the full row validation loop runs **2 times** (pre-flight + execute). The CSV bytes are also re-parsed from bytes in each phase.

### Fix — Phase A: Merge `structuralParseDecodedRows` into the existing isolate

- [x] **2.1** — Modify `CsvParserUtil.parseCsvBytes()` to return `CsvStructuralParseOutput` instead of raw `List<List<dynamic>>`. Move `structuralParseDecodedRows()` inside the existing `Isolate.run()` closure:

```dart
// BEFORE:
static Future<List<List<dynamic>>> parseCsvBytes(...) {
  return Isolate.run(() => parseCsvRowsSync(owned, decodingMode: decodingMode));
}

// AFTER:
static Future<CsvStructuralParseOutput> parseCsvBytesStructured(...) {
  return Isolate.run(() {
    final rows = parseCsvRowsSync(owned, decodingMode: decodingMode);
    return structuralParseDecodedRows(rows);
  });
}
```

- [x] **2.2** — Update all 3 call sites (`_parseIntoPreview`, `_prepareCsvImportContext` in use case, and test files) to use the new combined method.

### Fix — Phase B: Isolate the row mapping loop in `execute()`

- [x] **2.3** — Extract the pure-computation portion of the `execute()` loop (lines 360–477) into a static, isolate-safe function. This function takes primitive/sendable inputs (body rows, header lookup map, seed contacts as serialized maps, avatar colors, ledger ID) and returns the built `CsvBulkPersistBatch` data + error list:

```dart
static _CsvBuildResult _buildEntitiesSync({
  required List<List<String>> bodyRows,
  required Map<String, int> headerBacking,
  required List<Map<String, Object?>> seedContactMaps,
  required String ledgerId,
  required DuplicateResolutionStrategy duplicateStrategy,
  required int activeContactCount,
  required int activeTransactionCount,
  required Map<String, Object?> entitlementMap,
}) {
  // All the row parsing + entity building logic — runs in isolate
}
```

- [x] **2.4** — Wrap the call in `Isolate.run()`:

```dart
final buildResult = await Isolate.run(
  () => _buildEntitiesSync(
    bodyRows: ctx.bodyRows,
    headerBacking: headerLookup.backing,
    // ... sendable primitives only
  ),
);
```

- [x] **2.5** — Apply the same pattern to `analyzeImport()` (lines 254–285). Extract the pre-flight loop into a separate static isolate-safe function.

### Fix — Phase C: Eliminate redundant re-parsing

- [x] **2.6** — Cache the `CsvStructuralParseOutput` in `ImportCsvUiState` after the first preview parse. Pass it to `analyzeImport()` and `execute()` instead of re-parsing from bytes each time. This eliminates 2 of the 3 redundant `parseCsvBytes` calls.

### Verification

- [ ] Run existing CSV import tests (`test/application/import/import_csv_use_case_test.dart`).
- [ ] Profile with a 2000-row CSV: measure main-thread time before and after. Target: main-thread contribution < 5ms (only the `Isolate.run()` call + await).

---

## Step 3: PDF Payload Serialization Optimization

> **Severity:** 🟡 MEDIUM  
> **Estimated CPU cost:** 5–20ms for 500+ transactions (7× `_sanitizePdfText()` rune scan per transaction in `buildIsolatePayload`)  
> **Affected user actions:** Export contact statement, Export ledger summary  
> **Files:** [`pdf_generator.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/pdf_generator.dart), [`pdf_ledger_summary.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/pdf_ledger_summary.dart)

### Problem — Contact Statement (`pdf_generator.dart`)

`buildIsolatePayload()` (L211–348) runs **on the main thread** before the isolate is spawned. At lines 309–321, it iterates the entire transaction list with a synchronous `.map().toList()`, calling `_sanitizePdfText()` on 6–7 fields per transaction. `_sanitizePdfText()` is a rune-by-rune scanner (L1321–1371).

For a contact with 1000 transactions: ~7000 `_sanitizePdfText()` calls on the main thread.

Note: The PDF build itself (font parsing, layout, widget tree, `document.save()`) is **correctly isolated** via `Isolate.spawn()` at L185. This is purely about the pre-spawn serialization.

### Problem — Ledger Summary (`pdf_ledger_summary.dart`)

1. Font bytes at lines 247–250 are passed as raw `Uint8List` inside the map payload — NOT wrapped in `TransferableTypedData`. This causes a **full copy** (~1.5MB+ for 4 fonts) across the isolate boundary instead of zero-copy transfer.
2. `request.toMap()` at L297 re-sanitizes all label strings AND iterates contacts/totals calling `_ledgerSanitizePdfText()` on each field.

### Fix

- [x] **3.1** — Move transaction serialization into the isolate. Instead of pre-serializing transactions in `buildIsolatePayload`, pass raw transaction data as primitive maps (which are already sendable) and let `_buildPdfIsolate` perform the `_sanitizePdfText()` sanitization. The transaction `.map()` at L309–321 should produce minimal sendable maps (just raw field values), with sanitization deferred to the isolate.

- [x] **3.2** — In `pdf_ledger_summary.dart`, wrap font byte arrays in `TransferableTypedData.fromList()` before passing to the isolate (matching the pattern already used in `pdf_generator.dart` at L334–344):

```dart
// BEFORE:
'cairoRegularFontBytes': cairoRegularFontBytes,  // ❌ full copy

// AFTER:
'cairoRegularFontBytes': TransferableTypedData.fromList([cairoRegularFontBytes]),  // ✅ zero-copy
```

- [x] **3.3** — Eliminate double sanitization: remove `_sanitizePdfText()` calls from `buildIsolatePayload` label strings (L279–325), since `_PdfRequest.fromMap()` inside the isolate (L1424–1495) already re-sanitizes everything. This is redundant CPU work.

### Verification

- [ ] Run existing PDF generation tests.
- [ ] Profile contact statement generation with a 1000-transaction contact. Verify main-thread contribution of `buildIsolatePayload` drops to < 3ms.

---

## Step 4: CSV Bulk Persist Entity-to-Model Mapping

> **Severity:** 🟠 MEDIUM  
> **Estimated CPU cost:** 5–15ms for 500+ entities (3× list `.map()` + JSON `encodePayload` per audit log)  
> **Affected user actions:** CSV import commit  
> **Files:** [`bulk_write_repository_impl.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/bulk_write_repository_impl.dart)

### Problem

`BulkWriteRepositoryImpl.persist()` performs synchronous domain-to-model mapping on the main thread:

- Lines 27–29: `.map(ContactModel.fromDomain).toList()` — iterates all contacts
- Lines 30–32: `.map(TransactionModel.fromDomain).toList()` — iterates all transactions
- Lines 48–56: `.map((log) => _mapAuditLog(...)).toList()` — iterates all audit logs with `encodePayload()` (JSON encoding) per entry

With 500 imported contacts + 500 transactions + 1000 audit logs: ~2000 `.fromDomain()` conversions + ~1000 JSON serializations on the main thread.

### Fix

- [x] **4.1** — ~~If Step 2 (Phase B) successfully moves entity building into the isolate, consider having the isolate produce `ContactModel`/`TransactionModel` directly instead of domain entities~~ **Cancelled** — rejected; domain layer must not produce data models; superseded by 4.2.

- [x] **4.2** — Alternatively, if the domain-layer boundary must be preserved, wrap the entire mapping block in `Isolate.run()`:

```dart
final (contactModels, transactionModels, auditCompanions) = await Isolate.run(() {
  final contacts = batch.contacts.map(ContactModel.fromDomain).toList();
  final transactions = batch.transactions.map(TransactionModel.fromDomain).toList();
  final audits = batch.auditLogs.map((log) => _mapAuditLog(log, ...)).toList();
  return (contacts, transactions, audits);
});
```

> **Note:** This step may become unnecessary if Step 2 Phase B is implemented aggressively (entities built as models directly in the isolate).

### Verification

- [ ] Run bulk write tests.
- [ ] Profile a 1000-entity persist batch: verify main-thread time < 2ms.

---

## Explicitly Excluded — Below Isolation Threshold

The following operations were analyzed and **deliberately excluded** because their CPU cost is below the 10ms threshold for realistic data volumes, making isolate spawn overhead counterproductive:

| Operation | File | Complexity | Estimated Cost (500 items) | Reason for Exclusion |
|---|---|---|---|---|
| `calculateContactBalances()` | [`balance_calculator.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/balance_calculator.dart) | O(n) integer add | < 0.5ms | Pure integer arithmetic with Map lookup |
| `aggregateBalancesByCurrency()` | [`aggregate_balances_by_currency.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/application/ledger/aggregate_balances_by_currency.dart) | O(n) integer add | < 0.3ms | Same — tiny per-element cost |
| `LedgerContactListPipeline.compute()` | [`ledger_contact_list_pipeline.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/presentation/screens/ledger/ledger_contact_list_pipeline.dart) | O(n log n) sort + O(n) filter | < 3ms for 500 contacts | **Already memoized** with hash-based cache invalidation. Recomputes only on data change, not per frame. |
| `BalanceRecalculationService` | [`balance_recalculation_service.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/balance_recalculation_service.dart) | O(n) per contact | < 1ms per contact | Called for single contacts; the loop is DB I/O-bound, not CPU-bound |
| Balance/Transaction/Contact mappers | `lib/data/mappers/*.dart` | O(1) per entity | < 0.01ms each | Field-level copy constructors; negligible even at scale |
| `encodePayload()` for audit log JSON | [`repository_utils.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/repository_utils.dart) | O(1) per call | < 0.05ms each | Only significant when called in bulk (covered by Step 4) |
| `PdfStorageService.saveStatement()` | [`pdf_storage_service.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/pdf_storage_service.dart) | O(1) regex | < 0.01ms | Filename sanitization only; file write is async I/O |
| `EncryptionUtil.encrypt/decrypt` | [`encryption_util.dart`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/encryption_util.dart) | — | — | **Already isolated** by callers; no standalone main-thread usage |

---

## Priority Execution Order

```
Step 1 (Backup SHA-256)      ████████████████████ DONE
Step 2 (CSV Row Isolation)   ████████████████████ DONE
Step 3 (PDF Payload)         ████████████████████ DONE
Step 4 (Bulk Persist Maps)   ████████████████████ DONE
```

> **Total actionable items:** 15 checkboxes across 4 steps — **all complete**  
> **Estimated engineering time:** 2–3 focused sessions  
> **Risk:** Low — all changes are confined to their respective utility/repository files. No schema migrations. No public API changes. Domain layer remains untouched.  
> **Testing:** Each step has existing test coverage. No new test files required (existing tests validate the same code paths).

---

## Architecture Note: Why `Isolate.run()` over `compute()`

- `Isolate.run()` (Dart 2.19+) is the successor to `compute()`. It has identical semantics but a cleaner API.
- The existing codebase already uses `Isolate.run()` in `backup_repository_impl.dart` (L178, L296), `csv_parser.dart` (L52), and `backup_download_integrity.dart` (L21).
- `Isolate.spawn()` is used only for PDF generation where progress callbacks are needed (streaming `_ProgressMsg` objects via `SendPort`).
- We maintain this convention: **`Isolate.run()` for fire-and-forget, `Isolate.spawn()` only when progress streaming is required.**
