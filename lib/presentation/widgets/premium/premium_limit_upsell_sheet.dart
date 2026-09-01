import 'dart:async';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Persuasive bottom sheet when a workspace limit blocks an action.
abstract final class PremiumLimitUpsellSheet {
  static Future<void> show(
    BuildContext context, {
    required LimitExceededFailure failure,
  }) {
    unawaited(HapticFeedback.mediumImpact());
    return AppBottomSheet.show<void>(
      context,
      maxHeightFactor: 0.72,
      child: _PremiumLimitUpsellBody(failure: failure),
    );
  }
}

class _PremiumLimitUpsellBody extends StatelessWidget {
  const _PremiumLimitUpsellBody({required this.failure});

  final LimitExceededFailure failure;

  String _resourceLabel(AppLocalizations l10n) {
    return switch (failure.featureKey) {
      AppConstants.featureUnlimitedLedgers => l10n.tierFeatureLedgers,
      AppConstants.featureUnlimitedContacts => l10n.tierFeatureContacts,
      AppConstants.featureUnlimitedTransactions => l10n.tierFeatureTransactions,
      AppConstants.featureLedgerArchiving => l10n.tierFeatureLedgerArchiving,
      'brandedPdf' => l10n.tierFeatureBrandedPdf,
      _ => l10n.tierFeatureContacts,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final isFeatureGate = failure.maxAllowed <= 0;
    final progress = failure.maxAllowed <= 0
        ? 1.0
        : (failure.currentCount / failure.maxAllowed).clamp(0.0, 1.0);

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
                Icons.lock_open_rounded,
                color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
                size: 36,
              ),
            ),
          ).animate().scale(
            begin: const Offset(0.6, 0.6),
            end: const Offset(1, 1),
            duration: 500.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            l10n.limitUpsellTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            l10n.limitUpsellSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          if (!isFeatureGate) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: isDark
                    ? AppColors.surface5
                    : AppColors.surface3Light,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.warning),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              l10n.limitUpsellProgress(
                failure.currentCount,
                failure.maxAllowed,
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
          Text(
            _resourceLabel(l10n),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          DaftarButton(
            label: l10n.limitUpsellCta,
            isExpanded: true,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(context.pushNamed(RouteNames.activation));
            },
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
