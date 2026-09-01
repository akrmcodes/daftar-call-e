import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/duplicate_resolution_strategy.dart';
import 'package:daftar/presentation/providers/import_csv_notifier.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_action_section.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_encoding_selector.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_file_zone.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_issue_banner.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_ledger_picker.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_mapping_section.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_preview_table.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_step_rail.dart';
import 'package:daftar/presentation/screens/settings/import_csv/widgets/import_csv_summary_block.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Clearance above the floating glass shell dock (bar + margins + safe area).
double _shellDockClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 120;

/// Imports ledger contacts + transactions from a CSV ledger export.
class ImportCsvScreen extends ConsumerStatefulWidget {
  const ImportCsvScreen({super.key, this.prefetchedLedgerId});

  final String? prefetchedLedgerId;

  @override
  ConsumerState<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends ConsumerState<ImportCsvScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTargetLedger());
  }

  void _syncTargetLedger() {
    final ledgers = ref.read(ledgersProvider).value;
    if (ledgers == null) {
      return;
    }
    ref.read(importCsvControllerProvider.notifier).syncDefaultTargetLedger(
          prefetchedLedgerId: widget.prefetchedLedgerId,
          globalSelectedLedgerId: ref.read(selectedLedgerIdProvider),
          ledgers: ledgers,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ledgersProvider, (previous, next) {
      next.whenData((ledgers) {
        ref.read(importCsvControllerProvider.notifier).syncDefaultTargetLedger(
              prefetchedLedgerId: widget.prefetchedLedgerId,
              globalSelectedLedgerId: ref.read(selectedLedgerIdProvider),
              ledgers: ledgers,
            );
      });
    });

    final l10n = AppLocalizations.of(context)!;
    final ui = ref.watch(importCsvControllerProvider);
    final notifier = ref.read(importCsvControllerProvider.notifier);
    final ledgersAsync = ref.watch(ledgersProvider);
    final ledgers = ledgersAsync.value ?? const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final ledgerId = ui.targetLedgerId;
    final showPreviewChrome =
        ui.phase == ImportCsvPhase.preview ||
            ui.phase == ImportCsvPhase.importing;
    final showEncodingControls =
        ui.fileBytes != null &&
            (ui.phase == ImportCsvPhase.idle ||
                ui.phase == ImportCsvPhase.preview);
    final mappingComplete = importCsvMappingComplete(
      ui.columnMapping,
      ui.headers.length,
    );
    final showStartButton = ui.phase == ImportCsvPhase.preview;
    final canStartImport =
        mappingComplete && ledgerId != null && !ui.previewRefreshing;
    final canPickLedger =
        ui.phase != ImportCsvPhase.importing &&
        ui.phase != ImportCsvPhase.summary;

    final dockClearance = _shellDockClearance(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.surface0Light,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          DaftarScrollScreenTitleSliver(
            title: Text(
              l10n.csvImportTitle,
              style: AppTextStyles.titleLarge.copyWith(
                color: inkPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
              SliverPadding(
                padding: EdgeInsetsDirectional.only(
                  start: AppDimensions.pagePaddingH,
                  end: AppDimensions.pagePaddingH,
                  top: AppDimensions.spacingMd,
                  bottom: dockClearance,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeSlideTransition(
                      child: ImportCsvStepRail(phase: ui.phase),
                    ),
                    const Gap(AppDimensions.spacingXl),
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 30),
                      child: Text(
                        l10n.csvImportSubtitle,
                        style: AppTextStyles.bodyLarge.copyWith(color: inkMuted),
                      ),
                    ),
                    const Gap(AppDimensions.spacingXl),
                    if (ledgersAsync.isLoading)
                      const Skeletonizer(
                        child: SizedBox(
                          height: 96,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                            ),
                          ),
                        ),
                      )
                    else if (ledgers.isEmpty)
                      const ImportCsvLedgerWarning()
                    else if (canPickLedger)
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 45),
                        child: ImportCsvLedgerPicker(
                          ledgers: ledgers,
                          selectedLedgerId: ledgerId,
                          onSelected: notifier.selectTargetLedger,
                        ),
                      ),
                    if (ledgers.isNotEmpty &&
                        ledgerId == null &&
                        canPickLedger) ...[
                      const Gap(AppDimensions.spacingSm),
                      Text(
                        l10n.csvImportNoLedgerSelected,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.warning
                              : AppColors.warningLight,
                        ),
                      ),
                    ],
                    const Gap(AppDimensions.spacingLg),
                    ImportCsvIssueBanner(
                      state: ui,
                      onDismiss: notifier.clearIdleIssue,
                    ),
                    if (ui.phase != ImportCsvPhase.summary) ...[
                      FadeSlideTransition(
                        delay: const Duration(milliseconds: 60),
                        child: ImportCsvFileZone(
                          state: ui,
                          onPickFile: notifier.pickCsvFile,
                        ),
                      ),
                      if (showStartButton)
                        ImportCsvStartButton(
                          isLoading: ui.previewRefreshing,
                          onPressed: canStartImport
                              ? () => _runCsvImportWithDuplicateGate(
                                    context,
                                    ref,
                                    ledgerId: ledgerId,
                                  )
                              : null,
                          disabledHint: ledgerId == null
                              ? l10n.csvImportNoLedgerSelected
                              : !mappingComplete
                                  ? l10n.csvImportMappingIncompleteHint
                                  : null,
                        ),
                    ],
                    if (ui.phase == ImportCsvPhase.importing) ...[
                      const Gap(AppDimensions.spacingXl),
                      ImportCsvProgressCard(
                        label: ui.importPipelineCommitStarted
                            ? l10n.csvImportProgressLabel
                            : l10n.csvImportPrefabProgressLabel,
                      ),
                    ],
                    if (showEncodingControls) ...[
                      const Gap(AppDimensions.spacingXl),
                      Skeletonizer(
                        enabled: ui.phase == ImportCsvPhase.preview &&
                            ui.previewRefreshing,
                        child: ImportCsvEncodingSelector(
                          value: ui.encoding,
                          onChanged: notifier.applyEncoding,
                        ),
                      ),
                    ],
                    if (showPreviewChrome) ...[
                      const Gap(AppDimensions.spacingXl),
                      Skeletonizer(
                        enabled: ui.previewRefreshing,
                        child: ImportCsvMappingSection(
                          headers: ui.headers,
                          previewRows: ui.previewRows,
                          columnMapping: ui.columnMapping,
                          onMappingChanged: notifier.updateColumnMapping,
                        ),
                      ),
                      const Gap(AppDimensions.spacingXl),
                      Skeletonizer(
                        enabled: ui.previewRefreshing,
                        child: ImportCsvPreviewTable(
                          headers: ui.headers,
                          rows: ui.previewRows,
                        ),
                      ),
                    ],
                    if (ui.phase == ImportCsvPhase.summary)
                      ImportCsvSummaryBlock(
                        state: ui,
                        onReset: notifier.resetFlow,
                      ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}

Future<void> _runCsvImportWithDuplicateGate(
  BuildContext context,
  WidgetRef ref, {
  required String ledgerId,
}) async {
  await HapticService.medium();
  if (!context.mounted) {
    return;
  }

  final notifier = ref.read(importCsvControllerProvider.notifier)
    ..beginImportPipeline();

  final preflightEither = await notifier.runPreflightAnalyze(ledgerId: ledgerId);

  if (!context.mounted) {
    return;
  }

  if (preflightEither.isLeft()) {
    notifier.reportImportFatal(
      preflightEither.getLeft().toNullable()!.message,
    );
    return;
  }

  final summary = preflightEither.getRight().toNullable()!;
  var strategy = DuplicateResolutionStrategy.merge;

  if (summary.duplicateContactsCount > 0) {
    final picked = await showCsvDuplicateStrategySheet(
      context,
      duplicateContactCount: summary.duplicateContactsCount,
    );
    if (!context.mounted) {
      return;
    }
    if (picked == null) {
      notifier.restorePreviewAfterCanceledImportPipeline();
      return;
    }
    strategy = picked;
  }

  await notifier.finalizeImportWithStrategy(
    ledgerId: ledgerId,
    duplicateStrategy: strategy,
  );
}

Future<DuplicateResolutionStrategy?> showCsvDuplicateStrategySheet(
  BuildContext context, {
  required int duplicateContactCount,
}) async {
  final l10n = AppLocalizations.of(context)!;
  return AppBottomSheet.show<DuplicateResolutionStrategy>(
    context,
    scrollable: false,
    title: l10n.csvImportDuplicatesSheetTitle,
    subtitle: l10n.csvImportDuplicatesSheetBody(duplicateContactCount),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DaftarButton(
          label: l10n.csvImportDuplicatesMergeRecommended,
          size: DaftarButtonSize.large,
          isExpanded: true,
          onPressed: () {
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(DuplicateResolutionStrategy.merge);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.csvImportDuplicatesSkipLabel,
          variant: DaftarButtonVariant.secondary,
          size: DaftarButtonSize.large,
          isExpanded: true,
          onPressed: () {
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(DuplicateResolutionStrategy.skip);
          },
        ),
        const Gap(AppDimensions.spacingSm),
        DaftarButton(
          label: l10n.csvImportDuplicatesCancelImport,
          variant: DaftarButtonVariant.tertiary,
          size: DaftarButtonSize.large,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
