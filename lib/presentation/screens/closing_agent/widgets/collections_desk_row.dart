import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/outreach_rail_badge.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// One Collections Desk reminder: amount, tone, draft, Open / Copy / Skip.
class CollectionsDeskRowCard extends StatelessWidget {
  /// Creates a desk row card.
  const CollectionsDeskRowCard({
    required this.row,
    required this.isOpening,
    required this.onSkip,
    required this.onCopy,
    required this.onOpen,
    required this.onTone,
    required this.onTogglePdf,
    this.leftoverActionsEnabled = true,
    this.showHybridELeftover = false,
    super.key,
  });

  /// Device-owned draft row.
  final CollectionsDeskRow row;

  /// True while this row's Open path is running.
  final bool isOpening;

  /// Skip callback.
  final VoidCallback onSkip;

  /// Copy callback.
  final VoidCallback onCopy;

  /// Leftover Hybrid E Open (`wa.me` / share-sheet). Not the filmed climax
  /// and not the missing-email fallback.
  final VoidCallback onOpen;

  /// Tone override.
  final ValueChanged<ReminderToneBand> onTone;

  /// Attach-statement toggle.
  final VoidCallback onTogglePdf;

  /// False while SMTP Approve is in flight — leftover Open/Skip/tone/attach off.
  final bool leftoverActionsEnabled;

  /// Leftover Hybrid E chrome (`wa.me`, tone picker, attach switch, per-row Skip).
  ///
  /// Default **false**: SMTP desk shows ranked draft + Copy only. Disabled
  /// WhatsApp is still visible — hiding is required, not `onPressed: null`.
  final bool showHybridELeftover;

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
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    final pending = row.status == CollectionsDeskRowStatus.pending;
    final leftoverPending = pending && leftoverActionsEnabled;
    final candidate = row.candidate;
    final owed = MoneyUtil.formatMinorUnitsForCode(
      candidate.owedMinor,
      candidate.currencyCode,
    );
    final statusLabel = switch (row.status) {
      CollectionsDeskRowStatus.pending => null,
      CollectionsDeskRowStatus.opened => l10n.collectionsDeskOpened,
      CollectionsDeskRowStatus.skipped => l10n.collectionsDeskSkippedStatus,
      CollectionsDeskRowStatus.sending => l10n.collectionsDeskSending,
      CollectionsDeskRowStatus.sent => l10n.collectionsDeskSentStatus,
      CollectionsDeskRowStatus.failed => l10n.collectionsDeskFailedStatus,
    };

    return Opacity(
      opacity: pending ? 1 : 0.55,
      child: RepaintBoundary(
        child: DaftarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      candidate.name,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: inkPrimary,
                      ),
                    ),
                  ),
                  OutreachRailBadge(rail: candidate.rail),
                  if (statusLabel != null) ...[
                    const Gap(AppDimensions.spacingXs),
                    Text(
                      statusLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const Gap(AppDimensions.spacingXs),
              Text(
                '$owed ${candidate.currencyCode}',
                style: AppTextStyles.amountSmall.copyWith(color: inkPrimary),
              ),
              const Gap(AppDimensions.spacingXxs),
              Text(
                l10n.collectionsDeskAgeDays(candidate.ageDays),
                style: AppTextStyles.bodySmall.copyWith(
                  color: row.toneBand == ReminderToneBand.firm
                      ? warning
                      : inkSecondary,
                ),
              ),
              if (candidate.daysSinceLastPayment != null) ...[
                const Gap(AppDimensions.spacingXxs),
                Text(
                  l10n.collectionsDeskLastPaymentDays(
                    candidate.daysSinceLastPayment!,
                  ),
                  style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
                ),
              ],
              if (showHybridELeftover) ...[
                const Gap(AppDimensions.spacingSm),
                _ToneChips(
                  selected: row.toneBand,
                  enabled: leftoverPending,
                  isDark: isDark,
                  l10n: l10n,
                  onTone: onTone,
                ),
              ],
              if (row.callTask.isNotEmpty) ...[
                const Gap(AppDimensions.spacingSm),
                Text(
                  l10n.collectionsDeskCallPreviewTitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AppDimensions.spacingXxs),
                SelectableText(
                  row.callTask,
                  style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
                ),
              ],
              if (row.subject.isNotEmpty) ...[
                if (row.callTask.isNotEmpty) const Gap(AppDimensions.spacingSm),
                Text(
                  row.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AppDimensions.spacingXxs),
              ],
              if (row.body.isNotEmpty) ...[
                const Gap(AppDimensions.spacingSm),
                Text(
                  row.body,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
                ),
                const Gap(AppDimensions.spacingXxs),
                Text(
                  row.attachPdf
                      ? l10n.collectionsDeskPdfAttached
                      : l10n.collectionsDeskReminderOnly,
                  style: AppTextStyles.labelSmall.copyWith(color: inkSecondary),
                ),
              ],
              if (showHybridELeftover) ...[
                const Gap(AppDimensions.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.collectionsDeskAttachStatement,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: inkPrimary,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.88,
                      child: CupertinoSwitch(
                        value: row.attachPdf,
                        activeTrackColor: isDark
                            ? AppColors.inkPrimary
                            : AppColors.inkPrimaryLight,
                        inactiveTrackColor: isDark
                            ? AppColors.surface5
                            : AppColors.surface3Light,
                        onChanged: leftoverPending
                            ? (_) {
                                unawaited(HapticService.toggleFlipped());
                                onTogglePdf();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
              const Gap(AppDimensions.spacingSm),
              Wrap(
                spacing: AppDimensions.spacingSm,
                runSpacing: AppDimensions.spacingSm,
                children: [
                  if (showHybridELeftover)
                    DaftarButton(
                      label: l10n.collectionsDeskOpenWhatsApp,
                      variant: DaftarButtonVariant.secondary,
                      size: DaftarButtonSize.small,
                      isLoading: isOpening,
                      onPressed: leftoverPending && !isOpening ? onOpen : null,
                    ),
                  DaftarButton(
                    label: l10n.collectionsDeskCopy,
                    variant: DaftarButtonVariant.tertiary,
                    size: DaftarButtonSize.small,
                    onPressed: onCopy,
                  ),
                  if (showHybridELeftover)
                    DaftarButton(
                      label: l10n.collectionsDeskSkip,
                      variant: DaftarButtonVariant.tertiary,
                      size: DaftarButtonSize.small,
                      onPressed: leftoverPending && !isOpening ? onSkip : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToneChips extends StatelessWidget {
  const _ToneChips({
    required this.selected,
    required this.enabled,
    required this.isDark,
    required this.l10n,
    required this.onTone,
  });

  final ReminderToneBand selected;
  final bool enabled;
  final bool isDark;
  final AppLocalizations l10n;
  final ValueChanged<ReminderToneBand> onTone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tone in ReminderToneBand.values) ...[
          if (tone != ReminderToneBand.friendly)
            const Gap(AppDimensions.spacingXs),
          Expanded(
            child: _ToneChip(
              label: switch (tone) {
                ReminderToneBand.friendly => l10n.collectionsDeskToneFriendly,
                ReminderToneBand.reminder => l10n.collectionsDeskToneReminder,
                ReminderToneBand.firm => l10n.collectionsDeskToneFirm,
              },
              selected: selected == tone,
              enabled: enabled,
              isFirm: tone == ReminderToneBand.firm,
              isDark: isDark,
              onTap: () => onTone(tone),
            ),
          ),
        ],
      ],
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.isFirm,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool isFirm;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    final fill = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final border = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final selectedInk = isFirm && selected ? warning : ink;
    final selectedBorder = isFirm && selected ? warning : ink;

    return GestureDetector(
      onTap: enabled
          ? () {
              unawaited(HapticService.selection());
              onTap();
            }
          : null,
      child: DaftarTapTarget(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: selected ? selectedBorder : border,
              width: selected ? 1.5 : AppDimensions.dividerThickness,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: AppDimensions.spacingXs,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? selectedInk : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
