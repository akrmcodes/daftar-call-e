import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/date_util.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_speakable_lines.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Drift-backed ask-the-books card. Amounts never come from the model.
class AgentAskCard extends StatefulWidget {
  /// Creates the ask card.
  const AgentAskCard({
    required this.answer,
    required this.isDark,
    this.onCandidateSelected,
    this.ttsMuted = false,
    this.ttsLocale = 'ar',
    super.key,
  });

  /// Device-authored answer.
  final AskBooksAnswer answer;

  /// Theme brightness flag.
  final bool isDark;

  /// Called when the merchant picks an ambiguous name.
  final ValueChanged<String>? onCandidateSelected;

  /// When true, skip TTS for this card.
  final bool ttsMuted;

  /// Session speech locale (`ar` / `en`) for TTS — not UI locale.
  final String ttsLocale;

  @override
  State<AgentAskCard> createState() => _AgentAskCardState();
}

class _AgentAskCardState extends State<AgentAskCard> {
  @override
  void initState() {
    super.initState();
    _speakAnswer();
  }

  @override
  void didUpdateWidget(covariant AgentAskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer) {
      _speakAnswer();
    }
  }

  void _speakAnswer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.ttsMuted) {
        return;
      }
      final line = askBooksSpeakable(
        widget.answer,
        speechLocalizations(widget.ttsLocale),
      );
      if (line.isEmpty) {
        return;
      }
      unawaited(AgentSpeech.speak(line, locale: widget.ttsLocale));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = widget.isDark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    return RepaintBoundary(
      child: DaftarCard(
        child: switch (widget.answer) {
          AskBooksOverdueList(:final rows) => _OutstandingBody(
            title: l10n.closingAgentAskOverdueTitle,
            rows: rows,
            l10n: l10n,
            inkPrimary: inkPrimary,
            inkSecondary: inkSecondary,
            isDark: isDark,
          ),
          AskBooksLargestOutstanding(:final rows) => _OutstandingBody(
            title: l10n.closingAgentAskLargestTitle,
            rows: rows,
            l10n: l10n,
            inkPrimary: inkPrimary,
            inkSecondary: inkSecondary,
            isDark: isDark,
          ),
          AskBooksSmallestOutstanding(:final rows) => _OutstandingBody(
            title: l10n.closingAgentAskSmallestTitle,
            rows: rows,
            l10n: l10n,
            inkPrimary: inkPrimary,
            inkSecondary: inkSecondary,
            isDark: isDark,
          ),
          AskBooksNamedBalance(:final row) => _NamedBody(
            row: row,
            l10n: l10n,
            inkPrimary: inkPrimary,
            isDark: isDark,
          ),
          final AskBooksLastTransaction last => _LastTxnBody(
            answer: last,
            l10n: l10n,
            inkPrimary: inkPrimary,
            inkSecondary: inkSecondary,
            isDark: isDark,
          ),
          AskBooksNoLastTransaction(
            :final contactName,
            :final type,
          ) =>
            Text(
              type == TransactionType.payment
                  ? l10n.closingAgentAskNoLastPayment(contactName)
                  : l10n.closingAgentAskNoLastDebt(contactName),
              style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
            ),
          AskBooksAmbiguous(:final candidates) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.closingAgentWhichContact,
                style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
              ),
              const Gap(AppDimensions.spacingSm),
              SizedBox(
                height: AppDimensions.minTapTarget,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final hit = candidates[index];
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppDimensions.spacingSm,
                      ),
                      child: _AskChip(
                        label: '${hit.contact.name} · ${hit.ledgerName}',
                        isDark: isDark,
                        onTap: () =>
                            widget.onCandidateSelected?.call(hit.contact.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          AskBooksUnresolved() => Text(
            l10n.closingAgentAskUnresolved,
            style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
          ),
          AskBooksNeedName() => Text(
            l10n.closingAgentAskNeedName,
            style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
          ),
        },
      ),
    );
  }
}

class _OutstandingBody extends StatelessWidget {
  const _OutstandingBody({
    required this.title,
    required this.rows,
    required this.l10n,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.isDark,
  });

  final String title;
  final List<AskBooksBalanceRow> rows;
  final AppLocalizations l10n;
  final Color inkPrimary;
  final Color inkSecondary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
        ),
        const Gap(AppDimensions.spacingSm),
        if (rows.isEmpty)
          Text(
            l10n.closingAgentAskEmpty,
            style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppDimensions.spacingSm,
                ),
                child: _BalanceLine(row: rows[index], isDark: isDark),
              );
            },
          ),
      ],
    );
  }
}

class _NamedBody extends StatelessWidget {
  const _NamedBody({
    required this.row,
    required this.l10n,
    required this.inkPrimary,
    required this.isDark,
  });

  final AskBooksBalanceRow row;
  final AppLocalizations l10n;
  final Color inkPrimary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.closingAgentAskBalanceTitle,
          style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
        ),
        const Gap(AppDimensions.spacingXs),
        _BalanceLine(row: row, isDark: isDark),
      ],
    );
  }
}

class _LastTxnBody extends StatelessWidget {
  const _LastTxnBody({
    required this.answer,
    required this.l10n,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.isDark,
  });

  final AskBooksLastTransaction answer;
  final AppLocalizations l10n;
  final Color inkPrimary;
  final Color inkSecondary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isPayment = answer.type == TransactionType.payment;
    final amountColor = isPayment
        ? (isDark ? AppColors.payment : AppColors.paymentLight)
        : (isDark ? AppColors.debt : AppColors.debtLight);
    final amount = MoneyUtil.formatMinorUnitsForCode(
      answer.amountMinor,
      answer.currencyCode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isPayment
              ? l10n.closingAgentAskLastPaymentTitle
              : l10n.closingAgentAskLastDebtTitle,
          style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
        ),
        const Gap(AppDimensions.spacingXs),
        Row(
          children: [
            Expanded(
              child: Text(
                answer.contactName,
                style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
              ),
            ),
            Text(
              '$amount ${answer.currencyCode}',
              textDirection: TextDirection.ltr,
              style: AppTextStyles.labelMedium.copyWith(color: amountColor),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingXs),
        Text(
          DateUtil.formatDate(answer.transactionDate),
          style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
        ),
      ],
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({
    required this.row,
    required this.isDark,
  });

  final AskBooksBalanceRow row;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final amountColor = row.netBalance < 0
        ? (isDark ? AppColors.debt : AppColors.debtLight)
        : row.netBalance > 0
        ? (isDark ? AppColors.payment : AppColors.paymentLight)
        : inkPrimary;
    final amount = MoneyUtil.formatMinorUnitsForCode(
      row.netBalance,
      row.currencyCode,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            row.contactName,
            style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
          ),
        ),
        Text(
          '$amount ${row.currencyCode}',
          textDirection: TextDirection.ltr,
          style: AppTextStyles.labelMedium.copyWith(color: amountColor),
        ),
      ],
    );
  }
}

class _AskChip extends StatelessWidget {
  const _AskChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final fill = isDark ? AppColors.surface2 : AppColors.surface1Light;
    return GestureDetector(
      onTap: () {
        unawaited(HapticService.selection());
        onTap();
      },
      child: DaftarTapTarget(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingMd,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(color: ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
