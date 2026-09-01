import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/presentation/shared/widgets/khazna_specular_panel.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Ephemeral hold-to-talk hint above the glass composer dock.
class ClosingAgentMicHintChip extends StatelessWidget {
  /// Creates the mic hint chip.
  const ClosingAgentMicHintChip({
    required this.message,
    super.key,
  });

  /// Localized hold-to-talk copy.
  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return Align(
      alignment: AlignmentDirectional.center,
      child: KhaznaSpecularPanel(
        shape: KhaznaSpecularPanelShape.pill,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingXs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_outlined,
              size: AppDimensions.iconSmall,
              color: inkMuted,
            ),
            const Gap(AppDimensions.spacingXs),
            Text(
              message,
              style: AppTextStyles.labelSmall.copyWith(
                color: ink,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
