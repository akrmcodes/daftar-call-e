import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Upload / restore action tiles for the signed-in Drive section.
class DriveActionGrid extends StatelessWidget {
  const DriveActionGrid({
    required this.l10n,
    required this.onUpload,
    required this.onRestoreList,
    super.key,
  });

  final AppLocalizations l10n;
  final VoidCallback onUpload;
  final VoidCallback? onRestoreList;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DriveActionTile(
            icon: Icons.cloud_upload_rounded,
            label: l10n.backupDriveBackupToDrive,
            emphasized: true,
            onTap: onUpload,
          ),
        ),
        const Gap(AppDimensions.spacingMd),
        Expanded(
          child: DriveActionTile(
            icon: Icons.cloud_download_rounded,
            label: l10n.backupDriveRestoreFromDrive,
            onTap: onRestoreList,
          ),
        ),
      ],
    );
  }
}

class DriveActionTile extends StatelessWidget {
  const DriveActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.surface3 : AppColors.surface1Light;
    final ink =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final borderColor = emphasized
        ? AppColors.lapis400
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: borderColor,
              width: 0.5,
            ),
          ),
          child: SizedBox(
            height: 96,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: ink, size: 26),
                  const Gap(AppDimensions.spacingSm),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppDimensions.spacingSm,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
