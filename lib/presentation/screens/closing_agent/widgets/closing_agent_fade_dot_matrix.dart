import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Whisper-quiet dot grid that fades toward the bottom — single-pass paint.
class ClosingAgentFadeDotMatrix extends StatelessWidget {
  const ClosingAgentFadeDotMatrix({
    required this.isDark,
    super.key,
    this.pitch = 9,
    this.dotRadius = 0.7,
  });

  final bool isDark;
  final double pitch;
  final double dotRadius;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FadeDotMatrixPainter(
          isDark: isDark,
          pitch: pitch,
          dotRadius: dotRadius,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FadeDotMatrixPainter extends CustomPainter {
  _FadeDotMatrixPainter({
    required this.isDark,
    required this.pitch,
    required this.dotRadius,
  });

  final bool isDark;
  final double pitch;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final baseInk = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final whisper = isDark ? AppColors.alphaWhisper : AppColors.alphaHairline;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = pitch * 0.5; y < size.height; y += pitch) {
      final fade = math.max(0, 1 - math.pow(y / size.height, 1.35));
      if (fade <= 0) {
        continue;
      }
      final rowAlpha = (whisper * fade).clamp(0.0, 0.12);
      paint.color = baseInk.withValues(alpha: rowAlpha);
      for (var x = pitch * 0.5; x < size.width; x += pitch) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FadeDotMatrixPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.pitch != pitch ||
        oldDelegate.dotRadius != dotRadius;
  }
}
