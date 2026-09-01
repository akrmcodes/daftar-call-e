import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Horizontally scrollable preview grid for delimiter + encoding verification.
class ImportCsvPreviewTable extends StatelessWidget {
  const ImportCsvPreviewTable({
    required this.headers,
    required this.rows,
    super.key,
  });

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    if (headers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.csvImportPreviewSection,
          style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
        ),
        const Gap(AppDimensions.spacingSm),
        DaftarCard(
          variant: DaftarCardVariant.compact,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: _PreviewGrid(headers: headers, rows: rows),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewGrid extends StatelessWidget {
  const _PreviewGrid({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final border =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final headerBg = isDark ? AppColors.surface4 : AppColors.surface2Light;

    const colMinWidth = 96.0;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(colMinWidth),
      border: TableBorder(
        horizontalInside: BorderSide(color: border),
        verticalInside: BorderSide(color: border),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerBg),
          children: [
            for (final header in headers)
              Padding(
                padding: const EdgeInsetsDirectional.all(
                  AppDimensions.spacingMd,
                ),
                child: Text(
                  header.isEmpty ? '—' : header,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: inkPrimary,
                    fontFamily: AppTextStyles.latinFontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              for (var col = 0; col < headers.length; col++)
                Padding(
                  padding: const EdgeInsetsDirectional.all(
                    AppDimensions.spacingMd,
                  ),
                  child: Text(
                    col < row.length ? row[col] : '',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: inkMuted,
                      fontFamily: AppTextStyles.latinFontFamily,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
