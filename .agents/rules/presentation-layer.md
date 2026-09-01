---
trigger: always_on
description: Rules for the presentation layer — Riverpod providers, screens, widgets, UI performance, and reactive data flow patterns.
globs:
  - "**/presentation/**/*.dart"
  - "**/app/**/*.dart"
---

# Presentation Layer Standards

<layer_boundary>
The presentation layer contains Riverpod providers, screens, and widgets.

PERMITTED IMPORTS:
- lib/domain/ (entities, enums, value objects, failures)
- lib/application/ (use cases)
- package:flutter/*
- package:riverpod/*, package:riverpod_annotation/*
- package:go_router/*
- package:flutter_riverpod/*

FORBIDDEN IMPORTS — critical defect if present:
- package:drift/* — never import Drift directly in presentation
- lib/data/* — never import data sources, models, or mappers
- lib/data/datasources/* — access data through providers only
- lib/data/repositories/* — access through use case providers
</layer_boundary>

## Riverpod Provider Standards

<provider_rules>
1. Use @riverpod annotation (code generation) for ALL providers. Never write providers manually.
2. Provider types:
   - AsyncNotifier for stateful data with mutations (CRUD operations)
   - StreamProvider for reactive Drift streams (watchAll(), watchByLedger())
   - FutureProvider for one-shot reads
   - Family providers for parameterized data (e.g., contactsProvider(ledgerId))
3. Provider organization: one file per feature area in lib/presentation/providers/.
4. CRITICAL: Providers call Use Cases — NEVER call repositories directly.
</provider_rules>

<reactive_data_flow>
The reactive data flow pattern:

Drift watch() Stream → StreamProvider → ConsumerWidget rebuilds automatically
Mutation: AsyncNotifier.method() → Use Case → Repository → Drift write → Stream auto-emits

Key rules:
- After a successful mutation, reactive streams auto-update watching providers. Do NOT manually call ref.invalidate() for streaming providers.
- For non-streaming providers, use ref.invalidate() after mutation to trigger refresh.
- Providers expose AsyncValue<T> with loading, data, and error states.
- UI uses asyncValue.when(loading: ..., data: ..., error: ...) for state rendering.
</reactive_data_flow>

<provider_template>
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ledger_providers.g.dart';

/// Watches all non-deleted ledgers, sorted by [sortOrder].
@riverpod
Stream<List<Ledger>> ledgers(LedgersRef ref) {
  final repository = ref.watch(ledgerRepositoryProvider);
  return repository.watchAll();
}

/// Manages ledger creation with loading/error states.
@riverpod
class CreateLedger extends _$CreateLedger {
  @override
  FutureOr<void> build() {}

  Future<void> create(CreateLedgerParams params) async {
    state = const AsyncLoading();
    final useCase = ref.read(createLedgerUseCaseProvider);
    final result = await useCase(params);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (_) => const AsyncData(null),
    );
  }
}
```
</provider_template>

## Error Handling in UI

<ui_errors>
- Error states show localized user-friendly messages via Failure.message, never raw exception strings.
- User-facing error messages always use ARB localization keys.
- Use bottom sheets for error display, not raw dialogs with exception text.
- Global error handler: FlutterError.onError and PlatformDispatcher.instance.onError log to Firebase Crashlytics.
</ui_errors>

## Screen & Widget Standards

<screen_rules>
1. Screens are Stateless where possible. All state lives in Riverpod providers.
2. Screens are grouped by feature under lib/presentation/screens/{feature}/.
3. Screen-specific widgets go in a widgets/ subdirectory.
4. Reusable app-wide widgets go in lib/presentation/shared/widgets/.
5. Reusable animations go in lib/presentation/shared/animations/.
</screen_rules>

<ui_design>
Follow these UX mandates from the product plan:
- Bottom-sheet-centric design — primary interactions use bottom sheets, not full-screen navigations.
- One-handed reachability — all primary actions within the bottom 60% of the screen.
- Minimum tap target: 48dp × 48dp on all interactive elements.
- Haptic feedback on: transaction save, delete undo, PIN button press.
- Skeleton loading (shimmer effect) for all async data — never blank screens.
- Swipe-to-delete with 30-second undo window via snackbar.
- Pull-to-refresh on all list screens.
</ui_design>

## Widget Performance

<widget_performance>
- Use const constructors wherever possible.
- Use ListView.builder (NOT ListView with a children list) for any dynamic list.
- Use RepaintBoundary for expensive subtrees (charts, animated balance cards).
- Implement animated number transitions on balance cards (count-up animation).
- Use page transition animations (shared element transitions for contact → detail).
- Use spring physics for bottom sheet enter/exit animations.
</widget_performance>

## Routing

<routing>
- Use go_router with declarative routing.
- ShellRoute for bottom tab navigation.
- Route names defined as constants in lib/app/router/route_names.dart.
- Deep-link structure must be verified for back-navigation behavior.
</routing>

## Khazna v3 — Lapis Lux (MANDATORY)

<lapis_lux_firewall>
CRITICAL: Lapis is light, not paint.

NEVER set backgroundColor / color fill to AppColors.lapis400 on buttons, cards, FABs, or chips.
NEVER use FilledButton or ElevatedButton with lapis or Theme.colorScheme.primary as a solid blue fill.

PERMITTED lapis usage ONLY:
- AppGlows shadows (glowMd on primary CTA, khazaFloat on dark cards)
- BorderSide(color: AppColors.lapis400, width: 0.5) on DaftarButton primary
- 1.5px focus ring on DaftarTextField
- Info banner background (lapis800 dark / lapis50 light) — sole fill exception

ONE lapis-glow moment per visible screen maximum.
</lapis_lux_firewall>

<mandatory_primitives>
FORBIDDEN: Material Card, FilledButton, ElevatedButton (product CTAs), TextField (product forms), ListTile.

REQUIRED:
- DaftarButton — Primary MUST use surface2/surface1Light fill + lapis400 0.5px border + AppGlows.ctaRest. Text: inkPrimary. HapticService.buttonPress().
- DaftarCard — Dark: surface2 + borderSubtle + AppGlows.khazaFloat + innerTopHighlight. Light: surface1Light + shadowFloat.
- DaftarTextField — surface5 fill; focus border lapis400 1.5px; NOT lapis fill.

Canonical spec: docs/design_system.md
</mandatory_primitives>

<typography_mandate>
All monetary amounts: AppTextStyles.amountHero | amountLarge | amountMedium | amountSmall | amountMicro.
These enforce FontFeature.tabularFigures() + liningFigures(). Never Noto Kufi for numbers.
Wrap amounts in Directionality(textDirection: TextDirection.ltr) inside RTL layouts.
</typography_mandate>

<rtl_geometry_law>
NEVER EdgeInsets.only(left:, right:), Positioned(left/right), Alignment.centerLeft/Right, TextAlign.left/right.
ALWAYS EdgeInsetsDirectional, PositionedDirectional, AlignmentDirectional, TextAlign.start/end.
</rtl_geometry_law>

## Approved UI Packages (geometry, motion, micro-interactions)

| Package | Use For |
|---|---|
| `motor` | Spring physics for sheets, toggles, glow breath (§7.3) |
| `figma_squircle` | iOS continuous corners on DaftarCard/DaftarButton (§5.1) |
| `flutter_slidable` | Swipe-to-delete with semantic colors + haptics (§7.4) |
| `animated_flip_counter` | Hero balance count-up 600ms curveEmphasized (§7.4) |
| `custom_refresh_indicator` | Lapis Arc pull-to-refresh (§7.4) |
| `flutter_animate` | Stagger entrances, press scale (§7.4) |
| `wolt_modal_sheet` | Bottom sheets — not `showModalBottomSheet` |
| `skeletonizer` | Async skeletons |
| `gap` | Directional spacing |

Haptics: `HapticService` only — no third-party haptic packages.

## Theme & Design Tokens

<theme>
Design token files in lib/app/theme/:
- app_colors.dart — Onyx/Bone monochrome, lapis scale, semantic debt/payment (NO gold/teal)
- app_glows.dart — lapis halos and light-mode paired shadows
- app_text_styles.dart — Noto Kufi + Inter tabular numeral scale
- app_dimensions.dart — 8dp grid, tap targets ≥ 48dp, animation tokens
- app_motion.dart — curveEnter, curveEmphasized, curveSheetSpring
- app_theme.dart — Material 3, NoSplash, elevation 0
- lib/core/utils/haptic_service.dart — HapticService (not raw HapticFeedback in widgets)

Dark mode DEFAULT (surface0 = #000000 OLED). Depth via Khazna Float, NOT Material elevation on dark.
</theme>
