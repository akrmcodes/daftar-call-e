> **Archived — not binding for All Things Agentic (Submission Period 3–31 Aug 2026).**
> Contest execution contract: `docs/roadmap_v2.md`.
> Original date retained for historical accuracy.

# UI Layer Optimization Plan — Operation Glass Frame + Flat Raster

> **Status:** 100% COMPLETE (code) — 2026-06-25  
> **Scope:** Presentation + Application wiring only  
> **Prerequisite:** [DB_OPTIMIZATION_PLAN.md](DB_OPTIMIZATION_PLAN.md) complete

## Summary

Operation Glass Frame eliminates N+1 Riverpod watches, enforces fixed list extents, and reduces scroll-path GPU cost. Operation Flat Raster completes the GPU pass: zero live blur in scroll lists, static glass heroes, and RepaintBoundary discipline — while preserving Khazna v3 Lapis Lux identity on pinned/static surfaces.

## Completed Steps

### Step 1 — Single-Stream Providers
- [x] `GetContactSummariesUseCase` + `WatchContactCountUseCase`
- [x] `contactSummariesByLedgerProvider`, `contactSummariesMapProvider`
- [x] `contactCountProvider` → SQL `COUNT(*)` stream
- [x] Ledger detail: `_ContactTileRow` with zero per-tile watches
- [x] `CreditLimitBanner` accepts pre-resolved contact/balances

### Step 2 — Fixed Extents & Slivers
- [x] `AppDimensions.contactListTileExtent` (+ transaction extents at 92dp)
- [x] Ledger detail: `SliverFixedExtentList` + `findChildIndexCallback`
- [x] Contact detail: fixed-height transaction blocks + stride tokens
- [x] Contact detail: pagination restored (`NotificationListener` + post-frame `loadMore`)

### Step 3 — GPU Budget (final)
- [x] Scroll list tiles: flat `borderSubtle` + `AppGlows.listTileEdge` (blur ≤ 2); zero `BackdropFilter`
- [x] `listTileFloat` removed from scroll paths; `listTileEdge` token added
- [x] `ScrollAwareGlassScope` removed; `scroll_aware_glass.dart` deleted
- [x] `BalanceCard`: opaque `surface2` / `surface1Light` hero in scroll sliver (no glass); modular `balance_card/` package; lapis trace optimized + isolated via `RepaintBoundary`
- [x] Scroll-path banners (`CreditLimit`, `ArchivedReadOnly`, vault hero): static fill, no live blur
- [x] `TransactionListTile`: `GestureDetector` press model (no `Material`/`InkWell` splash layer)
- [x] Per-item `RepaintBoundary` removed from contact + transaction lists
- [x] `EmptyState` icon cached via `RepaintBoundary` + micro-shadow
- [x] Pinned ledger back button: `khazaFloat` behind `RepaintBoundary` (static chrome)

### Step 4 — Pipeline Memoization
- [x] `LedgerContactListPipeline` with screen-level cache
- [x] Removed `_balanceCache` side channel

### Step 5 — Animation Discipline
- [x] Mount-only stagger via `_animatedContactIds` + `StatefulWidget`
- [x] `AnimatedFlipCounter` always active in `BalanceCard` (no scroll gating)

### Step 6 — Verification
- [x] Static verification: `flutter analyze` + balance card widget tests
- [ ] Tier 3 device benchmark — see [PERFORMANCE_TELEMETRY_RUNBOOK.md](PERFORMANCE_TELEMETRY_RUNBOOK.md)

```bash
flutter test integration_test/ui_scroll_benchmark_test.dart \
  -d <DEVICE_ID> --no-pub --profile
```

---

## Operation Flat Raster — GPU Jank Eradication (Final Pass)

> **Status:** Implemented (2026-06-25)

Strips scroll-path GPU bottlenecks while keeping premium depth on pinned/static widgets (`main_shell` dock, pinned header delegate, back button with `RepaintBoundary`).

### Key files

| File | Change |
|------|--------|
| `app_glows.dart` | `listTileEdge` (blur 2); `listTileFloat` removed |
| `contact_list_tile.dart`, `ledger_list_tile.dart` | Flat border-only tiles |
| `transaction_list_tile.dart` | `GestureDetector` + `AnimatedScale` |
| `balance_card.dart` | Static glass, no `BackdropFilter` |
| `home_screen.dart`, `ledger_detail_screen.dart` | `ScrollAwareGlassScope` removed |
| `credit_limit_banner.dart`, `archived_ledger_read_only_banner.dart` | Static semantic fill |
| `contact_detail_screen.dart` | Flat vault hero; pagination preserved |
| `empty_state.dart` | `RepaintBoundary` on icon halo |
| `scroll_aware_glass.dart` | Deleted |
