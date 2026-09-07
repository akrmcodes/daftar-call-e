import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Monochrome call progress from per-row results (no fake spinner).
class CollectionsCallProgressBar extends StatelessWidget {
  /// Creates the progress bar.
  const CollectionsCallProgressBar({
    required this.progress,
    this.barHeight = 4,
    super.key,
  });

  /// Device-side call progress.
  final CollectionsCallProgress progress;

  /// Track height — session UI uses a thicker lapis-edged bar.
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final track = isDark ? AppColors.surface5 : AppColors.surface3Light;

    final total = progress.total;
    final index = progress.callingIndex;
    final fraction = total == 0 ? 0.0 : index / total;
    final latestStatus = progress.latestRowStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.collectionsDeskCallingProgress(index, total),
                style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
              ),
            ),
            if (latestStatus != null)
              Text(
                statusLabel(l10n, latestStatus),
                style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
              ),
          ],
        ),
        const Gap(AppDimensions.spacingXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          child: SizedBox(
            height: barHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: track),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction.clamp(0, 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: inkPrimary,
                      border: const Border(
                        top: BorderSide(color: AppColors.lapis400, width: 2),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String statusLabel(
    AppLocalizations l10n,
    CollectionsCallRowStatus status,
  ) {
    return switch (status) {
      CollectionsCallRowStatus.planned => l10n.architectureHudCallPlanned,
      CollectionsCallRowStatus.ringing => l10n.architectureHudCallRinging,
      CollectionsCallRowStatus.completed => l10n.architectureHudCallCompleted,
      CollectionsCallRowStatus.failed => l10n.architectureHudCallFailed,
    };
  }
}
