import 'dart:async';

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shows a floating undo snackbar after a ledger is soft-deleted on home.
void showHomeUndoDeleteSnackBar({
  required BuildContext context,
  required AppLocalizations l10n,
  required ColorScheme colors,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);

  final snackBar = SnackBar(
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    backgroundColor: const Color(0xFF171717),
    content: Row(
      children: [
        const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: Text(
            l10n.ledgerDeleted,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
    action: SnackBarAction(
      label: l10n.undo,
      textColor: colors.primary,
      onPressed: () {
        messenger.hideCurrentSnackBar();
        onUndo();
      },
    ),
  );

  messenger.removeCurrentSnackBar();
  final controller = messenger.showSnackBar(snackBar);

  unawaited(
    Future<void>.delayed(const Duration(seconds: 5), () {
      try {
        controller.close();
      } on Object {
        // Ignore if already closed or the scaffold is gone.
      }
    }),
  );
}
