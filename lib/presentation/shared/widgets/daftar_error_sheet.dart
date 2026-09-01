import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/localized_error_content.dart';
import 'package:daftar/core/utils/premium_upsell_policy.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reassuring bottom sheet for operational errors — never raw exceptions.
abstract final class DaftarErrorSheet {
  static Future<void> show(
    BuildContext context, {
    required LocalizedErrorContent content,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    unawaited(HapticService.validationError());
    return AppBottomSheet.show<void>(
      context,
      maxHeightFactor: 0.52,
      scrollable: false,
      child: _DaftarErrorSheetBody(
        content: content,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  /// Maps [error], then presents the appropriate sheet.
  static Future<void> showForError(
    BuildContext context, {
    required Object error,
  }) {
    if (error is LimitExceededFailure &&
        PremiumUpsellPolicy.showsPremiumUpsell(error)) {
      return PremiumLimitUpsellSheet.show(context, failure: error);
    }
    if (error is RateLimitedFailure) {
      final l10n = AppLocalizations.of(context)!;
      final content = ErrorTranslator.translate(l10n, error);
      return show(context, content: content);
    }

    final l10n = AppLocalizations.of(context)!;
    final content = ErrorTranslator.translate(l10n, error);
    return show(context, content: content);
  }
}

class _DaftarErrorSheetBody extends StatelessWidget {
  const _DaftarErrorSheetBody({
    required this.content,
    this.actionLabel,
    this.onAction,
  });

  final LocalizedErrorContent content;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final iconBackground = AppColors.debt.withValues(alpha: isDark ? 0.18 : 0.12);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
        AppDimensions.pagePaddingH,
        AppDimensions.pagePaddingV,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBackground,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.debt,
                size: 36,
              ),
            ),
          ).animate().scale(
            begin: const Offset(0.85, 0.85),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            content.message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: muted),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          if (actionLabel != null && onAction != null) ...[
            DaftarButton(
              label: actionLabel!,
              isExpanded: true,
              onPressed: () {
                Navigator.of(context).pop();
                onAction!();
              },
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.errorSheetDismiss,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else
            DaftarButton(
              label: l10n.errorSheetDismiss,
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}
