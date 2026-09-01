import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/shared/widgets/daftar_coach_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/widgets/transactions/quick_add_bottom_sheet.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NAVIGATION TAB MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// Describes a single tab destination in the floating navigation bar.
class _NavTab {
  const _NavTab({
    required this.icon,
    required this.activeIcon,
  });

  final IconData icon;
  final IconData activeIcon;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SHELL — The navigation scaffold with a floating glassmorphic bar
// ═══════════════════════════════════════════════════════════════════════════════

/// Application shell that hosts the floating glassmorphic navigation bar.
///
/// Wraps all top-level [ShellRoute] destinations in a persistent scaffold
/// with a `BackdropFilter`-powered frosted glass squircle and a centered FAB.
///
/// ### Motion Architecture — Identity-Stable Animation
/// The critical insight: [AnimationController] is passed directly to children
/// (its identity never changes across rebuilds). A companion [ValueNotifier<double>]
/// carries the *target* index. [_NavTabItem] uses [AnimatedBuilder] on the
/// controller and reads the target from the notifier to compute proximity.
/// This avoids the stale-reference bug where swapping `_indicatorPosition` to
/// a new [Tween]-derived [Animation] left children observing the old object.
///
/// ### Performance Architecture
/// The expensive `BackdropFilter` (σ=16) lives inside a [RepaintBoundary] that
/// never repaints during tab-switch animations. The tab indicator and icon
/// transitions are driven by the shared [AnimationController] on a separate
/// paint layer above the frozen glass.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    required this.child,
    required this.currentLocation,
    super.key,
  });

  final Widget child;
  final String currentLocation;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  // The controller is the single stable identity passed to the child tree.
  // It drives the ease curve; its .value at any moment encodes the animated
  // fractional position of the indicator between tab slots.
  late final AnimationController _controller;

  // Carries the *rendered* (interpolated) indicator position as a double in
  // [0, tabCount-1] space. Derived from a Tween on _controller, but exposed
  // as a stable ValueNotifier so children never hold a stale Animation ref.
  final ValueNotifier<double> _indicatorPos = ValueNotifier(0);
  final GlobalKey _fabCoachTargetKey = GlobalKey();
  bool _fabCoachShowPending = false;
  bool _fabCoachShown = false;
  int _fabCoachAttempts = 0;
  DateTime? _fabCoachRetryUntil;
  static const int _fabCoachMaxAttempts = 240;
  static const Duration _fabCoachRetryWindow = Duration(seconds: 8);

  late int _selectedIndex;
  late Animation<double> _currentTween;

  /// Resolve current tab index from the location path.
  int _indexFromLocation(String location) {
    final uri = Uri.parse(location);
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'settings') {
      return 1;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexFromLocation(widget.currentLocation);

    _controller = AnimationController(
      vsync: this,
      duration: AppDimensions.animationMedium,
    );

    // Seed the tween so _currentTween is valid before the first build.
    _currentTween = AlwaysStoppedAnimation(_selectedIndex.toDouble());
    _indicatorPos.value = _selectedIndex.toDouble();

    // Keep the notifier in sync with every tick of the controller.
    _controller.addListener(_onControllerTick);
  }

  void _onControllerTick() {
    _indicatorPos.value = _currentTween.value;
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = _indexFromLocation(widget.currentLocation);
    if (newIndex != _selectedIndex) {
      _animateToIndex(newIndex);
    }
  }

  void _animateToIndex(int index) {
    // Capture the current rendered position as the tween start, so the
    // animation picks up from wherever it is mid-flight.
    final fromPos = _indicatorPos.value;
    _selectedIndex = index;

    // Build a new tween over the same stable controller.
    _currentTween =
        Tween<double>(
          begin: fromPos,
          end: index.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppMotion.curveEmphasized,
          ),
        );

    // forward(from:0) resets the controller to 0 and starts it — this fires
    // _onControllerTick on every frame, which pushes the correct interpolated
    // value into _indicatorPos and causes all listening AnimatedBuilders to
    // rebuild with the new proximity.
    unawaited(_controller.forward(from: 0));
    unawaited(HapticService.selection());
  }

  void _onTabTapped(int index) {
    final rootPath = index == 0 ? RouteNames.homePath : RouteNames.settingsPath;
    if (index == _selectedIndex && widget.currentLocation == rootPath) {
      return;
    }
    if (index == 0) {
      context.goNamed(RouteNames.home);
    } else {
      context.goNamed(RouteNames.settings);
    }
  }

  void _onFabTapped() {
    unawaited(HapticService.buttonPress());
    unawaited(context.pushNamed(RouteNames.closingAgent));
  }

  void _onFabLongPressed() {
    unawaited(HapticService.longPress());
    unawaited(showQuickAddBottomSheet(context));
  }

  void _scheduleFabCoachIfNeeded({
    required bool onHome,
    required bool ledgersReady,
    required AppSettings? settings,
  }) {
    if (_fabCoachShown || _fabCoachShowPending || !onHome || !ledgersReady) {
      return;
    }
    if (settings == null ||
        !settings.hasSeenOnboarding ||
        settings.hasSeenAgentFabTip) {
      return;
    }
    _fabCoachShowPending = true;
    _fabCoachAttempts = 0;
    _fabCoachRetryUntil = DateTime.now().add(_fabCoachRetryWindow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showFabCoach());
    });
  }

  bool _canStillRetryFabCoach() {
    final deadline = _fabCoachRetryUntil;
    if (deadline == null) {
      return _fabCoachAttempts < _fabCoachMaxAttempts;
    }
    return _fabCoachAttempts < _fabCoachMaxAttempts &&
        DateTime.now().isBefore(deadline);
  }

  void _queueFabCoachRetry() {
    if (!_canStillRetryFabCoach()) {
      _fabCoachShowPending = false;
      return;
    }
    _fabCoachAttempts += 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showFabCoach());
    });
  }

  Future<void> _showFabCoach() async {
    if (!mounted || _fabCoachShown) {
      _fabCoachShowPending = false;
      return;
    }
    final onHome = _indexFromLocation(widget.currentLocation) == 0;
    final ledgersReady = ref.read(ledgersProvider).hasValue;
    final settings = ref.read(appSettingsProvider).asData?.value;
    if (!onHome ||
        !ledgersReady ||
        settings == null ||
        !settings.hasSeenOnboarding ||
        settings.hasSeenAgentFabTip) {
      _fabCoachShowPending = false;
      return;
    }
    // Coach overlay needs a laid-out FAB target (first frames are often 0×0).
    // used to call ref.read on a deactivated MainShell and replace the
    // tree with DaftarFatalErrorView.
    if (!DaftarCoachMark.isTargetLaidOut(_fabCoachTargetKey)) {
      _queueFabCoachRetry();
      return;
    }
    final markSeen = ref.read(markAgentFabTipSeenUseCaseProvider);
    final shown = await DaftarCoachMark.showFab(
      context: context,
      targetKey: _fabCoachTargetKey,
      onDismissed: () {
        unawaited(markSeen.execute());
      },
    );
    if (!mounted) {
      _fabCoachShowPending = false;
      return;
    }
    if (shown) {
      _fabCoachShowPending = false;
      _fabCoachShown = true;
    } else {
      _queueFabCoachRetry();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerTick)
      ..dispose();
    _indicatorPos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onHome = _indexFromLocation(widget.currentLocation) == 0;
    final ledgersReady = ref.watch(ledgersProvider).hasValue;
    final settings = ref.watch(appSettingsProvider).asData?.value;
    ref
        ..listen(appSettingsProvider, (previous, next) {
          final prevSeen = previous?.asData?.value.hasSeenAgentFabTip ?? false;
          final nextSeen = next.asData?.value.hasSeenAgentFabTip ?? false;
          if (!prevSeen && nextSeen) {
            _fabCoachShown = true;
            _fabCoachShowPending = false;
          }
          _scheduleFabCoachIfNeeded(
            onHome: onHome,
            ledgersReady: ledgersReady,
            settings: next.asData?.value,
          );
        })
        ..listen(ledgersProvider, (previous, next) {
          _scheduleFabCoachIfNeeded(
            onHome: onHome,
            ledgersReady: next.hasValue,
            settings: settings,
          );
        });
    _scheduleFabCoachIfNeeded(
      onHome: onHome,
      ledgersReady: ledgersReady,
      settings: settings,
    );

    return Scaffold(
      // Let the body extend behind the floating bar so content can scroll
      // underneath the glass.
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _FloatingGlassNavBar(
        indicatorPos: _indicatorPos,
        fabCoachTargetKey: _fabCoachTargetKey,
        onTabTapped: _onTabTapped,
        onFabTapped: _onFabTapped,
        onFabLongPressed: _onFabLongPressed,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLOATING GLASS NAV BAR — The frosted glass squircle dock
// ═══════════════════════════════════════════════════════════════════════════════

class _FloatingGlassNavBar extends StatelessWidget {
  const _FloatingGlassNavBar({
    required this.indicatorPos,
    required this.fabCoachTargetKey,
    required this.onTabTapped,
    required this.onFabTapped,
    required this.onFabLongPressed,
  });

  // Identity-stable notifier — never replaced, always the same object.
  final ValueNotifier<double> indicatorPos;
  final GlobalKey fabCoachTargetKey;
  final ValueChanged<int> onTabTapped;
  final VoidCallback onFabTapped;
  final VoidCallback onFabLongPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // ── Global Glass Illumination tokens ──────────────────────────────────
    // The dock must look like real refractive glass at ALL times, independent
    // of which tab is active. Physical glass transmits and scatters overhead
    // ambient light across its entire surface. We model this with two light
    // sources:
    //
    //   1. Bilateral lobe sweep (horizontal): a soft white specular peak at
    //      ≈25% from the left, dipping to near-zero at the centre, and a
    //      symmetric softer peak at ≈75% right. This simulates ambient ceiling
    //      light scattering across the full width of the dock.
    //
    //   2. Top-edge specular bar: a 0.5px razor-thin bright line at y=0 that
    //      catches overhead light on the bevelled top edge of the glass slab.
    //
    //   3. Inner-top sheen: a 0→transparent gradient over the top ~30% of the
    //      height, representing the Fresnel brightening at shallow angles.
    //
    // All alpha values are ultra-sheer. Combined additive alpha ≤ 0x12 so
    // blurred background colours bleed through vividly.
    final glassStroke = isDark
        ? const Color(0x0AFFFFFF)
        : const Color(0x0A000000);

    // Bilateral horizontal illumination: peaks at 25% and 75% of width.
    // The three colours form a W-shaped luminance curve across the capsule.
    final bilateralLightLeft = isDark
        ? const Color(0x0CFFFFFF)
        : const Color(0x08FFFFFF);
    final bilateralLightCenter = isDark
        ? const Color(0x01FFFFFF)
        : const Color(0x01FFFFFF);
    final bilateralLightRight = isDark
        ? const Color(0x08FFFFFF)
        : const Color(0x05FFFFFF);

    // Inner-top Fresnel sheen: scatters across the full top edge.
    final fresnelSheen = isDark
        ? const Color(0x05FFFFFF)
        : const Color(0x04FFFFFF);

    // Subtle diagonal warmth: glass is never perfectly neutral; a micro-tint
    // gives it a live, material character without washing out the blur output.
    final diagonalTintTop = isDark
        ? const Color(0x04FFFFFF)
        : const Color(0x03000000);
    final diagonalTintBottom = isDark
        ? const Color(0x01FFFFFF)
        : const Color(0x01000000);

    const tabs = [
      _NavTab(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _NavTab(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
      ),
    ];

    // Squircle geometry — exact match with BalanceCard / LedgerListTile.
    // cornerRadius: radiusMd (12), cornerSmoothing: 0.6.
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusMd,
      cornerSmoothing: 0.6,
    );

    // The outer container: floating squircle with margin from screen edges.
    // Extra bottom margin accounts for safe area on notched devices.
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppDimensions.spacingLg,
        end: AppDimensions.spacingLg,
        bottom: bottomPadding + AppDimensions.spacingMd,
      ),
      child: SizedBox(
        height: 64,
        // Outer shadow layer — sits outside the clip, just like BalanceCard.
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(borderRadius: squircleRadius),
            shadows: [
              // Ambient float shadow — grounds the dock in space.
              BoxShadow(
                color: isDark
                    ? const Color(0x52020610)
                    : const Color(0x14000000),
                blurRadius: isDark ? 36 : 24,
                offset: const Offset(0, 10),
              ),
              // Secondary soft spread for diffuse halo.
              BoxShadow(
                color: isDark
                    ? const Color(0x18020610)
                    : const Color(0x08000000),
                blurRadius: isDark ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipSmoothRect(
            radius: squircleRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Layer 1: Glass core (full-bleed backdrop blur) ────────
                // Positioned must be a direct Stack child; RepaintBoundary sits
                // inside it to isolate the expensive σ=16 blur from Layer 2.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: BackdropFilter(
                      // σ=16: shapes and colours behind the dock remain
                      // recognisable as blurred silhouettes, matching iOS
                      // frosted glass behaviour.
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── 1a. Base diagonal micro-tint ──────────────
                          // Ultra-sheer diagonal gradient that gives the glass
                          // a barely-there material character.
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topStart,
                                  end: AlignmentDirectional.bottomEnd,
                                  colors: [
                                    diagonalTintTop,
                                    diagonalTintBottom,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── 1b. Global bilateral light sweep ──────────
                          // W-shaped horizontal luminance curve that illuminates
                          // the ENTIRE dock surface like overhead ambient light
                          // diffracting through glass. Left lobe is brighter
                          // (simulating a dominant left ceiling source).
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    bilateralLightLeft,
                                    bilateralLightCenter,
                                    bilateralLightRight,
                                    bilateralLightCenter,
                                    bilateralLightLeft,
                                  ],
                                  stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // ── 1c. Inner-top Fresnel sheen ───────────────
                          // Shallow-angle Fresnel brightening across the full
                          // top strip — the glass becomes slightly more
                          // reflective when viewed at a low angle from below.
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    fresnelSheen,
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.72],
                                ),
                              ),
                            ),
                          ),

                          // ── 1d. Specular top-edge razor line ──────────
                          // 0.5px razor-bright line at the very top bevel.
                          // This is the single sharpest optical cue that the
                          // object is solid glass rather than a floating panel.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 0.5,
                            child: ColoredBox(
                              color: isDark
                                  ? const Color(0x35FFFFFF)
                                  : const Color(0x26FFFFFF),
                            ),
                          ),

                          // ── 1e. Crystalline border overlay ────────────
                          // 0.5px stroke tracing the squircle silhouette.
                          // Uniform on sides/bottom; the razor line above
                          // provides the asymmetric top-bevel brightness.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  shape: SmoothRectangleBorder(
                                    borderRadius: squircleRadius,
                                    side: BorderSide(
                                      color: glassStroke,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Layer 2: Interactive content (tabs + FAB) ────────────
                Positioned.fill(
                  child: Row(
                    children: [
                      // Left tab zone
                      Expanded(
                        child: _NavTabItem(
                          indicatorPos: indicatorPos,
                          tab: tabs[0],
                          tabIndex: 0,
                          onTap: () => onTabTapped(0),
                        ),
                      ),

                      // Center FAB — flush inside the bar
                      _InlineFab(
                        key: const ValueKey<String>('main-shell-inline-fab'),
                        coachTargetKey: fabCoachTargetKey,
                        onTap: onFabTapped,
                        onLongPress: onFabLongPressed,
                        isDark: isDark,
                      ),

                      // Right tab zone
                      Expanded(
                        child: _NavTabItem(
                          indicatorPos: indicatorPos,
                          tab: tabs[1],
                          tabIndex: 1,
                          onTap: () => onTabTapped(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAV TAB ITEM — Ultra-minimal icon + soft emission glow (no background shapes)
// ═══════════════════════════════════════════════════════════════════════════════

class _NavTabItem extends StatelessWidget {
  const _NavTabItem({
    required this.indicatorPos,
    required this.tab,
    required this.tabIndex,
    required this.onTap,
  });

  // Identity-stable — the same ValueNotifier for the widget's entire lifetime.
  final ValueNotifier<double> indicatorPos;
  final _NavTab tab;
  final int tabIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      key: ValueKey('main-shell-tab-$tabIndex'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        // ValueListenableBuilder listens to the stable notifier. The notifier
        // is updated every controller tick via _MainShellState._onControllerTick,
        // so this rebuilds on every animation frame without ever holding a stale
        // Animation<double> reference.
        child: ValueListenableBuilder<double>(
          valueListenable: indicatorPos,
          builder: (context, pos, _) {
            // Proximity: 1.0 when this tab is the active position, 0.0 when
            // the indicator is fully on the opposite tab.
            final distance = (pos - tabIndex).abs();
            final proximity = (1.0 - distance).clamp(0.0, 1.0);

            final iconScale = 1.0 + (proximity * 0.04);

            // Muted → crisp: inkSecondary (~50% perceptual weight) to inkPrimary.
            final inactiveColor = Color.lerp(
              isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
              isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight,
              0.5,
            )!;
            final activeColor = isDark
                ? AppColors.inkPrimary
                : AppColors.inkPrimaryLight;
            final iconColor = Color.lerp(
              inactiveColor,
              activeColor,
              proximity,
            )!;

            // Icon emission — no geometry; scales with proximity².
            final glowStrength = proximity * proximity;
            final glowCore = isDark
                ? const Color(0x66FFFFFF) // 40% white core halo
                : const Color(0x400A0A0C); // 25% ink halo (light)
            final glowAmbient = isDark
                ? const Color(0x33FFFFFF) // 20% ambient spill
                : const Color(0x260A0A0C);
            final iconShadows = glowStrength > 0.01
                ? [
                    Shadow(
                      color: glowCore.withValues(
                        alpha: glowCore.a * glowStrength,
                      ),
                      blurRadius: 8 + (4 * proximity),
                    ),
                    Shadow(
                      color: glowAmbient.withValues(
                        alpha: glowAmbient.a * glowStrength,
                      ),
                      blurRadius: 16 + (6 * proximity),
                    ),
                  ]
                : null;

            return SizedBox(
              width: AppDimensions.minTapTarget,
              height: AppDimensions.minTapTarget,
              child: Center(
                child: Transform.scale(
                  scale: iconScale,
                  child: Icon(
                    proximity > 0.5 ? tab.activeIcon : tab.icon,
                    size: AppDimensions.iconMedium,
                    color: iconColor,
                    shadows: iconShadows,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE FAB — Flush-centered action button within the glass bar
// ═══════════════════════════════════════════════════════════════════════════════

/// A premium centered FAB that sits flush inside the glass navigation bar.
///
/// ### Geometry
/// The FAB is 44×44 — matching the tab highlight dimensions — so all three
/// interactive elements are vertically and horizontally aligned on a single
/// baseline inside the 64dp bar.
///
/// ### Lapis Firewall Compliance
/// Monochrome `surface3` / `surface2Light` fill with a 0.5px `lapis400`
/// border. Lapis appears as border accent and a subtle `glowSm` ambient
/// shadow — never as a solid fill.
///
/// ### Press Interaction
/// Scale to 0.92 on tap-down with `curveEmphasized`, spring back on release
/// with elastic overshoot. `HapticService.buttonPress()` fires on tap.
class _InlineFab extends StatefulWidget {
  const _InlineFab({
    required this.coachTargetKey,
    required this.onTap,
    required this.onLongPress,
    required this.isDark,
    super.key,
  });

  final GlobalKey coachTargetKey;

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isDark;

  @override
  State<_InlineFab> createState() => _InlineFabState();
}

class _InlineFabState extends State<_InlineFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _consumedByLongPress = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationFast,
      reverseDuration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: AppMotion.curveEmphasized,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (_isPressed) return;
    _isPressed = true;
    unawaited(_pressController.forward());
  }

  void _handleTapUp(TapUpDetails _) {
    _isPressed = false;
    unawaited(_pressController.reverse());
    if (_consumedByLongPress) {
      _consumedByLongPress = false;
      return;
    }
    widget.onTap();
  }

  void _handleTapCancel() {
    _isPressed = false;
    unawaited(_pressController.reverse());
    _consumedByLongPress = false;
  }

  void _handleLongPress() {
    _consumedByLongPress = true;
    _isPressed = false;
    unawaited(_pressController.reverse());
    widget.onLongPress();
  }

  @override
  Widget build(BuildContext context) {
    // 44×44 — precisely matching the tab highlight size.
    const fabSize = 44.0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPress: _handleLongPress,
        child: DaftarTapTarget(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              key: widget.coachTargetKey,
              width: fabSize,
              height: fabSize,
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: widget.isDark
                      ? const [
                          Color(0xF01A1A20),
                          Color(0xEA121216),
                        ]
                      : const [
                          Color(0xF9FFFFFF),
                          Color(0xEEF1EFE8),
                        ],
                ),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: AppDimensions.radiusSm,
                    cornerSmoothing: 0.6,
                  ),
                  side: BorderSide(
                    color: widget.isDark
                        ? const Color(0x30FFFFFF)
                        : const Color(0x24000000),
                    width: 0.5,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: widget.isDark
                        ? const Color(0x26000000)
                        : const Color(0x14000000),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  AppGlows.glowXs,
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                size: AppDimensions.iconMedium,
                color: widget.isDark
                    ? AppColors.inkPrimary
                    : AppColors.inkPrimaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
