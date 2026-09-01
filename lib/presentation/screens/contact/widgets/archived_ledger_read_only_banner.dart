import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';

class ArchivedLedgerReadOnlyBanner extends StatelessWidget {
  const ArchivedLedgerReadOnlyBanner({
    this.title,
    this.subtitle,
    super.key,
  });

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = AppColors.warning;
    final backgroundColor = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.12 : 0.10),
      colors.surface,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingSm,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingXs,
        ),
        child: FadeSlideTransition(
          child: Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: accentColor.withValues(
                    alpha: isDark ? 0.18 : 0.16,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.cardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: AppDimensions.iconLarge,
                      height: AppDimensions.iconLarge,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.lock_clock_outlined,
                        color: accentColor,
                        size: AppDimensions.iconMedium,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? l10n.contactArchivedReadOnlyTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            subtitle ?? l10n.contactArchivedReadOnlySubtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
