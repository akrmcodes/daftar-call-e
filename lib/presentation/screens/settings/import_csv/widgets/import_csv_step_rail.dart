import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/import_csv_notifier.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Horizontal phase rail — monochrome steps with a single active emphasis.
class ImportCsvStepRail extends StatelessWidget {
  const ImportCsvStepRail({
    required this.phase,
    super.key,
  });

  final ImportCsvPhase phase;

  int get _activeIndex => switch (phase) {
        ImportCsvPhase.idle => 0,
        ImportCsvPhase.preview => 1,
        ImportCsvPhase.importing => 2,
        ImportCsvPhase.summary => 3,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final borderSubtle =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    final labels = [
      l10n.csvImportStepFile,
      l10n.csvImportStepMapping,
      l10n.csvImportStepImport,
      l10n.csvImportStepDone,
    ];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: AppDimensions.dividerThickness,
                margin: const EdgeInsetsDirectional.only(
                  bottom: AppDimensions.spacingLg,
                ),
                color: i <= _activeIndex ? inkSecondary : borderSubtle,
              ),
            ),
          _StepNode(
            index: i,
            label: labels[i],
            isActive: i == _activeIndex,
            isComplete: i < _activeIndex,
            inkPrimary: inkPrimary,
            inkMuted: inkMuted,
            inkSecondary: inkSecondary,
            borderSubtle: borderSubtle,
            isDark: isDark,
          ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isComplete,
    required this.inkPrimary,
    required this.inkMuted,
    required this.inkSecondary,
    required this.borderSubtle,
    required this.isDark,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isComplete;
  final Color inkPrimary;
  final Color inkMuted;
  final Color inkSecondary;
  final Color borderSubtle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final ringColor = isActive
        ? (isDark ? AppColors.borderStrong : AppColors.borderStrongLight)
        : borderSubtle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isComplete ? surface : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: isActive ? 1.5 : AppDimensions.dividerThickness,
            ),
          ),
          alignment: Alignment.center,
          child: isComplete
              ? Icon(
                  Icons.check_rounded,
                  size: AppDimensions.iconSmall,
                  color: inkSecondary,
                )
              : Text(
                  '${index + 1}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive ? inkPrimary : inkMuted,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
        ),
        const Gap(AppDimensions.spacingXs),
        SizedBox(
          width: 56,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: isActive ? inkPrimary : inkMuted,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
