import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:daftar/presentation/providers/archived_ledger_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/add_ledger_sheet.dart';
import 'package:daftar/presentation/screens/ledger/widgets/archive_ceremony_overlay.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

enum _FinancialCloseMode { archiveOnly, carryForward }

class FinancialCloseWizardSheet extends ConsumerStatefulWidget {
  const FinancialCloseWizardSheet({required this.sourceLedger, super.key});

  final Ledger sourceLedger;

  static Future<void> show(
    BuildContext context, {
    required Ledger sourceLedger,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;

    return AppBottomSheet.show<void>(
      context,
      title: l10n.financialCloseTitle,
      subtitle: l10n.financialCloseSubtitle,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: isDark ? 0.16 : 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_clock_rounded,
          color: AppColors.warning,
          size: AppDimensions.iconMedium,
        ),
      ),
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: FinancialCloseWizardSheet(sourceLedger: sourceLedger),
    );
  }

  @override
  ConsumerState<FinancialCloseWizardSheet> createState() =>
      _FinancialCloseWizardSheetState();
}

class _FinancialCloseWizardSheetState
    extends ConsumerState<FinancialCloseWizardSheet> {
  _FinancialCloseMode _mode = _FinancialCloseMode.archiveOnly;
  String? _targetLedgerId;
  bool _isSubmitting = false;

  bool get _canConfirm {
    if (_isSubmitting) {
      return false;
    }
    if (_mode == _FinancialCloseMode.archiveOnly) {
      return true;
    }
    return _targetLedgerId != null && _targetLedgerId!.isNotEmpty;
  }

  Future<void> _createTargetLedger() async {
    final created = await AddLedgerSheet.show(context);
    if (!mounted || created == null) {
      return;
    }
    setState(() {
      _targetLedgerId = created.id;
      _mode = _FinancialCloseMode.carryForward;
    });
  }

  Future<void> _confirm() async {
    if (!_canConfirm || !mounted) {
      return;
    }

    unawaited(HapticService.buttonPress());
    final l10n = AppLocalizations.of(context)!;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final notifier = ref.read(archiveLedgerControllerProvider.notifier);
    final sourceId = widget.sourceLedger.id;

    setState(() => _isSubmitting = true);

    ArchiveWithCarryForwardParams? carryForward;
    if (_mode == _FinancialCloseMode.carryForward) {
      carryForward = ArchiveWithCarryForwardParams(
        sourceLedgerId: sourceId,
        targetLedgerId: _targetLedgerId!,
        operationId: UuidUtil.generate(),
        openingBalanceItemName: l10n.openingBalanceItemName,
        openingBalanceDescription: l10n.carryForwardOpeningBalanceNote(
          widget.sourceLedger.name,
        ),
      );
    }

    Navigator.of(context).pop();

    Either<Failure, Ledger>? result;
    final ok = await ArchiveCeremonyOverlay.runWithCeremony(
      context: rootContext,
      successTitle: l10n.carryForwardSuccess,
      successSubtitle: l10n.carryForwardSuccessBody,
      operation: () async {
        result = await notifier.archive(
          ledgerId: sourceId,
          carryForward: carryForward,
        );
        return result!.isRight();
      },
    );

    if (!rootContext.mounted) {
      return;
    }

    if (ok) {
      unawaited(HapticService.success());
      return;
    }

    final failure = result?.fold((left) => left, (_) => null);
    if (failure == null) {
      return;
    }
    if (failure is LimitExceededFailure) {
      unawaited(PremiumLimitUpsellSheet.show(rootContext, failure: failure));
      return;
    }
    unawaited(DaftarErrorSheet.showForError(rootContext, error: failure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final asyncLedgers = ref.watch(ledgersProvider);
    final targetCandidates = asyncLedgers.asData?.value
            .where(
              (ledger) =>
                  ledger.id != widget.sourceLedger.id && !ledger.isUserArchived,
            )
            .toList() ??
        const <Ledger>[];

    final previewAsync = _targetLedgerId == null
        ? null
        : ref.watch(
            previewCarryForwardProvider(
              widget.sourceLedger.id,
              _targetLedgerId!,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EducationCard(
          title: l10n.financialCloseEducationTitle,
          body: l10n.financialCloseEducationBody,
          isDark: isDark,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        _ModeCard(
          title: l10n.financialCloseArchiveOnly,
          subtitle: l10n.financialCloseArchiveOnlyDescription,
          icon: Icons.inventory_2_outlined,
          isSelected: _mode == _FinancialCloseMode.archiveOnly,
          isDark: isDark,
          onTap: () => setState(() => _mode = _FinancialCloseMode.archiveOnly),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        _ModeCard(
          title: l10n.carryForwardToggleLabel,
          subtitle: l10n.carryForwardToggleDescription,
          icon: Icons.swap_horiz_rounded,
          isSelected: _mode == _FinancialCloseMode.carryForward,
          isDark: isDark,
          onTap: () => setState(() => _mode = _FinancialCloseMode.carryForward),
        ),
        if (_mode == _FinancialCloseMode.carryForward) ...[
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            l10n.carryForwardTargetPickerLabel,
            style: AppTextStyles.labelLarge.copyWith(
              color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            l10n.carryForwardTargetPickerHint,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          _TargetLedgerSelector(
            ledgers: targetCandidates,
            selectedId: _targetLedgerId,
            isDark: isDark,
            createLabel: l10n.carryForwardCreateNewLedger,
            onSelected: (id) => setState(() => _targetLedgerId = id),
            onCreate: _isSubmitting ? null : () => unawaited(_createTargetLedger()),
          ),
          if (previewAsync != null) ...[
            const SizedBox(height: AppDimensions.spacingLg),
            previewAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.spacingLg),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => Text(
                l10n.loadingError,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.debt : AppColors.debtLight,
                ),
              ),
              data: (result) => result.fold(
                (_) => const SizedBox.shrink(),
                (preview) => _PreviewCard(
                  preview: preview,
                  isDark: isDark,
                  l10n: l10n,
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: AppDimensions.spacingLg),
        _ReassuranceCard(
          title: l10n.carryForwardConfirmTitle,
          body: l10n.carryForwardConfirmBody,
          isDark: isDark,
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        DaftarButton(
          label: l10n.confirmArchive,
          isExpanded: true,
          isLoading: _isSubmitting,
          onPressed: _canConfirm ? () => unawaited(_confirm()) : null,
        ),
      ],
    );
  }
}

class _EducationCard extends StatelessWidget {
  const _EducationCard({
    required this.title,
    required this.body,
    required this.isDark,
  });

  final String title;
  final String body;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: isDark ? AppColors.lapis800.withValues(alpha: 0.42) : AppColors.lapis50,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppDimensions.radiusLg,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide(
            color: (isDark ? AppColors.lapis400 : AppColors.lapis500)
                .withValues(alpha: 0.28),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: AppDimensions.iconMedium,
              color: isDark ? AppColors.lapis400 : AppColors.lapis500,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: isDark
                          ? AppColors.inkPrimary
                          : AppColors.inkPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXxs),
                  Text(
                    body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReassuranceCard extends StatelessWidget {
  const _ReassuranceCard({
    required this.title,
    required this.body,
    required this.isDark,
  });

  final String title;
  final String body;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: isDark
            ? AppColors.surface3.withValues(alpha: 0.65)
            : AppColors.surface2Light,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppDimensions.radiusLg,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: AppDimensions.iconSmall + 2,
              color: isDark ? AppColors.payment : AppColors.paymentLight,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: isDark
                          ? AppColors.inkPrimary
                          : AppColors.inkPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXxs),
                  Text(
                    body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = isSelected
        ? (isDark ? AppColors.surface4 : AppColors.surface3Light)
        : (isDark
            ? AppColors.surface3.withValues(alpha: 0.6)
            : AppColors.surface2Light);
    final border = isSelected
        ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);

    return GestureDetector(
      onTap: () {
        unawaited(HapticService.selection());
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.animationFast,
        curve: Curves.easeOutCubic,
        decoration: ShapeDecoration(
          color: fill,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: AppDimensions.radiusLg,
              cornerSmoothing: 0.6,
            ),
            side: BorderSide(
              color: border,
              width: AppDimensions.dividerThickness,
            ),
          ),
          shadows: isSelected ? AppGlows.haloXs : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: isDark
                            ? AppColors.inkPrimary
                            : AppColors.inkPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.inkSecondary
                            : AppColors.inkSecondaryLight,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
                    : (isDark ? AppColors.inkMuted : AppColors.inkMutedLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetLedgerSelector extends StatelessWidget {
  const _TargetLedgerSelector({
    required this.ledgers,
    required this.selectedId,
    required this.isDark,
    required this.createLabel,
    required this.onSelected,
    this.onCreate,
  });

  final List<Ledger> ledgers;
  final String? selectedId;
  final bool isDark;
  final String createLabel;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < ledgers.length; index++) ...[
          if (index > 0) const SizedBox(height: AppDimensions.spacingSm),
          _TargetLedgerCard(
            ledger: ledgers[index],
            isSelected: ledgers[index].id == selectedId,
            isDark: isDark,
            onTap: () {
              unawaited(HapticService.selection());
              onSelected(ledgers[index].id);
            },
          ),
        ],
        if (onCreate != null) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          _CreateLedgerCard(
            label: createLabel,
            isDark: isDark,
            onTap: () {
              unawaited(HapticService.light());
              onCreate!();
            },
          ),
        ],
      ],
    );
  }
}

class _TargetLedgerCard extends StatelessWidget {
  const _TargetLedgerCard({
    required this.ledger,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final Ledger ledger;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _ledgerAccentColor(ledger);
    final fill = isSelected
        ? (isDark ? AppColors.surface4 : AppColors.surface3Light)
        : (isDark ? AppColors.surface3 : AppColors.surface2Light);
    final border = isSelected
        ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.animationFast,
        curve: Curves.easeOutCubic,
        decoration: ShapeDecoration(
          color: fill,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: AppDimensions.radiusLg,
              cornerSmoothing: 0.6,
            ),
            side: BorderSide(color: border, width: AppDimensions.dividerThickness),
          ),
          shadows: isSelected ? AppGlows.haloXs : null,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingMd,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  ledger.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isDark
                        ? AppColors.inkPrimary
                        : AppColors.inkPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isSelected
                    ? (isDark ? AppColors.lapis400 : AppColors.lapis500)
                    : (isDark ? AppColors.inkMuted : AppColors.inkMutedLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateLedgerCard extends StatelessWidget {
  const _CreateLedgerCard({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: AppDimensions.radiusLg,
              cornerSmoothing: 0.6,
            ),
            side: BorderSide(
              color: border.withValues(alpha: 0.45),
              width: AppDimensions.dividerThickness,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: border,
                size: AppDimensions.iconMedium,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.isDark,
    required this.l10n,
  });

  final CarryForwardPreview preview;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final totals = preview.totalsByCurrency;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: isDark
            ? AppColors.surface3.withValues(alpha: 0.7)
            : AppColors.surface2Light,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppDimensions.radiusLg,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide(
            color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.carryForwardPreviewTitle,
              style: AppTextStyles.titleSmall.copyWith(
                color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              l10n.carryForwardPreviewContacts(preview.contactCount),
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.inkSecondary
                    : AppColors.inkSecondaryLight,
              ),
            ),
            Text(
              l10n.carryForwardPreviewTransactions(preview.transactionCount),
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.inkSecondary
                    : AppColors.inkSecondaryLight,
              ),
            ),
            if (totals.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              for (final entry in totals.entries)
                Text(
                  '${entry.key}: ${MoneyUtil.formatMinorUnitsForCode(entry.value, entry.key)}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark
                        ? AppColors.inkPrimary
                        : AppColors.inkPrimaryLight,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _ledgerAccentColor(Ledger ledger) {
  final raw = ledger.color.trim();
  if (raw.startsWith('#')) {
    final hex = raw.substring(1);
    final value = int.tryParse(hex, radix: 16);
    if (value != null) {
      final color = hex.length <= 6
          ? Color(0xFF000000 | value)
          : Color(value);
      return color;
    }
  }
  final parsed = int.tryParse(raw);
  if (parsed != null) {
    return Color(parsed);
  }
  return AppColors.avatarColors[ledger.id.hashCode.abs() %
      AppColors.avatarColors.length];
}
