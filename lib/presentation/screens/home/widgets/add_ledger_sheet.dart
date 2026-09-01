import 'dart:async';

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet for creating a new ledger.
class AddLedgerSheet extends ConsumerStatefulWidget {
  /// Creates the add sheet.
  const AddLedgerSheet({super.key});

  /// Shows the sheet and returns the created ledger on success.
  static Future<Ledger?> show(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AppBottomSheet.show<Ledger>(
      context,
      title: l10n.addLedger,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: isDark ? 0.16 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.folder_special_rounded,
          color: colors.primary,
          size: AppDimensions.iconMedium,
        ),
      ),
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: const AddLedgerSheet(),
    );
  }

  @override
  ConsumerState<AddLedgerSheet> createState() => _AddLedgerSheetState();
}

class _AddLedgerSheetState extends ConsumerState<AddLedgerSheet> {
  static const List<Color> _colorOptions = [
    Color(0xFFD97706),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF14B8A6),
    Color(0xFFB45309),
    Color(0xFF0F766E),
    Color(0xFFA16207),
    Color(0xFF64748B),
    Color(0xFF0EA5E9),
    Color(0xFFDC2626),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_handleNameChanged);
    _nameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isNameValid => _nameController.text.trim().isNotEmpty;

  bool get _canSave => _isNameValid && !_isSubmitting;

  Color get _previewColor {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return context.colorScheme.primary;
    }

    final normalized = name.normalizeArabic().toLowerCase();
    return _colorOptions[_stableIndex(normalized)];
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _nameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    unawaited(HapticFeedback.mediumImpact());

    final result = await ref
        .read(ledgerControllerProvider.notifier)
        .createLedger(
          name: _nameController.text.trim(),
          type: LedgerType.custom,
          icon: 'folder_special_rounded',
          color: _previewColor.toARGB32(),
        );

    if (!mounted) {
      return;
    }

    result.fold(
      (failure) {
        setState(() {
          _isSubmitting = false;
        });

        if (failure is LimitExceededFailure) {
          unawaited(PremiumLimitUpsellSheet.show(context, failure: failure));
          return;
        }

        unawaited(AppBottomSheet.showError(context, error: failure));
      },
      (ledger) {
        Navigator.of(context).pop(ledger);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? colors.surface.withValues(alpha: 0.82)
        : colors.surface.withValues(alpha: 0.92);
    final borderColor = colors.onSurface.withValues(
      alpha: isDark ? 0.10 : 0.06,
    );

    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LedgerPreviewCard(
              name: _nameController.text.trim().isEmpty
                  ? l10n.addLedger
                  : _nameController.text.trim(),
              color: _previewColor,
              isDark: isDark,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(color: borderColor),
              ),
              child: TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                autofocus: true,
                enabled: !_isSubmitting,
                autofillHints: const [AutofillHints.organizationName],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.nameRequired;
                  }

                  return null;
                },
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: l10n.ledgerName,
                  prefixIcon: Icon(
                    Icons.badge_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colors.surface.withValues(
                    alpha: isDark ? 0.60 : 0.90,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingLg,
                    vertical: AppDimensions.spacingLg,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    borderSide: BorderSide(color: colors.primary, width: 1.3),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    borderSide: BorderSide(
                      color: colors.error.withValues(alpha: 0.80),
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    borderSide: BorderSide(
                      color: colors.error,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            DaftarButton(
              label: l10n.save,
              icon: Icons.check_rounded,
              size: DaftarButtonSize.large,
              isExpanded: true,
              isLoading: _isSubmitting,
              onPressed: _canSave ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  static int _stableIndex(String value) {
    var sum = 0;
    for (final codeUnit in value.codeUnits) {
      sum = (sum + codeUnit) & 0x7fffffff;
    }

    return sum % _colorOptions.length;
  }

}

class _LedgerPreviewCard extends StatelessWidget {
  const _LedgerPreviewCard({
    required this.name,
    required this.color,
    required this.isDark,
  });

  final String name;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: isDark ? 0.14 : 0.10),
          colors.surface,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.24 : 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.10 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.92 : 0.82),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.folder_special_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  AppLocalizations.of(context)!.addLedger,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
