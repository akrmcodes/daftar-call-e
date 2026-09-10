import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_send_queue_bar.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna Collections Desk: dual-rail HITL consent + ranked drafts.
class CollectionsDeskPanel extends StatelessWidget {
  /// Creates the desk panel.
  const CollectionsDeskPanel({
    required this.rows,
    required this.startSendingIsPrimary,
    required this.busyContactId,
    required this.onSkip,
    required this.onCopy,
    required this.onOpen,
    required this.onTone,
    required this.onTogglePdf,
    required this.onStartSending,
    required this.onApproveAndSend,
    required this.onDone,
    required this.callCount,
    required this.emailCount,
    required this.callConsented,
    required this.sendOutreachEnabled,
    required this.onCommitOutreach,
    this.isDispatching = false,
    this.isQueueInFlight = false,
    this.isQueuePaused = false,
    this.queueIndex = 0,
    this.queueTotal = 0,
    this.queueContactName = '',
    this.onQueuePause,
    this.onQueueResume,
    this.onQueueSkip,
    this.showHybridELeftover = false,
    this.showRetrySend = false,
    this.callProgress,
    this.retryOfferCount = 0,
    this.onRetryUnanswered,
    this.paddingBottom = 0,
    this.deskSubtitle,
    super.key,
  });

  /// Ranked desk rows (full dual-rail shortlist).
  final List<CollectionsDeskRow> rows;

  /// When true, Start sending owns the lapis glow (Hybrid E only).
  final bool startSendingIsPrimary;

  /// Contact currently opening WhatsApp or a PDF share sheet.
  final String? busyContactId;

  /// CALL-E call-set size.
  final int callCount;

  /// Email-rail size.
  final int emailCount;

  /// Merchant consented to outbound calls.
  final bool callConsented;

  /// Plan chose Confirm & Send (SMTP path available).
  final bool sendOutreachEnabled;

  /// Commits chip-selected outreach (call / send / seal).
  final void Function({required bool call, required bool send}) onCommitOutreach;

  /// Seeded call progress after Confirm & Call.
  final CollectionsCallProgress? callProgress;

  /// Contacts eligible for one no-answer/voicemail retry.
  final int retryOfferCount;

  /// Merchant consents to retry unanswered calls.
  final VoidCallback? onRetryUnanswered;

  /// Skip a pending row.
  final ValueChanged<String> onSkip;

  /// Copy a row body.
  final ValueChanged<String> onCopy;

  /// Leftover Hybrid E Open.
  final ValueChanged<String> onOpen;

  /// Change tone for a pending row.
  final void Function(String contactId, ReminderToneBand tone) onTone;

  /// Toggle attach-PDF for a pending row.
  final ValueChanged<String> onTogglePdf;

  /// Leftover Hybrid E Start sending.
  final VoidCallback onStartSending;

  /// SMTP Approve & send (whole send set).
  final VoidCallback onApproveAndSend;

  /// Confirm without sending / skip outreach.
  final VoidCallback onDone;

  /// True while send-batch PDFs / SMTP are in flight.
  final bool isDispatching;

  /// Leftover Hybrid E sticky bar.
  final bool isQueueInFlight;

  /// True when resume-advance is paused.
  final bool isQueuePaused;

  /// 1-based Sending i.
  final int queueIndex;

  /// Prepared N.
  final int queueTotal;

  /// Next pending contact name.
  final String queueContactName;

  /// Pause resume-advance.
  final VoidCallback? onQueuePause;

  /// Resume resume-advance.
  final VoidCallback? onQueueResume;

  /// Skip the first pending row from the sticky bar.
  final VoidCallback? onQueueSkip;

  /// Leftover Hybrid E chrome.
  final bool showHybridELeftover;

  /// SMTP lead: show Retry sending after a failed dispatch.
  final bool showRetrySend;

  /// Extra bottom inset so the last row clears the floating composer dock.
  final double paddingBottom;

  /// Optional subtitle (B-trigger credit-limit desk).
  final String? deskSubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final hasPending = rows.any(
      (row) => row.status == CollectionsDeskRowStatus.pending,
    );
    final busy = busyContactId != null;
    final callLeadName = _callLeadName(rows);
    final pdfCount = _emailPdfCount(rows);
    final textCount = emailCount - pdfCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.pagePaddingH,
            AppDimensions.spacingSm,
            AppDimensions.pagePaddingH,
            AppDimensions.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.collectionsDeskTitle,
                style: AppTextStyles.titleLarge.copyWith(
                  color: inkPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AppDimensions.spacingXxs),
              Text(
                l10n.collectionsDeskCount(rows.length),
                style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
              ),
              if (deskSubtitle != null && deskSubtitle!.trim().isNotEmpty) ...[
                const Gap(AppDimensions.spacingXxs),
                Text(
                  deskSubtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: inkSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              0,
              AppDimensions.pagePaddingH,
              AppDimensions.spacingMd,
            ),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final contactId = row.candidate.contactId;
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppDimensions.spacingMd,
                ),
                child: CollectionsDeskRowCard(
                  row: row,
                  isOpening: busyContactId == contactId,
                  leftoverActionsEnabled: !isDispatching,
                  showHybridELeftover: showHybridELeftover,
                  onSkip: () => onSkip(contactId),
                  onCopy: () => onCopy(contactId),
                  onOpen: () => onOpen(contactId),
                  onTone: (tone) => onTone(contactId, tone),
                  onTogglePdf: () => onTogglePdf(contactId),
                ),
              );
            },
          ),
        ),
        if (!showHybridELeftover)
          Padding(
            padding: EdgeInsets.only(
              bottom: _deskComposerClearance(paddingBottom),
            ),
            child: CollectionsDeskConsentCard(
              callCount: callCount,
              emailCount: emailCount,
              callLeadName: callLeadName,
              pdfCount: pdfCount,
              textCount: textCount < 0 ? 0 : textCount,
              callConsented: callConsented,
              sendOutreachEnabled: sendOutreachEnabled,
              busy: busy,
              isDispatching: isDispatching,
              callProgress: callProgress,
              retryOfferCount: retryOfferCount,
              onRetryUnanswered: onRetryUnanswered,
              onCommit: onCommitOutreach,
            ),
          ),
        if (showHybridELeftover || isDispatching || showRetrySend)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              0,
              AppDimensions.pagePaddingH,
              AppDimensions.spacingMd + paddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHybridELeftover && isQueueInFlight)
                  CollectionsSendQueueBar(
                    index: queueIndex,
                    total: queueTotal,
                    contactName: queueContactName,
                    isPaused: isQueuePaused,
                    openIsPrimary: startSendingIsPrimary,
                    isBusy: busy,
                    onOpen: onStartSending,
                    onSkip: onQueueSkip ?? onDone,
                    onPause: onQueuePause ?? _collectionsDeskQueueNoop,
                    onResume: onQueueResume ?? _collectionsDeskQueueNoop,
                  )
                else if (showHybridELeftover && isDispatching)
                  DaftarButton(
                    label: queueTotal > 0
                        ? l10n.collectionsQueueSending(
                            queueIndex < 1 ? 1 : queueIndex,
                            queueTotal,
                          )
                        : l10n.collectionsDeskSending,
                    isExpanded: true,
                    isLoading: true,
                    onPressed: null,
                  )
                else if (showHybridELeftover)
                  DaftarButton(
                    label: l10n.collectionsDeskApproveSend,
                    variant: startSendingIsPrimary
                        ? DaftarButtonVariant.primary
                        : DaftarButtonVariant.secondary,
                    isExpanded: true,
                    onPressed: hasPending && !busy ? onApproveAndSend : null,
                  )
                else if (isDispatching)
                  DaftarButton(
                    label: queueTotal > 0
                        ? l10n.collectionsQueueSending(
                            queueIndex < 1 ? 1 : queueIndex,
                            queueTotal,
                          )
                        : l10n.collectionsDeskSending,
                    variant: DaftarButtonVariant.secondary,
                    isExpanded: true,
                    isLoading: true,
                    onPressed: null,
                  )
                else if (showRetrySend)
                  DaftarButton(
                    label: l10n.collectionsDeskRetrySend,
                    variant: DaftarButtonVariant.secondary,
                    isExpanded: true,
                    onPressed: hasPending && !busy ? onApproveAndSend : null,
                  ),
                if (showHybridELeftover) ...[
                  const Gap(AppDimensions.spacingSm),
                  DaftarButton(
                    label: l10n.collectionsDeskSkipOutreach,
                    variant: DaftarButtonVariant.tertiary,
                    isExpanded: true,
                    onPressed: busy || isDispatching ? null : onDone,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

void _collectionsDeskQueueNoop() {}

/// Pulls the HITL dock down toward the glass composer without overlapping it.
///
/// [paddingBottom] already includes composer height + safe area + spacing.
/// The extra [AppDimensions.spacing3xl] slack is for scrolling lists, not
/// this pinned dock.
double _deskComposerClearance(double paddingBottom) {
  const slack = AppDimensions.spacing3xl;
  if (paddingBottom <= slack) {
    return paddingBottom;
  }
  return paddingBottom - slack;
}

bool _isCallRail(OutreachRail rail) {
  return rail == OutreachRail.call || rail == OutreachRail.both;
}

bool _isEmailRail(OutreachRail rail) {
  return rail == OutreachRail.email ||
      rail == OutreachRail.both ||
      rail == OutreachRail.callUnavailable;
}

String _callLeadName(List<CollectionsDeskRow> rows) {
  for (final row in rows) {
    if (_isCallRail(row.candidate.rail)) {
      return row.candidate.name;
    }
  }
  return '';
}

int _emailPdfCount(List<CollectionsDeskRow> rows) {
  var count = 0;
  for (final row in rows) {
    if (_isEmailRail(row.candidate.rail) && row.attachPdf) {
      count += 1;
    }
  }
  return count;
}
