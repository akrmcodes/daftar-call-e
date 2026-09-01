import 'dart:async';

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shows the contacts-denied snack with an Open Settings action.
void showContactsPermissionDeniedFeedback(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDaftarSnackBar(
    context: context,
    message: l10n.closingAgentContactsPermissionDenied,
    actionLabel: l10n.closingAgentMicOpenSettings,
    onAction: () {
      unawaited(openAppSettings());
    },
  );
}

class ContactPickerFieldSuffix extends StatelessWidget {
  const ContactPickerFieldSuffix({
    required this.onPicked,
    required this.enabled,
    required this.iconColor,
    this.icon = Icons.contacts_outlined,
    this.onDenied,
    super.key,
  });

  final ValueChanged<NativeContactPickResult> onPicked;
  final bool enabled;
  final Color iconColor;
  final IconData icon;

  /// Optional override. Default shows a Khazna snack with Open Settings.
  final VoidCallback? onDenied;

  @override
  Widget build(BuildContext context) {
    if (!NativeContactPickerService.isSupported) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.importFromContacts,
      child: IconButton(
        onPressed: enabled ? () => unawaited(_handleTap(context)) : null,
        icon: Icon(
          icon,
          size: AppDimensions.iconSmall + 2,
          color: iconColor,
        ),
        tooltip: l10n.importFromContacts,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: AppDimensions.minTapTarget,
          minHeight: AppDimensions.minTapTarget,
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    await HapticService.light();
    final outcome = await NativeContactPickerService.pickNameAndPhone();
    switch (outcome) {
      case NativeContactPicked(:final result):
        onPicked(result);
      case NativeContactDenied():
        if (onDenied != null) {
          onDenied!();
          return;
        }
        if (context.mounted) {
          showContactsPermissionDeniedFeedback(context);
        }
      case NativeContactCancelled():
        return;
    }
  }
}
