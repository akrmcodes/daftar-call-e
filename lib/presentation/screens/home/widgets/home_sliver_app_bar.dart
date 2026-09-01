import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/providers/archived_ledger_providers.dart';
import 'package:daftar/presentation/widgets/premium/premium_tier_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeSliverAppBar extends ConsumerWidget {
  const HomeSliverAppBar({
    required this.onSearchTap,
    super.key,
  });

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final archivedCount = ref.watch(archivedLedgerCountProvider);

    return SliverAppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: theme.scaffoldBackgroundColor,
      foregroundColor: colors.onSurface,
      automaticallyImplyLeading: false,
      pinned: true,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: AppDimensions.appBarHeight - AppDimensions.spacingXs,
      titleSpacing: AppDimensions.pagePaddingH,
      title: Text(
        l10n.greeting,
        style: AppTextStyles.titleLarge.copyWith(
          color: colors.onSurface,
        ),
      ),
      actions: [
        _VaultEntryButton(
          archivedCount: archivedCount,
          isDark: isDark,
          semanticsLabel: l10n.homeArchiveVaultEntry,
          onTap: () {
            unawaited(HapticService.light());
            unawaited(context.pushNamed(RouteNames.archiveVault));
          },
        ),
        Semantics(
          button: true,
          label: l10n.searchHint,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSearchTap,
            child: SizedBox(
              width: AppDimensions.minTapTarget,
              height: AppDimensions.minTapTarget,
              child: Icon(
                Icons.search_rounded,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsetsDirectional.only(
            end: AppDimensions.pagePaddingH,
          ),
          child: PremiumTierBadge(),
        ),
      ],
    );
  }
}

class _VaultEntryButton extends StatelessWidget {
  const _VaultEntryButton({
    required this.archivedCount,
    required this.isDark,
    required this.semanticsLabel,
    required this.onTap,
  });

  final int? archivedCount;
  final bool isDark;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final showCount = archivedCount != null && archivedCount! > 0;
    final semantics = showCount
        ? '$semanticsLabel ($archivedCount)'
        : semanticsLabel;

    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AppDimensions.minTapTarget,
          height: AppDimensions.minTapTarget,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: iconColor,
                  size: AppDimensions.iconMedium,
                ),
                if (showCount)
                  PositionedDirectional(
                    top: -5,
                    end: -7,
                    child: _VaultCountBadge(
                      count: archivedCount!,
                      isDark: isDark,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultCountBadge extends StatelessWidget {
  const _VaultCountBadge({
    required this.count,
    required this.isDark,
  });

  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface4 : AppColors.surface1Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(
          color: isDark
              ? AppColors.borderSubtle
              : AppColors.borderSubtleLight,
          width: AppDimensions.dividerThickness,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark
                    ? AppColors.inkPrimary
                    : AppColors.inkPrimaryLight,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
