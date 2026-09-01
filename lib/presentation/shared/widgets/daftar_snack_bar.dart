import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Short monochrome floating snack — never Material default purple.
void showDaftarSnackBar({
  required BuildContext context,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final background = isDark ? AppColors.surface2 : AppColors.surface1Light;
  final foreground = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 0,
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.spacingLg,
          0,
          AppDimensions.spacingLg,
          AppDimensions.spacingXl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.borderSubtleLight,
            width: AppDimensions.dividerThickness,
          ),
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: foreground),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: foreground,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
