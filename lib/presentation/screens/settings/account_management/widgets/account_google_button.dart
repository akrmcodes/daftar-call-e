import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

enum AccountGoogleButtonVariant { primary, glass }

/// Google-branded action button — primary uses Khazna monochrome + lapis glow.
///
/// Logo mark uses the official full-color Google "G"
/// (https://developers.google.com/identity/branding-guidelines).
class AccountGoogleButton extends StatefulWidget {
  const AccountGoogleButton({
    required this.label,
    required this.isDark,
    required this.isLoading,
    required this.onPressed,
    super.key,
    this.variant = AccountGoogleButtonVariant.glass,
    this.icon,
  });

  final String label;
  final bool isDark;
  final bool isLoading;
  final VoidCallback? onPressed;
  final AccountGoogleButtonVariant variant;
  final IconData? icon;

  @override
  State<AccountGoogleButton> createState() => _AccountGoogleButtonState();
}

class _AccountGoogleButtonState extends State<AccountGoogleButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == AccountGoogleButtonVariant.primary;
    final foreground =
        widget.isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    final fill = isPrimary
        ? (widget.isDark ? AppColors.surface2 : AppColors.surface1Light)
        : (widget.isDark ? AppColors.glassFill : AppColors.glassFillLight);

    final border = isPrimary
        ? Border.all(
            color: widget.isDark ? AppColors.lapis400 : AppColors.lapis500,
            width: AppDimensions.dividerThickness,
          )
        : Border.all(
            color: widget.isDark
                ? AppColors.borderSubtle.withValues(alpha: 0.55)
                : AppColors.borderSubtleLight.withValues(alpha: 0.7),
          );

    final glow = isPrimary
        ? (_pressed && _enabled ? AppGlows.ctaPressed : AppGlows.ctaRest)
        : null;

    return Semantics(
      button: true,
      label: widget.label,
      enabled: _enabled,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                unawaited(HapticService.buttonPress());
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed && _enabled ? 0.97 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppDimensions.animationFast,
            height: AppDimensions.minTapTarget,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(
                isPrimary
                    ? AppDimensions.radiusSm
                    : AppDimensions.radiusCircular,
              ),
              border: border,
              boxShadow: glow,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.spacingXl,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    )
                  else ...[
                    if (widget.icon != null)
                      Icon(widget.icon, size: 22, color: foreground)
                    else
                      const GoogleGLogoMark(),
                    const Gap(AppDimensions.spacingMd),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Official full-color Google "G" mark.
///
/// Asset: `assets/icons/google_g_logo.svg` — Google product logo
/// (`fonts.gstatic.com/.../googleg/v6`). Do not recolor or distort.
class GoogleGLogoMark extends StatelessWidget {
  const GoogleGLogoMark({super.key, this.size = 18});

  /// Diameter of the Google "G" glyph.
  final double size;

  static const String assetPath = 'assets/icons/google_g_logo.svg';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google',
      image: true,
      excludeSemantics: true,
      child: SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        excludeFromSemantics: true,
      ),
    );
  }
}
