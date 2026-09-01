import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/home/widgets/animated_create_ledger_action.dart';
import 'package:flutter/material.dart';

/// Section header for the "My Ledgers" grid on the home screen.
class HomeMyLedgersHeader extends StatelessWidget {
  const HomeMyLedgersHeader({
    required this.onAddLedgerTap,
    super.key,
  });

  final VoidCallback onAddLedgerTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colorScheme;
    final isDark = context.theme.brightness == Brightness.dark;
    final borderSubtle =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacing3xl,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surface2
                            : AppColors.surface1Light,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: lapis,
                          width: AppDimensions.dividerThickness,
                        ),
                        boxShadow: AppGlows.haloXs,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Flexible(
                      child: Text(
                        l10n.myLedgers,
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              AnimatedCreateLedgerAction(onTap: onAddLedgerTap),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  borderSubtle.withValues(alpha: 0),
                  borderSubtle,
                  borderSubtle.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
