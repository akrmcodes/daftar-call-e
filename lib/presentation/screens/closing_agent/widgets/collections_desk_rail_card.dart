import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna outreach rail — Settings-style title row + compact body lines.
///
/// Active rails use a stepped surface tint + [AppGlows.haloXs] only (no stroke).
/// Switch ON uses semantic [AppColors.payment] (matches Settings toggles).
class CollectionsDeskRailCard extends StatelessWidget {
  /// Creates a rail card.
  const CollectionsDeskRailCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.detail,
    super.key,
  });

  /// Rail title (Voice calls / Email statements).
  final String title;

  /// Primary body line (scheduled calls, statement count, or skipped).
  final String subtitle;

  /// Optional second line (PDF / text tier breakdown).
  final String? detail;

  /// Whether this rail is included in the commit.
  final bool value;

  /// False while in-flight or after call rail is committed.
  final bool enabled;

  /// Toggles local intent before the merchant commits.
  final ValueChanged<bool> onChanged;

  /// Compact switch scale — Khazna Settings tiles use the same density.
  static const double _switchScale = 0.82;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = value && enabled;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final trackOff = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final thumbOn = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final surfaceActive = isDark ? AppColors.surface4 : AppColors.surface3Light;
    final semanticsBody = detail == null ? subtitle : '$subtitle. $detail';

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
      label: '$title. $semanticsBody',
      child: AnimatedContainer(
        duration: AppDimensions.animationFast,
        curve: AppMotion.curveEnter,
        decoration: BoxDecoration(
          color: active ? surfaceActive : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: active ? AppGlows.haloXs : null,
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.spacingMd,
          AppDimensions.spacingSm,
          AppDimensions.spacingSm,
          AppDimensions.spacingSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? toggle : null,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: enabled
                            ? inkPrimary
                            : inkPrimary.withValues(
                                alpha: AppColors.alphaMedium,
                              ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: _switchScale,
                  alignment: AlignmentDirectional.centerEnd,
                  child: CupertinoSwitch(
                    value: value,
                    activeTrackColor: AppColors.payment,
                    inactiveTrackColor: trackOff,
                    thumbColor: thumbOn,
                    onChanged: enabled
                        ? (next) {
                            unawaited(HapticService.selection());
                            onChanged(next);
                          }
                        : null,
                  ),
                ),
              ],
            ),
            const Gap(AppDimensions.spacingXxs),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? toggle : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: active ? inkSecondary : inkMuted,
                      height: 1.35,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (detail != null && detail!.trim().isNotEmpty) ...[
                    const Gap(AppDimensions.spacingXxs),
                    Text(
                      detail!,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
