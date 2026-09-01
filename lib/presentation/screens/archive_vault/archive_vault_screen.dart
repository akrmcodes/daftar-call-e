import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/providers/archived_ledger_providers.dart';
import 'package:daftar/presentation/screens/archive_vault/widgets/archived_ledger_tile.dart';
import 'package:daftar/presentation/screens/archive_vault/widgets/archived_total_card.dart';
import 'package:daftar/presentation/screens/archive_vault/widgets/vault_ambient_backdrop.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:daftar/presentation/shared/widgets/empty_state.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class ArchiveVaultScreen extends ConsumerWidget {
  const ArchiveVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.surface0 : AppColors.surface0Light;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final asyncLedgers = ref.watch(archivedLedgersProvider);

    ref.listen(archiveLedgerControllerProvider, (previous, next) {
      final wasLoading = previous?.isLoading ?? false;
      if (wasLoading && next.hasValue) {
        unawaited(HapticService.success());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.unarchiveLedgerSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      next.whenOrNull(
        error: (error, _) {
          if (error is LimitExceededFailure) {
            unawaited(
              PremiumLimitUpsellSheet.show(context, failure: error),
            );
            return;
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          VaultAmbientBackdrop(
            isDark: isDark,
            surfaceColor: surfaceColor,
          ),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              DaftarScrollScreenTitleSliver(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.archiveVaultTitle,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: inkPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AppDimensions.spacingXxs),
                    Text(
                      l10n.archiveVaultSubtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: ArchivedTotalCard()),
              asyncLedgers.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.all(
                      AppDimensions.pagePaddingH,
                    ),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.errorGenericTitle,
                    subtitle: l10n.errorGenericMessage,
                  ),
                ),
                data: (ledgers) {
                  if (ledgers.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: FadeSlideTransition(
                        child: EmptyState(
                          icon: Icons.lock_clock_outlined,
                          title: l10n.archiveVaultEmptyTitle,
                          subtitle: l10n.archiveVaultEmptySubtitle,
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ArchivedLedgerTile(
                        ledger: ledgers[index],
                      ),
                      childCount: ledgers.length,
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom +
                      AppDimensions.spacing4xl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
