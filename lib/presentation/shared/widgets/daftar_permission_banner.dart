import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna info banner — the sole allowed lapis fill (`lapis800` / `lapis50`).
///
/// Used for permission-missing and hold-to-talk hints. The CTA is a
/// monochrome secondary button (never a lapis fill). Callers must not
/// invoke Settings / Sign-in from `initState`; the merchant taps the action.
class DaftarPermissionBanner extends StatelessWidget {
  /// Creates an info permission / hint banner.
  const DaftarPermissionBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
    super.key,
  });

  /// Localized body copy.
  final String message;

  /// Localized action label. Null hides the button.
  final String? actionLabel;

  /// User-gesture action (Open Settings, Sign in). Never auto-fired.
  final VoidCallback? onAction;

  /// Optional override for the screen-reader label.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.onInfo : AppColors.onInfoLight;
    final showAction =
        actionLabel != null &&
        actionLabel!.trim().isNotEmpty &&
        onAction != null;

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel ?? message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.lapis800 : AppColors.lapis50,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.lapis400, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: ink),
              ),
              if (showAction) ...[
                const Gap(AppDimensions.spacingSm),
                DaftarButton(
                  label: actionLabel!,
                  variant: DaftarButtonVariant.secondary,
                  size: DaftarButtonSize.small,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
