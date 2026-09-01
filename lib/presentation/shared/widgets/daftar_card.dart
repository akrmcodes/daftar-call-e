import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';

/// Khazna Float card — stepped surface + ambient shadow + top highlight.
///
/// See `docs/design_system.md` §5.3, §5.5, §8.3.
enum DaftarCardVariant {
  standard,
  hero,
  compact,
  selectable,
  premium,
}

class DaftarCard extends StatefulWidget {
  const DaftarCard({
    required this.child,
    super.key,
    this.variant = DaftarCardVariant.standard,
    this.onTap,
    this.isSelected = false,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final DaftarCardVariant variant;
  final VoidCallback? onTap;
  final bool isSelected;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  @override
  State<DaftarCard> createState() => _DaftarCardState();
}

class _DaftarCardState extends State<DaftarCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.borderRadius ??
        BorderRadius.circular(
          widget.variant == DaftarCardVariant.hero
              ? AppDimensions.radiusLg
              : AppDimensions.radiusMd,
        );
    final padding = widget.padding ??
        (widget.variant == DaftarCardVariant.compact
            ? const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingSm,
              )
            : const EdgeInsets.all(AppDimensions.cardPadding));

    final decoration = _buildDecoration(isDark, radius);
    final content = Padding(padding: padding, child: widget.child);

    Widget card = AnimatedScale(
      scale: _pressed && widget.onTap != null ? 0.99 : 1,
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              if (widget.variant == DaftarCardVariant.hero)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (isDark ? AppColors.lapis400 : AppColors.lapis500)
                              .withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: Container(
                  height: AppDimensions.dividerThickness,
                  color: isDark ? AppColors.innerTopHighlight : Colors.transparent,
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.light());
          widget.onTap?.call();
        },
        child: card,
      );
    }

    if (widget.margin != null) {
      card = Padding(padding: widget.margin!, child: card);
    }

    return card;
  }

  BoxDecoration _buildDecoration(bool isDark, BorderRadius radius) {
    final fill = switch (widget.variant) {
      DaftarCardVariant.hero ||
      DaftarCardVariant.standard ||
      DaftarCardVariant.selectable ||
      DaftarCardVariant.premium =>
        isDark ? AppColors.surface2 : AppColors.surface1Light,
      DaftarCardVariant.compact =>
        isDark ? AppColors.surface3 : AppColors.surface2Light,
    };

    final borderColor = widget.isSelected
        ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);

    final shadows = switch (widget.variant) {
      DaftarCardVariant.premium => AppGlows.premiumPro,
      DaftarCardVariant.hero || DaftarCardVariant.standard => isDark
          ? AppGlows.khazaFloat
          : AppGlows.shadowFloat,
      DaftarCardVariant.compact => isDark ? AppGlows.khazaFloat : AppGlows.shadowSoft,
      DaftarCardVariant.selectable => isDark
          ? AppGlows.khazaFloat
          : AppGlows.shadowFloat,
    };

    return BoxDecoration(
      color: fill,
      borderRadius: radius,
      border: Border.all(
        color: borderColor,
        width: AppDimensions.dividerThickness,
      ),
      boxShadow: shadows,
    );
  }
}
