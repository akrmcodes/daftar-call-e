import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// iOS-style squircle container for grouped settings rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  static SmoothBorderRadius get _radius => SmoothBorderRadius(
        cornerRadius: AppDimensions.radiusMd,
        cornerSmoothing: 0.6,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppDimensions.spacingSm,
            bottom: AppDimensions.spacingSm,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: titleColor,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: ClipSmoothRect(
            radius: _radius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2 : AppColors.surface1Light,
                border: Border.all(
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight,
                  width: AppDimensions.dividerThickness,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Divider(
                        height: AppDimensions.dividerThickness,
                        thickness: AppDimensions.dividerThickness,
                        color: isDark
                            ? AppColors.borderSubtle
                            : AppColors.borderSubtleLight,
                        indent: AppDimensions.spacingLg + AppDimensions.iconMedium + AppDimensions.spacingMd,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
