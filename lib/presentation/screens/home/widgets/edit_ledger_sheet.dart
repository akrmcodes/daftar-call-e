import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

/// Bottom sheet for renaming a ledger and changing its visual identity.
class EditLedgerSheet extends ConsumerStatefulWidget {
  /// Creates an edit sheet for the provided [ledger].
  const EditLedgerSheet({required this.ledger, super.key});

  final Ledger ledger;

  /// Shows the edit sheet and returns the updated ledger on success.
  static Future<Ledger?> show(
    BuildContext context, {
    required Ledger ledger,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return AppBottomSheet.show<Ledger>(
      context,
      title: l10n.editLedger,
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacingXs,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
      ),
      child: EditLedgerSheet(ledger: ledger),
    );
  }

  @override
  ConsumerState<EditLedgerSheet> createState() => _EditLedgerSheetState();
}

class _EditLedgerSheetState extends ConsumerState<EditLedgerSheet> {
  static const List<_LedgerColorOption> _colorOptions = [
    _LedgerColorOption(hex: '#D97706', color: Color(0xFFD97706)),
    _LedgerColorOption(hex: '#2563EB', color: Color(0xFF2563EB)),
    _LedgerColorOption(hex: '#7C3AED', color: Color(0xFF7C3AED)),
    _LedgerColorOption(hex: '#14B8A6', color: Color(0xFF14B8A6)),
    _LedgerColorOption(hex: '#B45309', color: Color(0xFFB45309)),
    _LedgerColorOption(hex: '#0F766E', color: Color(0xFF0F766E)),
    _LedgerColorOption(hex: '#A16207', color: Color(0xFFA16207)),
    _LedgerColorOption(hex: '#64748B', color: Color(0xFF64748B)),
    _LedgerColorOption(hex: '#0EA5E9', color: Color(0xFF0EA5E9)),
    _LedgerColorOption(hex: '#DC2626', color: Color(0xFFDC2626)),
  ];

  static const List<_LedgerIconOption> _iconOptions = [
    _LedgerIconOption(
      iconName: 'account_balance_wallet_rounded',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _LedgerIconOption(
      iconName: 'storefront_rounded',
      icon: Icons.storefront_rounded,
    ),
    _LedgerIconOption(
      iconName: 'receipt_long_rounded',
      icon: Icons.receipt_long_rounded,
    ),
    _LedgerIconOption(
      iconName: 'savings_rounded',
      icon: Icons.savings_rounded,
    ),
    _LedgerIconOption(
      iconName: 'handshake_rounded',
      icon: Icons.handshake_rounded,
    ),
    _LedgerIconOption(
      iconName: 'work_outline_rounded',
      icon: Icons.work_outline_rounded,
    ),
    _LedgerIconOption(
      iconName: 'shopping_bag_rounded',
      icon: Icons.shopping_bag_rounded,
    ),
    _LedgerIconOption(
      iconName: 'inventory_2_rounded',
      icon: Icons.inventory_2_rounded,
    ),
    _LedgerIconOption(
      iconName: 'trending_up_rounded',
      icon: Icons.trending_up_rounded,
    ),
    _LedgerIconOption(
      iconName: 'payments_rounded',
      icon: Icons.payments_rounded,
    ),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late String _selectedColorHex;
  late String _selectedIconName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ledger.name);
    _nameController.addListener(_handleNameChanged);
    _nameFocusNode = FocusNode();

    final normalizedColor = _normalizeColorHex(widget.ledger.color);
    final colorIndex = _colorOptions.indexWhere(
      (option) => option.normalizedHex == normalizedColor,
    );
    final resolvedColor = colorIndex == -1
        ? _LedgerColorOption(
            hex: _canonicalColorHex(widget.ledger.color),
            color: _parseLedgerColor(
              widget.ledger.color,
              fallback: AppColors.lapis500,
            ),
          )
        : _colorOptions[colorIndex];

    final trimmedIcon = widget.ledger.icon.trim();
    final iconIndex = _iconOptions.indexWhere(
      (option) => option.iconName == trimmedIcon,
    );
    final resolvedIcon = iconIndex == -1
        ? _LedgerIconOption(
            iconName: trimmedIcon,
            icon: _resolveLedgerIcon(widget.ledger.icon, widget.ledger.type),
          )
        : _iconOptions[iconIndex];

    _selectedColorHex = resolvedColor.hex;
    _selectedIconName = resolvedIcon.iconName;
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



  Color get _selectedColor => _parseLedgerColor(
    _selectedColorHex,
    fallback: context.theme.colorScheme.primary,
  );

  IconData get _selectedIcon => _resolveLedgerIcon(
    _selectedIconName,
    widget.ledger.type,
  );

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

    unawaited(HapticService.transactionSaved());

    final updatedLedger = widget.ledger.copyWith(
      name: _nameController.text.trim(),
      color: _selectedColorHex,
      icon: _selectedIconName,
    );

    final result = await ref
        .read(ledgerControllerProvider.notifier)
        .updateLedger(updatedLedger);

    if (!mounted) {
      return;
    }

    result.fold(
      (failure) {
        setState(() {
          _isSubmitting = false;
        });

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
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final borderSubtle = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: Live glyph + Name field — side by side ───────────
            _NameGlyphRow(
              nameController: _nameController,
              nameFocusNode: _nameFocusNode,
              isSubmitting: _isSubmitting,
              selectedColor: _selectedColor,
              selectedIcon: _selectedIcon,
              isDark: isDark,
              fill: fill,
              lapis: lapis,
              inkPrimary: inkPrimary,
              inkMuted: inkMuted,
              borderSubtle: borderSubtle,
              hintText: l10n.ledgerName,
              validationMessage: l10n.nameRequired,
              onSubmitted: (_) => _submit(),
            ),

            const Gap(AppDimensions.spacingMd),

            // ── Row 2: Color palette — inline label + compact rail ──────
            _InlineSectionLabel(
              label: l10n.selectColor,
              inkMuted: inkMuted,
            ),
            const Gap(AppDimensions.spacingXs),
            _ColorSwatchRail(
              options: _effectiveColorOptions(colors.primary),
              selectedHex: _selectedColorHex,
              isDark: isDark,
              onSelected: (hex) {
                if (_selectedColorHex == hex) return;
                setState(() => _selectedColorHex = hex);
                unawaited(HapticService.selection());
              },
            ),

            const Gap(AppDimensions.spacingMd),

            // ── Row 3: Icon grid — inline label + compact wrap ──────────
            _InlineSectionLabel(
              label: l10n.selectIcon,
              inkMuted: inkMuted,
            ),
            const Gap(AppDimensions.spacingXs),
            _IconOptionWrap(
              options: _effectiveIconOptions(),
              selectedIconName: _selectedIconName,
              isDark: isDark,
              onSelected: (iconName) {
                if (_selectedIconName == iconName) return;
                setState(() => _selectedIconName = iconName);
                unawaited(HapticService.selection());
              },
            ),

            const Gap(AppDimensions.spacingMd),

            // ── Row 4: Save CTA — always in thumb reach ─────────────────
            DaftarButton(
              label: l10n.saveChanges,
              icon: Icons.check_rounded,
              isExpanded: true,
              isLoading: _isSubmitting,
              onPressed: _canSave ? _submit : null,
            ),

            const Gap(AppDimensions.spacingXs),
          ],
        ),
      ),
    );
  }

  List<_LedgerColorOption> _effectiveColorOptions(Color fallback) {
    final currentHex = _canonicalColorHex(widget.ledger.color);
    final options = <_LedgerColorOption>[..._colorOptions];
    final exists = options.any(
      (option) => option.normalizedHex == _normalizeColorHex(currentHex),
    );

    if (!exists) {
      options.insert(
        0,
        _LedgerColorOption(
          hex: currentHex,
          color: _parseLedgerColor(widget.ledger.color, fallback: fallback),
        ),
      );
    }

    return options;
  }

  List<_LedgerIconOption> _effectiveIconOptions() {
    final currentIconName = widget.ledger.icon.trim();
    final options = <_LedgerIconOption>[..._iconOptions];
    final exists = options.any((option) => option.iconName == currentIconName);

    if (!exists) {
      options.insert(
        0,
        _LedgerIconOption(
          iconName: currentIconName,
          icon: _resolveLedgerIcon(currentIconName, widget.ledger.type),
        ),
      );
    }

    return options;
  }
}

// ---------------------------------------------------------------------------
// Name + Glyph row — compact, side-by-side with live preview
// ---------------------------------------------------------------------------

/// Compact row: animated glyph on the start edge, name text field filling the
/// rest. The glyph updates live as the merchant picks new colours or icons,
/// giving instant feedback without a separate preview card.
class _NameGlyphRow extends StatelessWidget {
  const _NameGlyphRow({
    required this.nameController,
    required this.nameFocusNode,
    required this.isSubmitting,
    required this.selectedColor,
    required this.selectedIcon,
    required this.isDark,
    required this.fill,
    required this.lapis,
    required this.inkPrimary,
    required this.inkMuted,
    required this.borderSubtle,
    required this.hintText,
    required this.validationMessage,
    required this.onSubmitted,
  });

  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final bool isSubmitting;
  final Color selectedColor;
  final IconData selectedIcon;
  final bool isDark;
  final Color fill;
  final Color lapis;
  final Color inkPrimary;
  final Color inkMuted;
  final Color borderSubtle;
  final String hintText;
  final String validationMessage;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live glyph — animates with colour/icon changes.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            top: AppDimensions.spacingXs,
          ),
          child: _LedgerGlyph(
            color: selectedColor,
            icon: selectedIcon,
            isDark: isDark,
            size: 48,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        // Name field — fills remaining width.
        Expanded(
          child: _CompactNameField(
            controller: nameController,
            focusNode: nameFocusNode,
            enabled: !isSubmitting,
            fill: fill,
            lapis: lapis,
            inkPrimary: inkPrimary,
            inkMuted: inkMuted,
            borderSubtle: borderSubtle,
            hintText: hintText,
            validationMessage: validationMessage,
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compact name field — borderless inside a tinted surface
// ---------------------------------------------------------------------------

class _CompactNameField extends StatefulWidget {
  const _CompactNameField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.fill,
    required this.lapis,
    required this.inkPrimary,
    required this.inkMuted,
    required this.borderSubtle,
    required this.hintText,
    required this.validationMessage,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final Color fill;
  final Color lapis;
  final Color inkPrimary;
  final Color inkMuted;
  final Color borderSubtle;
  final String hintText;
  final String validationMessage;
  final ValueChanged<String> onSubmitted;

  @override
  State<_CompactNameField> createState() => _CompactNameFieldState();
}

class _CompactNameFieldState extends State<_CompactNameField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusNode.hasFocus;

    return AnimatedContainer(
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      height: 52,
      decoration: BoxDecoration(
        color: widget.fill,
        borderRadius: BorderRadius.circular(10),
        border: isFocused
            ? Border.all(color: widget.lapis, width: 1.5)
            : Border.all(color: widget.borderSubtle, width: 0.5),
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        enabled: widget.enabled,
        autofillHints: const [AutofillHints.organizationName],
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: widget.onSubmitted,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return widget.validationMessage;
          }
          return null;
        },
        strutStyle: StrutStyle(
          fontFamily: AppTextStyles.titleSmall.fontFamily,
          fontSize: AppTextStyles.titleSmall.fontSize,
          height: 1,
          leading: 0,
          forceStrutHeight: true,
          fontWeight: FontWeight.w600,
        ),
        style: AppTextStyles.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: widget.inkPrimary,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        decoration: InputDecoration(
          isDense: true,
          visualDensity: VisualDensity.compact,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          hintText: widget.hintText,
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: widget.inkMuted,
            fontWeight: FontWeight.w400,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          contentPadding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.spacingMd,
            14,
            AppDimensions.spacingMd,
            14,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline section label — typography-only, no icon
// ---------------------------------------------------------------------------

class _InlineSectionLabel extends StatelessWidget {
  const _InlineSectionLabel({
    required this.label,
    required this.inkMuted,
  });

  final String label;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: inkMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _ColorSwatchRail extends StatelessWidget {
  const _ColorSwatchRail({
    required this.options,
    required this.selectedHex,
    required this.isDark,
    required this.onSelected,
  });

  final List<_LedgerColorOption> options;
  final String selectedHex;
  final bool isDark;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedNormalized = _normalizeColorHex(selectedHex);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(
          width: AppDimensions.spacingSm,
        ),
        itemBuilder: (context, index) {
          final option = options[index];
          return _ColorSwatch(
            color: option.color,
            hex: option.hex,
            isDark: isDark,
            isSelected: option.normalizedHex == selectedNormalized,
            onTap: () => onSelected(option.hex),
          );
        },
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.hex,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final String hex;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return AnimatedScale(
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      scale: isSelected ? 1.06 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
          child: AnimatedContainer(
            duration: AppDimensions.animationMedium,
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.onSurface.withValues(
                        alpha: isDark ? 0.14 : 0.08,
                      ),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: isSelected
                ? Center(
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: _contrastForeground(color),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Returns white or dark text colour based on luminance of [bg].
  static Color _contrastForeground(Color bg) {
    return bg.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
  }
}

class _IconOptionWrap extends StatelessWidget {
  const _IconOptionWrap({
    required this.options,
    required this.selectedIconName,
    required this.isDark,
    required this.onSelected,
  });

  final List<_LedgerIconOption> options;
  final String selectedIconName;
  final bool isDark;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingSm,
      children: [
        for (final option in options)
          _IconOptionTile(
            icon: option.icon,
            iconName: option.iconName,
            isDark: isDark,
            isSelected: option.iconName == selectedIconName,
            onTap: () => onSelected(option.iconName),
          ),
      ],
    );
  }
}

class _IconOptionTile extends StatelessWidget {
  const _IconOptionTile({
    required this.icon,
    required this.iconName,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String iconName;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final selectedFill = Color.alphaBlend(
      lapis.withValues(alpha: isDark ? 0.12 : 0.08),
      colors.surface,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          width: AppDimensions.minTapTarget,
          height: AppDimensions.minTapTarget,
          decoration: BoxDecoration(
            color: isSelected ? selectedFill : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isSelected
                  ? lapis
                  : colors.onSurface.withValues(
                      alpha: isDark ? 0.10 : 0.06,
                    ),
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? lapis : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerGlyph extends StatelessWidget {
  const _LedgerGlyph({
    required this.color,
    required this.icon,
    required this.isDark,
    required this.size,
  });

  final Color color;
  final IconData icon;
  final bool isDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.22 : 0.16),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.46,
        color: color,
      ),
    );
  }
}

class _LedgerColorOption {
  const _LedgerColorOption({required this.hex, required this.color});

  final String hex;
  final Color color;

  String get normalizedHex => _normalizeColorHex(hex);
}

class _LedgerIconOption {
  const _LedgerIconOption({required this.iconName, required this.icon});

  final String iconName;
  final IconData icon;
}

Color _parseLedgerColor(String value, {required Color fallback}) {
  final normalized = _normalizeColorHex(value);

  try {
    if (normalized.length == 3) {
      final expanded = normalized
          .split('')
          .map((digit) => '$digit$digit')
          .join();
      return Color(int.parse('ff$expanded', radix: 16));
    }

    if (normalized.length == 6) {
      return Color(int.parse('ff$normalized', radix: 16));
    }

    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
  } on FormatException {
    return fallback;
  } on Object {
    return fallback;
  }

  return fallback;
}

String _canonicalColorHex(String value) {
  final normalized = _normalizeColorHex(value);
  return '#$normalized';
}

String _normalizeColorHex(String value) {
  return value.trim().toUpperCase().replaceFirst(RegExp('^(#|0X)'), '');
}

IconData _resolveLedgerIcon(String iconName, LedgerType ledgerType) {
  final normalized = iconName.trim().toLowerCase();

  switch (normalized) {
    case 'customers':
    case 'people':
    case 'people_alt_rounded':
    case 'group_rounded':
      return Icons.people_alt_rounded;
    case 'suppliers':
    case 'local_shipping_rounded':
    case 'delivery_dining_rounded':
      return Icons.local_shipping_rounded;
    case 'personal':
    case 'person_rounded':
    case 'person_outline_rounded':
      return Icons.person_rounded;
    case 'custom':
    case 'folder_special_rounded':
    case 'bookmark_rounded':
      return Icons.folder_special_rounded;
    case 'storefront_rounded':
    case 'store_rounded':
      return Icons.storefront_rounded;
    case 'receipt_long_rounded':
    case 'receipt_rounded':
      return Icons.receipt_long_rounded;
    case 'shopping_bag_rounded':
    case 'shopping_cart_rounded':
      return Icons.shopping_bag_rounded;
    case 'account_balance_wallet_rounded':
    case 'wallet_rounded':
      return Icons.account_balance_wallet_rounded;
    case 'work_outline_rounded':
    case 'business_center_rounded':
      return Icons.work_outline_rounded;
    case 'home_work_rounded':
      return Icons.home_work_rounded;
    case 'savings_rounded':
      return Icons.savings_rounded;
    case 'handshake_rounded':
      return Icons.handshake_rounded;
    case 'inventory_2_rounded':
      return Icons.inventory_2_rounded;
    case 'trending_up_rounded':
      return Icons.trending_up_rounded;
    case 'payments_rounded':
      return Icons.payments_rounded;
    default:
      return _fallbackLedgerIcon(ledgerType);
  }
}

IconData _fallbackLedgerIcon(LedgerType ledgerType) {
  switch (ledgerType) {
    case LedgerType.customers:
      return Icons.people_alt_rounded;
    case LedgerType.suppliers:
      return Icons.local_shipping_rounded;
    case LedgerType.personal:
      return Icons.person_rounded;
    case LedgerType.custom:
      return Icons.folder_special_rounded;
  }
}
