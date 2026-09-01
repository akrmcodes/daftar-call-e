import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Floating pill toggle — the interactive atom inside the Hero Bento Card.
///
/// Fixed 56dp height for pixel-perfect Apple-tier alignment across the grid.
/// Set [iconOnly] to hide labels and center the icon (security toggles).
class GlowPillToggle extends StatelessWidget {
  const GlowPillToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.sublabel,
    this.icon,
    this.compact = false,
    this.iconOnly = false,
    this.enabled = true,
    this.onDisabledTap,
  });

  static const double pillHeight = 56;

  final String label;
  final String? sublabel;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// When `true`, uses a denser horizontal layout (height stays 56dp).
  final bool compact;

  /// When `true`, hides label text and centers the icon for minimal pills.
  final bool iconOnly;

  /// When `false`, the switch is inactive and [onDisabledTap] runs on interaction.
  final bool enabled;

  /// Called when the user interacts while [enabled] is `false`.
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = value
        ? (isDark ? AppColors.surface5 : AppColors.surface1Light)
        : (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surface3Light);

    final borderColor = value
        ? AppColors.lapis400.withValues(alpha: 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.borderSubtleLight);

    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final iconColor = value ? AppColors.lapis300 : inkMuted;
    final labelColor = value ? inkPrimary : inkSecondary;

    final pill = SizedBox(
        height: pillHeight,
        child: AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: iconOnly
                ? AppDimensions.spacingSm
                : AppDimensions.spacingMd,
          ),
          alignment: iconOnly
              ? AlignmentDirectional.center
              : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: value
                ? const [
                    BoxShadow(
                      color: Color(0x1A0356C5),
                      blurRadius: 12,
                    ),
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              if (iconOnly) ...[
                Expanded(
                  child: Center(
                    child: AnimatedScale(
                      scale: value ? 1.1 : 1.0,
                      duration: AppDimensions.animationMedium,
                      curve: value ? Curves.elasticOut : Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: AppDimensions.animationFast,
                        child: Icon(
                          icon,
                          key: ValueKey(value),
                          size: AppDimensions.iconSmall + 2,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppDimensions.iconSmall + 2,
                    color: iconColor,
                  ),
                  const Gap(AppDimensions.spacingSm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: labelColor,
                          fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sublabel != null && !compact) ...[
                        const Gap(1),
                        Text(
                          sublabel!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: inkMuted,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const Gap(AppDimensions.spacingSm),
              Transform.scale(
                scale: 0.80,
                child: CupertinoSwitch(
                  value: value,
                  activeTrackColor: AppColors.lapis400.withValues(alpha: 0.85),
                  inactiveTrackColor:
                      isDark ? AppColors.surface6 : AppColors.surface3Light,
                  onChanged: enabled
                      ? (next) {
                          unawaited(HapticService.toggleFlipped());
                          onChanged(next);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      );

    final semantics = Semantics(
      label: label,
      toggled: value,
      enabled: enabled,
      child: !enabled && onDisabledTap != null
          ? GestureDetector(
              onTap: () {
                unawaited(HapticService.light());
                onDisabledTap!();
              },
              behavior: HitTestBehavior.opaque,
              child: pill,
            )
          : pill,
    );

    return semantics;
  }
}
