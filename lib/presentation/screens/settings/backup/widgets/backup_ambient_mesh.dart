import 'dart:ui' show ImageFilter;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Ambient refraction mesh — visual continuity with the settings dashboard.
class BackupAmbientMesh extends StatelessWidget {
  const BackupAmbientMesh({super.key});

  static const _blurSigma = 120.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final trailingOrb = AppColors.lapisLumen.withValues(
      alpha: isDark ? 0.24 : 0.17,
    );
    final leadingOrb = AppColors.avatarColors[7].withValues(
      alpha: isDark ? 0.21 : 0.15,
    );

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        textDirection: Directionality.of(context),
        children: [
          PositionedDirectional(
            top: -80,
            start: -100,
            child: _BlurredOrb(
              diameter: 300,
              color: trailingOrb,
              blurSigma: _blurSigma,
            ),
          ),
          PositionedDirectional(
            top: 280,
            end: -120,
            child: _BlurredOrb(
              diameter: 280,
              color: leadingOrb,
              blurSigma: _blurSigma,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredOrb extends StatelessWidget {
  const _BlurredOrb({
    required this.diameter,
    required this.color,
    required this.blurSigma,
  });

  final double diameter;
  final Color color;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
      ),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
