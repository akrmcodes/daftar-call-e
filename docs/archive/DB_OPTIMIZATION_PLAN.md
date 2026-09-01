> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Database Layer Optimization Plan — Phase 1: DB-Only

> **Generated:** 2026-06-24  
> **Author:** Principal DB Architect — Autonomous Analysis  
> **Scope:** Exclusively Database & Data Flow. Zero UI changes.  
> **Status:** Phase 1 complete — Operation Bedrock sealed (100%)  
> **Codename:** Operation Bedrock

---

## Executive Summary

Deep analysis of **11 table definitions**, **13 datasource files**, **10 repository implementations**, **11 mapper files**, and the Drift database core reveals **7 critical defect categories** in the data layer that degrade performance, threaten data integrity, and introduce correctness bugs — all independent of the UI.

| # | Defect Category | Severity | Measured Impact | Files Affected |
|---|---|---|---|---|
| 1 | N+1 Cascade Loops (row-by-row UPDATE) | 🔴 CRITICAL | 533ms for 50C/500T delete | 3 repos |
| 2 | Missing Bulk/Batch APIs | 🔴 CRITICAL | 602ms for 200-contact import | DS + repos |
| 3 | Duplicated `_recalculateBalancesForContact` (4 copies, inconsistent) | 🔴 CRITICAL | Correctness bug — different filters | 4 files |
| 4 | `SELECT *` + `.length` count anti-pattern | 🟠 HIGH | O(n) object allocation per count | 4 methods |
| 5 | Missing atomicity on critical write paths | 🟠 HIGH | Data loss risk on crash | 3 methods |
| 6 | FTS index management overhead in hot paths | 🟡 MEDIUM | Per-row DELETE + INSERT for every contact mutation | 2 files |
| 7 | Potential restore correctness bug | 🟡 MEDIUM | Restoring individually-deleted transactions | 1 method |

---

## Defect Inventory (Evidence-Based)

### Defect D-1: Cascade Delete N+1 Loops

**Root Cause:** Cascade soft-delete operations iterate rows and issue individual SQL statements per entity instead of bulk `UPDATE ... WHERE id IN (...)`.

**Evidence:**

| Location | Operation | SQL Round-trips for 50C/500T |
|---|---|---|
| [`ledger_repository_impl.dart:196–219`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/ledger_repository_impl.dart#L196-L219) | Per-contact UPDATE + FTS remove + per-transaction UPDATE | 50 + 50 + 500 = **600** |
| [`contact_repository_impl.dart:273–277`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_repository_impl.dart#L273-L277) | `deleteTransaction(id)` per row → SELECT + UPDATE each | 10 transactions × 2 = **20 per contact** |

The `deleteTransaction()` datasource method at [`transaction_local_ds.dart:48–72`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/transaction_local_ds.dart#L48-L72) internally does `getTransactionById()` (SELECT) then `updateTransaction()` (UPDATE) — **2 SQL operations per row** in the cascade loop.

**Cascade Restore has the same pattern:** [`ledger_repository_impl.dart:290–356`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/ledger_repository_impl.dart#L290-L356) and [`contact_repository_impl.dart:337–356`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_repository_impl.dart#L337-L356).

---

### Defect D-2: Missing Bulk/Batch APIs

**Root Cause:** `ContactLocalDataSource` and `TransactionLocalDataSource` only expose single-row CRUD. No `batch()` wrappers exist for contacts or transactions. The only `batch()` calls in the codebase are:

| File | Line | Context |
|---|---|---|
| [`drift_database.dart:216`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/drift_database.dart#L216) | Migration currency seeding |
| [`backup_local_ds.dart:191`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/backup_local_ds.dart#L191) | Backup metadata restore |
| [`dev_database_seeder.dart:147`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/core/utils/dev_database_seeder.dart) | Dev seeder only |

**Consequence:** CSV import of 200 contacts executes **600+ sequential SQL statements** (INSERT contact + INSERT FTS + INSERT audit × 200). The FTS upsert itself does DELETE + INSERT (2 statements per contact), making it closer to **800+ statements**.

---

### Defect D-3: `_recalculateBalancesForContact` — 4 Copies, Inconsistent Filters

**Root Cause:** The balance recalculation logic is copy-pasted across 4 files with **semantically different** transaction filters:

| Location | `isDeleted` filter | `isArchived` filter | Transaction wrapper |
|---|---|---|---|
| [`ledger_repository_impl.dart:926–955`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/ledger_repository_impl.dart#L926-L955) | `isDeleted = false` | ❌ Missing | Relies on caller |
| [`transaction_repository_impl.dart:539–569`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/transaction_repository_impl.dart#L539-L569) | `isDeleted = false` | ✅ `isArchived = false` | Relies on caller |
| [`contact_repository_impl.dart:477–506`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_repository_impl.dart#L477-L506) | `isDeleted = false` | ❌ Missing | Relies on caller |
| [`balance_repository_impl.dart:71–107`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/balance_repository_impl.dart#L71-L107) | `isDeleted = false` | ❌ Missing | ❌ **NO transaction wrapper** |

**Correctness Bug:** The `TransactionRepositoryImpl` version correctly excludes archived transactions from balance calculation. The other 3 copies include archived transactions, producing **different balance results** depending on which code path triggers the recalculation.

**Data Loss Risk:** `BalanceRepositoryImpl.recalculate()` performs DELETE + INSERT **without a Drift `transaction()` wrapper**. A crash between the delete and the first insert loses all balance data for that contact.

Additionally, all 4 copies use the **DELETE all + INSERT loop** pattern for balance upsert, which could be replaced with `INSERT OR REPLACE` (already exists as `insertOnConflictUpdate` in [`balance_local_ds.dart:106`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/balance_local_ds.dart#L106)) — eliminating the delete step entirely.

---

### Defect D-4: `SELECT *` + `.length` Count Anti-Pattern

**Root Cause:** Count queries materialize all rows into Dart objects, then call `.length` on the resulting list.

| Method | Location | What It Materializes |
|---|---|---|
| `_countActiveLedgers()` | [`ledger_repository_impl.dart:387–396`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/ledger_repository_impl.dart#L387-L396) | All active ledger rows |
| `getArchivedCount()` | [`ledger_repository_impl.dart:399–412`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/ledger_repository_impl.dart#L399-L412) | All archived ledger rows |
| `_countActiveContacts()` | [`contact_repository_impl.dart:389–398`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_repository_impl.dart#L389-L398) | All active contact rows |
| `getArchivedCount()` | [`contact_repository_impl.dart:401–414`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_repository_impl.dart#L401-L414) | All archived contact rows |
| `countUserArchivedLedgers()` | [`ledger_local_ds.dart:94–103`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/ledger_local_ds.dart#L94-L103) | All user-archived ledger rows |

**Contrast:** `TransactionRepositoryImpl._countActiveTransactions()` at [`transaction_repository_impl.dart:442–451`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/transaction_repository_impl.dart#L442-L451) correctly uses `SELECT COUNT(*) AS cnt`. This is the pattern all count methods should follow.

**Impact:** With 500 contacts, the `_countActiveContacts()` call deserializes 500 `Contact` Dart objects (each with ~12 fields) just to return `500`. The `COUNT(*)` equivalent touches zero Dart objects.

---

### Defect D-5: Missing Atomicity on Critical Write Paths

| Method | Location | Risk |
|---|---|---|
| `BalanceRepositoryImpl.recalculate()` | [`balance_repository_impl.dart:71–107`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/balance_repository_impl.dart#L71-L107) | DELETE all balances → INSERT loop, **no `transaction()`** — crash = data loss |
| `CurrencyRepositoryImpl.addCustom()` | [`currency_repository_impl.dart:72–125`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/currency_repository_impl.dart#L72-L125) | INSERT currency + audit log as **separate operations** |
| `CurrencyRepositoryImpl.toggleActive()` | [`currency_repository_impl.dart:128–158`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/currency_repository_impl.dart#L128-L158) | UPDATE + audit log as **separate operations** |

---

### Defect D-6: FTS Index Overhead in Hot Paths

**Pattern:** Every contact create/update/delete touches the FTS5 virtual table via 2 raw SQL statements (DELETE old entry + INSERT new entry):

- [`contact_search_index_utils.dart:6–18`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_search_index_utils.dart#L6-L18): `upsertContactSearchIndex()` — always deletes then inserts.
- [`contact_local_ds.dart:256–264`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/contact_local_ds.dart#L256-L264): Duplicate implementation of the same logic.

**Impact on Bulk Operations:** For 200 contacts, this adds **400 raw SQL statements** on top of the 200 contact inserts.

**Additional concern:** The DELETE in `contact_search_index_utils.dart:27` uses **string interpolation** with `_escapeSql()` instead of parameterized queries. While UUIDs are safe, this is a hygiene issue.

---

### Defect D-7: Contact Restore — Over-Restoration Bug

**Location:** [`contact_repository_impl.dart:311–313`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/contact_repository_impl.dart#L311-L313)

```dart
final transactionRows = await (_database.select(
  _database.transactions,
)..where((table) => table.contactId.equals(id))).get();
```

This fetches **ALL transactions** for the contact — including those that were individually soft-deleted before the contact was deleted. Restoring the contact thus **incorrectly resurrects** transactions that the user had previously deleted on purpose.

**Contrast:** `LedgerRepositoryImpl.restore()` at [`ledger_repository_impl.dart:260–273`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/ledger_repository_impl.dart#L260-L273) correctly correlates by `isDeleted = true AND updatedAt = deletedAt`.

---

## Execution Plan

### Step 1: Canonicalize `_recalculateBalancesForContact` (Correctness + Integrity)

> **Priority:** 🔴 CRITICAL — Fixes a correctness bug and eliminates code duplication  
> **Risk:** LOW — Pure refactoring, no schema changes  
> **Estimated SQL improvement:** Eliminates redundant DELETE + INSERT loop → single `INSERT OR REPLACE`

- [x] **1.1** Create a single canonical `recalculateBalancesForContact()` method in a shared utility (e.g., `balance_recalculation_service.dart` in `lib/data/repositories/`).
- [x] **1.2** Standardize the transaction filter: `isDeleted = false AND isArchived = false` (matching the `TransactionRepositoryImpl` version which is semantically correct — archived transactions should NOT count toward live balances).
- [x] **1.3** Replace the DELETE-all + INSERT-loop pattern with direct `insertOnConflictUpdate` calls (the `upsertBalance()` method already uses this at [`balance_local_ds.dart:106`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/datasources/local/balance_local_ds.dart#L106)). After upserting all current balances, delete any stale currency rows for currencies that no longer have transactions.
- [x] **1.4** Ensure the canonical method is **always called within a Drift `transaction()`** — add a debug assertion or documentation contract.
- [x] **1.5** Replace all 4 copies in `LedgerRepositoryImpl`, `TransactionRepositoryImpl`, `ContactRepositoryImpl`, and `BalanceRepositoryImpl` with calls to the canonical method.
- [x] **1.6** Write unit tests: verify that archived transactions are excluded, verify crash-safety (the caller's transaction wrapper ensures atomicity), verify that stale currency balance rows are cleaned up.

**Files modified:**
- `lib/data/repositories/ledger_repository_impl.dart`
- `lib/data/repositories/transaction_repository_impl.dart`
- `lib/data/repositories/contact_repository_impl.dart`
- `lib/data/repositories/balance_repository_impl.dart`
- `lib/data/repositories/balance_calculator.dart` (no change, but referenced)
- **[NEW]** `lib/data/repositories/balance_recalculation_service.dart`

---

### Step 2: Bulk Cascade Delete/Restore via Single SQL Statements

> **Priority:** 🔴 CRITICAL — Reduces 533ms → target < 100ms  
> **Risk:** LOW — Behavioral parity, fewer SQL statements  
> **Measured baseline:** `DEVICE_DB_CASCADE_DELETE_50C_500T` = 533ms

- [x] **2.1** Add `bulkSoftDeleteTransactionsByContactIds(List<String> contactIds)` to `TransactionLocalDataSource`:
  ```sql
  UPDATE transactions SET is_deleted = 1, updated_at = ?, sync_version = sync_version + 1
  WHERE contact_id IN (?) AND is_deleted = 0
  ```
  Uses Drift's `CustomExpression('sync_version + 1')` for atomic increment.

- [x] **2.2** Add `bulkSoftDeleteContactsByLedgerId(String ledgerId)` to `ContactLocalDataSource`:
  ```sql
  UPDATE contacts SET is_deleted = 1, updated_at = ?, sync_version = sync_version + 1
  WHERE ledger_id = ? AND is_deleted = 0
  ```

- [x] **2.3** Add `bulkRemoveContactSearchIndex(List<String> contactIds)` to `ContactLocalDataSource` — uses parameterized DELETE:
  ```sql
  DELETE FROM contact_fts WHERE contact_id IN (?)
  ```

- [x] **2.4** Add corresponding `bulkRestoreTransactionsByContactIds()` and `bulkRestoreContactsByLedgerId()` methods for the restore path:
  - Restore only correlates by `updatedAt = deletedAt` (matching the existing ledger restore pattern).

- [x] **2.5** Refactor `LedgerRepositoryImpl.delete()` to call bulk methods instead of per-row loops.
- [x] **2.6** Refactor `ContactRepositoryImpl.delete()` to call `bulkSoftDeleteTransactionsByContactIds([contactId])` instead of looping through `deleteTransaction()`.
- [x] **2.7** Refactor `LedgerRepositoryImpl.restore()` to call bulk restore methods.
- [x] **2.8** Refactor `ContactRepositoryImpl.restore()` to call bulk restore + add timestamp correlation filter (fixes **Defect D-7**).
- [x] **2.9** Write benchmark test: cascade delete 50 contacts × 10 transactions, assert < 100ms.

**Files modified:**
- `lib/data/datasources/local/transaction_local_ds.dart`
- `lib/data/datasources/local/contact_local_ds.dart`
- `lib/data/repositories/ledger_repository_impl.dart`
- `lib/data/repositories/contact_repository_impl.dart`

---

### Step 3: Bulk Insert APIs + Batch Pipeline

> **Priority:** 🔴 CRITICAL — Reduces 602ms → target < 100ms  
> **Risk:** LOW — Additive API, does not change existing single-insert paths  
> **Measured baseline:** `DEVICE_DB_BULK_CONTACT_INSERT_200` = 602ms

- [x] **3.1** Add `bulkCreateContacts(List<ContactModel> contacts)` to `ContactLocalDataSource` using Drift's `batch()`:
  ```dart
  Future<void> bulkCreateContacts(List<ContactModel> contacts) async {
    await database.batch((batch) {
      for (final contact in contacts) {
        batch.insert(database.contacts, contact.toDrift());
      }
    });
  }
  ```

- [x] **3.2** Add `bulkCreateTransactions(List<TransactionModel> transactions)` to `TransactionLocalDataSource` with the same `batch()` pattern.

- [x] **3.3** Add `bulkUpsertContactSearchIndex(Map<String, String> idToName)` that batches FTS INSERT statements:
  ```dart
  Future<void> bulkUpsertContactSearchIndex(Map<String, String> idToName) async {
    await database.batch((batch) {
      for (final entry in idToName.entries) {
        batch.rawInsert(
          'INSERT INTO contact_fts (contact_id, normalized_name) VALUES (?, ?)',
          [entry.key, entry.value.normalizeArabic()],
        );
      }
    });
  }
  ```

- [x] **3.4** Add `bulkAppendAuditLogs(List<AuditLogModel> logs)` to `AuditLogLocalDataSource` using `batch()`.

- [x] **3.5** Add `bulkUpsertBalances(List<BalanceModel> balances)` to `BalanceLocalDataSource` using `batch()` with `insertOnConflictUpdate`.

- [x] **3.6** Create `BulkWriteService` in `lib/data/repositories/` that orchestrates the full bulk pipeline:
  1. `batch()` insert contacts
  2. `batch()` insert FTS entries
  3. `batch()` insert transactions
  4. `batch()` upsert balances
  5. `batch()` insert audit logs

  All wrapped in a single Drift `transaction()`.

- [x] **3.7** Refactor `import_csv_use_case.dart` to parse first, then call `BulkWriteService` for the DB writes.

- [x] **3.8** Write benchmark test: bulk insert 200 contacts with FTS + audit, assert < 100ms.

**Files modified:**
- `lib/data/datasources/local/contact_local_ds.dart`
- `lib/data/datasources/local/transaction_local_ds.dart`
- `lib/data/datasources/local/audit_log_local_ds.dart`
- `lib/data/datasources/local/balance_local_ds.dart`
- **[NEW]** `lib/data/repositories/bulk_write_service.dart`
- `lib/application/import/import_csv_use_case.dart`

---

### Step 4: Replace `SELECT * ... .length` with `SELECT COUNT(*)`

> **Priority:** 🟠 HIGH — Eliminates unnecessary O(n) object allocation  
> **Risk:** ZERO — Drop-in replacement, identical semantics  

- [x] **4.1** Replace `LedgerRepositoryImpl._countActiveLedgers()` with `SELECT COUNT(*) AS cnt FROM ledgers WHERE is_deleted = 0 AND is_archived = 0`.
- [x] **4.2** Replace `LedgerRepositoryImpl.getArchivedCount()` with equivalent `COUNT(*)`.
- [x] **4.3** Replace `ContactRepositoryImpl._countActiveContacts()` with `SELECT COUNT(*) AS cnt FROM contacts WHERE is_deleted = 0 AND is_archived = 0`.
- [x] **4.4** Replace `ContactRepositoryImpl.getArchivedCount()` with equivalent `COUNT(*)`.
- [x] **4.5** Replace `LedgerLocalDataSource.countUserArchivedLedgers()` with `SELECT COUNT(*) AS cnt FROM ledgers WHERE is_deleted = 0 AND is_user_archived = 1`.
- [x] **4.6** Add `Stream<int> watchContactCountByLedger(String ledgerId)` to `ContactLocalDataSource` for the N+1 provider fix (UI will consume this in the future):
  ```sql
  SELECT COUNT(*) AS cnt FROM contacts
  WHERE ledger_id = ? AND is_deleted = 0 AND is_archived = 0
  ```
- [x] **4.7** Wire `watchContactCountByLedger` through `ContactRepository` interface and implementation.

**Files modified:**
- `lib/data/repositories/ledger_repository_impl.dart`
- `lib/data/repositories/contact_repository_impl.dart`
- `lib/data/datasources/local/ledger_local_ds.dart`
- `lib/data/datasources/local/contact_local_ds.dart`
- `lib/domain/repositories/contact_repository.dart` (add interface method)

---

### Step 5: Add Ledger Contact Summary Query (Single JOIN replacing N+1)

> **Priority:** 🟠 HIGH — Prepares the data layer for the UI N+1 fix  
> **Risk:** LOW — Additive query, no existing behavior changes  
> **Note:** This step creates the DB infrastructure. The UI change is out of scope.

- [x] **5.1** Add `watchContactSummariesByLedger(String ledgerId)` to `ContactLocalDataSource` or `BalanceLocalDataSource`:
  ```sql
  SELECT
    c.id AS contact_id,
    c.name,
    c.phone,
    c.avatar_color,
    c.credit_limit,
    c.credit_currency,
    cb.currency_code,
    cb.total_debt,
    cb.total_payment,
    cb.net_balance,
    (SELECT COUNT(*) FROM transactions t
     WHERE t.contact_id = c.id AND t.is_deleted = 0 AND t.is_archived = 0) AS txn_count
  FROM contacts c
  LEFT JOIN contact_balances cb ON c.id = cb.contact_id
  WHERE c.ledger_id = ? AND c.is_deleted = 0 AND c.is_archived = 0
  ORDER BY c.name COLLATE NOCASE
  ```

- [x] **5.2** Create a `ContactSummaryRow` data model to hold the join result.
- [x] **5.3** Wire through `ContactRepository` → domain layer as `ContactWithSummary` or similar value object.
- [x] **5.4** Ensure the query uses the existing `idx_contacts_ledger_active_name` covering index.

**Files modified:**
- `lib/data/datasources/local/contact_local_ds.dart` or `balance_local_ds.dart`
- **[NEW]** `lib/data/models/contact_summary_row.dart`
- `lib/domain/repositories/contact_repository.dart` (add interface method)
- `lib/data/repositories/contact_repository_impl.dart`

---

### Step 6: Fix Missing Atomicity + Hygiene

> **Priority:** 🟠 HIGH (atomicity), 🟡 MEDIUM (hygiene)  
> **Risk:** ZERO — Wrapping in `transaction()` does not change behavior  

- [x] **6.1** Wrap `BalanceRepositoryImpl.recalculate()` in `_database.transaction()`.
- [x] **6.2** Wrap `CurrencyRepositoryImpl.addCustom()` in `_database.transaction()` (insert + audit).
- [x] **6.3** Wrap `CurrencyRepositoryImpl.toggleActive()` in `_database.transaction()` (update + audit).
- [x] **6.4** Fix FTS DELETE in `contact_search_index_utils.dart` to use parameterized query instead of string interpolation:
  ```dart
  // BEFORE (string interpolation):
  await database.customStatement(
    "DELETE FROM contact_fts WHERE contact_id = '${_escapeSql(contactId)}'",
  );
  
  // AFTER (parameterized):
  await database.customStatement(
    'DELETE FROM contact_fts WHERE contact_id = ?',
    [contactId],
  );
  ```
- [x] **6.5** Deduplicate `_upsertContactSearchIndex` — remove the copy in `contact_local_ds.dart:256–264` and use the canonical one from `contact_search_index_utils.dart`.
- [x] **6.6** Fix `CurrencyRepositoryImpl.getActive()` at [`currency_repository_impl.dart:57–69`](file:///Users/aq/Work/01_Projects/02_Mobile/01_Clients/daftar/lib/data/repositories/currency_repository_impl.dart#L57-L69) — currently fetches ALL currencies then filters in Dart. Add SQL `WHERE is_active = 1` at the datasource level.

**Files modified:**
- `lib/data/repositories/balance_repository_impl.dart`
- `lib/data/repositories/currency_repository_impl.dart`
- `lib/data/repositories/contact_search_index_utils.dart`
- `lib/data/datasources/local/contact_local_ds.dart`
- `lib/data/datasources/local/currency_local_ds.dart`

---

### Step 7: Fix Contact Restore Over-Restoration Bug

> **Priority:** 🟡 MEDIUM — Correctness bug, not performance  
> **Risk:** LOW — Behavioral change, but corrects a defect  

- [x] **7.1** Modify `ContactRepositoryImpl.restore()` to fetch only transactions that were cascade-deleted at the same time as the contact:
  ```dart
  // BEFORE:
  final transactionRows = await (_database.select(
    _database.transactions,
  )..where((table) => table.contactId.equals(id))).get();
  
  // AFTER:
  final deletedAt = existing.updatedAt;
  final transactionRows = await (_database.select(_database.transactions)
    ..where((table) => table.contactId.equals(id))
    ..where((table) => table.isDeleted.equals(true))
    ..where((table) => table.updatedAt.equals(deletedAt))
  ).get();
  ```

- [x] **7.2** Write test: individually delete transaction T1, then soft-delete contact, then restore contact. Assert T1 remains deleted.

**Files modified:**
- `lib/data/repositories/contact_repository_impl.dart`

---

## Index Analysis — Current State Assessment

The existing index coverage is **strong** for the main query patterns:

| Index | Covers Query | Verdict |
|---|---|---|
| `idx_contacts_ledger_active_name (ledgerId, isDeleted, isArchived, name)` | `watchContactsByLedger` | ✅ Covering |
| `idx_txn_contact_list (contactId, isDeleted, isArchived, transactionDate, createdAt)` | `watchTransactionsByContact`, `watchPaginatedTransactions` | ✅ Covering |
| `idx_ledgers_active_list (isDeleted, isArchived, isUserArchived, sortOrder, name)` | `watchAllLedgers` | ✅ Covering |
| `idx_audit_entity_timestamp (entityType, entityId, timestamp)` | `getLogsByEntity` | ✅ Covering |

**`ContactBalances` has NO declared indexes**, but the composite PK `{contactId, currencyCode}` creates an implicit index on `(contactId, currencyCode)` which covers the main lookup pattern. The JOINs in `watchAllBalances` and `watchBalancesByLedger` join on `contactId` which is the leftmost PK column — **this is sufficient; no additional index needed**.

**No new indexes are required for this optimization plan.** The existing composite indexes already cover the bulk UPDATE patterns (the `WHERE contact_id IN (...)` clause uses `idx_txn_contact_list`, and `WHERE ledger_id = ?` uses `idx_contacts_ledger_active_name`).

---

## Verification Plan

### After Step 1 (Balance Recalculation Canonicalization)
```
Test: flutter test test/data/repositories/balance_recalculation_service_test.dart
Assert: Archived transactions excluded, crash-safety verified, stale currencies cleaned
```

### After Step 2 (Bulk Cascade Delete/Restore)
```
Metric: DEVICE_DB_CASCADE_DELETE_50C_500T
Pass Criteria: < 100ms wall time
Test: integration_test/db_on_device_benchmark_test.dart — cascade delete 50C/500T
```

### After Step 3 (Bulk Insert Pipeline)
```
Metric: DEVICE_DB_BULK_CONTACT_INSERT_200
Pass Criteria: < 100ms wall time
Test: integration_test/db_on_device_benchmark_test.dart — bulk insert 200 contacts
```

### After Step 4 (COUNT Queries)
```
Test: flutter test — verify COUNT queries return identical results to .length pattern
Metric: Profile workspace limit checks — expect < 1ms per count call
```

### After Step 6 (Atomicity Fixes)
```
Test: Simulate crash during BalanceRepositoryImpl.recalculate() — verify no data loss
Test: flutter analyze — zero warnings
```

### After Step 7 (Restore Bug)
```
Test: Individually delete T1, cascade-delete contact, restore contact. Assert T1 remains deleted.
```

---

## Execution Order & Dependencies

```
Step 1: Balance Recalculation Canonicalization  ──► No dependencies
Step 2: Bulk Cascade Delete/Restore             ──► Depends on Step 1 (uses canonical recalc)
Step 3: Bulk Insert APIs + Batch Pipeline       ──► Depends on Step 1 (uses canonical recalc)
Step 4: COUNT Query Replacements                ──► No dependencies (can run parallel)
Step 5: Contact Summary JOIN Query              ──► No dependencies (can run parallel)
Step 6: Atomicity + Hygiene Fixes               ──► No dependencies (can run parallel)
Step 7: Contact Restore Bug Fix                 ──► No dependencies (can run parallel)
```

```
CRITICAL PATH:  Step 1 → Step 2 → Step 3
PARALLEL TRACK: Step 4 + Step 5 + Step 6 + Step 7 (independent, any order)
```

> **Total actionable items:** 28  
> **Files modified:** ~18 (12 existing + 3 new + 3 test files)  
> **Schema migrations required:** ZERO  
> **Risk of UI regression:** ZERO — all changes are below the repository interface boundary
