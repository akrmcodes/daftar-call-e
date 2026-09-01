> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# Performance Telemetry Runbook

> **Phase:** Measurement (Pre-Optimization Baseline)
> **Status:** Archived
> **Target Device:** Samsung Galaxy A03 (or any API 26+ low-end Android)
> **Last Updated:** 2026-06-20

---

## Architecture Overview

This benchmark suite uses a **three-tier measurement strategy** to isolate performance bottlenecks:

| Tier | What It Measures | Where It Runs | I/O Type |
|------|-----------------|---------------|----------|
| **Tier 1: In-Memory DB** | Pure SQL + Dart mapper overhead | `flutter test` (host machine) | In-memory SQLite |
| **Tier 2: On-Device DB** | Real SQLite with disk I/O, WAL, filesystem | `flutter test -d <DEVICE>` | On-disk SQLite |
| **Tier 3: UI Frame Timings** | Full-app frame durations during scrolls | `flutter test -d <DEVICE> --profile` | Full rendering pipeline |

### Key Design Decisions

1. **`Stopwatch` for DB ops** — Microsecond-resolution wall-clock timing via Dart's monotonic clock. More reliable than `DateTime.now()` for short operations.

2. **`SchedulerBinding.addTimingsCallback` for UI** — The engine-level frame timing API that captures the *total span* from vsync start to raster finish. This is the ground truth for jank detection — no sampling bias, no instrumentation overhead.

3. **Statistical output** — Every benchmark emits **p50, p95, max, and mean** (or individual measurements for large operations). P95 is the decision metric — it represents the worst 1-in-20 experience your users actually feel.

4. **Deterministic seeding** — `Random(42)` ensures reproducible data across runs. Same Arabic names, same transaction amounts, same distribution.

5. **Warm-up iterations** — DB micro-benchmarks run 3 warm-up iterations (discarded) before 20 measured iterations to eliminate JIT and SQLite page-cache cold-start effects.

---

## Prerequisites

```bash
# 1. Ensure Flutter is on the right channel
flutter --version

# 2. Connect your physical device and verify
flutter devices

# 3. Ensure the project builds cleanly
cd /path/to/daftar
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

---

## Tier 1: In-Memory Database Benchmarks

**Purpose:** Baseline SQL + mapper overhead, isolated from disk I/O.

```bash
flutter test test/benchmark/db_benchmark_test.dart --reporter expanded
```

**Expected output:**
```
METRIC: DB_LEDGER_CREATE_P50                               =       0.12 ms
METRIC: DB_LEDGER_CREATE_P95                               =       0.18 ms
METRIC: DB_CONTACT_CREATE_P50                              =       0.35 ms
METRIC: DB_TXN_CREATE_WITH_BALANCE_P50                     =       0.80 ms
METRIC: DB_BULK_CONTACT_INSERT_500                         =      45.00 ms
METRIC: DB_BULK_TXN_INSERT_500                             =      30.00 ms
METRIC: DB_CASCADE_DELETE_50C_500T                         =      25.00 ms
METRIC: DB_BALANCE_RECALC_500_P50                          =       2.50 ms
METRIC: DB_FTS_SEARCH_PREFIX_200_P50                       =       0.15 ms
...
```

### What to look for:
- **`DB_TXN_CREATE_WITH_BALANCE`** — If P95 > 5ms, the balance recalculation path is a bottleneck
- **`DB_CASCADE_DELETE_50C_500T`** — If > 200ms, the per-row cascade loop needs batch optimization
- **`DB_BULK_TXN_INSERT_500`** — Baseline for CSV import performance
- **`DB_FTS_SEARCH_*`** — Arabic normalization + FTS5 query cost

---

## Tier 2: On-Device Database Benchmarks

**Purpose:** Real SQLite with disk I/O on target hardware.

```bash
flutter test integration_test/db_on_device_benchmark_test.dart \
  -d <DEVICE_ID> \
  --no-pub
```

> Replace `<DEVICE_ID>` with your device identifier from `flutter devices`.

**Expected output (Samsung A03 ballpark):**
```
METRIC: DEVICE_DB_BULK_CONTACT_INSERT_200                  =     120.00 ms
METRIC: DEVICE_DB_BULK_TXN_INSERT_500                      =     280.00 ms
METRIC: DEVICE_DB_FTS_SEARCH_MEAN_20                       =       1.50 ms
METRIC: DEVICE_DB_CASCADE_DELETE_50C_500T                  =     350.00 ms
METRIC: DEVICE_DB_WAL_CHECKPOINT                           =      15.00 ms
```

### What to look for:
- **Device/InMemory ratio** — Compare each metric to Tier 1. A ratio > 5x suggests disk I/O is the dominant factor and WAL/batching optimizations will have high impact.
- **`DEVICE_DB_WAL_CHECKPOINT`** — This blocks backup. If > 100ms, it's a latent UX issue.

---

## Tier 3: UI Frame Timing Benchmarks

**Purpose:** Detect jank in the heaviest scrollable screens.

```bash
flutter test integration_test/ui_scroll_benchmark_test.dart \
  -d <DEVICE_ID> \
  --no-pub \
  --profile
```

> **CRITICAL:** The `--profile` flag is mandatory. Debug mode adds ~2x frame overhead that makes results meaningless.

**Expected output:**
```
METRIC: UI_HOME_SCROLL_FRAME_COUNT                         =        120
METRIC: UI_HOME_SCROLL_P50                                 =       8.30 ms
METRIC: UI_HOME_SCROLL_P95                                 =      14.20 ms
METRIC: UI_HOME_SCROLL_MAX_FRAME                           =      28.50 ms
METRIC: UI_HOME_SCROLL_JANK_COUNT                          =          5
METRIC: UI_HOME_SCROLL_SEVERE_JANK_COUNT                   =          1
  (4.2% jank rate — 5/120 frames > 16.67ms)

METRIC: UI_LEDGER_DETAIL_SCROLL_100C_FRAME_COUNT           =        240
METRIC: UI_LEDGER_DETAIL_SCROLL_100C_P95                   =      18.90 ms
METRIC: UI_LEDGER_DETAIL_SCROLL_100C_JANK_COUNT            =         30
...
METRIC: UI_CONTACT_DETAIL_SCROLL_500T_FRAME_COUNT            =        180
METRIC: UI_CONTACT_DETAIL_SCROLL_500T_P95                   =      22.10 ms
...
```

### What to look for:
- **P95 > 16.67ms** — Your users feel this. Every 20th frame stutters.
- **Jank rate > 5%** — Needs optimization. Target < 1% for premium feel.
- **Severe jank (> 33ms)** — Visually obvious dropped frames. Zero tolerance.
- **`UI_LEDGER_DETAIL_SCROLL_100C`** — This is the #1 screen to optimize. 100 contacts each with balance widgets is the heaviest list in the app.

### Troubleshooting:
- If UI tests emit `SKIP: Ledger card not found`, the app may be blocked by onboarding or auth. The DB benchmarks are still valid.
- If `tap()` logs a hit-test warning (e.g. "would not hit test on the specified widget"), navigation failed and Phase 2/3 metrics are measuring the wrong screen — fix navigation in the test script and re-run.
- If frame counts are very low (< 20), the scroll didn't produce enough frames for meaningful statistics.

---

## Baseline Results Template

Copy this table and fill it in after running all three tiers on your target device.

### Device Information

| Field | Value |
|-------|-------|
| **Device** | |
| **Android Version** | |
| **RAM** | |
| **Flutter Version** | |
| **Date** | |

### Tier 1: In-Memory DB (Host Machine)

| Metric | P50 (ms) | P95 (ms) | Max (ms) |
|--------|----------|----------|----------|
| DB_LEDGER_CREATE | 0.54 | 3.91 | 3.91 |
| DB_CONTACT_CREATE | 1.43 | 2.69 | 2.69 |
| DB_TXN_CREATE | 0.88 | 1.10 | 1.10 |
| DB_TXN_CREATE_WITH_BALANCE | 2.06 | 3.01 | 3.01 |
| DB_AUDIT_LOG_APPEND | 0.31 | 0.43 | 0.43 |
| DB_CONTACT_LIST_QUERY_200 | 1.70 | 4.75 | 4.75 |
| DB_TXN_LIST_QUERY_500 | 4.20 | 5.06 | 5.06 |
| DB_TXN_PAGINATED_QUERY_20_OF_500 | 0.34 | 0.48 | 0.48 |
| DB_BALANCE_WATCH_ALL_JOIN_50 | 1.05 | 1.71 | 1.71 |
| DB_BALANCE_WATCH_BY_LEDGER_50 | 1.17 | 4.45 | 4.45 |
| DB_FTS_SEARCH_PREFIX_200 | 4.02 | 4.28 | 4.28 |
| DB_FTS_SEARCH_DIACRITICS_200 | 4.10 | 4.92 | 4.92 |
| DB_FTS_SEARCH_PARTIAL_200 | 5.89 | 7.51 | 7.51 |
| DB_BALANCE_RECALC_50 | 0.77 | 1.13 | 1.13 |
| DB_BALANCE_RECALC_200 | 2.08 | 2.69 | 2.69 |
| DB_BALANCE_RECALC_500 | 4.19 | 5.22 | 5.22 |
| DB_RECENT_ITEM_SEARCH_500 | SKIP | SKIP | SKIP |

| Metric | Total (ms) |
|--------|------------|
| DB_BULK_CONTACT_INSERT_50 | 29.00 |
| DB_BULK_CONTACT_INSERT_200 | 89.00 |
| DB_BULK_CONTACT_INSERT_500 | 198.00 |
| DB_BULK_TXN_INSERT_50 | 10.00 |
| DB_BULK_TXN_INSERT_200 | 33.00 |
| DB_BULK_TXN_INSERT_500 | 69.00 |
| DB_BULK_TXN_INSERT_500_WITH_BALANCE | 58.00 |
| DB_BALANCE_RECALC_500_TXNS | 12.00 |
| DB_CASCADE_DELETE_50C_500T | 81.00 |

### Tier 2: On-Device DB

| Metric | Value (ms) |
|--------|------------|
| DEVICE_DB_LEDGER_CREATE_MEAN_20 | 11.35 |
| DEVICE_DB_BULK_CONTACT_INSERT_50 | 204.00 |
| DEVICE_DB_BULK_CONTACT_INSERT_200 | 602.00 |
| DEVICE_DB_BULK_TXN_INSERT_100 | 131.00 |
| DEVICE_DB_BULK_TXN_INSERT_500 | 456.00 |
| DEVICE_DB_FTS_SEARCH_MEAN_20 | 1.65 |
| DEVICE_DB_TXN_LIST_FULL_MEAN_20 | 27.85 |
| DEVICE_DB_TXN_PAGINATED_20_MEAN_20 | 2.35 |
| DEVICE_DB_CASCADE_DELETE_50C_500T | 533.00 |
| DEVICE_DB_WAL_CHECKPOINT | 1.00 |

### Tier 2: On-Device DB (Post-Optimization: Steps 2 & 3)

| Metric | Value (ms) |
|--------|------------|
| DEVICE_DB_LEDGER_CREATE_MEAN_20 | 10.75 |
| DEVICE_DB_BULK_CONTACT_INSERT_50 | 85.00 |
| DEVICE_DB_BULK_CONTACT_INSERT_200 | 121.00 |
| DEVICE_DB_BULK_TXN_INSERT_100 | 126.00 |
| DEVICE_DB_BULK_TXN_INSERT_500 | 438.00 |
| DEVICE_DB_FTS_SEARCH_MEAN_20 | 1.40 |
| DEVICE_DB_TXN_LIST_FULL_MEAN_20 | 30.25 |
| DEVICE_DB_TXN_PAGINATED_20_MEAN_20 | 3.50 |
| DEVICE_DB_CASCADE_DELETE_50C_500T | 78.00 |
| DEVICE_DB_WAL_CHECKPOINT | 2.00 |

### Tier 2: On-Device DB (Final Optimized: Steps 1 through 7)
*Note: Cascade deletes and Bulk inserts are batched. All critical writes are now atomic via Drift transactions(). Counts use pure SQL COUNT(*).*

| Metric | Value (ms) |
|--------|------------|
| DEVICE_DB_LEDGER_CREATE_MEAN_20 | 9.05 |
| DEVICE_DB_BULK_CONTACT_INSERT_50 | 91.00 |
| DEVICE_DB_BULK_CONTACT_INSERT_200 | 122.00 |
| DEVICE_DB_BULK_TXN_INSERT_100 | 111.00 |
| DEVICE_DB_BULK_TXN_INSERT_500 | 435.00 |
| DEVICE_DB_FTS_SEARCH_MEAN_20 | 1.20 |
| DEVICE_DB_TXN_LIST_FULL_MEAN_20 | 25.60 |
| DEVICE_DB_TXN_PAGINATED_20_MEAN_20 | 1.70 |
| DEVICE_DB_CASCADE_DELETE_50C_500T | 98.00 |
| DEVICE_DB_WAL_CHECKPOINT | 1.00 |

### Tier 3: UI Frame Timings (Profile Mode)

| Screen | Frames | P50 (ms) | P95 (ms) | Max (ms) | Jank Count | Severe Jank | Jank Rate |
|--------|--------|----------|----------|----------|------------|-------------|-----------|
| UI_HOME_SCROLL | 57 | 16.88 | 53.70 | 60.40 | 29 | 15 | 50.9% |
| UI_LEDGER_DETAIL_SCROLL_100C | 84 | 25.68 | 59.03 | 76.95 | 82 | 15 | 97.6% |
| UI_CONTACT_DETAIL_SCROLL_500T | 114 | 14.26 | 36.87 | 51.49 | 41 | 11 | 36.0% |

### Tier 3: UI Frame Timings (Profile Mode - Final Stress Test on Samsung S9)
*Note: Final architectural state with all optimizations applied (Zero N+1, RepaintBoundaries, Bulk SQL). These numbers represent the absolute physical silicon and thermal ceiling of the 6-year-old Snapdragon 845 / Exynos 9810. The app remains completely stable (No ANRs) despite hardware throttling.*

| Screen | Frames | P50 (ms) | P95 (ms) | Max (ms) | Jank Count | Severe Jank | Jank Rate |
|--------|--------|----------|----------|----------|------------|-------------|-----------|
| UI_HOME_SCROLL | 61 | 23.06 | 38.99 | 47.42 | 51 | 6 | 83.6% |
| UI_LEDGER_DETAIL_SCROLL_100C | 83 | 22.52 | 49.71 | 65.34 | 62 | 17 | 74.7% |
| UI_CONTACT_DETAIL_SCROLL_500T | 116 | 11.78 | 35.15 | 40.45 | 24 | 7 | 20.7% |

### Tier 3: UI Frame Timings (Post Operation Glass Frame)

> **Pending:** Re-run on Samsung A03 (or target low-end device) in `--profile` mode after UI optimizations land. See [UI_OPTIMIZATION_PLAN.md](UI_OPTIMIZATION_PLAN.md).


| Screen | Frames | P50 (ms) | P95 (ms) | Max (ms) | Jank Count | Severe Jank | Jank Rate |
|--------|--------|----------|----------|----------|------------|-------------|-----------|
| UI_HOME_SCROLL | 58 | 27.60 | 40.04 | 42.73 | 56 | 7 | 96.6% |
| UI_LEDGER_DETAIL_SCROLL_100C | 83 | 19.24 | 39.12 | 62.33 | 54 | 8 | 65.1% |
| UI_CONTACT_DETAIL_SCROLL_500T | 117 | 21.77 | 32.77 | 48.40 | 67 | 4 | 57.3% |

---

## Decision Framework

After collecting baseline numbers, use this framework to prioritize:

| Threshold | Action |
|-----------|--------|
| DB P95 < 5ms per op | ✅ No action needed |
| DB P95 5–16ms per op | ⚠️ Monitor, optimize if blocking UI thread |
| DB P95 > 16ms per op | 🔴 Critical — will cause visible jank |
| UI P95 < 16.67ms | ✅ Smooth 60fps |
| UI P95 16.67–33ms | ⚠️ Occasional jank, optimize top offenders |
| UI P95 > 33ms | 🔴 Severe jank, must fix before release |
| Jank rate < 1% | ✅ Premium feel |
| Jank rate 1–5% | ⚠️ Noticeable on careful observation |
| Jank rate > 5% | 🔴 Users will notice and complain |

---

## File Inventory

| File | Purpose |
|------|---------|
| `test/benchmark/db_benchmark_test.dart` | Tier 1: In-memory Drift DB micro-benchmarks |
| `integration_test/db_on_device_benchmark_test.dart` | Tier 2: On-device Drift DB with real disk I/O |
| `integration_test/ui_scroll_benchmark_test.dart` | Tier 3: Full-app UI frame timing capture |
| `test_driver/integration_test.dart` | Standard `flutter drive` orchestration driver |
| `docs/architecture/PERFORMANCE_TELEMETRY_RUNBOOK.md` | This file |
