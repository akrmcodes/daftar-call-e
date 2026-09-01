import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/demo_seed_report.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';

/// Brief post-seed summary for judges — no email addresses.
Future<void> showDemoSeedReportDialog(
  BuildContext context,
  DemoSeedReport report,
) {
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final inkPrimary =
      isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
  final inkSecondary =
      isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

  final storeLine = report.storeNameKept
      ? l10n.demoSeedReportStoreKept(report.storeName)
      : l10n.demoSeedReportStoreGenerated(report.storeName);

  final bullets = <String>[
    storeLine,
    l10n.demoSeedReportLedger(report.ledgerName),
    l10n.demoSeedReportContacts(report.contactCount),
    l10n.demoSeedReportTones,
    l10n.demoSeedReportSendSplit(report.pdfCount, report.textOnlyCount),
  ];

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: isDark ? AppColors.surface2 : AppColors.surface1Light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        title: Text(
          l10n.demoSeedReportTitle,
          style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in bullets)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppDimensions.spacingSm,
                  ),
                  child: Text(
                    line,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: inkSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          DaftarButton(
            label: l10n.demoSeedReportDone,
            size: DaftarButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}
