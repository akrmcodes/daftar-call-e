import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/drive_backup_date_filter.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_format_utils.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_remote_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Full catalog sheet for choosing a Google Drive backup to restore.
class DriveRestorePickerSheet extends ConsumerStatefulWidget {
  const DriveRestorePickerSheet({
    required this.onSelected,
    super.key,
  });

  final ValueChanged<GoogleDriveRemoteBackupItem> onSelected;

  /// Presents the picker and loads the complete Drive catalog first.
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required ValueChanged<GoogleDriveRemoteBackupItem> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.surface2 : AppColors.surface1Light;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: AppMotion.sheetAnimationStyle,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.92;
        return SizedBox(
          height: maxHeight,
          child: DriveRestorePickerSheet(onSelected: onSelected),
        );
      },
    );
  }

  @override
  ConsumerState<DriveRestorePickerSheet> createState() =>
      _DriveRestorePickerSheetState();
}

class _DriveRestorePickerSheetState extends ConsumerState<DriveRestorePickerSheet> {
  DateTime? _selectedDay;
  bool _catalogRequested = false;
  bool _isLoadingCatalog = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_catalogRequested) {
        return;
      }
      _catalogRequested = true;
      await ref.read(driveBackupProvider.notifier).loadRestoreCatalog();
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    });
  }

  Future<void> _pickDate(List<GoogleDriveRemoteBackupItem> backups) async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final oldest = oldestBackupDay(backups) ??
        now.subtract(const Duration(days: 365 * 5));

    final picked = await showDatePicker(
      context: context,
      helpText: l10n.backupDriveRestorePickDate,
      initialDate:
          _selectedDay ?? backups.first.modifiedTimeUtc?.toLocal() ?? now,
      firstDate: oldest,
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  surface:
                      isDark ? AppColors.surface2 : AppColors.surface1Light,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDay = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final fill = isDark ? AppColors.surface3 : AppColors.surface1Light;
    final border =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    final driveState = ref.watch(driveBackupProvider);
    final backups = driveState.remoteBackups;
    final isLoading = _isLoadingCatalog;

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const Gap(AppDimensions.spacingMd),
            Text(
              l10n.backupDriveRestoreLoading,
              style: AppTextStyles.bodyMedium.copyWith(
                color: inkSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (backups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
          child: Text(
            driveState.lastFailure != null
                ? ErrorTranslator.driveFailureMessage(
                    l10n,
                    driveState.lastFailure!,
                  )
                : l10n.backupDriveNoCloudBackups,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: inkSecondary,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    final filtered = filterDriveBackupsByDay(backups, _selectedDay);
    final groups = _selectedDay == null
        ? groupDriveBackupsByDay(backups)
        : <DriveBackupDayGroup>[
            if (filtered.isNotEmpty)
              DriveBackupDayGroup(day: _selectedDay!, items: filtered),
          ];

    final dateLabel = _selectedDay == null
        ? l10n.backupDriveRestorePickDate
        : DateFormat.yMMMd(AppConstants.numeralLocale).format(_selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.pagePaddingH,
            AppDimensions.spacingSm,
            AppDimensions.pagePaddingH,
            AppDimensions.spacingMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.backupDriveRestorePickTitle,
                style: AppTextStyles.titleMedium.copyWith(
                  color: inkPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AppDimensions.spacingXxs),
              Text(
                l10n.backupDriveRestorePickerCount(backups.length),
                style: AppTextStyles.bodySmall.copyWith(
                  color: inkSecondary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.pagePaddingH,
          ),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: fill,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: InkWell(
                    onTap: () => _pickDate(backups),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusLg),
                        border: Border.all(color: border, width: 0.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppDimensions.spacingMd,
                          vertical: AppDimensions.spacingMd,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: inkSecondary,
                              size: 22,
                            ),
                            const Gap(AppDimensions.spacingMd),
                            Expanded(
                              child: Text(
                                dateLabel,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: inkPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              color: inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_selectedDay != null) ...[
                const Gap(AppDimensions.spacingSm),
                TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: Text(l10n.backupDriveRestoreClearDate),
                ),
              ],
            ],
          ),
        ),
        const Gap(AppDimensions.spacingMd),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
                child: Text(
                  l10n.backupDriveRestoreDateEmpty,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: inkMuted,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.pagePaddingH,
                0,
                AppDimensions.pagePaddingH,
                AppDimensions.spacingLg,
              ),
              itemCount: _visibleRowCount(groups),
              itemBuilder: (context, index) {
                final row = _resolveRow(groups, index);
                if (row.isHeader) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppDimensions.spacingSm,
                      bottom: AppDimensions.spacingXs,
                    ),
                    child: Text(
                      _sectionTitle(l10n, row.day!),
                      style: AppTextStyles.labelLarge.copyWith(
                        color: inkSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                final item = row.item!;
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onSelected(item);
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: AppDimensions.spacingMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_done_rounded,
                          color: inkSecondary,
                          size: 22,
                        ),
                        const Gap(AppDimensions.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  formatDriveBackupDate(context, item),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: inkPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                item.sizeBytes != null
                                    ? formatBackupSize(l10n, item.sizeBytes!)
                                    : '—',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: inkMuted,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _sectionTitle(AppLocalizations l10n, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (isSameCalendarDay(day, today)) {
      return l10n.today;
    }
    if (isSameCalendarDay(day, yesterday)) {
      return l10n.yesterday;
    }
    return DateFormat.yMMMd(AppConstants.numeralLocale).format(day);
  }
}

class _PickerRow {
  const _PickerRow._({this.day, this.item});

  factory _PickerRow.header(DateTime day) => _PickerRow._(day: day);
  factory _PickerRow.item(GoogleDriveRemoteBackupItem item) =>
      _PickerRow._(item: item);

  final DateTime? day;
  final GoogleDriveRemoteBackupItem? item;

  bool get isHeader => day != null;
}

int _visibleRowCount(List<DriveBackupDayGroup> groups) {
  var count = 0;
  for (final group in groups) {
    count += 1 + group.items.length;
  }
  return count;
}

_PickerRow _resolveRow(List<DriveBackupDayGroup> groups, int index) {
  var cursor = 0;
  for (final group in groups) {
    if (cursor == index) {
      return _PickerRow.header(group.day);
    }
    cursor++;
    for (final item in group.items) {
      if (cursor == index) {
        return _PickerRow.item(item);
      }
      cursor++;
    }
  }
  throw RangeError.index(index, groups, 'index');
}
