import 'dart:math';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/import_csv_notifier.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Post-import results — metric cards, error list, and navigation actions.
class ImportCsvSummaryBlock extends StatelessWidget {
  const ImportCsvSummaryBlock({
    required this.state,
    required this.onReset,
    super.key,
  });

  final ImportCsvUiState state;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    final blocking = state.summaryBlockingMessage;
    if (blocking != null) {
      return FadeSlideTransition(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DaftarCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: isDark ? AppColors.debt : AppColors.debtLight,
                      ),
                      const Gap(AppDimensions.spacingMd),
                      Expanded(
                        child: Text(
                          l10n.csvImportBlockingFailureTitle,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: inkPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppDimensions.spacingMd),
                  Text(
                    blocking,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(AppDimensions.spacingXl),
            DaftarButton(
              label: l10n.retry,
              variant: DaftarButtonVariant.secondary,
              size: DaftarButtonSize.large,
              isExpanded: true,
              onPressed: onReset,
            ),
          ],
        ),
      );
    }

    final result = state.summaryResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final errorListHeight = min(
      result.errors.length * 56.0,
      MediaQuery.sizeOf(context).height * 0.32,
    );

    final successRate = result.totalRows > 0
        ? result.successCount / result.totalRows
        : 0.0;

    return FadeSlideTransition(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DaftarCard(
            variant: DaftarCardVariant.hero,
            child: Column(
              children: [
                Icon(
                  result.failureCount == 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.fact_check_outlined,
                  size: 40,
                  color: result.failureCount == 0
                      ? (isDark ? AppColors.payment : AppColors.paymentLight)
                      : (isDark ? AppColors.warning : AppColors.warningLight),
                ),
                const Gap(AppDimensions.spacingMd),
                Text(
                  l10n.csvImportSummaryTitle,
                  style: AppTextStyles.headlineMedium.copyWith(color: inkPrimary),
                  textAlign: TextAlign.center,
                ),
                const Gap(AppDimensions.spacingLg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: successRate,
                    backgroundColor: isDark
                        ? AppColors.surface5
                        : AppColors.surface3Light,
                    color: isDark ? AppColors.payment : AppColors.paymentLight,
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppDimensions.spacingLg),
          _MetricCard(
            label: l10n.csvImportTotalRows,
            valueText: '${result.totalRows}',
            accent: inkPrimary,
          ),
          _MetricCard(
            label: l10n.csvImportSuccessLabel,
            valueText: '${result.successCount}',
            accent: isDark ? AppColors.payment : AppColors.paymentLight,
          ),
          _MetricCard(
            label: l10n.csvImportFailureLabel,
            valueText: '${result.failureCount}',
            accent: isDark ? AppColors.debt : AppColors.debtLight,
          ),
          if (result.skippedDuplicateRows > 0)
            _MetricCard(
              label: l10n.csvImportSkippedDuplicatesLabel,
              valueText: '${result.skippedDuplicateRows}',
              accent: isDark ? AppColors.warning : AppColors.warningLight,
            ),
          if (result.errors.isNotEmpty) ...[
            const Gap(AppDimensions.spacingLg),
            Text(
              l10n.csvImportRowErrors,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarCard(
              variant: DaftarCardVariant.compact,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: errorListHeight,
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.all(
                    AppDimensions.spacingMd,
                  ),
                  itemCount: result.errors.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderSubtle
                        : AppColors.borderSubtleLight,
                  ),
                  itemBuilder: (context, index) {
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        result.errors[index],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.inkSecondary
                              : AppColors.inkSecondaryLight,
                          fontFamily: AppTextStyles.latinFontFamily,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const Gap(AppDimensions.spacingXl),
          Row(
            children: [
              Expanded(
                child: DaftarButton(
                  label: l10n.csvImportAnotherFile,
                  variant: DaftarButtonVariant.secondary,
                  size: DaftarButtonSize.large,
                  onPressed: onReset,
                ),
              ),
              const Gap(AppDimensions.spacingMd),
              Expanded(
                child: DaftarButton(
                  label: l10n.csvImportFinish,
                  size: DaftarButtonSize.large,
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.valueText,
    required this.accent,
  });

  final String label;
  final String valueText;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingSm,
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                valueText,
                style: AppTextStyles.amountMedium.copyWith(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
