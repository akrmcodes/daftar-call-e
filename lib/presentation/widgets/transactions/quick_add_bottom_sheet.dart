import 'dart:async' show unawaited;

import 'package:daftar/app/router/app_router.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/transaction/quick_add_state.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/csv_parser.dart';
import 'package:daftar/core/utils/grouped_amount_input_formatter.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/providers/quick_add_controller.dart';
import 'package:daftar/presentation/providers/transaction_providers.dart';
import 'package:daftar/presentation/screens/contact/credit_limit_b_trigger.dart';
import 'package:daftar/presentation/shared/currency_creation_policy.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/currency_selector.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:daftar/presentation/widgets/transactions/quick_add_no_ledger_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

// ---------------------------------------------------------------------------
// Layout constants — hand-tuned for the density target.
// ---------------------------------------------------------------------------

/// Height of the debt/payment segmented toggle pill.
const double _kToggleHeight = 38;

/// Height of the name+amount input surface.
const double _kInputRowHeight = 52;

/// Corner radius for all input surfaces in this sheet.
const double _kInputRadius = 10;

/// The fraction of the row width given to the name field.
const int _kNameFlex = 3;

/// The fraction of the row width given to the amount field.
const int _kAmountFlex = 2;

/// Symmetric vertical padding for a fixed 52dp input surface.
///
/// Collapsed input decorations ignore vertical alignment; padding is explicit.
EdgeInsetsDirectional _quickAddSymmetricFieldPadding({
  required double fontSize,
  double lineHeightFactor = 1,
}) {
  final lineExtent = fontSize * lineHeightFactor;
  final vertical =
      ((_kInputRowHeight - lineExtent) / 2).clamp(0.0, _kInputRowHeight / 2);
  return EdgeInsetsDirectional.fromSTEB(
    AppDimensions.spacingMd,
    vertical,
    AppDimensions.spacingMd,
    vertical,
  );
}

StrutStyle _quickAddFieldStrutStyle({
  required double fontSize,
  String? fontFamily,
  FontWeight? fontWeight,
}) {
  return StrutStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    height: 1,
    leading: 0,
    forceStrutHeight: true,
    fontWeight: fontWeight,
  );
}

InputDecoration _quickAddFieldDecoration({
  required String hintText,
  required TextStyle hintStyle,
  required double fontSize,
  double lineHeightFactor = 1,
  TextDirection? hintTextDirection,
}) {
  return InputDecoration(
    isDense: true,
    visualDensity: VisualDensity.compact,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: false,
    hintText: hintText,
    hintStyle: hintStyle,
    hintTextDirection: hintTextDirection,
    contentPadding: _quickAddSymmetricFieldPadding(
      fontSize: fontSize,
      lineHeightFactor: lineHeightFactor,
    ),
  );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Presents the quick-add transaction bottom sheet (center FAB entry point).
Future<bool?> showQuickAddBottomSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);

  var ledgers = container.read(ledgersProvider).value;
  if (ledgers == null) {
    try {
      ledgers = await container.read(ledgersProvider.future);
    } on Object {
      ledgers = null;
    }
  }

  if (!context.mounted) {
    return null;
  }

  if (ledgers != null && ledgers.isEmpty) {
    final ready = await QuickAddNoLedgerSheet.show(context);
    if (!ready || !context.mounted) {
      return null;
    }
  }

  if (!context.mounted) {
    return null;
  }

  container.read(quickAddControllerProvider.notifier).reset();
  final l10n = AppLocalizations.of(context)!;

  return AppBottomSheet.show<bool>(
    context,
    title: l10n.quickAddTitle,
    maxHeightFactor: 0.94,
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppDimensions.pagePaddingH,
      AppDimensions.spacingXs,
      AppDimensions.pagePaddingH,
      AppDimensions.spacingMd,
    ),
    child: const QuickAddBottomSheetBody(),
  ).whenComplete(() {
    container.read(quickAddControllerProvider.notifier).reset();
  });
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

/// Form body for [showQuickAddBottomSheet].
class QuickAddBottomSheetBody extends ConsumerStatefulWidget {
  const QuickAddBottomSheetBody({super.key});

  @override
  ConsumerState<QuickAddBottomSheetBody> createState() =>
      _QuickAddBottomSheetBodyState();
}

class _QuickAddBottomSheetBodyState
    extends ConsumerState<QuickAddBottomSheetBody> {
  static const List<Currency> _currencies = BuiltInCurrencies.all;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _nameFocusNode.dispose();
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _onSuggestionSelected(Contact match) {
    final name = match.name;
    _nameController.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    ref.read(quickAddControllerProvider.notifier).selectSuggestedContact(match);
  }

  bool _canSave(QuickAddState state) {
    final name = state.nameQuery.trim();
    if (name.isEmpty) {
      return false;
    }
    final amount = state.amountMinorUnits;
    if (amount == null || amount <= 0) {
      return false;
    }
    if (state.selectedLedgerId == null) {
      return false;
    }
    return !_isSubmitting;
  }

  String _amountCurrencyCode(QuickAddState state, AppSettings settings) {
    if (settings.isMultiCurrencyEnabled) {
      return state.selectedCurrencyCode;
    }
    return settings.defaultCurrency;
  }

  void _onAmountChanged(String value, String currencyCode) {
    final minor = CsvParserUtil.parseAmountToMinorUnits(value, currencyCode);
    ref.read(quickAddControllerProvider.notifier).setAmountMinorUnits(minor);
  }

  Future<void> _submit() async {
    final state = ref.read(quickAddControllerProvider);
    if (!_canSave(state)) {
      return;
    }

    final amount = state.amountMinorUnits!;
    final ledgerId = state.selectedLedgerId!;
    final name = state.nameQuery.trim();

    context.unfocus();
    setState(() => _isSubmitting = true);

    final contactId = await _resolveContactId(state, ledgerId, name);
    if (!mounted) {
      return;
    }
    if (contactId == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final itemName = state.note.trim().isEmpty ? null : state.note.trim();
    final settings =
        ref.read(appSettingsProvider).value ?? const AppSettings();
    final currency = effectiveCreationCurrency(
      settings,
      _amountCurrencyCode(state, settings),
    );

    final result = await ref.read(transactionControllerProvider.notifier).addTransaction(
          contactId: contactId,
          type: state.transactionType,
          amount: amount,
          currency: currency,
          itemName: itemName,
          warningNotificationTitle: l10n.notificationWarningTitle,
          warningNotificationBody: l10n.notificationWarningBody(name),
          exceededNotificationBody: l10n.notificationExceededBody(name),
        );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    await result.fold(
      (failure) async {
        await DaftarErrorSheet.showForError(context, error: failure);
      },
      (saveResult) async {
        unawaited(HapticService.transactionSaved());
        final overlayContext =
            rootNavigatorKey.currentContext ??
            Navigator.of(context, rootNavigator: true).context;
        if (context.mounted) {
          Navigator.of(context).pop(true);
        }
        if (saveResult.warningLevel == CreditWarningLevel.exceeded &&
            state.transactionType == TransactionType.debt) {
          final shown = await CreditLimitBTrigger.offerAfterDebtSave(
            context: overlayContext,
            ref: ref,
            contactId: contactId,
            type: state.transactionType,
            warningLevel: saveResult.warningLevel,
          );
          if (!shown && mounted) {
            final contact = await ref
                .read(contactByIdProvider(contactId).future)
                .then((result) => result.fold((_) => null, (c) => c));
            final policy = ref.read(calleDevicePolicyProvider);
            if (!mounted) {
              return;
            }
            if (contact != null &&
                !CreditLimitBTrigger.isCallPromptEligible(contact, policy)) {
              final host = rootNavigatorKey.currentContext ?? overlayContext;
              if (!host.mounted) {
                return;
              }
              final messenger = ScaffoldMessenger.of(host);
              final isDark = Theme.of(host).brightness == Brightness.dark;
              _showCreditLimitExceededSnackBar(
                messenger: messenger,
                message: l10n.creditLimitExceeded,
                isDark: isDark,
              );
            }
          }
        }
      },
    );
  }

  Future<String?> _resolveContactId(
    QuickAddState state,
    String ledgerId,
    String name,
  ) async {
    final selectedId = state.selectedContactId;
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId;
    }

    switch (state.accountResolution) {
      case QuickAddAccountResolution.singleLedgerAuto:
        final existing = _contactForLedger(state.matchedContacts, ledgerId);
        if (existing != null) {
          return existing.id;
        }
        return _createContact(ledgerId, name);
      case QuickAddAccountResolution.multiLedgerPick:
        final existing = _contactForLedger(state.matchedContacts, ledgerId);
        if (existing != null) {
          return existing.id;
        }
        return null;
      case QuickAddAccountResolution.newAccount:
        return _createContact(ledgerId, name);
      case QuickAddAccountResolution.idle:
        if (state.matchedContacts.isEmpty) {
          return _createContact(ledgerId, name);
        }
        final existing = _contactForLedger(state.matchedContacts, ledgerId);
        return existing?.id ?? _createContact(ledgerId, name);
    }
  }

  Contact? _contactForLedger(List<Contact> contacts, String ledgerId) {
    for (final contact in contacts) {
      if (contact.ledgerId == ledgerId) {
        return contact;
      }
    }
    return null;
  }

  Future<String?> _createContact(String ledgerId, String name) async {
    final result = await ref
        .read(contactControllerProvider.notifier)
        .createContact(ledgerId: ledgerId, name: name);

    if (!mounted) {
      return null;
    }

    return result.fold(
      (failure) {
        unawaited(DaftarErrorSheet.showForError(context, error: failure));
        return null;
      },
      (contact) => contact.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(quickAddControllerProvider);
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();
    final isMultiCurrency = settings.isMultiCurrencyEnabled;
    final amountCurrencyCode = _amountCurrencyCode(state, settings);
    final canSave = _canSave(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row 1: Debt / Payment toggle pill ──────────────────────────────
        _QuickAddTogglePill(
          isCredit: state.isCredit,
          onChanged: (isCredit) {
            unawaited(HapticService.toggleFlipped());
            ref
                .read(quickAddControllerProvider.notifier)
                .setIsCredit(isCredit: isCredit);
          },
        ),

        const Gap(AppDimensions.spacingSm),

        // ── Row 2: Name | Amount — side-by-side ────────────────────────────
        _QuickAddDualInputRow(
          nameController: _nameController,
          amountController: _amountController,
          nameFocusNode: _nameFocusNode,
          amountFocusNode: _amountFocusNode,
          isDebt: !state.isCredit,
          isSearching: state.isSearchingName,
          showNewBadge: state.isNewAccount,
          amountCurrencyCode: amountCurrencyCode,
          onNameChanged: (v) =>
              ref.read(quickAddControllerProvider.notifier).onNameChanged(v),
          onAmountChanged: (v) => _onAmountChanged(v, amountCurrencyCode),
          onAmountSubmitted: (_) => _noteFocusNode.requestFocus(),
          l10n: l10n,
        ),

        if (isMultiCurrency) ...[
          const Gap(AppDimensions.spacingSm),
          CurrencySelector(
            currencies: _currencies,
            selectedCurrencyCode: state.selectedCurrencyCode,
            enabled: !_isSubmitting,
            onChanged: (currency) {
              final currentMinor =
                  ref.read(quickAddControllerProvider).amountMinorUnits;
              ref
                  .read(quickAddControllerProvider.notifier)
                  .setSelectedCurrencyCode(currency.code);
              if (currentMinor != null) {
                _amountController.text = MoneyUtil.formatMinorUnitsForCode(
                  currentMinor,
                  currency.code,
                );
              }
            },
          ),
        ],

        // ── Row 3: Contact autocomplete strip (collapses when empty) ────────
        _QuickAddContactSuggestions(
          onSuggestionSelected: _onSuggestionSelected,
        ),

        // ── Row 4: Ledger reaction zone (collapses when idle) ───────────────
        const _QuickAddLedgerReactionZone(),

        const Gap(AppDimensions.spacingSm),

        // ── Row 5: Note — icon-prefixed inline strip ────────────────────────
        _QuickAddNoteField(
          controller: _noteController,
          focusNode: _noteFocusNode,
          hint: l10n.itemName,
          onChanged: (v) =>
              ref.read(quickAddControllerProvider.notifier).setNote(v),
          onSubmitted: (_) {
            if (canSave) {
              unawaited(_submit());
            }
          },
        ),

        const Gap(AppDimensions.spacingSm),

        // ── Row 6: Save CTA ─────────────────────────────────────────────────
        DaftarButton(
          label: l10n.saveTransaction,
          isExpanded: true,
          isLoading: _isSubmitting,
          onPressed: canSave ? _submit : null,
        ),

        const Gap(AppDimensions.spacingXs),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dual input row — Name (flex 3) + Amount (flex 2) sharing a single row
// ---------------------------------------------------------------------------

/// A single horizontal row that hosts the name and amount fields side by side.
///
/// The name field uses a flex ratio of [_kNameFlex]:
/// the amount field uses [_kAmountFlex].
/// Both fields share the same visual surface height ([_kInputRowHeight]).
class _QuickAddDualInputRow extends StatelessWidget {
  const _QuickAddDualInputRow({
    required this.nameController,
    required this.amountController,
    required this.nameFocusNode,
    required this.amountFocusNode,
    required this.isDebt,
    required this.isSearching,
    required this.showNewBadge,
    required this.amountCurrencyCode,
    required this.onNameChanged,
    required this.onAmountChanged,
    required this.onAmountSubmitted,
    required this.l10n,
  });

  final TextEditingController nameController;
  final TextEditingController amountController;
  final FocusNode nameFocusNode;
  final FocusNode amountFocusNode;
  final bool isDebt;
  final bool isSearching;
  final bool showNewBadge;
  final String amountCurrencyCode;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onAmountSubmitted;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "New account" badge — floats above the row when active.
        AnimatedSize(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showNewBadge
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppDimensions.spacingXs,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _QuickAddNewAccountBadge(
                      label: l10n.quickAddNewAccountBadge,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Row(
          children: [
            // Name field — wider portion.
            Expanded(
              flex: _kNameFlex,
              child: _QuickAddSingleSurfaceField(
                controller: nameController,
                focusNode: nameFocusNode,
                hint: l10n.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: onNameChanged,
                trailingWidget: isSearching
                    ? const Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: AppDimensions.spacingMd,
                        ),
                        child: CupertinoActivityIndicator(radius: 8),
                      )
                    : null,
              ),
            ),

            const Gap(AppDimensions.spacingSm),

            // Amount field — narrower portion with semantic colour cue.
            Expanded(
              flex: _kAmountFlex,
              child: _QuickAddAmountField(
                controller: amountController,
                focusNode: amountFocusNode,
                isDebt: isDebt,
                hint: l10n.amount,
                currencyCode: amountCurrencyCode,
                onChanged: onAmountChanged,
                onSubmitted: onAmountSubmitted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single-surface field — no separate label row, hint-only
// ---------------------------------------------------------------------------

/// A compact text field with a single filled surface and an inline hint.
/// The label is embedded as a hint — typography hierarchy is established by
/// font weight contrast (hint = w400 muted, input = w600 primary).
class _QuickAddSingleSurfaceField extends StatefulWidget {
  const _QuickAddSingleSurfaceField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.trailingWidget,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  /// Optional widget shown at the end of the surface (e.g. spinner).
  final Widget? trailingWidget;

  @override
  State<_QuickAddSingleSurfaceField> createState() =>
      _QuickAddSingleSurfaceFieldState();
}

class _QuickAddSingleSurfaceFieldState
    extends State<_QuickAddSingleSurfaceField> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final isFocused = widget.focusNode.hasFocus;

    return AnimatedContainer(
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      height: _kInputRowHeight,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_kInputRadius),
        border: isFocused
            ? Border.all(color: lapis, width: 1.5)
            : Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: 0.5,
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              strutStyle: _quickAddFieldStrutStyle(
                fontSize: AppTextStyles.titleSmall.fontSize!,
                fontFamily: AppTextStyles.titleSmall.fontFamily,
                fontWeight: FontWeight.w600,
              ),
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: inkPrimary,
                height: 1,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              decoration: _quickAddFieldDecoration(
                hintText: widget.hint,
                fontSize: AppTextStyles.titleSmall.fontSize!,
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: inkMuted,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (widget.trailingWidget != null) widget.trailingWidget!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount field — numeric, with semantic tint on the hint label
// ---------------------------------------------------------------------------

/// Amount field with semantic tint and tabular-figure input style.
class _QuickAddAmountField extends StatefulWidget {
  const _QuickAddAmountField({
    required this.controller,
    required this.focusNode,
    required this.isDebt,
    required this.hint,
    required this.currencyCode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDebt;
  final String hint;
  final String currencyCode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_QuickAddAmountField> createState() => _QuickAddAmountFieldState();
}

class _QuickAddAmountFieldState extends State<_QuickAddAmountField> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final isFocused = widget.focusNode.hasFocus;

    // Semantic amount colour — ruby for عليه, emerald for له.
    final semanticColor =
        widget.isDebt ? AppColors.debt : AppColors.payment;
    final decimalPlaces = CurrencyPrecision.decimalPlacesForCode(
      widget.currencyCode,
    );
    final allowsDecimal = decimalPlaces > 0;

    return AnimatedContainer(
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      height: _kInputRowHeight,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_kInputRadius),
        border: isFocused
            ? Border.all(color: lapis, width: 1.5)
            : Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: 0.5,
              ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.numberWithOptions(decimal: allowsDecimal),
          textInputAction: TextInputAction.next,
          textAlign: TextAlign.end,
          strutStyle: _quickAddFieldStrutStyle(
            fontSize: 20,
            fontFamily: AppTextStyles.numeralInput.fontFamily,
            fontWeight: AppTextStyles.numeralInput.fontWeight,
          ),
          inputFormatters: [
            GroupedAmountInputFormatter(
              allowDecimal: allowsDecimal,
              maxFractionDigits: decimalPlaces,
            ),
          ],
          style: AppTextStyles.numeralInput.copyWith(
            color: semanticColor,
            fontSize: 20,
            letterSpacing: 0.5,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          decoration: _quickAddFieldDecoration(
            hintText: widget.hint,
            fontSize: 20,
            hintTextDirection: TextDirection.rtl,
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: semanticColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Note field — icon-prefixed single-line strip
// ---------------------------------------------------------------------------

/// A compact, icon-prefixed note field.
///
/// Renders as a single strip with a leading pencil icon; no separate label row.
/// The icon takes on the focus colour when the field is active.
class _QuickAddNoteField extends StatefulWidget {
  const _QuickAddNoteField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_QuickAddNoteField> createState() => _QuickAddNoteFieldState();
}

class _QuickAddNoteFieldState extends State<_QuickAddNoteField> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final isFocused = widget.focusNode.hasFocus;

    return AnimatedContainer(
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      height: _kInputRowHeight,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_kInputRadius),
        border: isFocused
            ? Border.all(color: lapis, width: 1.5)
            : Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: 0.5,
              ),
      ),
      child: Row(
        children: [
          // Leading icon — transitions from muted → lapis on focus.
          AnimatedContainer(
            duration: AppDimensions.animationFast,
            width: AppDimensions.spacingXxl + AppDimensions.spacingSm,
            alignment: Alignment.center,
            child: Icon(
              Icons.edit_note_rounded,
              size: 18,
              color: isFocused
                  ? lapis
                  : isDark
                      ? AppColors.inkMuted
                      : AppColors.inkMutedLight,
            ),
          ),
          // Vertical divider — hairline separator between icon and text.
          Container(
            width: 0.5,
            height: 22,
            color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
          ),
          // Note text field.
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              strutStyle: _quickAddFieldStrutStyle(
                fontSize: AppTextStyles.titleSmall.fontSize!,
                fontFamily: AppTextStyles.titleSmall.fontFamily,
                fontWeight: FontWeight.w400,
              ),
              style: AppTextStyles.titleSmall.copyWith(
                color: inkPrimary,
                fontWeight: FontWeight.w400,
                height: 1,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              decoration: _quickAddFieldDecoration(
                hintText: widget.hint,
                fontSize: AppTextStyles.titleSmall.fontSize!,
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: inkMuted,
                  fontWeight: FontWeight.w400,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle pill — debt / payment
// ---------------------------------------------------------------------------

/// Slim segmented pill — debt on start, payment on end.
class _QuickAddTogglePill extends StatelessWidget {
  const _QuickAddTogglePill({
    required this.isCredit,
    required this.onChanged,
  });

  final bool isCredit;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final isDebt = !isCredit;

    return Container(
      height: _kToggleHeight,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(_kInputRadius),
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
              // Sliding indicator pill.
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
                    borderRadius: BorderRadius.circular(_kInputRadius - 2),
                  ),
                ),
              ),
              // Labels.
              Row(
                children: [
                  Expanded(
                    child: _QuickAddToggleSegment(
                      label: l10n.debt,
                      icon: Icons.arrow_upward_rounded,
                      isSelected: isDebt,
                      color: AppColors.debt,
                      onTap: () => onChanged(false),
                    ),
                  ),
                  Expanded(
                    child: _QuickAddToggleSegment(
                      label: l10n.payment,
                      icon: Icons.arrow_downward_rounded,
                      isSelected: isCredit,
                      color: isDark ? AppColors.payment : AppColors.paymentLight,
                      onTap: () => onChanged(true),
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

class _QuickAddToggleSegment extends StatelessWidget {
  const _QuickAddToggleSegment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final textColor = isSelected ? (color ?? muted) : muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: _kToggleHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: textColor),
            const Gap(5),
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

// ---------------------------------------------------------------------------
// New-account badge
// ---------------------------------------------------------------------------

class _QuickAddNewAccountBadge extends StatelessWidget {
  const _QuickAddNewAccountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight,
          ),
          const Gap(5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isDark
                  ? AppColors.inkSecondary
                  : AppColors.inkSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact autocomplete suggestions strip
// ---------------------------------------------------------------------------

/// Horizontal autocomplete strip for contact name search hits.
class _QuickAddContactSuggestions extends ConsumerWidget {
  const _QuickAddContactSuggestions({required this.onSuggestionSelected});

  final ValueChanged<Contact> onSuggestionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSuggestions = ref.watch(
      quickAddControllerProvider.select((s) => s.showContactSuggestions),
    );
    final matchedContacts = ref.watch(
      quickAddControllerProvider.select((s) => s.matchedContacts),
    );
    final availableLedgers = ref.watch(
      quickAddControllerProvider.select((s) => s.availableLedgers),
    );

    return AnimatedSize(
      duration: AppDimensions.animationMedium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: showSuggestions
          ? Padding(
              padding: const EdgeInsetsDirectional.only(
                top: AppDimensions.spacingSm,
              ),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: matchedContacts.length,
                  separatorBuilder: (_, _) =>
                      const Gap(AppDimensions.spacingSm),
                  itemBuilder: (context, index) {
                    final contact = matchedContacts[index];
                    final ledger =
                        _ledgerForContact(contact, availableLedgers);
                    return _QuickAddContactSuggestionChip(
                      contact: contact,
                      ledgerName: ledger?.name ?? '',
                      ledgerColorHex: ledger?.color,
                      onTap: () {
                        unawaited(HapticService.selection());
                        onSuggestionSelected(contact);
                      },
                    );
                  },
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Ledger? _ledgerForContact(Contact contact, List<Ledger> ledgers) {
    for (final ledger in ledgers) {
      if (ledger.id == contact.ledgerId) {
        return ledger;
      }
    }
    return null;
  }
}

class _QuickAddContactSuggestionChip extends StatelessWidget {
  const _QuickAddContactSuggestionChip({
    required this.contact,
    required this.ledgerName,
    required this.onTap,
    this.ledgerColorHex,
  });

  final Contact contact;
  final String ledgerName;
  final String? ledgerColorHex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _parseLedgerHexColor(
      ledgerColorHex ?? contact.avatarColor,
    );
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        splashColor: inkPrimary.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contact.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isDark
                      ? AppColors.inkPrimary
                      : AppColors.inkPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (ledgerName.isNotEmpty) ...[
                const Gap(AppDimensions.spacingSm),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.spacingSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surface5
                        : AppColors.surface3Light,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCircular,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Gap(4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 88),
                        child: Text(
                          ledgerName,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ledger reaction zone — driven by Mohammed logic
// ---------------------------------------------------------------------------

/// Adaptive ledger picker driven by the account-resolution state machine.
class _QuickAddLedgerReactionZone extends ConsumerWidget {
  const _QuickAddLedgerReactionZone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(
      quickAddControllerProvider.select((s) => s.accountResolution),
    );

    return AnimatedSize(
      duration: AppDimensions.animationMedium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDimensions.animationMedium,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: switch (resolution) {
          QuickAddAccountResolution.idle => const SizedBox.shrink(
              key: ValueKey('ledger_idle'),
            ),
          QuickAddAccountResolution.singleLedgerAuto =>
            const _QuickAddLockedLedgerBadge(
              key: ValueKey('ledger_single'),
            ),
          QuickAddAccountResolution.multiLedgerPick => const SizedBox.shrink(
              key: ValueKey('ledger_multi'),
            ),
          QuickAddAccountResolution.newAccount =>
            const _QuickAddNewAccountLedgerChips(
              key: ValueKey('ledger_new'),
            ),
        },
      ),
    );
  }
}

class _QuickAddLockedLedgerBadge extends ConsumerWidget {
  const _QuickAddLockedLedgerBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ledgerId = ref.watch(
      quickAddControllerProvider.select((s) => s.selectedLedgerId),
    );
    final ledgers = ref.watch(
      quickAddControllerProvider.select((s) => s.availableLedgers),
    );

    if (ledgerId == null) {
      return const SizedBox.shrink();
    }

    Ledger? ledger;
    for (final item in ledgers) {
      if (item.id == ledgerId) {
        ledger = item;
        break;
      }
    }
    if (ledger == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _parseLedgerHexColor(ledger.color);
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppDimensions.spacingSm),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingXs + 2,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const Gap(AppDimensions.spacingSm),
            Expanded(
              child: Text(
                ledger.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isDark
                      ? AppColors.inkPrimary
                      : AppColors.inkPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Inline hint label — saves a full separate label row.
            Text(
              l10n.quickAddLedgerLockedHint,
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
              ),
            ),
            const Gap(AppDimensions.spacingXs),
            Icon(
              Icons.lock_rounded,
              size: AppDimensions.iconSmall,
              color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddNewAccountLedgerChips extends ConsumerWidget {
  const _QuickAddNewAccountLedgerChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ledgers = ref.watch(
      quickAddControllerProvider.select((s) => s.ledgersForPicker),
    );
    final selectedId = ref.watch(
      quickAddControllerProvider.select((s) => s.selectedLedgerId),
    );

    if (ledgers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppDimensions.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.quickAddSelectLedgerHint,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.inkMuted
                  : AppColors.inkMutedLight,
            ),
          ),
          const Gap(AppDimensions.spacingXs),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ledgers.length,
              separatorBuilder: (_, _) => const Gap(AppDimensions.spacingSm),
              itemBuilder: (context, index) {
                final ledger = ledgers[index];
                return _QuickAddLedgerChip(
                  ledger: ledger,
                  selected: ledger.id == selectedId,
                  onSelected: () {
                    unawaited(HapticService.selection());
                    ref
                        .read(quickAddControllerProvider.notifier)
                        .selectLedger(ledger.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddLedgerChip extends StatelessWidget {
  const _QuickAddLedgerChip({
    required this.ledger,
    required this.selected,
    required this.onSelected,
  });

  final Ledger ledger;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _parseLedgerHexColor(ledger.color);
    final fill = selected
        ? (isDark ? AppColors.surface3 : AppColors.surface1Light)
        : (isDark ? AppColors.surface4 : AppColors.surface2Light);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const Gap(AppDimensions.spacingSm),
              Text(
                ledger.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? (isDark
                          ? AppColors.inkPrimary
                          : AppColors.inkPrimaryLight)
                      : (isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

void _showCreditLimitExceededSnackBar({
  required ScaffoldMessengerState messenger,
  required String message,
  required bool isDark,
}) {
  final accentColor = isDark ? AppColors.debt : AppColors.debtLight;
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
                    Icons.error_outline_rounded,
                    color: accentColor,
                    size: AppDimensions.iconSmall + 2,
                  ),
                ),
                const Gap(AppDimensions.spacingMd),
                Expanded(
                  child: Text(
                    message,
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
        ),
      ),
    );
}

Color _parseLedgerHexColor(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return AppColors.inkMuted;
  }
  return Color(parsed);
}
