import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/import_csv_notifier.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Recoverable pre-preview issue surfaced after a failed file pick or parse.
class ImportCsvIssueBanner extends StatelessWidget {
  const ImportCsvIssueBanner({
    required this.state,
    required this.onDismiss,
    super.key,
  });

  final ImportCsvUiState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final kind = state.idleIssueKind;
    if (kind == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debt = isDark ? AppColors.debt : AppColors.debtLight;

    final title = switch (kind) {
      ImportCsvIdleIssueKind.readFailed => l10n.csvImportReadFailed,
      ImportCsvIdleIssueKind.emptyBytes => l10n.csvImportEmptyFile,
      ImportCsvIdleIssueKind.parseWorkerFailed =>
        l10n.csvImportParseWorkerFailed,
      ImportCsvIdleIssueKind.structureFatal =>
        l10n.csvImportStructureFatalPrefix,
    };

    final detail = state.idleIssueDetail;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingLg,
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: debt, size: 22),
                const Gap(AppDimensions.spacingMd),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(color: debt),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (detail != null && detail.trim().isNotEmpty) ...[
              const Gap(AppDimensions.spacingXs),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppDimensions.spacing3xl,
                ),
                child: Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.inkSecondary
                        : AppColors.inkSecondaryLight,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ledger prerequisite warning — import cannot proceed without a target ledger.
class ImportCsvLedgerWarning extends StatelessWidget {
  const ImportCsvLedgerWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debt = isDark ? AppColors.debt : AppColors.debtLight;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingLg,
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: debt),
            const Gap(AppDimensions.spacingMd),
            Expanded(
              child: Text(
                l10n.csvImportNoLedgerMessage,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.inkPrimary
                      : AppColors.inkPrimaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
