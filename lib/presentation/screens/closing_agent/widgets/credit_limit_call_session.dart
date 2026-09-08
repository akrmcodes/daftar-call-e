import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/constants/promised_calendar_day.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/providers/architecture_hud_provider.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_call_progress_bar.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

/// Dedicated Khazna surface for the credit-limit B-trigger call session.
///
/// One HITL on the sheet — this screen shows live progress then a terminal
/// summary. Merchant leaves via close/back; session persists until Done.
class CreditLimitCallSession extends ConsumerWidget {
  /// Creates the session body.
  const CreditLimitCallSession({
    required this.paddingBottom,
    super.key,
  });

  /// Scroll inset for the hidden composer dock.
  final double paddingBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(closingAgentControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    final row = state.deskRows.isNotEmpty ? state.deskRows.first : null;
    final contactId = state.creditLimitSessionContactId;
    Contact? contact;
    if (contactId != null) {
      contact = ref
          .watch(contactByIdProvider(contactId))
          .asData
          ?.value
          .getRight()
          .toNullable();
    }
    final terminal = state.creditLimitCallSessionTerminal;
    final progress = state.callProgress;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
        AppDimensions.pagePaddingH,
        paddingBottom,
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              terminal
                  ? l10n.creditLimitCallSessionSummaryTitle
                  : l10n.creditLimitCallSessionTitle,
              style: AppTextStyles.titleMedium.copyWith(
                color: inkPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(AppDimensions.spacingMd),
            if (!terminal) ...[
              _LiveSessionBody(
                row: row,
                contact: contact,
                progress: progress,
                callConsented: state.callConsented,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
            ] else ...[
              _SummaryBody(
                row: row,
                contactId: contactId,
                progress: progress,
                inkPrimary: inkPrimary,
                inkSecondary: inkSecondary,
              ),
              const Gap(AppDimensions.spacingLg),
              DaftarButton(
                label: l10n.creditLimitCallSessionDone,
                isExpanded: true,
                onPressed: () {
                  unawaited(HapticService.medium());
                  unawaited(
                    ref
                        .read(closingAgentControllerProvider.notifier)
                        .dismissCreditLimitSession(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveSessionBody extends StatelessWidget {
  const _LiveSessionBody({
    required this.row,
    required this.contact,
    required this.progress,
    required this.callConsented,
    required this.inkPrimary,
    required this.inkSecondary,
  });

  final CollectionsDeskRow? row;
  final Contact? contact;
  final CollectionsCallProgress? progress;
  final bool callConsented;
  final Color inkPrimary;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contactName = row?.candidate.name ?? '';
    final currencyCode = row?.candidate.currencyCode ?? 'YER';
    final outstandingMinor = row == null
        ? 0
        : (-row!.candidate.netBalance).clamp(0, 1 << 62);
    final creditLimitMinor = contact?.creditLimit ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          contactName,
          style: AppTextStyles.titleSmall.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        if (outstandingMinor > 0) ...[
          _AmountRow(
            label: l10n.creditLimitCallSheetOutstanding,
            amount: _formatAmount(outstandingMinor, currencyCode),
            inkSecondary: inkSecondary,
            inkPrimary: inkPrimary,
          ),
          if (creditLimitMinor > 0) ...[
            const Gap(AppDimensions.spacingXs),
            _AmountRow(
              label: l10n.creditLimitCallSheetLimit,
              amount: _formatAmount(creditLimitMinor, currencyCode),
              inkSecondary: inkSecondary,
              inkPrimary: inkPrimary,
            ),
          ],
          const Gap(AppDimensions.spacingMd),
        ],
        Text(
          callConsented
              ? l10n.creditLimitCallSessionInProgress
              : l10n.creditLimitCallSessionPreparing,
          style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
        ),
        const Gap(AppDimensions.spacingSm),
        if (progress != null)
          CollectionsCallProgressBar(
            progress: progress!,
            barHeight: 8,
          ),
        if (_runIdTail(progress) != null) ...[
          const Gap(AppDimensions.spacingSm),
          Text(
            l10n.creditLimitCallSessionRunId(_runIdTail(progress)!),
            style: AppTextStyles.labelSmall.copyWith(color: inkSecondary),
          ),
        ],
        if (row != null && row!.callTask.isNotEmpty) ...[
          const Gap(AppDimensions.spacingMd),
          Text(
            l10n.collectionsDeskCallPreviewTitle,
            style: AppTextStyles.labelSmall.copyWith(
              color: inkSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(AppDimensions.spacingXs),
          Text(
            row!.callTask,
            style: AppTextStyles.bodySmall.copyWith(
              color: inkPrimary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({
    required this.row,
    required this.contactId,
    required this.progress,
    required this.inkPrimary,
    required this.inkSecondary,
  });

  final CollectionsDeskRow? row;
  final String? contactId;
  final CollectionsCallProgress? progress;
  final Color inkPrimary;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final contactName = row?.candidate.name ?? '';
    final status = progress?.latestRowStatus;
    final statusLabel = status == null
        ? ''
        : CollectionsCallProgressBar.statusLabel(l10n, status);

    final promises = contactId == null
        ? const <CollectionPromise>[]
        : ref
                .watch(pendingCollectionPromisesProvider(contactId!))
                .value ??
            const <CollectionPromise>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          contactName,
          style: AppTextStyles.titleSmall.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (statusLabel.isNotEmpty) ...[
          const Gap(AppDimensions.spacingSm),
          Text(
            statusLabel,
            style: AppTextStyles.bodyMedium.copyWith(
              color: inkPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_runIdTail(progress) != null) ...[
          const Gap(AppDimensions.spacingXs),
          Text(
            l10n.creditLimitCallSessionRunId(_runIdTail(progress)!),
            style: AppTextStyles.labelSmall.copyWith(color: inkSecondary),
          ),
        ],
        if (promises.isNotEmpty) ...[
          const Gap(AppDimensions.spacingMd),
          Text(
            l10n.contactPendingPromiseBody(
              _formatPromiseAmount(promises.first),
              _formatPromiseDate(context, promises.first.promisedDate) ?? '',
            ),
            style: AppTextStyles.bodySmall.copyWith(
              color: inkSecondary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.inkSecondary,
    required this.inkPrimary,
  });

  final String label;
  final String amount;
  final Color inkSecondary;
  final Color inkPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ),
        Text(
          amount,
          textDirection: ui.TextDirection.ltr,
          style: AppTextStyles.amountSmall.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String? _runIdTail(CollectionsCallProgress? progress) {
  final runId = progress?.lastRowWithRunId?.runId;
  return ArchitectureHudSnapshot.tail8(runId);
}

String _formatAmount(int minorUnits, String currencyCode) {
  final symbol = _symbolFor(currencyCode);
  return MoneyUtil.formatWithSymbolForCode(minorUnits, currencyCode, symbol);
}

String _formatPromiseAmount(CollectionPromise promise) {
  return _formatAmount(promise.amountMinor, promise.currencyCode);
}

String? _formatPromiseDate(BuildContext context, String promisedDate) {
  final normalized = PromisedCalendarDay.tryParse(promisedDate);
  if (normalized == null) {
    return null;
  }
  final parts = normalized.split('-');
  final date = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(date);
}

String _symbolFor(String code) {
  final normalized = code.trim().toUpperCase();
  for (final currency in BuiltInCurrencies.all) {
    if (currency.code == normalized) {
      return currency.symbol;
    }
  }
  return normalized;
}
