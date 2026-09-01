import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Compact monochrome trust signals under the activation panel.
class PlanTrustStrip extends StatelessWidget {
  const PlanTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      children: [
        _TrustRow(
          icon: Icons.lock_outline_rounded,
          label: l10n.premiumTrustEncrypted,
          color: muted,
        ),
        const Gap(AppDimensions.spacingSm),
        _TrustRow(
          icon: Icons.cloud_off_outlined,
          label: l10n.premiumTrustOffline,
          color: muted,
        ),
      ],
    ).animate().fadeIn(delay: 120.ms, duration: 350.ms);
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
