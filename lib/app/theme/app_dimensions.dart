/// Daftar spacing, sizing, and dimension tokens.
///
/// All dimensions follow an 8dp base grid system.
/// Minimum tap target is 48dp (Android/Material guidelines + WCAG).
abstract final class AppDimensions {
  // ==========================================================================
  // SPACING (8dp base grid)
  // ==========================================================================

  /// 2dp — micro spacing (icon-to-text within a label).
  static const double spacingXxs = 2;

  /// 4dp — extra-small spacing.
  static const double spacingXs = 4;

  /// 8dp — small spacing (between related elements).
  static const double spacingSm = 8;

  /// 12dp — medium-small spacing.
  static const double spacingMd = 12;

  /// 16dp — medium spacing (standard padding).
  static const double spacingLg = 16;

  /// 20dp — medium-large spacing.
  static const double spacingXl = 20;

  /// 24dp — large spacing (section gaps).
  static const double spacingXxl = 24;

  /// 32dp — extra-large spacing.
  static const double spacing3xl = 32;

  /// 40dp — 2x extra-large.
  static const double spacing4xl = 40;

  /// 48dp — 3x extra-large.
  static const double spacing5xl = 48;

  /// 64dp — hero spacing.
  static const double spacing6xl = 64;

  // ==========================================================================
  // PADDING
  // ==========================================================================

  /// Standard horizontal page padding.
  static const double pagePaddingH = 16;

  /// Standard vertical page padding.
  static const double pagePaddingV = 16;

  /// Card content padding.
  static const double cardPadding = 16;

  /// Bottom sheet content padding.
  static const double bottomSheetPadding = 20;

  /// List tile horizontal padding.
  static const double listTilePaddingH = 16;

  /// List tile vertical padding.
  static const double listTilePaddingV = 12;

  /// Fixed extent for ledger contact rows (tile + inter-row gap).
  ///
  /// Measured: `listTilePaddingV`×2 + ~44dp content + `spacingMd` gap.
  static const double contactListTileExtent = 80;

  /// Fixed extent for contact-detail transaction rows (icon row only).
  ///
  /// Measured: `spacingLg`×2 padding (32) + max(44dp icon, ~60dp details
  /// with description, 48dp menu tap target) ≈ 92dp.
  static const double transactionListTileExtent = 92;

  /// Fixed extent for relative date group headers in transaction lists.
  static const double transactionDateGroupHeaderExtent = 48;

  /// Fixed extent for transaction list dividers.
  static const double transactionListDividerExtent = 1;

  /// Maximum stride for a transaction block (header + tile).
  static const double transactionListTileStrideExtent =
      transactionDateGroupHeaderExtent + transactionListTileExtent;

  /// Scroll inset above the floating shell dock (64dp bar + margin + gap).
  static const double shellDockScrollInset =
      spacing6xl + spacingMd + spacingLg;

  // ==========================================================================
  // BORDER RADIUS
  // ==========================================================================

  /// Micro — small chips, tags.
  static const double radiusXs = 4;

  /// Small — buttons, text fields.
  static const double radiusSm = 8;

  /// Medium — cards, dialogs.
  static const double radiusMd = 12;

  /// Large — bottom sheets, FABs.
  static const double radiusLg = 16;

  /// Extra-large — full-screen modals top corners.
  static const double radiusXl = 24;

  /// Circular — avatars, round buttons.
  static const double radiusCircular = 999;

  // ==========================================================================
  // ELEVATION
  // ==========================================================================

  /// No elevation — flat surfaces.
  static const double elevationNone = 0;

  /// Low — cards on surface.
  static const double elevationLow = 1;

  /// Medium — floating elements, FABs.
  static const double elevationMedium = 4;

  /// High — bottom sheets, dialogs.
  static const double elevationHigh = 8;

  /// Highest — tooltips, popovers.
  static const double elevationHighest = 16;

  // ==========================================================================
  // TAP TARGETS (WCAG + Material guidelines)
  // ==========================================================================

  /// Minimum tap target size — NEVER go below this.
  /// Required by WCAG 2.5.5 and Material Design guidelines.
  static const double minTapTarget = 48;

  /// Comfortable tap target — preferred for primary actions.
  static const double comfortableTapTarget = 56;

  /// Large tap target — FABs, primary CTAs.
  static const double largeTapTarget = 64;

  // ==========================================================================
  // COMPONENT SIZES
  // ==========================================================================

  /// App bar height.
  static const double appBarHeight = 56;

  /// Bottom navigation bar height.
  static const double bottomNavHeight = 64;

  /// Bottom sheet drag handle width.
  static const double dragHandleWidth = 40;

  /// Bottom sheet drag handle height.
  static const double dragHandleHeight = 4;

  /// Avatar — small (list items).
  static const double avatarSmall = 36;

  /// Avatar — medium (contact detail).
  static const double avatarMedium = 48;

  /// Avatar — large (profile, hero).
  static const double avatarLarge = 72;

  /// Icon size — small (inline).
  static const double iconSmall = 16;

  /// Icon size — medium (list trailing, buttons).
  static const double iconMedium = 24;

  /// Icon size — large (empty state illustrations).
  static const double iconLarge = 48;

  /// Divider thickness.
  static const double dividerThickness = 0.5;

  // ==========================================================================
  // ANIMATION DURATIONS
  // ==========================================================================

  /// Instant — micro-bounces, toggle ticks.
  static const Duration animationInstant = Duration(milliseconds: 80);

  /// Fast — micro-interactions (button press, icon change).
  static const Duration animationFast = Duration(milliseconds: 150);

  /// Medium — state transitions (expand/collapse, tab switch).
  static const Duration animationMedium = Duration(milliseconds: 300);

  /// Slow — page transitions, balance reveals.
  static const Duration animationSlow = Duration(milliseconds: 450);

  /// Snappy enter — hero companion fade, bottom sheet slide-up.
  static const Duration animationSnappyEnter = Duration(milliseconds: 300);

  /// Snappy exit — route pop, bottom sheet dismiss.
  static const Duration animationSnappyExit = Duration(milliseconds: 250);

  /// Minimum spinner phase during pull-to-refresh (before fake-done hold).
  static const Duration refreshPerceivedDuration = Duration(milliseconds: 500);

  /// Alias for [animationSnappyEnter] (hero fade, sheet enter).
  static const Duration animationLuxury = animationSnappyEnter;

  /// Extra slow — number count-up, balance card reveal.
  static const Duration animationXSlow = Duration(milliseconds: 600);

  /// Onboard — onboarding hero animations, success celebrations.
  static const Duration animationOnboard = Duration(milliseconds: 900);

  /// Breath — lapis glow breathing pulse on awaiting CTAs.
  static const Duration animationBreath = Duration(milliseconds: 2400);

  // ==========================================================================
  // ONE-HANDED REACHABILITY
  // ==========================================================================

  /// Maximum percentage of screen height for primary actions.
  /// All primary actions must be within the bottom 60% of the screen.
  static const double primaryActionZonePercent = 0.6;
}
