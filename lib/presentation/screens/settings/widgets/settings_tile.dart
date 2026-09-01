import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Premium settings row — scale press, no Material ripple.
class SettingsTile extends StatefulWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.showChevron = true,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool showChevron;
  final Widget? badge;

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final interactive = widget.onTap != null;

    final content = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.spacingLg,
        vertical: AppDimensions.spacingMd,
      ),
      child: Row(
        children: [
          Icon(
            widget.icon,
            size: AppDimensions.iconMedium,
            color: inkSecondary,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.title,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: inkPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.badge != null) ...[
                      const SizedBox(width: AppDimensions.spacingSm),
                      widget.badge!,
                    ],
                  ],
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AppDimensions.spacingXxs),
                  Text(
                    widget.subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: inkSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailingText != null) ...[
            const SizedBox(width: AppDimensions.spacingSm),
            Text(
              widget.trailingText!,
              style: AppTextStyles.bodySmall.copyWith(
                color: inkSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (widget.trailing != null) widget.trailing!,
          if (widget.showChevron && interactive && widget.trailing == null)
            Icon(
              Icons.chevron_right_rounded,
              color: inkSecondary.withValues(alpha: 0.7),
              size: AppDimensions.iconMedium,
            ),
        ],
      ),
    );

    if (!interactive) {
      return content;
    }

    return Semantics(
      button: true,
      label: widget.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.light());
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: content,
        ),
      ),
    );
  }
}

/// Toggle row with a styled [CupertinoSwitch].
class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppColors.surface5 : AppColors.surface3Light;

    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      showChevron: false,
      trailing: Transform.scale(
        scale: 0.88,
        child: CupertinoSwitch(
          value: value,
          activeTrackColor: AppColors.payment,
          inactiveTrackColor: trackColor,
          onChanged: (next) {
            unawaited(HapticService.toggleFlipped());
            onChanged(next);
          },
        ),
      ),
    );
  }
}
