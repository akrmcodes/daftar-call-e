import 'package:daftar/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class VaultAmbientBackdrop extends StatelessWidget {
  const VaultAmbientBackdrop({
    required this.isDark,
    required this.surfaceColor,
    super.key,
  });

  final bool isDark;
  final Color surfaceColor;

  Color _bleed(double mix) => Color.lerp(
        surfaceColor,
        isDark ? AppColors.lapis400 : AppColors.lapis500,
        mix,
      )!;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.92),
            stops: const [0.0, 0.06, 0.14, 0.26, 0.42, 0.62, 0.82, 1.0],
            colors: isDark
                ? [
                    _bleed(0.32),
                    _bleed(0.24),
                    _bleed(0.16),
                    _bleed(0.10),
                    _bleed(0.06),
                    _bleed(0.03),
                    _bleed(0.01),
                    surfaceColor,
                  ]
                : [
                    _bleed(0.22),
                    _bleed(0.16),
                    _bleed(0.11),
                    _bleed(0.07),
                    _bleed(0.04),
                    _bleed(0.02),
                    _bleed(0.01),
                    surfaceColor,
                  ],
          ),
        ),
      ),
    );
  }
}
