import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_permission_banner.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// HITL consent card: Confirm & Call · Confirm & Send · without paths.
class CollectionsDeskConsentCard extends StatelessWidget {
  /// Creates the consent card.
  const CollectionsDeskConsentCard({
    required this.callCount,
    required this.emailCount,
    required this.callConsented,
    required this.sendOutreachEnabled,
    required this.busy,
    required this.isDispatching,
    required this.onConfirmAndCall,
    required this.onConfirmAndSend,
    required this.onConfirmWithoutCalling,
    required this.onConfirmWithoutSending,
    this.callProgress,
    super.key,
  });

  /// CALL-E call-set size.
  final int callCount;

  /// Email-rail size.
  final int emailCount;

  /// Merchant already consented to outbound calls.
  final bool callConsented;

  /// Plan-level Confirm & Send was chosen (SMTP available).
  final bool sendOutreachEnabled;

  /// Desk row action in flight.
  final bool busy;

  /// SMTP send-batch in flight.
  final bool isDispatching;

  /// Local call consent (no HTTP in 3.1).
  final VoidCallback onConfirmAndCall;

  /// SMTP Approve & send.
  final VoidCallback onConfirmAndSend;

  /// Skip call rail; email remains available.
  final VoidCallback onConfirmWithoutCalling;

  /// Skip SMTP / finish desk.
  final VoidCallback onConfirmWithoutSending;

  /// Seeded after Confirm & Call.
  final CollectionsCallProgress? callProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final callPrimary = callCount > 0 && !callConsented;
    final sendPrimary = !callPrimary && sendOutreachEnabled && emailCount > 0;
    final actionsLocked = busy || isDispatching;

    return DaftarCard(
      variant: DaftarCardVariant.premium,
      margin: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        0,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (callCount > 0)
            Text(
              l10n.collectionsDeskCallCount(callCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (emailCount > 0) ...[
            if (callCount > 0) const Gap(AppDimensions.spacingXxs),
            Text(
              l10n.collectionsDeskEmailCount(emailCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const Gap(AppDimensions.spacingSm),
          DaftarPermissionBanner(
            message: l10n.collectionsDeskPromiseNotPayment,
            semanticsLabel: l10n.collectionsDeskPromiseNotPaymentSubtitle,
          ),
          if (callProgress != null) ...[
            const Gap(AppDimensions.spacingMd),
            CollectionsCallProgressBar(progress: callProgress!),
          ],
          if (!callConsented) ...[
            const Gap(AppDimensions.spacingMd),
            DaftarButton(
              label: l10n.collectionsDeskConfirmAndCall,
              variant: callPrimary
                  ? DaftarButtonVariant.primary
                  : DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: callCount > 0 && !actionsLocked
                  ? () {
                      unawaited(HapticService.medium());
                      onConfirmAndCall();
                    }
                  : null,
            ),
          ],
          if (sendOutreachEnabled) ...[
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.closingAgentConfirmAndSend,
              variant: sendPrimary
                  ? DaftarButtonVariant.primary
                  : DaftarButtonVariant.secondary,
              isExpanded: true,
              isLoading: isDispatching,
              onPressed: emailCount > 0 && !actionsLocked
                  ? () {
                      if (sendPrimary) {
                        unawaited(HapticService.medium());
                      }
                      onConfirmAndSend();
                    }
                  : null,
            ),
          ],
          if (!callConsented) ...[
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.collectionsDeskConfirmWithoutCalling,
              variant: DaftarButtonVariant.tertiary,
              isExpanded: true,
              onPressed: actionsLocked ? null : onConfirmWithoutCalling,
            ),
          ],
          const Gap(AppDimensions.spacingSm),
          DaftarButton(
            label: l10n.closingAgentConfirmWithoutSending,
            variant: DaftarButtonVariant.tertiary,
            isExpanded: true,
            onPressed: actionsLocked ? null : onConfirmWithoutSending,
          ),
        ],
      ),
    );
  }
}
