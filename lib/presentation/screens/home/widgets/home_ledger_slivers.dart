import 'dart:async';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/presentation/providers/workspace_limit_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/ledger_drag_proxy.dart';
import 'package:daftar/presentation/screens/home/widgets/ledger_tile_with_count.dart';
import 'package:daftar/presentation/shared/widgets/empty_state.dart';
import 'package:daftar/presentation/shared/widgets/skeleton_ledger_grid.dart';
import 'package:daftar/presentation/widgets/premium/premium_upgrade_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

/// Builds the sliver list for the home screen ledger grid and its async states.
abstract final class HomeLedgerSlivers {
  const HomeLedgerSlivers._();

  static List<Widget> loading() => const [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.spacingLg,
          ),
          sliver: SliverToBoxAdapter(
            child: SkeletonLedgerGrid(),
          ),
        ),
      ];

  static List<Widget> error({
    required AppLocalizations l10n,
    required ColorScheme colors,
  }) =>
      [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    l10n.loadingError,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];

  static List<Widget> empty({
    required AppLocalizations l10n,
    required VoidCallback onAddLedger,
  }) =>
      [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.menu_book_rounded,
            title: l10n.noLedgersYet,
            subtitle: l10n.noLedgersSubtitle,
            ctaLabel: l10n.addLedger,
            ctaIcon: Icons.add_rounded,
            onCtaPressed: onAddLedger,
          ),
        ),
      ];

  static List<Widget> populated({
    required BuildContext context,
    required List<Ledger> ledgers,
    required void Function(int oldIndex, int newIndex) onReorder,
    required void Function(Ledger ledger) onEdit,
    required void Function(Ledger ledger) onDelete,
    required void Function(Ledger ledger) onArchive,
    required void Function(Ledger ledger) onTap,
  }) =>
      [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
          ),
          sliver: SliverToBoxAdapter(
            child: PremiumUpgradeBanner(
              resource: WorkspaceLimitResource.ledgers,
              onUpgradeTap: () => context.pushNamed(RouteNames.activation),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.pagePaddingH,
            AppDimensions.spacingSm,
            AppDimensions.pagePaddingH,
            AppDimensions.pagePaddingV,
          ),
          sliver: ReorderableSliverGridView.count(
            // childAspectRatio gives O(1) grid cell layout; eager `children:`
            // builds all tiles upfront — acceptable for typical ledger counts.
            crossAxisCount: 2,
            crossAxisSpacing: AppDimensions.spacingMd,
            mainAxisSpacing: AppDimensions.spacingMd,
            childAspectRatio: 1.12,
            dragWidgetBuilderV2: DragWidgetBuilderV2(
              builder: buildLedgerDragProxy,
            ),
            onDragStart: (_) {
              unawaited(HapticFeedback.lightImpact());
            },
            onReorder: onReorder,
            children: [
              for (final ledger in ledgers)
                LedgerTileWithCount(
                  key: ValueKey(ledger.id),
                  ledger: ledger,
                  onEdit: () => onEdit(ledger),
                  onDelete: () => onDelete(ledger),
                  onArchive: () => onArchive(ledger),
                  onTap: () => onTap(ledger),
                ),
            ],
          ),
        ),
      ];
}
