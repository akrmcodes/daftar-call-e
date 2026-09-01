import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Monochrome progress rows for summary / backup / shortlist.
class ClosingRitualProgress extends StatelessWidget {
  /// Creates the progress card.
  const ClosingRitualProgress({
    required this.stepsDone,
    super.key,
  });

  /// Count of completed steps (0–3).
  final int stepsDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final labels = [
      l10n.closingRitualProgressSummary,
      l10n.closingRitualProgressBackup,
      l10n.closingRitualProgressShortlist,
    ];

    return RepaintBoundary(
      child: DaftarCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.closingRitualRunning,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingMd),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: labels.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppDimensions.spacingSm,
                  ),
                  child: _ProgressRow(
                    label: labels[index],
                    isDone: stepsDone > index,
                    isCurrent: stepsDone == index,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isDark,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final payment = isDark ? AppColors.payment : AppColors.paymentLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;

    final IconData icon;
    final Color color;
    if (isDone) {
      icon = Icons.check_circle_rounded;
      color = payment;
    } else if (isCurrent) {
      icon = Icons.hourglass_top_rounded;
      color = warning;
    } else {
      icon = Icons.circle_outlined;
      color = inkMuted;
    }

    return Row(
      children: [
        Icon(icon, size: AppDimensions.iconMedium, color: color),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDone || isCurrent ? inkPrimary : inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
