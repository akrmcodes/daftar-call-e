import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/grouped_amount_input_formatter.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/contact_picker_field_suffix.dart';
import 'package:daftar/presentation/shared/widgets/contact_sheet_fields.dart';
import 'package:daftar/presentation/shared/widgets/currency_selector.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/read_only_currency_suffix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class EditContactSheet extends ConsumerStatefulWidget {
  const EditContactSheet({required this.contact, super.key});

  final Contact contact;

  @override
  ConsumerState<EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends ConsumerState<EditContactSheet> {
  static const List<Currency> _currencies = BuiltInCurrencies.all;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _notesController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _emailFocusNode;
  late final FocusNode _creditLimitFocusNode;
  late final FocusNode _notesFocusNode;

  late String _selectedCurrencyCode;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _phoneController = TextEditingController(text: widget.contact.phone ?? '');
    _emailController = TextEditingController(text: widget.contact.email ?? '');
    final initialCreditCurrency =
        widget.contact.creditCurrency ?? DbConstants.currencyYer;
    _creditLimitController = TextEditingController(
      text: widget.contact.creditLimit == null
          ? ''
          : MoneyUtil.formatMinorUnitsForCode(
              widget.contact.creditLimit!,
              initialCreditCurrency,
            ),
    );
    _notesController = TextEditingController(text: widget.contact.notes ?? '');
    _nameFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _creditLimitFocusNode = FocusNode();
    _notesFocusNode = FocusNode();
    _selectedCurrencyCode =
        widget.contact.creditCurrency ?? DbConstants.currencyYer;

    _nameController.addListener(_handleInputChanged);
    _phoneController.addListener(_handleInputChanged);
    _emailController.addListener(_handleInputChanged);
    _creditLimitController.addListener(_handleInputChanged);
    _notesController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _phoneController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _emailController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _creditLimitController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _notesController
      ..removeListener(_handleInputChanged)
      ..dispose();
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

  bool get _isNameValid => _nameController.text.trim().isNotEmpty;

  bool get _isCreditLimitValid {
    return _creditLimitController.text.trim().isEmpty ||
        _parseCreditLimit(
          _creditLimitController.text,
          _creditLimitCurrencyCode(),
        ) !=
            null;
  }

  bool get _hasChanges {
    return _normalizedName != widget.contact.name.trim() ||
        _normalizedPhone != _normalizePhone(widget.contact.phone) ||
        _normalizedEmail != ContactEmail.normalize(widget.contact.email) ||
        _normalizedNotes != _normalizeOptionalText(widget.contact.notes) ||
        _parsedCreditLimit != widget.contact.creditLimit ||
        _selectedCurrencyCode !=
            (widget.contact.creditCurrency ?? DbConstants.currencyYer);
  }

  bool get _canSave =>
      _isNameValid && _isCreditLimitValid && _hasChanges && !_isSubmitting;

  String get _normalizedName => _nameController.text.trim();

  String? get _normalizedPhone => _normalizePhone(_phoneController.text);

  String? get _normalizedEmail => ContactEmail.normalize(_emailController.text);

  String? get _normalizedNotes => _normalizeOptionalText(_notesController.text);

  int? get _parsedCreditLimit => _parseCreditLimit(
        _creditLimitController.text,
        _creditLimitCurrencyCode(),
      );

  String _creditLimitCurrencyCode() {
    final settings =
        ref.read(appSettingsProvider).value ?? const AppSettings();
    if (settings.isMultiCurrencyEnabled) {
      return _selectedCurrencyCode;
    }
    return widget.contact.creditCurrency ??
        settings.defaultCurrency.trim().toUpperCase();
  }

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
      if (!_isNameValid) {
        FocusScope.of(context).requestFocus(_nameFocusNode);
      }
      return;
    }

    if (!_hasChanges) {
      await Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final settings =
        ref.read(appSettingsProvider).value ?? const AppSettings();
    final resolvedCreditCurrency = settings.isMultiCurrencyEnabled
        ? _selectedCurrencyCode
        : widget.contact.creditCurrency;

    final updatedContact = widget.contact.copyWith(
      name: _normalizedName,
      phone: _normalizedPhone,
      email: _normalizedEmail,
      notes: _normalizedNotes,
      creditLimit: _parsedCreditLimit,
      creditCurrency: resolvedCreditCurrency,
    );

    final result = await ref
        .read(contactControllerProvider.notifier)
        .updateContact(updatedContact);

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
        : (widget.contact.creditCurrency ??
            settings.defaultCurrency.trim().toUpperCase());
    final creditLimitDecimalPlaces =
        CurrencyPrecision.decimalPlacesForCode(displayCurrencyCode);
    final creditLimitAllowsDecimal = creditLimitDecimalPlaces > 0;
    final isDark = context.theme.brightness == Brightness.dark;
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
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
            ContactSheetSectionLabel(
              label: l10n.creditLimit,
              inkMuted: inkMuted,
            ),
            const Gap(AppDimensions.spacingXs),
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }

                if (_parseCreditLimit(value, displayCurrencyCode) == null) {
                  return l10n.invalidAmount;
                }

                return null;
              },
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
              minLines: 2,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              fill: fill,
              lapis: lapis,
              inkPrimary: inkPrimary,
              inkMuted: inkMuted,
              borderSubtle: borderSubtle,
            ),
            const Gap(AppDimensions.spacingMd),
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
