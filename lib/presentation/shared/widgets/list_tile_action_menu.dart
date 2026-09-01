import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:flutter/material.dart';

/// Trailing kebab menu for list tiles — Edit and Delete actions.
enum ListTileAction { edit, delete }

/// Subtle [Icons.more_vert] menu anchored below the tap target.
class ListTileActionMenu extends StatelessWidget {
  const ListTileActionMenu({
    required this.menuSemanticsLabel,
    required this.isDark,
    super.key,
    this.onEdit,
    this.onDelete,
    this.editLabel,
    this.deleteLabel,
  });

  final String menuSemanticsLabel;
  final bool isDark;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? editLabel;
  final String? deleteLabel;

  Future<void> _showMenu(BuildContext context) async {
    if (onEdit == null && onDelete == null) {
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

    final action = await showMenu<ListTileAction>(
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
      case ListTileAction.edit:
        onEdit?.call();
      case ListTileAction.delete:
        onDelete?.call();
    }
  }

  List<PopupMenuEntry<ListTileAction>> _buildMenuItems(
    BuildContext context,
    ColorScheme colors,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<ListTileAction>>[];

    if (onEdit != null) {
      items.add(
        PopupMenuItem<ListTileAction>(
          value: ListTileAction.edit,
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
                    editLabel ?? l10n.editContact,
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

    if (onEdit != null && onDelete != null) {
      items.add(
        const PopupMenuDivider(height: AppDimensions.spacingSm),
      );
    }

    if (onDelete != null) {
      items.add(
        PopupMenuItem<ListTileAction>(
          value: ListTileAction.delete,
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
                    deleteLabel ?? l10n.delete,
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
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMenu(context),
        child: SizedBox(
          width: AppDimensions.minTapTarget,
          height: AppDimensions.minTapTarget,
          child: Icon(
            Icons.more_vert_rounded,
            color: iconColor,
            size: AppDimensions.iconMedium,
          ),
        ),
      ),
    );
  }
}
