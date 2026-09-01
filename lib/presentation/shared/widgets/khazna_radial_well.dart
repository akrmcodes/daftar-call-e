import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Emissive lapis light-well for cinematic studio canvases.
///
/// Scene illumination via [BoxShadow] emission — not a painted gradient.
/// Does not count as the screen's CTA halo. See `docs/design_system.md` §5.6.
class KhaznaRadialWell extends StatefulWidget {
  const KhaznaRadialWell({
    super.key,
    this.opacity = 1,
    this.heroAlignment = const Alignment(0, -0.15),
    this.showFloorBounce = true,
    this.breathe = true,
  });

  /// Multiplier for dimming during non-idle phases (e.g. 0.35).
  final double opacity;

  /// Anchor for the primary emissive orb behind the hero cluster.
  final Alignment heroAlignment;

  /// Secondary floor bounce behind the composer dock (dark mode only).
  final bool showFloorBounce;

  /// Subtle scale breath on the primary well.
  final bool breathe;

  @override
  State<KhaznaRadialWell> createState() => _KhaznaRadialWellState();
}

class _KhaznaRadialWellState extends State<KhaznaRadialWell>
    with SingleTickerProviderStateMixin {
  AnimationController? _breathController;
  Animation<double>? _breathScale;

  @override
  void initState() {
    super.initState();
    _initBreath();
  }

  @override
  void didUpdateWidget(KhaznaRadialWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breathe != widget.breathe) {
      _disposeBreath();
      _initBreath();
    }
  }

  void _initBreath() {
    if (!widget.breathe) {
      return;
    }
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    unawaited(_breathController!.repeat(reverse: true));
    _breathScale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(
        parent: _breathController!,
        curve: AppMotion.curveBreath,
      ),
    );
  }

  void _disposeBreath() {
    _breathController?.dispose();
    _breathController = null;
    _breathScale = null;
  }

  @override
  void dispose() {
    _disposeBreath();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final wellShadows =
        isDark ? AppGlows.studioWellDark : AppGlows.studioWellLight;
    const coreDiameter = 180.0;

    Widget primaryOrb = _EmissiveOrb(
      diameter: coreDiameter,
      shadows: wellShadows,
    );

    if (widget.breathe && !reduceMotion && _breathScale != null) {
      primaryOrb = AnimatedBuilder(
        animation: _breathScale!,
        builder: (context, child) {
          return Transform.scale(
            scale: _breathScale!.value,
            child: child,
          );
        },
        child: primaryOrb,
      );
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedOpacity(
          opacity: widget.opacity.clamp(0, 1),
          duration: const Duration(milliseconds: 450),
          curve: AppMotion.curveStandard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: widget.heroAlignment,
                child: primaryOrb,
              ),
              if (widget.showFloorBounce && isDark)
                const Align(
                  alignment: Alignment(0, 0.85),
                  child: _EmissiveOrb(
                    diameter: 120,
                    shadows: [AppGlows.glowWellFloor],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmissiveOrb extends StatelessWidget {
  const _EmissiveOrb({
    required this.diameter,
    required this.shadows,
  });

  final double diameter;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          boxShadow: shadows,
        ),
      ),
    );
  }
}
