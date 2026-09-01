> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Performance Optimization Roadmap

> **Generated from:** CTO baseline telemetry results, 2026-06-20
> **Codename:** Operation Scalpel — Surgical Performance Triage
> **Status:** PLAN ONLY — Awaiting CTO approval before execution

---

## Executive Summary

The baseline telemetry reveals three crisis zones:

| Zone | Metric | Measured | Target | Severity |
|---|---|---|---|---|
| **UI — Ledger Detail** | `UI_LEDGER_DETAIL_SCROLL_100C` P95 | **59.03ms** (97.6% jank) | < 16.67ms | 🔴 CRITICAL |
| **UI — Home Screen** | `UI_HOME_SCROLL` P95 | **53.70ms** (50.9% jank) | < 16.67ms | 🔴 CRITICAL |
| **DB — Cascade Delete** | `DEVICE_DB_CASCADE_DELETE_50C_500T` | **533ms** | < 100ms | 🟠 HIGH |
| **DB — Bulk Insert** | `DEVICE_DB_BULK_CONTACT_INSERT_200` | **602ms** | < 100ms | 🟠 HIGH |

---

## Root Cause Analysis

### Why is `UI_LEDGER_DETAIL_SCROLL_100C` at 59.03ms P95 (97.6% jank)?

The Ledger Detail screen ([ledger_detail_screen.dart](../../lib/presentation/screens/ledger/ledger_detail_screen.dart)) has **five compounding defects** that turn every frame into a computational firestorm:

1. **O(n) Arabic normalization in `build()`** — Lines 338–370: The search→filter→sort pipeline calls `normalizeArabic().toLowerCase()` on *every contact name* on *every rebuild*. With 100 contacts, that's 100+ Unicode normalization passes per frame. The `_sortKey()` method (L727–729) compounds this — `normalizeArabic().toLowerCase()` runs O(n log n) times during the sort comparator.

2. **N+1 Provider Waterfalls** — Lines 917–918: Each `_ContactTileWithData` widget individually watches `contactBalanceProvider(contact.id)` and `transactionCountProvider(contact.id)`. With 100 contacts visible, that's **200 independent stream subscriptions**, each potentially triggering a rebuild of its tile, which cascades into the parent's layout.

3. **Side effect inside `build()`** — Line 929: `onBalanceResolved(contact.id, netBalance)` writes to the parent's `_balanceCache` Map during the build phase. While technically not calling `setState`, this is a code smell that creates temporal coupling between child builds and parent filter logic.

4. **Animation controller allocation per rebuild** — Lines 948–960: `flutter_animate`'s `.animate().fadeIn().slideY()` chain creates new animation controllers on every rebuild, not just the initial mount. This allocates GPU-bound resources during scroll.

5. **Dual `ledgersProvider` watches** — Lines 144 and 152: The same `ref.watch(ledgersProvider)` (the entire ledger list) is watched *twice* in the build method for fallback logic, doubling subscription overhead.

### Why is `UI_HOME_SCROLL` at 53.70ms P95 (50.9% jank)?

The Home Screen ([home_screen.dart](../../lib/presentation/screens/home/home_screen.dart)) is architecturally leaner, but is killed by one anti-pattern:

1. **`contactCountProvider` materializes full contact lists** — [contact_providers.dart:146–148](../../lib/presentation/providers/contact_providers.dart#L146-L148): `contactCountProvider` calls `ref.watch(contactsProvider(ledgerId))` then `.asData?.value.length`. This deserializes **every contact row** from SQLite into Dart objects just to count them. With 5 ledgers × 100 contacts each, that's 500 contact objects materialized every time any contact stream fires.

2. **`_countActiveContacts()` row materialization** — [contact_repository_impl.dart:389–397](../../lib/data/repositories/contact_repository_impl.dart#L389-L397): Uses `SELECT * ... .get()` then `.length` instead of `SELECT COUNT(*)`. Same pattern in `getArchivedCount()` (L401–414) and `LedgerRepositoryImpl._countActiveLedgers()`.

### Why is `DEVICE_DB_BULK_CONTACT_INSERT_200` at 602ms?

1. **No `batch()` implementation exists** — `ContactLocalDataSource` only has `createContact()` for single-row inserts. The CSV import use case ([import_csv_use_case.dart:319–441](../../lib/application/import/import_csv_use_case.dart#L319-L441)) loops row-by-row, calling the full `CreateContactUseCase.execute()` → Repository → DataSource → individual INSERT per row. Each row also triggers FTS index upsert + audit log append. For 200 contacts: **600+ sequential SQL statements** (INSERT + FTS + Audit × 200).

2. **Drift `batch()` is only used in migration seeding** — [drift_database.dart:216](../../lib/data/datasources/local/drift_database.dart#L216) for currencies. No batch APIs exist for contacts or transactions.

### Why is `DEVICE_DB_CASCADE_DELETE_50C_500T` at 533ms?

1. **O(2n) per-transaction cascade** — [contact_repository_impl.dart:273–277](../../lib/data/repositories/contact_repository_impl.dart#L273-L277): Each transaction is soft-deleted by calling `_transactionLocalDataSource.deleteTransaction(id)`, which internally does a `getTransactionById()` (SELECT) then `updateTransaction()` (UPDATE) — **2 SQL operations per transaction**. For 50 contacts × 10 transactions each = **1,000 SQL round-trips** inside a single `transaction()` block.

2. **No bulk UPDATE** — The ideal pattern is a single `UPDATE transactions SET is_deleted = 1, updated_at = ?, sync_version = sync_version + 1 WHERE contact_id IN (...)`, replacing 1,000 operations with 1.

---

## Phase 1: Ledger Detail UI Jank — CRITICAL

> **Target:** Reduce `UI_LEDGER_DETAIL_SCROLL_100C` from 59.03ms P95 / 97.6% jank to < 16.67ms P95 / < 5% jank

### Task 1.1 — Memoize the Search/Filter/Sort Pipeline

**File:** [ledger_detail_screen.dart](../../lib/presentation/screens/ledger/ledger_detail_screen.dart) L338–370, L727–729
**Metric:** `UI_LEDGER_DETAIL_SCROLL_100C`

**Problem:** `normalizeArabic().toLowerCase()` runs O(n) per build (search filter) + O(n log n) per build (sort comparator). With 100 contacts, this is ~700+ Unicode normalization calls per frame.

**Fix:**
- Pre-compute a `Map<String, String> _normalizedNameCache` keyed by `contact.id`. Invalidate only when the contacts list reference changes.
- Cache `_sortedContacts` as a field. Recompute only when `_searchQuery`, `_currentFilter`, `_currentSortMode`, or the contacts list identity changes.
- Move the pipeline out of `build()` into a dedicated `_recomputePipeline()` called from `didChangeDependencies()` or a `ref.listen()` callback.

**Expected Impact:** Eliminates ~700 `normalizeArabic()` calls per frame → ~0 during scroll. Frame time contribution: **-15–25ms**.

---

### Task 1.2 — Eliminate N+1 Provider Watches in Contact Tiles

**File:** [ledger_detail_screen.dart](../../lib/presentation/screens/ledger/ledger_detail_screen.dart) L917–918 (`_ContactTileWithData`)
**Metric:** `UI_LEDGER_DETAIL_SCROLL_100C`

**Problem:** Each of 100 tiles watches `contactBalanceProvider(contact.id)` + `transactionCountProvider(contact.id)` = 200 stream subscriptions. Each subscription fires independently, causing cascading rebuilds.

**Fix:**
- Create a single `ledgerContactSummariesProvider(ledgerId)` that returns a `Map<String, ContactSummary>` containing balance + count for all contacts in one query.
- Use a single SQL `JOIN` query:
  ```sql
  SELECT c.id, cb.net_balance, cb.currency_code,
         (SELECT COUNT(*) FROM transactions t
          WHERE t.contact_id = c.id AND t.is_deleted = 0) AS txn_count
  FROM contacts c
  LEFT JOIN contact_balances cb ON c.id = cb.contact_id
  WHERE c.ledger_id = ? AND c.is_deleted = 0
  ```
- Pass pre-resolved data to tiles as constructor params. Tiles become `StatelessWidget` — zero provider watches.

**Expected Impact:** 200 stream subscriptions → 1. Frame time contribution: **-20–30ms**.

---

### Task 1.3 — Gate Stagger Animations to Initial Mount Only

**File:** [ledger_detail_screen.dart](../../lib/presentation/screens/ledger/ledger_detail_screen.dart) L948–960
**Metric:** `UI_LEDGER_DETAIL_SCROLL_100C`

**Problem:** `flutter_animate`'s `.animate().fadeIn().slideY()` chain runs on every rebuild, not just the first mount. During scroll, off-screen tiles are recycled and rebuilt, triggering animation controller allocation + GPU composition for the entrance effect.

**Fix:**
- Track whether the initial entrance animation has completed using a `ValueNotifier<bool>` or `Set<String>` of animated contact IDs.
- After the first animation completes, skip the `.animate()` chain entirely and render the tile directly.
- Alternative: Use `AnimateList` with `autoPlay: false` + explicit trigger on first visible.

**Expected Impact:** Eliminates animation controller allocation during scroll. Frame time contribution: **-5–10ms**.

---

### Task 1.4 — Remove Side Effect from `build()`

**File:** [ledger_detail_screen.dart](../../lib/presentation/screens/ledger/ledger_detail_screen.dart) L929
**Metric:** `UI_LEDGER_DETAIL_SCROLL_100C`

**Problem:** `onBalanceResolved(contact.id, netBalance)` writes to the parent's `_balanceCache` Map during the build phase.

**Fix:** With Task 1.2 (single summary provider), the `_balanceCache` becomes unnecessary. Remove the callback entirely. If the cache is still needed, populate it via `ref.listen()` in the parent, not via child build callbacks.

**Expected Impact:** Eliminates N write operations during build phase. Negligible frame time impact, but critical for correctness.

---

### Task 1.5 — Deduplicate `ledgersProvider` Watches

**File:** [ledger_detail_screen.dart](../../lib/presentation/screens/ledger/ledger_detail_screen.dart) L144, L152
**Metric:** `UI_LEDGER_DETAIL_SCROLL_100C`

**Problem:** `ref.watch(ledgersProvider)` is called twice in the build method — once for fallback loading, once for `sourceLedger` derivation.

**Fix:** Resolve once at the top of the build method: `final ledgersList = ref.watch(ledgersProvider);`. Use the local variable for both derivations.

**Expected Impact:** Minor — eliminates one redundant stream subscription. Frame time contribution: **~1ms**.

---

## Phase 2: Home Screen UI Jank — CRITICAL

> **Target:** Reduce `UI_HOME_SCROLL` from 53.70ms P95 / 50.9% jank to < 16.67ms P95 / < 5% jank

### Task 2.1 — Replace `contactCountProvider` with SQL COUNT(*)

**File:** [contact_providers.dart](../../lib/presentation/providers/contact_providers.dart) L146–148
**Metric:** `UI_HOME_SCROLL`

**Problem:** `contactCountProvider` calls `ref.watch(contactsProvider(ledgerId))` then `.asData?.value.length`. This deserializes ALL contact objects from SQLite just to count them.

**Fix:**
- Add `Stream<int> watchContactCountByLedger(String ledgerId)` to `ContactLocalDataSource` using:
  ```sql
  SELECT COUNT(*) AS cnt FROM contacts
  WHERE ledger_id = ? AND is_deleted = 0 AND is_archived = 0
  ```
- Wire through Repository → Use Case → Provider.
- Replace `contactCountProvider` to watch the `Stream<int>` directly.

**Expected Impact:** Eliminates N×100 row deserializations per ledger tile. Frame time contribution: **-25–35ms**.

---

### Task 2.2 — Replace Row-Materialization COUNT Anti-Patterns in Repositories

**Files:**
- [contact_repository_impl.dart](../../lib/data/repositories/contact_repository_impl.dart) L389–397 (`_countActiveContacts`)
- [contact_repository_impl.dart](../../lib/data/repositories/contact_repository_impl.dart) L401–414 (`getArchivedCount`)
- `LedgerRepositoryImpl._countActiveLedgers()`, `getArchivedCount()`

**Metric:** `UI_HOME_SCROLL`, workspace limit checks

**Problem:** `SELECT * ... .get()` then `.length` materializes all rows into Dart objects.

**Fix:** Replace with `SELECT COUNT(*) AS cnt ... .getSingle()` → `row.read<int>('cnt')`. Follow the pattern already used in [transaction_local_ds.dart:143–152](../../lib/data/datasources/local/transaction_local_ds.dart#L143-L152) (`watchTransactionCountByContact`).

**Expected Impact:** Eliminates O(n) object construction for count queries. ~5ms per count call.

---

## Phase 3: Database I/O — Cascade Delete

> **Target:** Reduce `DEVICE_DB_CASCADE_DELETE_50C_500T` from 533ms to < 100ms

### Task 3.1 — Bulk Soft-Delete Transactions via Single UPDATE

**File:** [contact_repository_impl.dart](../../lib/data/repositories/contact_repository_impl.dart) L273–277
**Metric:** `DEVICE_DB_CASCADE_DELETE_50C_500T`

**Problem:** Each transaction is soft-deleted via `deleteTransaction(id)` which does SELECT + UPDATE per row. For 500 transactions: 1,000 SQL round-trips.

**Fix:**
- Add `bulkSoftDeleteByContactId(String contactId)` to `TransactionLocalDataSource`:
  ```dart
  Future<int> bulkSoftDeleteByContactId(String contactId) async {
    return (database.update(database.transactions)
          ..where((t) => t.contactId.equals(contactId))
          ..where((t) => t.isDeleted.equals(false)))
        .write(TransactionsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now().toUtc()),
          syncVersion: const CustomExpression('sync_version + 1'),
        ));
  }
  ```
- Replace the loop in `ContactRepositoryImpl.delete()` with a single call.
- Add a batch audit log entry recording the count of cascaded deletes.

**Expected Impact:** 1,000 SQL operations → 1. Target: **< 50ms** for the transaction cascade portion.

---

### Task 3.2 — Bulk Soft-Delete Contacts in Ledger Cascade

**File:** `ledger_repository_impl.dart` L196–219
**Metric:** `DEVICE_DB_CASCADE_DELETE_50C_500T`

**Problem:** Ledger cascade delete loops through contacts and transactions one-by-one with individual UPDATE statements.

**Fix:**
- Add `bulkSoftDeleteByLedgerId(String ledgerId)` for contacts.
- Add `bulkSoftDeleteByContactIds(List<String> contactIds)` for transactions.
- Use `WHERE contact_id IN (SELECT id FROM contacts WHERE ledger_id = ? AND is_deleted = 0)` for a single-statement cascade.
- Batch FTS index removal: `DELETE FROM contact_fts WHERE rowid IN (...)`.

**Expected Impact:** O(n + m) individual UPDATEs → 2–3 bulk statements. Target: **< 80ms total** for 50C/500T.

---

## Phase 4: Database I/O — Bulk Insert

> **Target:** Reduce `DEVICE_DB_BULK_CONTACT_INSERT_200` from 602ms to < 100ms

### Task 4.1 — Implement Drift `batch()` for Contact Inserts

**File:** [contact_local_ds.dart](../../lib/data/datasources/local/contact_local_ds.dart)
**Metric:** `DEVICE_DB_BULK_CONTACT_INSERT_200`

**Problem:** No bulk insert API exists. Each contact insert is a separate `INTO ... INSERT` statement with its own transaction commit.

**Fix:**
- Add `bulkCreateContacts(List<ContactModel> contacts)` using Drift's `batch()`:
  ```dart
  Future<void> bulkCreateContacts(List<ContactModel> contacts) async {
    await database.batch((batch) {
      for (final contact in contacts) {
        batch.insert(database.contacts, contact.toDrift());
      }
    });
  }
  ```
- Add corresponding `bulkCreateTransactions()`.
- Batch FTS index inserts and audit log entries within the same `batch()`.

**Expected Impact:** 600+ individual commits → 1 batch commit. Target: **< 80ms** for 200 contacts.

---

### Task 4.2 — Refactor CSV Import to Use Batch Pipeline

**File:** [import_csv_use_case.dart](../../lib/application/import/import_csv_use_case.dart) L319–441
**Metric:** `DEVICE_DB_BULK_CONTACT_INSERT_200`

**Problem:** The import loop calls `CreateContactUseCase.execute()` per row, which goes through the full use case → repository → data source → individual INSERT pipeline per row.

**Fix:**
- Parse all CSV rows into a `List<ContactModel>` + `List<TransactionModel>` first.
- Call `bulkCreateContacts()` and `bulkCreateTransactions()` from Task 4.1.
- Perform validation (credit limits, duplicates) in the parse phase, not during DB writes.
- Write all audit log entries in a single batch.

**Expected Impact:** Sequential per-row pipeline → single batch. Critical for the import UX.

---

## Phase 5: Immediate Bug Fixes (Completed)

### ✅ Task 5.1 — Fix `searchRecentItems` SQL Column Name Mismatch

**File:** [transaction_local_ds.dart](../../lib/data/datasources/local/transaction_local_ds.dart) L191–241
**Metric:** Autocomplete functionality (broken)

**Problem:** Raw SQL used camelCase Dart property names (`itemName`, `createdAt`, `isDeleted`) instead of the actual snake_case SQLite column names that Drift generates (`item_name`, `created_at`, `is_deleted`).

**Status:** ✅ **FIXED** — All 9 raw SQL column references corrected to snake_case. `SELECT item_name AS itemName` alias preserves the Dart `row.read()` contract.

---

## Verification Plan

### After Phase 1 (Ledger Detail)
```
Metric: UI_LEDGER_DETAIL_SCROLL_100C
Pass Criteria: P95 < 16.67ms, jank_ratio < 5%
Test: Scroll 100-contact ledger on physical device, measure with SchedulerBinding.addTimingsCallback
```

### After Phase 2 (Home Screen)
```
Metric: UI_HOME_SCROLL
Pass Criteria: P95 < 16.67ms, jank_ratio < 5%
Test: Scroll home with 5 ledgers, measure frame timings
```

### After Phase 3 (Cascade Delete)
```
Metric: DEVICE_DB_CASCADE_DELETE_50C_500T
Pass Criteria: < 100ms wall time
Test: Seed 50 contacts × 10 transactions, cascade delete ledger, measure Stopwatch
```

### After Phase 4 (Bulk Insert)
```
Metric: DEVICE_DB_BULK_CONTACT_INSERT_200
Pass Criteria: < 100ms wall time
Test: Bulk insert 200 contacts via batch API, measure Stopwatch
```

---

## Priority Execution Order

```
Phase 5 (Bug Fix)     ████████████████████ DONE
Phase 1 (Ledger UI)   ████████████████████ NEXT — Highest user-visible impact
Phase 2 (Home UI)     ████████████████████ THEN — Second-highest user-visible impact
Phase 3 (DB Cascade)  ████████████████████ THEN — Blocking for ledger management
Phase 4 (DB Bulk)     ████████████████████ LAST — Blocking for CSV import
```

> **Total estimated tasks:** 11 (1 done, 10 remaining)
> **Estimated engineering time:** 3–4 focused sessions
> **Risk:** Zero — all changes are isolated to their respective layers. No schema migrations required.
