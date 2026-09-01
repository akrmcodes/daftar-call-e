import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Squircle geometry shared with the home balance hero for continuity.
SmoothBorderRadius get _ledgerTileSquircleRadius => SmoothBorderRadius(
  cornerRadius: AppDimensions.radiusMd,
  cornerSmoothing: 0.6,
);

/// Private-banking ledger tile for the home screen modular grid.
class LedgerListTile extends StatefulWidget {
  const LedgerListTile({
    required this.ledger,
    required this.contactCount,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onArchive,
    super.key,
  });

  final Ledger ledger;
  final int contactCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;

  @override
  State<LedgerListTile> createState() => _LedgerListTileState();
}

class _LedgerListTileState extends State<LedgerListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final indexColor = _resolveLedgerIndexColor(widget.ledger);
    final squircleRadius = _ledgerTileSquircleRadius;
    final ledgerIcon = _resolveLedgerIcon(
      widget.ledger.icon,
      widget.ledger.type,
    );
    final iconTint = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Semantics(
      button: true,
      label:
          '${widget.ledger.name}, ${l10n.ledgerAccountCount(widget.contactCount)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.light());
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.99 : 1,
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          child: ClipSmoothRect(
            radius: squircleRadius,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: isDark ? AppColors.surface2 : AppColors.surface1Light,
                shape: SmoothRectangleBorder(
                  borderRadius: squircleRadius,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.borderSubtle
                        : AppColors.borderSubtleLight,
                    width: AppDimensions.dividerThickness,
                  ),
                ),
                shadows: AppGlows.listTileEdge,
              ),
              child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (isDark)
                      const PositionedDirectional(
                        top: 0,
                        start: 0,
                        end: 0,
                        child: SizedBox(
                          height: AppDimensions.dividerThickness,
                          child: ColoredBox(color: AppColors.innerTopHighlight),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppDimensions.cardPadding,
                        AppDimensions.cardPadding,
                        AppDimensions.cardPadding,
                        AppDimensions.cardPadding + AppDimensions.spacingXxs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                ledgerIcon,
                                size: AppDimensions.iconMedium,
                                color: iconTint,
                              ),
                              const Spacer(),
                              if (widget.onEdit != null ||
                                  widget.onDelete != null ||
                                  widget.onArchive != null)
                                _LedgerMoreMenuButton(
                                  menuSemanticsLabel: MaterialLocalizations.of(
                                    context,
                                  ).moreButtonTooltip,
                                  isDark: isDark,
                                  onEdit: widget.onEdit,
                                  onDelete: widget.onDelete,
                                  onArchive: widget.onArchive,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            widget.ledger.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.inkPrimary
                                  : AppColors.inkPrimaryLight,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            l10n.ledgerAccountCount(widget.contactCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.inkSecondary
                                  : AppColors.inkSecondaryLight,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: _LedgerIndexBottomGlow(color: indexColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}

/// 2dp index stripe at the card base.
class _LedgerIndexBottomGlow extends StatelessWidget {
  const _LedgerIndexBottomGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: ColoredBox(color: color),
    );
  }
}

class _LedgerMoreMenuButton extends StatelessWidget {
  const _LedgerMoreMenuButton({
    required this.menuSemanticsLabel,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    this.onArchive,
  });

  final String menuSemanticsLabel;
  final bool isDark;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;

  Future<void> _showMenu(BuildContext context) async {
    if (onEdit == null && onDelete == null && onArchive == null) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }

    final colors = context.theme.colorScheme;
    final offset = box.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height,
      offset.dx + box.size.width,
      offset.dy,
    );

    unawaited(HapticService.light());

    final action = await showMenu<_LedgerTileAction>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 224),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      items: _buildMenuItems(context, colors),
    );

    if (action == null) {
      return;
    }
    switch (action) {
      case _LedgerTileAction.edit:
        onEdit?.call();
      case _LedgerTileAction.archive:
        onArchive?.call();
      case _LedgerTileAction.delete:
        onDelete?.call();
    }
  }

  List<PopupMenuEntry<_LedgerTileAction>> _buildMenuItems(
    BuildContext context,
    ColorScheme colors,
  ) {
    final items = <PopupMenuEntry<_LedgerTileAction>>[];

    if (onEdit != null) {
      items.add(
        PopupMenuItem<_LedgerTileAction>(
          value: _LedgerTileAction.edit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 184),
            child: Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: AppDimensions.iconSmall + 2,
                  color: colors.onSurface,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.editLedger,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (onEdit != null && (onArchive != null || onDelete != null)) {
      items.add(
        const PopupMenuDivider(height: AppDimensions.spacingSm),
      );
    }

    if (onArchive != null) {
      items.add(
        PopupMenuItem<_LedgerTileAction>(
          value: _LedgerTileAction.archive,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 184),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  size: AppDimensions.iconSmall + 2,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.archiveLedgerAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (onArchive != null && onDelete != null) {
      items.add(
        const PopupMenuDivider(height: AppDimensions.spacingSm),
      );
    }

    if (onDelete != null) {
      items.add(
        PopupMenuItem<_LedgerTileAction>(
          value: _LedgerTileAction.delete,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 184),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: AppDimensions.iconSmall + 2,
                  color: colors.error,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.delete,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Semantics(
      button: true,
      label: menuSemanticsLabel,
      child: GestureDetector(
        key: const ValueKey('ledger_tile_more_menu'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMenu(context),
        child: SizedBox(
          width: AppDimensions.minTapTarget,
          height: AppDimensions.minTapTarget,
          child: Icon(
            Icons.more_horiz_rounded,
            color: iconColor,
            size: AppDimensions.iconMedium,
          ),
        ),
      ),
    );
  }
}

enum _LedgerTileAction { edit, archive, delete }

Color _resolveLedgerIndexColor(Ledger ledger) {
  final parsed = _tryParseHexColor(ledger.color);
  if (parsed != null) {
    return _nearestAvatarColor(parsed);
  }

  return AppColors.avatarColors[_stableIndex(ledger.id)];
}

Color _nearestAvatarColor(Color source) {
  var best = AppColors.avatarColors.first;
  var bestDistance = double.maxFinite;

  for (final candidate in AppColors.avatarColors) {
    final dr = source.r * 255 - candidate.r * 255;
    final dg = source.g * 255 - candidate.g * 255;
    final db = source.b * 255 - candidate.b * 255;
    final distance = dr * dr + dg * dg + db * db;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }

  return best;
}

int _stableIndex(String value) {
  var sum = 0;
  for (final codeUnit in value.codeUnits) {
    sum = (sum + codeUnit) & 0x7fffffff;
  }

  return sum % AppColors.avatarColors.length;
}

Color? _tryParseHexColor(String value) {
  final normalized = value.trim().toLowerCase().replaceFirst(
    RegExp('^(#|0x)'),
    '',
  );

  try {
    if (normalized.length == 3) {
      final expanded = normalized
          .split('')
          .map((digit) => '$digit$digit')
          .join();
      return Color(int.parse('ff$expanded', radix: 16));
    }

    if (normalized.length == 6) {
      return Color(int.parse('ff$normalized', radix: 16));
    }

    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
  } on FormatException {
    return null;
  } on Object {
    return null;
  }

  return null;
}

IconData _resolveLedgerIcon(String iconName, LedgerType ledgerType) {
  final normalized = iconName.trim().toLowerCase();

  switch (normalized) {
    case 'customers':
    case 'people':
    case 'people_alt_rounded':
    case 'group_rounded':
      return Icons.people_alt_rounded;
    case 'suppliers':
    case 'local_shipping_rounded':
    case 'delivery_dining_rounded':
      return Icons.local_shipping_rounded;
    case 'personal':
    case 'person_rounded':
    case 'person_outline_rounded':
      return Icons.person_rounded;
    case 'custom':
    case 'folder_special_rounded':
    case 'bookmark_rounded':
      return Icons.folder_special_rounded;
    case 'storefront_rounded':
    case 'store_rounded':
      return Icons.storefront_rounded;
    case 'receipt_long_rounded':
    case 'receipt_rounded':
      return Icons.receipt_long_rounded;
    case 'shopping_bag_rounded':
    case 'shopping_cart_rounded':
      return Icons.shopping_bag_rounded;
    case 'account_balance_wallet_rounded':
    case 'wallet_rounded':
      return Icons.account_balance_wallet_rounded;
    case 'work_outline_rounded':
    case 'business_center_rounded':
      return Icons.work_outline_rounded;
    case 'home_work_rounded':
      return Icons.home_work_rounded;
    case 'savings_rounded':
      return Icons.savings_rounded;
    case 'handshake_rounded':
      return Icons.handshake_rounded;
    default:
      return _fallbackLedgerIcon(ledgerType);
  }
}

IconData _fallbackLedgerIcon(LedgerType ledgerType) {
  switch (ledgerType) {
    case LedgerType.customers:
      return Icons.people_alt_rounded;
    case LedgerType.suppliers:
      return Icons.local_shipping_rounded;
    case LedgerType.personal:
      return Icons.person_rounded;
    case LedgerType.custom:
      return Icons.folder_special_rounded;
  }
}
