import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Khazna v3 — motion curves and spring physics.
///
/// `Curves.linear` is banned for UI motion. Every transition resolves to one
/// of the curves below. See `docs/design_system.md` §7.3.
abstract final class AppMotion {
  /// Entering elements (sheets up, cards in, fade-in).
  static const Curve curveEnter = Curves.easeOutCubic;

  /// Exiting elements (sheets down, fade-out).
  static const Curve curveExit = Curves.easeInCubic;

  /// Bidirectional transitions (tab switch, page push/pop).
  static const Curve curveStandard = Curves.easeInOutCubic;

  /// Hero number count-up, balance reveal — dramatic deceleration.
  static const Curve curveEmphasized = Curves.easeOutExpo;

  /// Toggles, save confirmations — spring overshoot.
  static const Curve curveSpring = Curves.elasticOut;

  /// Subtle wind-up before primary CTA confirm.
  static const Curve curveAnticipate = Cubic(0.4, 0, 0.6, -0.6);

  /// Glow breathing pulse loop on awaiting CTAs.
  static const Curve curveBreath = Curves.easeInOut;

  /// Sheet / modal enter — buttery deceleration tuned for 300ms snappy duration.
  static const Curve curveSheetEnter = Curves.easeOutExpo;

  /// Sheet / modal exit — smooth acceleration tuned for 250ms dismiss.
  static const Curve curveSheetExit = Curves.easeInCubic;

  /// Contact detail push fade — harmonized with sheet enter at 300ms.
  static const Curve curvePageLuxuryEnter = curveSheetEnter;

  /// Contact detail pop fade — harmonized with sheet exit at 250ms.
  static const Curve curvePageLuxuryExit = curveSheetExit;

  /// Global bottom-sheet route animation (enter / exit).
  static AnimationStyle get sheetAnimationStyle => const AnimationStyle(
    duration: AppDimensions.animationSnappyEnter,
    reverseDuration: AppDimensions.animationSnappyExit,
    curve: curveSheetEnter,
    reverseCurve: curveSheetExit,
  );

  /// Bottom-sheet drag-snap spring description.
  /// Use with `SpringSimulation(curveSheetSpring, ...)`.
  static const SpringDescription curveSheetSpring = SpringDescription(
    mass: 1,
    stiffness: 280,
    damping: 24,
  );

  /// Build a `SpringSimulation` for the canonical sheet-snap spring.
  /// Caller supplies `start`, `end`, and `velocity` (px/s in the sheet axis).
  static SpringSimulation sheetSpring({
    required double start,
    required double end,
    double velocity = 0,
  }) {
    return SpringSimulation(curveSheetSpring, start, end, velocity);
  }
}
