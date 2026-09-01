import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_send_queue_bar.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna Collections Desk: ranked C.2 drafts and live SMTP dispatch.
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
    this.paddingBottom = 0,
    super.key,
  });

  /// Ranked reminder rows.
  final List<CollectionsDeskRow> rows;

  /// When true, Start sending owns the lapis glow.
  final bool startSendingIsPrimary;

  /// Contact currently opening WhatsApp or a PDF share sheet.
  final String? busyContactId;

  /// Skip a pending row.
  final ValueChanged<String> onSkip;

  /// Copy a row body.
  final ValueChanged<String> onCopy;

  /// Leftover Hybrid E Open. Not the filmed climax or missing-email fallback.
  final ValueChanged<String> onOpen;

  /// Change tone for a pending row.
  final void Function(String contactId, ReminderToneBand tone) onTone;

  /// Toggle attach-PDF for a pending row.
  final ValueChanged<String> onTogglePdf;

  /// Leftover Hybrid E Start sending. Not the filmed climax.
  final VoidCallback onStartSending;

  /// SMTP Approve & send (whole send set).
  final VoidCallback onApproveAndSend;

  /// Skip outreach (remaining pending treated as skipped).
  final VoidCallback onDone;

  /// True while send-batch PDFs / SMTP are in flight.
  final bool isDispatching;

  /// Leftover Hybrid E sticky bar. Must stay false on the SMTP path.
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

  /// Leftover Hybrid E chrome on rows + sticky `wa.me` bar.
  ///
  /// Default **false** on the SMTP desk. Disabled Open WhatsApp is still
  /// visible — hide, do not only set `leftoverActionsEnabled: false`.
  final bool showHybridELeftover;

  /// SMTP lead: show Retry sending after a failed auto-dispatch (not a new consent).
  final bool showRetrySend;

  /// Extra bottom inset so the last row clears the floating composer dock.
  final double paddingBottom;

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
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              0,
              AppDimensions.pagePaddingH,
              AppDimensions.spacingMd + paddingBottom,
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
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.pagePaddingH,
            0,
            AppDimensions.pagePaddingH,
            AppDimensions.spacingMd,
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
                  isExpanded: true,
                  isLoading: true,
                  onPressed: null,
                )
              else if (showRetrySend)
                DaftarButton(
                  label: l10n.collectionsDeskRetrySend,
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
