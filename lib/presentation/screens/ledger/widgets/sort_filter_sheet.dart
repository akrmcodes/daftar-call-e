import 'dart:async';

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _sortModeName = 'name';
const String _sortModeBalance = 'balance';
const String _sortModeRecent = 'recent';

/// Premium bottom sheet for choosing how the contact list is sorted.
class SortFilterSheet extends StatelessWidget {
  /// Creates a sort sheet with the current selection and change callback.
  const SortFilterSheet({
    required this.currentSortOption,
    required this.onSortChanged,
    super.key,
  });

  final String currentSortOption;
  final ValueChanged<String> onSortChanged;

  /// Presents the sheet using the app's standard modal sheet styling.
  static Future<void> show(
    BuildContext context, {
    required String currentSortOption,
    required ValueChanged<String> onSortChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AppBottomSheet.show<void>(
      context,
      title: l10n.sortBy,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: isDark ? 0.16 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.sort_rounded,
          color: colors.primary,
          size: AppDimensions.iconMedium,
        ),
      ),
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
      maxHeightFactor: 0.56,
      child: SortFilterSheet(
        currentSortOption: currentSortOption,
        onSortChanged: onSortChanged,
      ),
    ).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final options = <_SortOption>[
      _SortOption(
        value: _sortModeName,
        icon: Icons.sort_by_alpha_rounded,
        label: l10n.sortByName,
      ),
      _SortOption(
        value: _sortModeBalance,
        icon: Icons.account_balance_wallet_rounded,
        label: l10n.sortByBalance,
      ),
      _SortOption(
        value: _sortModeRecent,
        icon: Icons.schedule_rounded,
        label: l10n.sortByRecent,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: isDark ? 0.10 : 0.06),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < options.length; index++) ...[
              _SortRow(
                option: options[index],
                isSelected: options[index].value == currentSortOption,
                isDark: isDark,
                onTap: () {
                  if (options[index].value != currentSortOption) {
                    onSortChanged(options[index].value);
                  }

                  unawaited(HapticFeedback.selectionClick());
                  Navigator.of(context).pop();
                },
              ),
              if (index != options.length - 1)
                Divider(
                  height: 1,
                  thickness: AppDimensions.dividerThickness,
                  color: colors.onSurface.withValues(
                    alpha: isDark ? 0.08 : 0.06,
                  ),
                ),
            ],
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final _SortOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final selectedBackground = Color.alphaBlend(
      colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
      colors.surface,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingLg,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : Colors.transparent,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppDimensions.animationMedium,
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                      : colors.onSurface.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.18)
                        : colors.onSurface.withValues(
                            alpha: isDark ? 0.08 : 0.05,
                          ),
                  ),
                ),
                child: Icon(
                  option.icon,
                  size: AppDimensions.iconSmall + 4,
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              AnimatedOpacity(
                duration: AppDimensions.animationFast,
                opacity: isSelected ? 1 : 0,
                child: AnimatedScale(
                  duration: AppDimensions.animationFast,
                  curve: Curves.easeOutCubic,
                  scale: isSelected ? 1 : 0.82,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortOption {
  const _SortOption({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;
}
