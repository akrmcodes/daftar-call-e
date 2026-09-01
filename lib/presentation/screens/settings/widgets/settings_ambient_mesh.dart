import 'dart:ui' show ImageFilter;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Parallax ambient refraction mesh for the settings command center.
///
/// Orb positions shift subtly with [scrollOffset] to create depth as the user
/// scrolls — a whisper of Salāsa without competing with content.
class SettingsAmbientMesh extends StatelessWidget {
  const SettingsAmbientMesh({
    super.key,
    this.scrollOffset = 0,
  });

  final double scrollOffset;

  static const _blurSigma = 120.0;
  static const _parallaxFactor = 0.18;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parallax = scrollOffset * _parallaxFactor;

    final trailingOrb = AppColors.lapisLumen.withValues(
      alpha: isDark ? 0.24 : 0.17,
    );
    final leadingOrb = AppColors.avatarColors[7].withValues(
      alpha: isDark ? 0.21 : 0.15,
    );
    final accentOrb = AppColors.payment.withValues(
      alpha: isDark ? 0.06 : 0.04,
    );

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        textDirection: Directionality.of(context),
        children: [
          PositionedDirectional(
            top: -80 + parallax,
            start: -100 - parallax * 0.5,
            child: _BlurredOrb(
              diameter: 300,
              color: trailingOrb,
              blurSigma: _blurSigma,
            ),
          ),
          PositionedDirectional(
            top: 280 - parallax * 0.7,
            end: -120 + parallax * 0.3,
            child: _BlurredOrb(
              diameter: 280,
              color: leadingOrb,
              blurSigma: _blurSigma,
            ),
          ),
          PositionedDirectional(
            top: 520 - parallax,
            start: 40,
            child: _BlurredOrb(
              diameter: 200,
              color: accentOrb,
              blurSigma: _blurSigma * 0.8,
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
