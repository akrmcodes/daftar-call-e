import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Trust manifest — sole permitted lapis fill on the account management screen.
class AccountTrustManifest extends StatelessWidget {
  const AccountTrustManifest({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppColors.lapis800 : AppColors.lapis50;
    final ink = isDark ? AppColors.onInfo : AppColors.onInfoLight;
    final border = AppColors.lapis400.withValues(alpha: 0.35);

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 120),
      duration: AppDimensions.animationSlow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TrustLine(
                icon: Icons.smartphone_outlined,
                text: l10n.accountManagementTrustLocalData,
                ink: ink,
              ),
              const Gap(AppDimensions.spacingSm),
              _TrustLine(
                icon: Icons.folder_special_outlined,
                text: l10n.accountManagementTrustDriveScope,
                ink: ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({
    required this.icon,
    required this.text,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ink),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: ink,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
