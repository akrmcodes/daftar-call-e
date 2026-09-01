import 'package:daftar/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Top-anchored ambient lapis bleed for the security vault screen.
class SecurityAmbientBackdrop extends StatelessWidget {
  const SecurityAmbientBackdrop({
    required this.isDark,
    required this.surfaceColor,
    super.key,
  });

  final bool isDark;
  final Color surfaceColor;

  Color _bleed(double mix) =>
      Color.lerp(surfaceColor, isDark ? AppColors.lapis400 : AppColors.lapis500, mix)!;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.88),
            stops: const [0.0, 0.07, 0.16, 0.28, 0.42, 0.58, 0.74, 1.0],
            colors: isDark
                ? [
                    _bleed(0.48),
                    _bleed(0.38),
                    _bleed(0.27),
                    _bleed(0.18),
                    _bleed(0.11),
                    _bleed(0.06),
                    _bleed(0.02),
                    surfaceColor,
                  ]
                : [
                    _bleed(0.36),
                    _bleed(0.28),
                    _bleed(0.20),
                    _bleed(0.13),
                    _bleed(0.08),
                    _bleed(0.04),
                    _bleed(0.01),
                    surfaceColor,
                  ],
          ),
        ),
      ),
    );
  }
}
