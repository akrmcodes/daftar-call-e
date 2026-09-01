import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/grouped_amount_input_formatter.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/shared/currency_creation_policy.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/contact_picker_field_suffix.dart';
import 'package:daftar/presentation/shared/widgets/contact_sheet_fields.dart';
import 'package:daftar/presentation/shared/widgets/currency_selector.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/read_only_currency_suffix.dart';
import 'package:daftar/presentation/widgets/premium/premium_limit_upsell_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class AddContactSheet extends ConsumerStatefulWidget {
  const AddContactSheet({required this.ledgerId, super.key});

  final String ledgerId;

  @override
  ConsumerState<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<AddContactSheet> {
  static const List<Currency> _currencies = BuiltInCurrencies.all;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _creditLimitController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _creditLimitFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  late String _selectedCurrencyCode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrencyCode = DbConstants.currencyYer;
    _nameController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _creditLimitFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isNameFilled => _nameController.text.trim().isNotEmpty;

  bool get _canSave => _isNameFilled && !_isSubmitting;

  void _applyPickedContact(NativeContactPickResult result) {
    if (result.name.isNotEmpty) {
      _nameController.text = result.name;
    }
    if (result.phone != null && result.phone!.isNotEmpty) {
      _phoneController.text = result.phone!;
    }
    _handleInputChanged();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (_nameController.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(_nameFocusNode);
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    unawaited(HapticService.transactionSaved());

    final settings =
        ref.read(appSettingsProvider).value ?? const AppSettings();
    final creditLimitCurrencyCode = settings.isMultiCurrencyEnabled
        ? _selectedCurrencyCode
        : settings.defaultCurrency.trim().toUpperCase();
    final creditCurrency = _parseCreditLimit(
              _creditLimitController.text,
              creditLimitCurrencyCode,
            ) ==
            null
        ? null
        : effectiveCreationCurrency(settings, _selectedCurrencyCode);

    final result = await ref
        .read(contactControllerProvider.notifier)
        .createContact(
          ledgerId: widget.ledgerId,
          name: _nameController.text.trim(),
          phone: _normalizePhone(_phoneController.text),
          email: ContactEmail.normalize(_emailController.text),
          notes: _normalizeOptionalText(_notesController.text),
          creditLimit: _parseCreditLimit(
            _creditLimitController.text,
            creditLimitCurrencyCode,
          ),
          creditCurrency: creditCurrency,
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
      (contact) {
        Navigator.of(context).pop(contact);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();
    final isMultiCurrency = settings.isMultiCurrencyEnabled;
    final displayCurrencyCode = isMultiCurrency
        ? _selectedCurrencyCode
        : settings.defaultCurrency.trim().toUpperCase();
    final creditLimitDecimalPlaces =
        CurrencyPrecision.decimalPlacesForCode(displayCurrencyCode);
    final creditLimitAllowsDecimal = creditLimitDecimalPlaces > 0;
    final isDark = context.theme.brightness == Brightness.dark;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: kContactSheetNameFlex,
                  child: ContactSheetInputField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    autofocus: true,
                    hint: l10n.name,
                    leading: ContactPickerFieldSuffix(
                      enabled: !_isSubmitting,
                      iconColor: inkMuted,
                      icon: Icons.person_outline_rounded,
                      onPicked: _applyPickedContact,
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    fill: fill,
                    lapis: lapis,
                    inkPrimary: inkPrimary,
                    inkMuted: inkMuted,
                    borderSubtle: borderSubtle,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.nameRequired;
                      }
                      return null;
                    },
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_phoneFocusNode);
                    },
                  ),
                ),
                const Gap(AppDimensions.spacingSm),
                Expanded(
                  flex: kContactSheetPhoneFlex,
                  child: ContactSheetInputField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    hint: l10n.phoneNumber,
                    leading: ContactPickerFieldSuffix(
                      enabled: !_isSubmitting,
                      iconColor: inkMuted,
                      onPicked: _applyPickedContact,
                    ),
                    autofillHints: const [AutofillHints.telephoneNumber],
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    fill: fill,
                    lapis: lapis,
                    inkPrimary: inkPrimary,
                    inkMuted: inkMuted,
                    borderSubtle: borderSubtle,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩+\-\s()]'),
                      ),
                    ],
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_emailFocusNode);
                    },
                  ),
                ),
              ],
            ),

            const Gap(AppDimensions.spacingSm),

            ContactSheetInputField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              hint: l10n.contactEmailHint,
              prefixIcon: Icons.mail_outline_rounded,
              autofillHints: const [AutofillHints.email],
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              fill: fill,
              lapis: lapis,
              inkPrimary: inkPrimary,
              inkMuted: inkMuted,
              borderSubtle: borderSubtle,
              validator: (value) {
                if (!ContactEmail.isValid(value)) {
                  return l10n.contactEmailInvalid;
                }
                return null;
              },
              onSubmitted: (_) {
                FocusScope.of(context).requestFocus(_creditLimitFocusNode);
              },
            ),

            const Gap(AppDimensions.spacingSm),

            // ── Row 2: Inline section label ───────────────────────────────
            ContactSheetSectionLabel(
              label: l10n.creditLimit,
              inkMuted: inkMuted,
            ),
            const Gap(AppDimensions.spacingXs),

            // ── Row 3: Credit Limit field ─────────────────────────────────
            ContactSheetInputField(
              controller: _creditLimitController,
              focusNode: _creditLimitFocusNode,
              hint: l10n.creditLimit,
              prefixIcon: Icons.account_balance_wallet_outlined,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.numberWithOptions(
                decimal: creditLimitAllowsDecimal,
              ),
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              fill: fill,
              lapis: lapis,
              inkPrimary: inkPrimary,
              inkMuted: inkMuted,
              borderSubtle: borderSubtle,
              inputFormatters: [
                GroupedAmountInputFormatter(
                  allowDecimal: creditLimitAllowsDecimal,
                  maxFractionDigits: creditLimitDecimalPlaces,
                ),
              ],
              suffix: ReadOnlyCurrencySuffix(
                currencyCode: displayCurrencyCode,
                currencies: _currencies,
              ),
              onSubmitted: (_) {
                FocusScope.of(context).requestFocus(_notesFocusNode);
              },
            ),

            if (isMultiCurrency) ...[
              const Gap(AppDimensions.spacingSm),
              CurrencySelector(
                currencies: _currencies,
                selectedCurrencyCode: _selectedCurrencyCode,
                label: l10n.selectCurrency,
                enabled: !_isSubmitting,
                onChanged: (currency) {
                  setState(() {
                    final existingMinor = _parseCreditLimit(
                      _creditLimitController.text,
                      displayCurrencyCode,
                    );
                    _selectedCurrencyCode = currency.code;
                    if (existingMinor != null) {
                      _creditLimitController.text =
                          MoneyUtil.formatMinorUnitsForCode(
                        existingMinor,
                        currency.code,
                      );
                    }
                  });
                },
              ),
            ],

            const Gap(AppDimensions.spacingSm),

            // ── Row 4: Notes — single-line icon-prefixed strip ────────────
            ContactSheetSectionLabel(
              label: l10n.notes,
              inkMuted: inkMuted,
            ),
            const Gap(AppDimensions.spacingXs),
            ContactSheetInputField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              hint: l10n.notes,
              prefixIcon: Icons.notes_rounded,
              enabled: !_isSubmitting,
              textInputAction: TextInputAction.done,
              fill: fill,
              lapis: lapis,
              inkPrimary: inkPrimary,
              inkMuted: inkMuted,
              borderSubtle: borderSubtle,
              onSubmitted: (_) {
                if (_canSave) unawaited(_submit());
              },
            ),

            const Gap(AppDimensions.spacingMd),

            // ── Row 5: Save CTA — thumb-reachable, Khazna-compliant ───────
            DaftarButton(
              label: l10n.save,
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

  static String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? _normalizePhone(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  int? _parseCreditLimit(String? value, String currencyCode) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return MoneyUtil.parseMinorUnitsForCode(trimmed, currencyCode);
  }
}
