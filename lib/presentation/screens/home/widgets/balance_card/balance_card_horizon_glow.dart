import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Top-to-transparent lapis gradient inside the balance card.
///
/// The glow keeps its current alpha stable across unrelated rebuilds.
/// It only updates when the observed balance changes, so expand/collapse
/// does not alter resting brightness — visibility is handled by the parent
/// [AnimatedOpacity] layer (0 when expanded, 1 when collapsed).
///
/// **Lapis compliance:** This is a gradient *light emission*, not a fill.
class BalanceCardHorizonGlow extends StatefulWidget {
  const BalanceCardHorizonGlow({
    required this.isDark,
    required this.netBalance,
    super.key,
  });

  final bool isDark;
  final int netBalance;

  @override
  State<BalanceCardHorizonGlow> createState() => _BalanceCardHorizonGlowState();
}

class _BalanceCardHorizonGlowState extends State<BalanceCardHorizonGlow> {
  late double _alpha;

  @override
  void initState() {
    super.initState();
    _alpha = _resolveAlpha(widget.isDark, widget.netBalance);
  }

  @override
  void didUpdateWidget(covariant BalanceCardHorizonGlow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isDark != widget.isDark ||
        oldWidget.netBalance != widget.netBalance) {
      final nextAlpha = _resolveAlpha(widget.isDark, widget.netBalance);
      if (nextAlpha != _alpha) {
        setState(() {
          _alpha = nextAlpha;
        });
      }
    }
  }

  double _resolveAlpha(bool isDark, int netBalance) {
    final restAlpha = isDark ? 0.08 : 0.04;
    final peakAlpha = isDark ? 0.20 : 0.10;
    return netBalance == 0 ? restAlpha : peakAlpha;
  }

  @override
  Widget build(BuildContext context) {
    final lapis = widget.isDark ? AppColors.lapis400 : AppColors.lapis500;
    return AnimatedOpacity(
      opacity: _alpha.clamp(0.0, 1.0),
      duration: AppDimensions.animationXSlow,
      curve: AppMotion.curveEmphasized,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lapis,
              Colors.transparent,
            ],
            stops: const [0, 0.8],
          ),
        ),
      ),
    );
  }
}
