import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/presentation/screens/contact/widgets/edit_contact_sheet.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:flutter/material.dart';

/// Opens the branded edit-contact bottom sheet.
Future<Contact?> showEditContactSheet(
  BuildContext context, {
  required Contact contact,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final colors = context.colorScheme;
  final isDark = context.theme.brightness == Brightness.dark;
  final accent = _parseHexColor(contact.avatarColor, fallback: colors.primary);

  return AppBottomSheet.show<Contact>(
    context,
    title: l10n.editContact,
    subtitle: contact.name,
    maxHeightFactor: 0.88,
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppDimensions.pagePaddingH,
      AppDimensions.spacingXs,
      AppDimensions.pagePaddingH,
      AppDimensions.spacingMd,
    ),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.edit_rounded,
        color: accent,
        size: AppDimensions.iconMedium,
      ),
    ),
    trailing: DaftarCloseIconButton(
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    child: EditContactSheet(contact: contact),
  );
}

Color _parseHexColor(String value, {required Color fallback}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }

  var hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length != 8) {
    return fallback;
  }

  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return fallback;
  }

  return Color(parsed);
}
