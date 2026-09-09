import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna outreach rail card — title, human subtitle, and adaptive switch.
///
/// Lapis appears as hairline border + [AppGlows.haloXs] when [value] is true;
/// never as card fill or switch track paint (§8.10).
class CollectionsDeskRailCard extends StatelessWidget {
  /// Creates a rail card.
  const CollectionsDeskRailCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  /// Rail title (Voice calls / Email statements).
  final String title;

  /// Human-readable breakdown or skipped copy.
  final String subtitle;

  /// Whether this rail is included in the commit.
  final bool value;

  /// False while in-flight or after call rail is committed.
  final bool enabled;

  /// Toggles local intent before the merchant commits.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final trackOff = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final trackOn = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final thumbOn = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final thumbOff =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    void toggle() {
      if (!enabled) {
        return;
      }
      unawaited(HapticService.selection());
      onChanged(!value);
    }

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: '$title. $subtitle',
      child: AnimatedContainer(
        duration: AppDimensions.animationFast,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: value && enabled ? AppGlows.haloXs : null,
        ),
        child: DaftarCard(
          variant: DaftarCardVariant.compact,
          isSelected: value && enabled,
          margin: EdgeInsets.zero,
          onTap: enabled ? toggle : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: enabled
                            ? inkPrimary
                            : inkPrimary.withValues(
                                alpha: AppColors.alphaMedium,
                              ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(AppDimensions.spacingXxs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: value && enabled ? inkSecondary : inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppDimensions.spacingSm),
              DaftarTapTarget(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    switchTheme: SwitchThemeData(
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return thumbOn;
                        }
                        return thumbOff;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return trackOn;
                        }
                        return trackOff;
                      }),
                      trackOutlineColor: WidgetStateProperty.resolveWith(
                        (states) {
                          if (states.contains(WidgetState.selected)) {
                            return isDark
                                ? AppColors.lapis400
                                : AppColors.lapis500;
                          }
                          return Colors.transparent;
                        },
                      ),
                    ),
                    cupertinoOverrideTheme: CupertinoThemeData(
                      primaryColor: thumbOn,
                      applyThemeToAll: true,
                    ),
                  ),
                  child: Switch.adaptive(
                    value: value,
                    onChanged: enabled
                        ? (next) {
                            unawaited(HapticService.selection());
                            onChanged(next);
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
