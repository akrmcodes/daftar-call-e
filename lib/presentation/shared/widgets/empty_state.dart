import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';

/// Centered empty state with a soft icon badge and localized copy.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCtaPressed,
    this.ctaIcon,
    this.iconColor,
    this.iconBackgroundColor,
    this.maxWidth = 320,
  });

  final IconData icon;
  final String? title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;
  final IconData? ctaIcon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final onSurfaceColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedColor = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final iconTint = iconColor ??
        (isDark ? AppColors.inkMuted : AppColors.inkMutedLight);
    final backgroundColor =
        iconBackgroundColor ??
        (isDark ? AppColors.surface3 : AppColors.surface2Light);
    final badgeBorderColor =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return FadeSlideTransition(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pagePaddingH,
              vertical: AppDimensions.spacing4xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: badgeBorderColor,
                      ),
                      boxShadow: AppGlows.listTileEdge,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size:
                          AppDimensions.iconLarge + AppDimensions.spacingSm * 2,
                      color: iconTint,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  title ?? l10n.emptyStateTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: onSurfaceColor,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  subtitle ?? l10n.emptyStateSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: mutedColor,
                  ),
                ),
                if (onCtaPressed != null) ...[
                  const SizedBox(height: AppDimensions.spacingXl),
                  DaftarButton(
                    label: ctaLabel ?? l10n.emptyStateAction,
                    icon: ctaIcon ?? Icons.add_rounded,
                    onPressed: onCtaPressed,
                    size: DaftarButtonSize.large,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
