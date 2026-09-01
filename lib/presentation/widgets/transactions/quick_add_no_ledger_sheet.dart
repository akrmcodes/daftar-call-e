import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/home/widgets/add_ledger_sheet.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Informs the user that quick-add requires at least one ledger.
///
/// Returns `true` when the user creates a ledger and quick-add may proceed.
abstract final class QuickAddNoLedgerSheet {
  static Future<bool> show(BuildContext context) async {
    unawaited(HapticService.selection());

    final shouldCreate = await AppBottomSheet.show<bool>(
      context,
      maxHeightFactor: 0.54,
      scrollable: false,
      child: const _QuickAddNoLedgerSheetBody(),
    );

    if (shouldCreate != true || !context.mounted) {
      return false;
    }

    final ledger = await AddLedgerSheet.show(context);
    return ledger != null;
  }
}

class _QuickAddNoLedgerSheetBody extends StatelessWidget {
  const _QuickAddNoLedgerSheetBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;

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
                color: isDark ? AppColors.surface2 : AppColors.surface1Light,
                border: Border.all(
                  color: lapis,
                  width: AppDimensions.dividerThickness,
                ),
                boxShadow: AppGlows.ctaRest,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: onSurface,
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
            l10n.quickAddNoLedgerTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            l10n.quickAddNoLedgerMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: muted),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          DaftarButton(
            label: l10n.addLedger,
            isExpanded: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.limitUpsellDismiss),
          ),
        ],
      ),
    );
  }
}
