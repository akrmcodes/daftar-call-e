import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';

/// The severity level for a free-tier limit banner.
enum LimitWarningSeverity {
  warning,
  error,
}

/// Banner that highlights approaching or exceeded free-tier limits.
class LimitWarningBanner extends StatelessWidget {
  const LimitWarningBanner({
    required this.currentCount,
    required this.maximumCount,
    required this.resourceLabel,
    super.key,
    this.severity = LimitWarningSeverity.warning,
    this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCtaPressed,
  });

  final int currentCount;
  final int maximumCount;
  final String resourceLabel;
  final LimitWarningSeverity severity;
  final String? title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final accentColor = severity == LimitWarningSeverity.warning
        ? AppColors.warning
        : AppColors.error;
    final titleColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedColor = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final surfaceColor = isDark
        ? AppColors.surface3
        : AppColors.surface2Light;
    final backgroundOpacity = severity == LimitWarningSeverity.warning
        ? 0.14
        : 0.12;
    final backgroundColor = Color.alphaBlend(
      accentColor.withValues(alpha: backgroundOpacity),
      surfaceColor,
    );
    final rawProgress = maximumCount <= 0 ? 0.0 : currentCount / maximumCount;
    final progress = rawProgress > 1.0 ? 1.0 : rawProgress;
    final countStyle = AppTextStyles.amountSmall.copyWith(
      color: accentColor,
      fontWeight: FontWeight.w700,
    );

    return FadeSlideTransition(
      child: Semantics(
        liveRegion: severity == LimitWarningSeverity.error,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            child: Row(
              textDirection: Directionality.of(context),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppDimensions.iconLarge,
                  height: AppDimensions.iconLarge,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    severity == LimitWarningSeverity.warning
                        ? Icons.warning_amber_rounded
                        : Icons.dangerous_rounded,
                    color: accentColor,
                    size: AppDimensions.iconMedium,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppDimensions.spacingSm,
                        runSpacing: AppDimensions.spacingXs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$currentCount/$maximumCount',
                            style: countStyle,
                          ),
                          Text(
                            resourceLabel,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: titleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingXxs),
                      Text(
                        title ??
                            (severity == LimitWarningSeverity.warning
                                ? l10n.limitWarningTitle
                                : l10n.limitReachedTitle),
                        style: AppTextStyles.titleMedium.copyWith(
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXxs),
                      Text(
                        subtitle ??
                            (severity == LimitWarningSeverity.warning
                                ? l10n.limitWarningSubtitle
                                : l10n.limitReachedSubtitle),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusCircular,
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.surface5
                              : AppColors.surface3Light,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      ),
                      if (onCtaPressed != null && ctaLabel != null) ...[
                        const SizedBox(height: AppDimensions.spacingMd),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: onCtaPressed,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(ctaLabel!),
                            style: TextButton.styleFrom(
                              foregroundColor: accentColor,
                              minimumSize: const Size(
                                AppDimensions.minTapTarget,
                                AppDimensions.minTapTarget,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spacingSm,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
