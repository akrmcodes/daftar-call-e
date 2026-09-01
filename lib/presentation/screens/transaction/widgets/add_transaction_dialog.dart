import 'dart:async';
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/grouped_amount_input_formatter.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/entities/item_suggestion.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/transaction_providers.dart';
import 'package:daftar/presentation/shared/currency_creation_policy.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';

import 'package:daftar/presentation/shared/widgets/currency_symbol_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/shared/widgets/read_only_currency_suffix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Displays the Add Transaction dialog for a given contact.
///
/// This is a centered smart dialog with:
/// - **Segmented type control**: Full-width له/عليه pill above the amount
///   field — same pattern as quick-add, with a sliding semantic indicator.
/// - **Hero amount row**: Large tabular numeral input with inline currency chip.
/// - **Keyboard-Immune Flotation**: The dialog insets with `viewInsets.bottom`
///   and the Save button sits outside the `Flexible` scroll zone, always
///   visible above the keyboard.
/// - **Staggered Entrance**: All form sections animate in with
///   `flutter_animate` fade + slide sequence.
/// - All `GroupedAmountInputFormatter` / `CurrencyPrecision` logic is 100%
///   preserved. Switching currency or type never steals focus from the amount
///   field.
Future<bool?> showAddTransactionDialog(
  BuildContext context, {
  required String contactId,
  required String contactName,
  String? defaultCurrency,
  Transaction? existingTransaction,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    transitionDuration: const Duration(milliseconds: 340),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AddTransactionDialog(
        contactId: contactId,
        contactName: contactName,
        defaultCurrency: defaultCurrency ?? DbConstants.currencyYer,
        existingTransaction: existingTransaction,
      );
    },
  );
}

class _AddTransactionDialog extends ConsumerStatefulWidget {
  const _AddTransactionDialog({
    required this.contactId,
    required this.contactName,
    required this.defaultCurrency,
    this.existingTransaction,
  });

  final String contactId;
  final String contactName;
  final String defaultCurrency;
  final Transaction? existingTransaction;

  @override
  ConsumerState<_AddTransactionDialog> createState() =>
      _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<_AddTransactionDialog>
    with SingleTickerProviderStateMixin {
  // ── Constants ────────────────────────────────────────────────────
  static const List<Currency> _currencies = BuiltInCurrencies.all;

  // ── State ────────────────────────────────────────────────────────
  late TransactionType _type;
  late String _selectedCurrencyCode;
  late DateTime _selectedDate;
  late final TextEditingController _amountController;
  late final TextEditingController _itemNameController;
  late final TextEditingController _descriptionController;
  late final FocusNode _amountFocusNode;
  late final FocusNode _itemNameFocusNode;
  late final FocusNode _descriptionFocusNode;
  late final AnimationController _colorAnimController;
  late final Animation<Color?> _accentAnimation;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _type = TransactionType.debt;
    _selectedCurrencyCode = widget.defaultCurrency;
    _selectedDate = DateTime.now();
    _amountController = TextEditingController()
      ..addListener(_onAmountChanged);
    _itemNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _amountFocusNode = FocusNode();
    _itemNameFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();

    final existingTransaction = widget.existingTransaction;
    if (existingTransaction != null) {
      _type = existingTransaction.type;
      _selectedCurrencyCode = existingTransaction.currency;
      _selectedDate = existingTransaction.transactionDate;
      _amountController.text = MoneyUtil.formatMinorUnitsForCode(
        existingTransaction.amount,
        existingTransaction.currency,
      );
      _itemNameController.text = existingTransaction.itemName ?? '';
      _descriptionController.text = existingTransaction.description ?? '';
    }

    _colorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _accentAnimation =
        ColorTween(
          begin: AppColors.debt,
          end: AppColors.payment,
        ).animate(
          CurvedAnimation(
            parent: _colorAnimController,
            curve: Curves.easeInOutCubic,
          ),
        );

    if (_type == TransactionType.payment) {
      _colorAnimController.value = 1.0;
    }

    // Auto-focus amount field after dialog opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    _itemNameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _colorAnimController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Color get _accentColor => _accentAnimation.value ?? AppColors.debt;

  bool get _isEditMode => widget.existingTransaction != null;

  void _onAmountChanged() {
    setState(() {});
  }

  void _setType(TransactionType newType) {
    if (_type == newType) return;
    setState(() => _type = newType);
    if (newType == TransactionType.payment) {
      unawaited(_colorAnimController.forward());
    } else {
      unawaited(_colorAnimController.reverse());
    }
    unawaited(HapticService.toggleFlipped());
    // Re-request focus so the amount field doesn't lose its active state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _amountFocusNode.requestFocus();
    });
  }

  int? _parseAmount() => MoneyUtil.parseMinorUnitsForCode(
        _amountController.text.trim(),
        _selectedCurrencyCode,
      );

  bool get _canSave => _parseAmount() != null && !_isSubmitting;

  Future<void> _submit() async {
    final amount = _parseAmount();
    if (amount == null) return;

    context.unfocus();

    setState(() => _isSubmitting = true);

    final l10n = AppLocalizations.of(context)!;
    final notificationContactName = widget.contactName.trim().isEmpty
        ? widget.contactId
        : widget.contactName.trim();
    final notificationTitle = l10n.notificationWarningTitle;
    final warningNotificationBody = l10n.notificationWarningBody(
      notificationContactName,
    );
    final exceededNotificationBody = l10n.notificationExceededBody(
      notificationContactName,
    );
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final itemName = _itemNameController.text.trim().isEmpty
        ? null
        : _itemNameController.text.trim();
    final controller = ref.read(transactionControllerProvider.notifier);
    final existingTransaction = widget.existingTransaction;

    final settings =
        ref.read(appSettingsProvider).value ?? const AppSettings();
    final currency = existingTransaction == null
        ? effectiveCreationCurrency(settings, _selectedCurrencyCode)
        : _selectedCurrencyCode;

    final result = existingTransaction == null
        ? await controller.addTransaction(
            contactId: widget.contactId,
            type: _type,
            amount: amount,
            currency: currency,
            description: description,
            itemName: itemName,
            transactionDate: _selectedDate,
            warningNotificationTitle: notificationTitle,
            warningNotificationBody: warningNotificationBody,
            exceededNotificationBody: exceededNotificationBody,
          )
        : await controller.updateTransaction(
            transactionId: existingTransaction.id,
            type: _type,
            amount: amount,
            currency: currency,
            description: description,
            itemName: itemName,
            transactionDate: _selectedDate,
            warningNotificationTitle: notificationTitle,
            warningNotificationBody: warningNotificationBody,
            exceededNotificationBody: exceededNotificationBody,
          );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isSubmitting = false);
        unawaited(AppBottomSheet.showError(context, error: failure));
      },
      (saveResult) {
        unawaited(HapticService.transactionSaved());
        final messenger = ScaffoldMessenger.of(context);
        final isDark = context.theme.brightness == Brightness.dark;

        Navigator.of(context).pop();

        if (saveResult.warningLevel == CreditWarningLevel.warning) {
          _showCreditLimitSnackBar(
            messenger: messenger,
            message: l10n.creditLimitWarning,
            accentColor: AppColors.warning,
            icon: Icons.warning_amber_rounded,
            isDark: isDark,
          );
        } else if (saveResult.warningLevel == CreditWarningLevel.exceeded) {
          _showCreditLimitSnackBar(
            messenger: messenger,
            message: l10n.creditLimitExceeded,
            accentColor: AppColors.error,
            icon: Icons.error_rounded,
            isDark: isDark,
          );
        }
      },
    );
  }

  void _showCreditLimitSnackBar({
    required ScaffoldMessengerState messenger,
    required String message,
    required Color accentColor,
    required IconData icon,
    required bool isDark,
  }) {
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2 : AppColors.surface1Light,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.34 : 0.24),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingMd,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: Text(
                      message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  void _onSuggestionSelected(ItemSuggestion suggestion) {
    _itemNameController.text = suggestion.itemName;

    // Auto-fill amount from recent price if the amount field is empty.
    if (suggestion.lastAmount != null &&
        _amountController.text.trim().isEmpty) {
      _amountController.text = MoneyUtil.formatMinorUnitsForCode(
        suggestion.lastAmount!,
        _selectedCurrencyCode,
      );
    }

    _itemNameFocusNode.unfocus();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
      builder: (context, child) {
        final isDark = context.theme.brightness == Brightness.dark;
        return Theme(
          data: context.theme.copyWith(
            colorScheme: context.colorScheme.copyWith(
              primary: _accentColor,
              surface: isDark ? AppColors.surface2 : AppColors.surface1Light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selectedDate = result);
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final isDark = theme.brightness == Brightness.dark;
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();
    final allowCurrencyChange = settings.isMultiCurrencyEnabled;

    return AnimatedBuilder(
      animation: _colorAnimController,
      builder: (context, _) {
        return Center(
          child: Padding(
            // viewInsets.bottom ensures the dialog floats above the keyboard
            // without any user interaction needed.
            padding: EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH + 4,
              MediaQuery.paddingOf(context).top + 24,
              AppDimensions.pagePaddingH + 4,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surface2
                      : AppColors.surface1Light,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(
                    color: _accentColor.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(
                        alpha: isDark ? 0.08 : 0.06,
                      ),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.32 : 0.08,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Scrollable form body ─────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppDimensions.spacingXl,
                          AppDimensions.spacingLg,
                          AppDimensions.spacingXl,
                          AppDimensions.spacingMd,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Title ────────────────────────────
                            Center(
                              child: Text(
                                _isEditMode
                                    ? l10n.editTransaction
                                    : l10n.addTransaction,
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(
                                  duration: 260.ms,
                                  curve: Curves.easeOut,
                                )
                                .slideY(
                                  begin: -0.08,
                                  end: 0,
                                  duration: 260.ms,
                                  curve: Curves.easeOut,
                                ),

                            const SizedBox(height: AppDimensions.spacingMd),

                            // ── ❶ Type toggle + Amount + Currency ───────────
                            _AmountSection(
                              amountController: _amountController,
                              amountFocusNode: _amountFocusNode,
                              type: _type,
                              accentColor: _accentColor,
                              currencies: _currencies,
                              selectedCurrencyCode: _selectedCurrencyCode,
                              allowCurrencyChange: allowCurrencyChange,
                              enabled: !_isSubmitting,
                              onTypeChanged: _setType,
                              onCurrencyChanged: (code) {
                                setState(() {
                                  final existingMinor =
                                      MoneyUtil.parseMinorUnitsForCode(
                                    _amountController.text.trim(),
                                    _selectedCurrencyCode,
                                  );
                                  _selectedCurrencyCode = code;
                                  if (existingMinor != null) {
                                    _amountController.text =
                                        MoneyUtil.formatMinorUnitsForCode(
                                      existingMinor,
                                      code,
                                    );
                                  }
                                });
                                // Preserve focus after currency switch.
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) _amountFocusNode.requestFocus();
                                });
                              },
                              onSubmitted: () {
                                _itemNameFocusNode.requestFocus();
                              },
                            )
                                .animate()
                                .fadeIn(
                                  delay: 60.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 60.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                ),

                            const SizedBox(height: AppDimensions.spacingSm),

                            // ── ❷ Item Name with Autocomplete ────
                            _ItemNameAutocomplete(
                              controller: _itemNameController,
                              focusNode: _itemNameFocusNode,
                              selectedCurrencyCode: _selectedCurrencyCode,
                              enabled: !_isSubmitting,
                              onSuggestionSelected: _onSuggestionSelected,
                              onSubmitted: () {
                                _descriptionFocusNode.requestFocus();
                              },
                            )
                                .animate()
                                .fadeIn(
                                  delay: 120.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 120.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                ),

                            const SizedBox(height: AppDimensions.spacingSm),

                            // ── ❸ Date Row (compact chip) ─────────
                            _DateRow(
                              selectedDate: _selectedDate,
                              accentColor: _accentColor,
                              enabled: !_isSubmitting,
                              onTap: _pickDate,
                            )
                                .animate()
                                .fadeIn(
                                  delay: 180.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 180.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                ),

                            const SizedBox(height: AppDimensions.spacingSm),

                            // ── ❹ Description (optional, compact) ─
                            _DescriptionInput(
                              controller: _descriptionController,
                              focusNode: _descriptionFocusNode,
                              enabled: !_isSubmitting,
                            )
                                .animate()
                                .fadeIn(
                                  delay: 240.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                )
                                .slideY(
                                  begin: 0.06,
                                  end: 0,
                                  delay: 240.ms,
                                  duration: 280.ms,
                                  curve: Curves.easeOut,
                                ),
                          ],
                        ),
                      ),
                    ),

                    // ── Save CTA — ALWAYS visible, outside scroll zone ──
                    // Sits between the form body and the dialog's bottom edge.
                    // Because it is outside the Flexible, it is immune to
                    // keyboard pop-up: it merely compresses the scroll area.
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppDimensions.spacingXl,
                        AppDimensions.spacingXs,
                        AppDimensions.spacingXl,
                        AppDimensions.spacingLg,
                      ),
                      child: _SaveButton(
                        accentColor: _accentColor,
                        canSave: _canSave,
                        isSubmitting: _isSubmitting,
                        label: _isEditMode
                            ? l10n.saveChanges
                            : l10n.saveTransaction,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ── AMOUNT SECTION ─────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════

/// Type toggle + hero amount input.
///
/// Layout:
///  ┌─────────────────────────────────────────────────────────────┐
///  │  [ عليه ▲  |  له ▼ ]   ← full-width segmented pill         │
///  └─────────────────────────────────────────────────────────────┘
///  ┌─────────────────────────────────────────────────────────────┐
///  │  [  hero amount input  ]              [Currency chip ▼]      │
///  └─────────────────────────────────────────────────────────────┘
///
/// The toggle sits above the amount card so each control has clear
/// visual hierarchy. Type changes re-request [amountFocusNode] focus.
class _AmountSection extends StatelessWidget {
  const _AmountSection({
    required this.amountController,
    required this.amountFocusNode,
    required this.type,
    required this.accentColor,
    required this.currencies,
    required this.selectedCurrencyCode,
    required this.allowCurrencyChange,
    required this.enabled,
    required this.onTypeChanged,
    required this.onCurrencyChanged,
    required this.onSubmitted,
  });

  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final TransactionType type;
  final Color accentColor;
  final List<Currency> currencies;
  final String selectedCurrencyCode;
  final bool allowCurrencyChange;
  final bool enabled;
  final ValueChanged<TransactionType> onTypeChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;

    final selectedCurrency = currencies.firstWhere(
      (c) => c.code == selectedCurrencyCode,
      orElse: () => currencies.first,
    );
    final decimalPlaces = selectedCurrency.decimalPlaces;
    final allowsDecimal = CurrencyPrecision.allowsFractionalInput(
      selectedCurrencyCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TransactionTypeToggle(
          type: type,
          enabled: enabled,
          onTypeChanged: onTypeChanged,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppDimensions.spacingLg,
            AppDimensions.spacingMd,
            AppDimensions.spacingLg,
            AppDimensions.spacingMd,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface3 : AppColors.surface2Light,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.22 : 0.16),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: TextField(
                    controller: amountController,
                    focusNode: amountFocusNode,
                    enabled: enabled,
                    autofocus: true,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: allowsDecimal,
                    ),
                    textDirection: ui.TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      GroupedAmountInputFormatter(
                        allowDecimal: allowsDecimal,
                        maxFractionDigits: decimalPlaces,
                      ),
                    ],
                    style: TextStyle(
                      fontFamily: AppTextStyles.latinFontFamily,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      height: 1.1,
                      letterSpacing: -0.5,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                        FontFeature.liningFigures(),
                      ],
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontFamily: AppTextStyles.latinFontFamily,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: (isDark
                                ? AppColors.inkMuted
                                : AppColors.inkMutedLight)
                            .withValues(alpha: 0.4),
                        height: 1.1,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSubmitted(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              if (allowCurrencyChange)
                _CurrencyChip(
                  currencies: currencies,
                  selectedCurrencyCode: selectedCurrencyCode,
                  accentColor: accentColor,
                  isDark: isDark,
                  enabled: enabled,
                  onCurrencyChanged: onCurrencyChanged,
                )
              else
                ReadOnlyCurrencySuffix(
                  currencyCode: selectedCurrencyCode,
                  currencies: currencies,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-width segmented pill — debt on start, payment on end.
///
/// Uses a sliding semantic indicator (same pattern as quick-add) instead of
/// a cramped vertical stack beside the amount field.
class _TransactionTypeToggle extends StatelessWidget {
  const _TransactionTypeToggle({
    required this.type,
    required this.enabled,
    required this.onTypeChanged,
  });

  final TransactionType type;
  final bool enabled;
  final ValueChanged<TransactionType> onTypeChanged;

  static const double _height = AppDimensions.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final trackColor = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final isDebt = type == TransactionType.debt;

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
          width: 0.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = constraints.maxWidth / 2;

          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: AppDimensions.animationMedium,
                curve: Curves.easeOutCubic,
                start: isDebt ? 2 : halfWidth,
                top: 2,
                bottom: 2,
                width: halfWidth - 2,
                child: AnimatedContainer(
                  duration: AppDimensions.animationMedium,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: (isDebt ? AppColors.debt : AppColors.payment)
                        .withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusLg - 2,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _TypeToggleSegment(
                      label: l10n.debt,
                      icon: Icons.arrow_upward_rounded,
                      isSelected: isDebt,
                      color: AppColors.debt,
                      enabled: enabled,
                      onTap: () => onTypeChanged(TransactionType.debt),
                    ),
                  ),
                  Expanded(
                    child: _TypeToggleSegment(
                      label: l10n.payment,
                      icon: Icons.arrow_downward_rounded,
                      isSelected: !isDebt,
                      color: isDark ? AppColors.payment : AppColors.paymentLight,
                      enabled: enabled,
                      onTap: () => onTypeChanged(TransactionType.payment),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeToggleSegment extends StatelessWidget {
  const _TypeToggleSegment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final textColor = isSelected ? color : muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        height: _TransactionTypeToggle._height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: AppDimensions.animationFast,
              style: AppTextStyles.labelSmall.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Currency chip for the fusion block's trailing area.
///
/// Tapping opens a contextual currency picker via [showMenu].
/// Focus is intentionally NOT taken by the chip — it is managed by the
/// parent via a post-frame callback on the amount FocusNode.
class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.currencies,
    required this.selectedCurrencyCode,
    required this.accentColor,
    required this.isDark,
    required this.enabled,
    required this.onCurrencyChanged,
  });

  final List<Currency> currencies;
  final String selectedCurrencyCode;
  final Color accentColor;
  final bool isDark;
  final bool enabled;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = currencies.firstWhere(
      (c) => c.code == selectedCurrencyCode,
      orElse: () => currencies.first,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _showCurrencyMenu(context) : null,
      child: DaftarTapTarget(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.28 : 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CurrencySymbolMark(
                currencyCode: selectedCurrency.code,
                symbol: selectedCurrency.symbol,
                color: accentColor,
                height: 13,
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyMenu(BuildContext context) {
    final renderBox = context.findRenderObject()! as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    unawaited(
      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          offset.dx,
          offset.dy + renderBox.size.height + 4,
          offset.dx + renderBox.size.width,
          0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        items: currencies.map((c) {
          return PopupMenuItem<String>(
            value: c.code,
            child: Row(
              children: [
                CurrencySymbolMark(
                  currencyCode: c.code,
                  symbol: c.symbol,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.inkPrimary
                      : AppColors.inkPrimaryLight,
                ),
                const SizedBox(width: 8),
                Text(
                  c.code,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontFamily: AppTextStyles.latinFontFamily,
                  ),
                ),
                if (c.code == selectedCurrencyCode) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ],
            ),
          );
        }).toList(),
      ).then((code) {
        if (code != null) {
          onCurrencyChanged(code);
        }
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ── SECONDARY FIELDS ───────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════

/// Item name field with smart autocomplete and premium dropdown overlay.
class _ItemNameAutocomplete extends ConsumerWidget {
  const _ItemNameAutocomplete({
    required this.controller,
    required this.focusNode,
    required this.selectedCurrencyCode,
    required this.enabled,
    required this.onSuggestionSelected,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String selectedCurrencyCode;
  final bool enabled;
  final ValueChanged<ItemSuggestion> onSuggestionSelected;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final colors = context.colorScheme;
    final fillColor = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final borderColor =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final labelColor =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final primary = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return Autocomplete<ItemSuggestion>(
      fieldViewBuilder: (context, textController, fieldFocusNode, onSubmit) {
        // Sync our external controller with autocomplete's internal one.
        textController.text = controller.text;
        controller.addListener(() {
          if (textController.text != controller.text) {
            textController.text = controller.text;
          }
        });
        textController.addListener(() {
          if (controller.text != textController.text) {
            controller.text = textController.text;
          }
        });

        return TextField(
          controller: textController,
          focusNode: fieldFocusNode,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            labelText: l10n.itemName,
            labelStyle: AppTextStyles.bodySmall.copyWith(
              color: labelColor,
            ),
            filled: true,
            fillColor: fillColor,
            prefixIcon: Icon(
              Icons.inventory_2_outlined,
              color: labelColor,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingMd,
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
              borderSide: BorderSide(color: primary, width: 1.3),
            ),
          ),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.length < 2) return const [];

        final result = await ref.read(
          autocompleteSuggestionsProvider(query).future,
        );

        return result.fold(
          (_) => const <ItemSuggestion>[],
          (suggestions) => suggestions,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              color: isDark ? AppColors.surface3 : AppColors.surface1Light,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final suggestion = options.elementAt(index);
                    return InkWell(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      onTap: () {
                        onSelected(suggestion);
                        onSuggestionSelected(suggestion);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingLg,
                          vertical: AppDimensions.spacingMd,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: labelColor,
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: Text(
                                suggestion.itemName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            if (suggestion.lastAmount != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                MoneyUtil.formatMinorUnitsForCode(
                                  suggestion.lastAmount!,
                                  selectedCurrencyCode,
                                ),
                                style: AppTextStyles.amountSmall.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      displayStringForOption: (suggestion) => suggestion.itemName,
    );
  }
}

/// Compact date chip — full-width tappable row.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.selectedDate,
    required this.accentColor,
    required this.enabled,
    required this.onTap,
  });

  final DateTime selectedDate;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final onSurface =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final borderColor =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final dateFormat = DateFormat.yMMMd(AppConstants.numeralLocale);
    final dateText = isToday ? l10n.today : dateFormat.format(selectedDate);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppDimensions.minTapTarget,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingMd,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface3 : AppColors.surface2Light,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: mutedColor,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                l10n.date,
                style: AppTextStyles.bodySmall.copyWith(
                  color: mutedColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: isDark ? 0.12 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusCircular,
                  ),
                ),
                child: Text(
                  dateText,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optional description text field — compact single-line by default.
class _DescriptionInput extends StatelessWidget {
  const _DescriptionInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final colors = context.colorScheme;
    final fillColor = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final borderColor =
        isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final labelColor =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final primary = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      style: AppTextStyles.bodyMedium.copyWith(
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        labelText: l10n.descriptionOptional,
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: labelColor,
        ),
        filled: true,
        fillColor: fillColor,
        prefixIcon: Icon(
          Icons.notes_rounded,
          color: labelColor,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: AppDimensions.spacingMd,
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
          borderSide: BorderSide(color: primary, width: 1.3),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ── SAVE BUTTON ────────────────────────────────────────────────────
// ════════════════════════════════════════════════════════════════════

/// Full-width save CTA.
///
/// Uses the semantic accent color (debt red / payment green) as a glow halo
/// (Lapis Lux compliant — color appears as glow shadow, not fill).
/// The fill itself is the monochrome surface2 / surface1Light, matching the
/// DaftarButton primary spec.
class _SaveButton extends StatefulWidget {
  const _SaveButton({
    required this.accentColor,
    required this.canSave,
    required this.isSubmitting,
    required this.label,
    required this.onPressed,
  });

  final Color accentColor;
  final bool canSave;
  final bool isSubmitting;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;

    final fillColor = isDark ? AppColors.surface2 : AppColors.surface1Light;
    final textColor = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return GestureDetector(
      onTapDown: widget.canSave ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.canSave ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          widget.canSave ? () => setState(() => _pressed = false) : null,
      onTap: widget.canSave
          ? () {
              unawaited(HapticService.buttonPress());
              widget.onPressed();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed && widget.canSave ? 0.97 : 1.0,
        duration: AppDimensions.animationFast,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: AppDimensions.comfortableTapTarget,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: widget.canSave
                  ? widget.accentColor.withValues(
                      alpha: isDark ? 0.55 : 0.45,
                    )
                  : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
              width: 0.5,
            ),
            boxShadow: widget.canSave
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(
                        alpha: isDark ? 0.24 : 0.18,
                      ),
                      blurRadius: _pressed ? 8 : 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          alignment: Alignment.center,
          child: widget.isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.accentColor,
                  ),
                )
              : Text(
                  widget.label,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: widget.canSave
                        ? textColor
                        : (isDark
                            ? AppColors.inkMuted
                            : AppColors.inkMutedLight),
                  ),
                ),
        ),
      ),
    );
  }
}
