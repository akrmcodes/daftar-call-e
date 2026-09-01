import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Presents the About Daftar bottom sheet.
Future<void> showSettingsAboutSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return AppBottomSheet.show<void>(
    context,
    title: l10n.settingsAbout,
    trailing: DaftarCloseIconButton(
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    scrollable: false,
    child: const _SettingsAboutBody(),
  );
}

class _SettingsAboutBody extends StatelessWidget {
  const _SettingsAboutBody();

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
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: AppGlows.haloMd,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface3 : AppColors.surface1Light,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: AppColors.lapis400.withValues(alpha: 0.35),
                  width: AppDimensions.dividerThickness,
                ),
              ),
              child: const DaftarBrandMark(size: AppDimensions.iconLarge),
            ),
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          l10n.appTitle,
          style: AppTextStyles.titleLarge.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppDimensions.spacingXs),
        Text(
          l10n.settingsVersionLabel(AppConstants.appVersionLabel),
          style: AppTextStyles.labelSmall.copyWith(
            color: inkMuted,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          l10n.settingsAboutDescription,
          style: AppTextStyles.bodyMedium.copyWith(
            color: inkSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.start,
        ),
        const Gap(AppDimensions.spacingLg),
        _AboutFeatureRow(
          icon: Icons.wifi_off_rounded,
          label: l10n.settingsAboutOfflineFirst,
          isDark: isDark,
        ),
        const Gap(AppDimensions.spacingSm),
        _AboutFeatureRow(
          icon: Icons.translate_rounded,
          label: l10n.settingsAboutArabicFirst,
          isDark: isDark,
        ),
        const Gap(AppDimensions.spacingSm),
        _AboutFeatureRow(
          icon: Icons.verified_user_outlined,
          label: l10n.settingsAboutFinancialGrade,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _AboutFeatureRow extends StatelessWidget {
  const _AboutFeatureRow({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    return Row(
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSmall,
          color: inkSecondary,
        ),
        const Gap(AppDimensions.spacingMd),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: inkSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
