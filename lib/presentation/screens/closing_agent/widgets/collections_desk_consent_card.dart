import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Compact HITL dock: dual primary + skip row (four explicit actions).
class CollectionsDeskConsentCard extends StatelessWidget {
  /// Creates the consent dock.
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

  /// CALL-E call-set size (controls call-rail visibility).
  final int callCount;

  /// Email-rail size (controls send enablement).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showCall = !callConsented && callCount > 0;
    final showSend = sendOutreachEnabled;
    final callPrimary = showCall;
    final sendPrimary = !callPrimary && showSend && emailCount > 0;
    final actionsLocked = busy || isDispatching;
    final hairline = isDark
        ? AppColors.borderSubtle.withValues(alpha: 0.8)
        : AppColors.borderSubtleLight.withValues(alpha: 0.9);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: hairline, width: 0.5),
        ),
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.premium,
        margin: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingSm,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (callProgress != null) ...[
              CollectionsCallProgressBar(progress: callProgress!),
              const Gap(AppDimensions.spacingSm),
            ],
            if (showCall || showSend)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCall)
                    Expanded(
                      child: DaftarButton(
                        label: l10n.collectionsDeskConfirmAndCall,
                        variant: callPrimary
                            ? DaftarButtonVariant.primary
                            : DaftarButtonVariant.secondary,
                        size: DaftarButtonSize.small,
                        isExpanded: true,
                        onPressed: !actionsLocked
                            ? () {
                                unawaited(HapticService.medium());
                                onConfirmAndCall();
                              }
                            : null,
                      ),
                    ),
                  if (showCall && showSend)
                    const Gap(AppDimensions.spacingSm),
                  if (showSend)
                    Expanded(
                      child: DaftarButton(
                        label: l10n.closingAgentConfirmAndSend,
                        variant: sendPrimary
                            ? DaftarButtonVariant.primary
                            : DaftarButtonVariant.secondary,
                        size: DaftarButtonSize.small,
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
                    ),
                ],
              ),
            if (showCall || showSend) const Gap(AppDimensions.spacingSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showCall)
                  Expanded(
                    child: DaftarButton(
                      label: l10n.collectionsDeskWithoutCalling,
                      variant: DaftarButtonVariant.tertiary,
                      size: DaftarButtonSize.small,
                      isExpanded: true,
                      onPressed: actionsLocked ? null : onConfirmWithoutCalling,
                    ),
                  ),
                if (showCall) const Gap(AppDimensions.spacingSm),
                Expanded(
                  child: DaftarButton(
                    label: l10n.collectionsDeskWithoutSending,
                    variant: DaftarButtonVariant.tertiary,
                    size: DaftarButtonSize.small,
                    isExpanded: true,
                    onPressed: actionsLocked ? null : onConfirmWithoutSending,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
