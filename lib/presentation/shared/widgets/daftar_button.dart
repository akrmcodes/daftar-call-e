import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';

/// Khazna v3 primary action button — monochrome fill + lapis glow border.
///
/// See `docs/design_system.md` §8.2.
enum DaftarButtonVariant {
  primary,
  secondary,
  tertiary,
  destructive,
  destructiveOutlined,
  premium,
}

enum DaftarButtonSize {
  small,
  medium,
  large,
  xlarge,
}

/// Branded button with press scale, haptics, and width-preserving loading.
class DaftarButton extends StatefulWidget {
  const DaftarButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = DaftarButtonVariant.primary,
    this.size = DaftarButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.semanticsLabel,
  });

  const DaftarButton.icon({
    required this.icon,
    required this.onPressed,
    super.key,
    this.variant = DaftarButtonVariant.primary,
    this.isLoading = false,
    this.semanticsLabel,
  }) : label = '',
       size = DaftarButtonSize.medium,
       isExpanded = false;

  final String label;
  final VoidCallback? onPressed;
  final DaftarButtonVariant variant;
  final DaftarButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final String? semanticsLabel;

  @override
  State<DaftarButton> createState() => _DaftarButtonState();
}

class _DaftarButtonState extends State<DaftarButton> {
  bool _pressed = false;

  bool get _isIconOnly => widget.label.isEmpty && widget.icon != null;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _resolveStyle(isDark);
    final dimensions = _resolveDimensions();

    final child = _isIconOnly
        ? _buildIconChild(style, dimensions)
        : _buildLabelChild(style, dimensions);

    final button = Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.label,
      enabled: _enabled,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled
            ? () {
                unawaited(HapticService.buttonPress());
                widget.onPressed?.call();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed && _enabled ? 0.97 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            width: widget.isExpanded ? double.infinity : null,
            constraints: BoxConstraints(
              minWidth: dimensions.minWidth,
              minHeight: dimensions.height,
            ),
            padding: _isIconOnly
                ? EdgeInsets.zero
                : EdgeInsetsDirectional.symmetric(
                    horizontal: dimensions.horizontalPadding,
                  ),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(
                _isIconOnly ? AppDimensions.radiusCircular : AppDimensions.radiusSm,
              ),
              border: style.border,
              boxShadow: _pressed && style.glowPressed != null
                  ? style.glowPressed
                  : style.glow,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    return button;
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Widget _buildIconChild(_ButtonStyle style, _ButtonDimensions dimensions) {
    return SizedBox(
      width: AppDimensions.minTapTarget,
      height: AppDimensions.minTapTarget,
      child: widget.isLoading
          ? SizedBox(
              width: AppDimensions.iconMedium,
              height: AppDimensions.iconMedium,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: style.foreground,
              ),
            )
          : Icon(widget.icon, color: style.foreground, size: AppDimensions.iconMedium),
    );
  }

  Widget _buildLabelChild(_ButtonStyle style, _ButtonDimensions dimensions) {
    final labelRow = Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: AppDimensions.iconMedium,
            color: style.foreground,
          ),
          if (widget.label.isNotEmpty)
            const SizedBox(width: AppDimensions.spacingSm),
        ],
        if (widget.label.isNotEmpty)
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dimensions.labelStyle.copyWith(color: style.foreground),
            ),
          ),
      ],
    );

    if (!widget.isLoading) {
      return labelRow;
    }

    final spinner = SizedBox(
      width: AppDimensions.iconSmall,
      height: AppDimensions.iconSmall,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: style.foreground,
      ),
    );

    // Full-width buttons: parent already sets width — center spinner in the
    // content box without a ghost row (avoids RTL / Flexible offset).
    if (widget.isExpanded) {
      return Center(child: spinner);
    }

    // Compact buttons: ghost label preserves intrinsic width; spinner centered.
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: labelRow),
        spinner,
      ],
    );
  }

  _ButtonStyle _resolveStyle(bool isDark) {
    switch (widget.variant) {
      case DaftarButtonVariant.primary:
        return _ButtonStyle(
          background: isDark ? AppColors.surface2 : AppColors.surface1Light,
          foreground: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          border: Border.all(
            color: isDark ? AppColors.lapis400 : AppColors.lapis500,
            width: AppDimensions.dividerThickness,
          ),
          glow: AppGlows.ctaRest,
          glowPressed: AppGlows.ctaPressed,
        );
      case DaftarButtonVariant.secondary:
        return _ButtonStyle(
          background: isDark ? AppColors.surface3 : AppColors.surface2Light,
          foreground: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          border: Border.all(
            color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
            width: AppDimensions.dividerThickness,
          ),
        );
      case DaftarButtonVariant.tertiary:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
        );
      case DaftarButtonVariant.destructive:
        return _ButtonStyle(
          background: isDark ? AppColors.debt : AppColors.debtLight,
          foreground: isDark ? AppColors.onDebt : AppColors.onDebtLight,
        );
      case DaftarButtonVariant.destructiveOutlined:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: isDark ? AppColors.debt : AppColors.debtLight,
          border: Border.all(
            color: isDark ? AppColors.debt : AppColors.debtLight,
            width: 1.5,
          ),
        );
      case DaftarButtonVariant.premium:
        return _ButtonStyle(
          background: isDark ? AppColors.surface2 : AppColors.surface1Light,
          foreground: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          border: Border.all(
            color: isDark ? AppColors.lapis400 : AppColors.lapis500,
            width: AppDimensions.dividerThickness,
          ),
          glow: AppGlows.premiumProPlus,
          glowPressed: AppGlows.ctaPressed,
        );
    }
  }

  _ButtonDimensions _resolveDimensions() {
    switch (widget.size) {
      case DaftarButtonSize.small:
        return const _ButtonDimensions(
          height: AppDimensions.minTapTarget,
          horizontalPadding: AppDimensions.spacingMd,
          minWidth: 64,
          labelStyle: AppTextStyles.labelMedium,
        );
      case DaftarButtonSize.medium:
        return const _ButtonDimensions(
          height: AppDimensions.minTapTarget,
          horizontalPadding: AppDimensions.spacingLg,
          minWidth: 96,
          labelStyle: AppTextStyles.labelLarge,
        );
      case DaftarButtonSize.large:
        return const _ButtonDimensions(
          height: AppDimensions.comfortableTapTarget,
          horizontalPadding: AppDimensions.spacingXl,
          minWidth: 128,
          labelStyle: AppTextStyles.labelLarge,
        );
      case DaftarButtonSize.xlarge:
        return const _ButtonDimensions(
          height: AppDimensions.largeTapTarget,
          horizontalPadding: AppDimensions.spacingXxl,
          minWidth: 96,
          labelStyle: AppTextStyles.labelLarge,
        );
    }
  }
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.border,
    this.glow,
    this.glowPressed,
  });

  final Color background;
  final Color foreground;
  final BoxBorder? border;
  final List<BoxShadow>? glow;
  final List<BoxShadow>? glowPressed;
}

class _ButtonDimensions {
  const _ButtonDimensions({
    required this.height,
    required this.horizontalPadding,
    required this.minWidth,
    required this.labelStyle,
  });

  final double height;
  final double horizontalPadding;
  final double minWidth;
  final TextStyle labelStyle;
}
