import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/enums/collections_call_report_status.dart';
import 'package:daftar/domain/value_objects/collections_call_report.dart';
import 'package:daftar/presentation/providers/architecture_hud_provider.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna call summary on the sealed daily closing report.
///
/// Visual only. The spoken close-day script does not narrate these rows.
class ClosingRitualCallReportSection extends StatelessWidget {
  /// Creates the call report inset.
  const ClosingRitualCallReportSection({
    required this.report,
    super.key,
  });

  /// Device-owned call rows for this close.
  final CollectionsCallReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    final fill = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final showPromiseNote = report.rows.any((row) => row.hasDisplayPromise);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: lapis,
          width: AppDimensions.dividerThickness,
        ),
        boxShadow: const [AppGlows.glowXs],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.spacingMd,
          AppDimensions.spacingMd,
          AppDimensions.spacingMd,
          AppDimensions.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.closingRitualCallReportTitle,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingSm),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.rows.length,
              itemBuilder: (context, index) {
                final row = report.rows[index];
                return Padding(
                  padding: EdgeInsetsDirectional.only(
                    bottom: index == report.rows.length - 1
                        ? 0
                        : AppDimensions.spacingSm,
                  ),
                  child: _CallReportRow(
                    row: row,
                    l10n: l10n,
                    inkPrimary: inkPrimary,
                    inkMuted: inkMuted,
                    warning: warning,
                  ),
                );
              },
            ),
            if (showPromiseNote) ...[
              const Gap(AppDimensions.spacingSm),
              Text(
                l10n.collectionsDeskPromiseNotPayment,
                style: AppTextStyles.bodySmall.copyWith(
                  color: inkSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallReportRow extends StatelessWidget {
  const _CallReportRow({
    required this.row,
    required this.l10n,
    required this.inkPrimary,
    required this.inkMuted,
    required this.warning,
  });

  final CollectionsCallReportRow row;
  final AppLocalizations l10n;
  final Color inkPrimary;
  final Color inkMuted;
  final Color warning;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(l10n, row.status);
    final runTail = ArchitectureHudSnapshot.tail8(row.runId);
    final promiseLine = _promiseLine(l10n);

    return Semantics(
      container: true,
      label: l10n.closingRitualCallRowSemantics(row.name, statusLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
                ),
              ),
              const Gap(AppDimensions.spacingSm),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _statusColor(row.status),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (promiseLine != null) ...[
            const Gap(AppDimensions.spacingXs),
            Text(
              promiseLine,
              style: AppTextStyles.amountSmall.copyWith(color: inkPrimary),
            ),
          ],
          if (runTail != null) ...[
            const Gap(AppDimensions.spacingXxs),
            Text(
              l10n.architectureHudCallId(runTail),
              style: AppTextStyles.numeralCaption.copyWith(color: inkMuted),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(CollectionsCallReportStatus status) {
    return switch (status) {
      CollectionsCallReportStatus.failed => warning,
      CollectionsCallReportStatus.callUnavailable ||
      CollectionsCallReportStatus.skipped ||
      CollectionsCallReportStatus.completed ||
      CollectionsCallReportStatus.planned ||
      CollectionsCallReportStatus.ringing =>
        inkMuted,
    };
  }

  String? _promiseLine(AppLocalizations l10n) {
    if (!row.hasDisplayPromise) {
      return null;
    }
    final amount = row.promisedAmountMinor!;
    final code = row.promisedCurrency!.trim().toUpperCase();
    final symbol = _symbolFor(code);
    final formatted = MoneyUtil.formatWithSymbolForCode(amount, code, symbol);
    return l10n.closingRitualCallPromiseLine(formatted, row.promisedDate!);
  }

  static String _symbolFor(String code) {
    for (final currency in BuiltInCurrencies.all) {
      if (currency.code == code) {
        return currency.symbol;
      }
    }
    return code;
  }

  static String _statusLabel(
    AppLocalizations l10n,
    CollectionsCallReportStatus status,
  ) {
    return switch (status) {
      CollectionsCallReportStatus.planned => l10n.architectureHudCallPlanned,
      CollectionsCallReportStatus.ringing => l10n.architectureHudCallRinging,
      CollectionsCallReportStatus.completed =>
        l10n.architectureHudCallCompleted,
      CollectionsCallReportStatus.failed => l10n.architectureHudCallFailed,
      CollectionsCallReportStatus.skipped => l10n.collectionsDeskSkippedStatus,
      CollectionsCallReportStatus.callUnavailable =>
        l10n.collectionsDeskRailCallUnavailable,
    };
  }
}
