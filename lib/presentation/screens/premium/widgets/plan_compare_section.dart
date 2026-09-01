import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Collapsible feature comparison — progressive disclosure by category.
class PlanCompareSection extends StatefulWidget {
  const PlanCompareSection({
    required this.currentTier,
    required this.focusTier,
    required this.onFocusTierChanged,
    super.key,
  });

  final AppTier currentTier;
  final AppTier focusTier;
  final ValueChanged<AppTier> onFocusTierChanged;

  @override
  State<PlanCompareSection> createState() => _PlanCompareSectionState();
}

class _PlanCompareSectionState extends State<PlanCompareSection> {
  /// First category open by default for immediate value.
  final Set<int> _expanded = {0};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final sections = _buildSections(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tierCompareTitle,
          style: AppTextStyles.titleLarge.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Gap(AppDimensions.spacingXxs),
        Text(
          l10n.tierCompareSubtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const Gap(AppDimensions.spacingMd),
        _TierLegend(
          freeLabel: l10n.tierCompareFree,
          proLabel: l10n.tierComparePro,
          proPlusLabel: l10n.tierCompareProPlus,
          currentLabel: l10n.planLegendCurrent,
          focusTier: widget.focusTier,
          currentTier: widget.currentTier,
          isDark: isDark,
          onSelect: widget.onFocusTierChanged,
        ),
        const Gap(AppDimensions.spacingMd),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const Gap(AppDimensions.spacingSm),
          _CategoryAccordion(
            section: sections[i],
            expanded: _expanded.contains(i),
            onToggle: () {
              unawaited(HapticService.selection());
              setState(() {
                if (_expanded.contains(i)) {
                  _expanded.remove(i);
                } else {
                  _expanded.add(i);
                }
              });
            },
            comingSoonLabel: l10n.tierBadgeComingSoon,
            isDark: isDark,
          ),
        ],
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  List<_CompareSection> _buildSections(AppLocalizations l10n) {
    return [
      _CompareSection(
        title: l10n.tierMatrixGroupWorkspace,
        icon: Icons.grid_view_rounded,
        rows: [
          _CompareRow(
            label: l10n.tierFeatureWorkspaceLimits,
            free: _Cell.text(l10n.tierValueStarter),
            pro: _Cell.text(l10n.tierUnlimited),
            proPlus: _Cell.text(l10n.tierUnlimited),
          ),
          _CompareRow(
            label: l10n.tierFeatureLedgers,
            free: _Cell.text(l10n.tierLimitLedgersFree),
            pro: _Cell.text(l10n.tierUnlimited),
            proPlus: _Cell.text(l10n.tierUnlimited),
          ),
          _CompareRow(
            label: l10n.tierFeatureContacts,
            free: _Cell.text(l10n.tierLimitContactsFree),
            pro: _Cell.text(l10n.tierUnlimited),
            proPlus: _Cell.text(l10n.tierUnlimited),
          ),
          _CompareRow(
            label: l10n.tierFeatureTransactions,
            free: _Cell.text(l10n.tierLimitTransactionsFree),
            pro: _Cell.text(l10n.tierUnlimited),
            proPlus: _Cell.text(l10n.tierUnlimited),
          ),
        ],
      ),
      _CompareSection(
        title: l10n.tierMatrixGroupData,
        icon: Icons.save_outlined,
        rows: [
          _CompareRow(
            label: l10n.tierFeatureBackupLocalCloud,
            free: const _Cell.included(),
            pro: const _Cell.included(),
            proPlus: const _Cell.included(),
          ),
          _CompareRow(
            label: l10n.tierFeatureCsvImport,
            free: const _Cell.included(),
            pro: const _Cell.included(),
            proPlus: const _Cell.included(),
          ),
          _CompareRow(
            label: l10n.tierFeatureDataExport,
            free: _Cell.text(l10n.tierValueBasicPdf),
            pro: _Cell.text(l10n.tierValueBrandedExport),
            proPlus: _Cell.text(l10n.tierValueBrandedExport),
          ),
          _CompareRow(
            label: l10n.tierFeatureLedgerArchiving,
            free: const _Cell.locked(),
            pro: const _Cell.included(),
            proPlus: const _Cell.included(),
          ),
        ],
      ),
      _CompareSection(
        title: l10n.tierMatrixGroupCloud,
        icon: Icons.cloud_outlined,
        rows: [
          if (!AppConstants.kContestDisableMultiDeviceSync)
            _CompareRow(
              label: l10n.tierFeatureSync,
              free: const _Cell.locked(),
              pro: const _Cell.locked(),
              proPlus: const _Cell.included(),
            ),
          _CompareRow(
            label: l10n.tierFeatureAiVoice,
            free: const _Cell.comingSoon(),
            pro: const _Cell.comingSoon(),
            proPlus: const _Cell.comingSoon(),
          ),
        ],
      ),
      _CompareSection(
        title: l10n.tierMatrixGroupGrowth,
        icon: Icons.trending_up_rounded,
        rows: [
          _CompareRow(
            label: l10n.tierFeatureStoreBranding,
            free: const _Cell.locked(),
            pro: const _Cell.included(),
            proPlus: const _Cell.included(),
          ),
          _CompareRow(
            label: l10n.tierFeatureAnalyticsDashboard,
            free: const _Cell.comingSoon(),
            pro: const _Cell.comingSoon(),
            proPlus: const _Cell.comingSoon(),
          ),
          _CompareRow(
            label: l10n.tierFeatureCustomerPortal,
            free: const _Cell.comingSoon(),
            pro: const _Cell.comingSoon(),
            proPlus: const _Cell.comingSoon(),
          ),
        ],
      ),
    ];
  }
}

enum _CellKind { included, locked, text, comingSoon }

final class _Cell {
  const _Cell._(this.kind, [this.text]);

  const _Cell.included() : this._(_CellKind.included);
  const _Cell.locked() : this._(_CellKind.locked);
  const _Cell.comingSoon() : this._(_CellKind.comingSoon);
  const _Cell.text(String value) : this._(_CellKind.text, value);

  final _CellKind kind;
  final String? text;
}

final class _CompareRow {
  const _CompareRow({
    required this.label,
    required this.free,
    required this.pro,
    required this.proPlus,
  });

  final String label;
  final _Cell free;
  final _Cell pro;
  final _Cell proPlus;
}

final class _CompareSection {
  const _CompareSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_CompareRow> rows;
}

class _TierLegend extends StatelessWidget {
  const _TierLegend({
    required this.freeLabel,
    required this.proLabel,
    required this.proPlusLabel,
    required this.currentLabel,
    required this.focusTier,
    required this.currentTier,
    required this.isDark,
    required this.onSelect,
  });

  final String freeLabel;
  final String proLabel;
  final String proPlusLabel;
  final String currentLabel;
  final AppTier focusTier;
  final AppTier currentTier;
  final bool isDark;
  final ValueChanged<AppTier> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _legendChip(freeLabel, AppTier.free)),
        const Gap(AppDimensions.spacingSm),
        Expanded(child: _legendChip(proLabel, AppTier.pro)),
        const Gap(AppDimensions.spacingSm),
        Expanded(child: _legendChip(proPlusLabel, AppTier.proPlus)),
      ],
    );
  }

  Widget _legendChip(String label, AppTier tier) {
    final active = focusTier == tier;
    final isCurrent = currentTier == tier;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: () {
          unawaited(HapticService.selection());
          onSelect(tier);
        },
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppColors.surface4 : AppColors.surface2Light)
                : (isDark ? AppColors.surface3 : AppColors.surface3Light),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: active
                  ? (isDark
                      ? AppColors.borderStrong
                      : AppColors.borderStrongLight)
                  : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
                ),
              ),
              if (isCurrent) ...[
                const Gap(AppDimensions.spacingXxs),
                Text(
                  currentLabel,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isDark
                        ? AppColors.inkMuted
                        : AppColors.inkMutedLight,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryAccordion extends StatelessWidget {
  const _CategoryAccordion({
    required this.section,
    required this.expanded,
    required this.onToggle,
    required this.comingSoonLabel,
    required this.isDark,
  });

  final _CompareSection section;
  final bool expanded;
  final VoidCallback onToggle;
  final String comingSoonLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DaftarCard(
      variant: DaftarCardVariant.compact,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingMd,
              ),
              child: Row(
                children: [
                  Icon(section.icon, size: 20, color: scheme.onSurface),
                  const Gap(AppDimensions.spacingSm),
                  Expanded(
                    child: Text(
                      section.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppDimensions.animationFast,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.spacingMd,
                    AppDimensions.spacingSm,
                    AppDimensions.spacingMd,
                    AppDimensions.spacingMd,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < section.rows.length; i++) ...[
                        if (i > 0) const Gap(AppDimensions.spacingMd),
                        _FeatureCompareRow(
                          row: section.rows[i],
                          comingSoonLabel: comingSoonLabel,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppDimensions.animationMedium,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _FeatureCompareRow extends StatelessWidget {
  const _FeatureCompareRow({
    required this.row,
    required this.comingSoonLabel,
    required this.isDark,
  });

  final _CompareRow row;
  final String comingSoonLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          row.label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        Row(
          children: [
            Expanded(child: _cell(row.free)),
            Expanded(child: _cell(row.pro)),
            Expanded(child: _cell(row.proPlus)),
          ],
        ),
      ],
    );
  }

  Widget _cell(_Cell cell) {
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Center(
      child: switch (cell.kind) {
        _CellKind.included => Icon(
            Icons.check_rounded,
            size: 18,
            color: ink,
          ),
        _CellKind.locked => Icon(
            Icons.remove_rounded,
            size: 18,
            color: muted,
          ),
        _CellKind.comingSoon => Text(
            comingSoonLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        _CellKind.text => Text(
            cell.text ?? '',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      },
    );
  }
}
