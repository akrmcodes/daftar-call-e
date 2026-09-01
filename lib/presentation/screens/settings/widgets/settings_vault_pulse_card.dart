import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_atoms.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_block.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Full-width vault health card — the visual anchor of the settings hub.
///
/// Uses [BentoBlock] lapis glow when backup attention is needed.
class SettingsVaultPulseCard extends StatelessWidget {
  const SettingsVaultPulseCard({
    required this.hasBackup,
    required this.bothSafe,
    required this.localProgress,
    required this.cloudProgress,
    required this.localColor,
    required this.cloudColor,
    required this.centerLabel,
    required this.centerColor,
    required this.onTap,
    required this.onCreateBackup,
    super.key,
  });

  final bool hasBackup;
  final bool bothSafe;
  final double localProgress;
  final double cloudProgress;
  final Color localColor;
  final Color cloudColor;
  final String centerLabel;
  final Color centerColor;
  final VoidCallback onTap;
  final VoidCallback onCreateBackup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final statusText = bothSafe
        ? l10n.backupStatusSafe
        : (hasBackup
            ? l10n.backupStatusLocalOnly
            : l10n.backupStatusNoBackupSubtitle);

    final statusColor = bothSafe ? AppColors.payment : AppColors.warning;

    return BentoBlock(
      lapisGlow: !bothSafe,
      onTap: onTap,
      child: Row(
        children: [
          VaultHealthRings(
            localProgress: localProgress,
            cloudProgress: cloudProgress,
            localColor: localColor,
            cloudColor: cloudColor,
            centerLabel: centerLabel,
            centerColor: centerColor,
            size: 72,
            showLegend: true,
            localLegend: l10n.settingsCommandBackup,
            cloudLegend: l10n.settingsCloudBackupLegend,
          ),
          const Gap(AppDimensions.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.backupTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: inkSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AppDimensions.spacingXs),
                Text(
                  statusText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!hasBackup) ...[
                  const Gap(AppDimensions.spacingMd),
                  _VaultPulseAction(
                    label: l10n.backupCreateNow,
                    onTap: onCreateBackup,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: inkMuted.withValues(alpha: 0.5),
            size: AppDimensions.iconMedium,
          ),
        ],
      ),
    );
  }
}

class _VaultPulseAction extends StatefulWidget {
  const _VaultPulseAction({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  State<_VaultPulseAction> createState() => _VaultPulseActionState();
}

class _VaultPulseActionState extends State<_VaultPulseAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppDimensions.animationFast,
        child: Text(
          widget.label,
          style: AppTextStyles.labelSmall.copyWith(
            color: widget.isDark
                ? AppColors.inkSecondary
                : AppColors.inkSecondaryLight,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: (widget.isDark
                    ? AppColors.inkSecondary
                    : AppColors.inkSecondaryLight)
                .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
