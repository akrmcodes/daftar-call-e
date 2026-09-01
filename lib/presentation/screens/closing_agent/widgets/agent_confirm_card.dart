import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/agent/contact_name_match.dart';
import 'package:daftar/application/agent/resolve_agent_money_goods.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/tts_sanitize.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_speakable_lines.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_fade_dot_matrix.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_permission_banner.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Intent-preview Confirm card for debt, payment, create, ledger, or statement.
class AgentConfirmCard extends StatefulWidget {
  /// Creates a Confirm card.
  const AgentConfirmCard({
    required this.proposal,
    required this.ledgers,
    required this.isConfirming,
    required this.onConfirm,
    required this.onSkip,
    required this.onLedgerSelected,
    required this.onCurrencySelected,
    this.selectedLedgerId,
    this.selectedCurrencyCode,
    this.currencies = const [],
    this.isMultiCurrencyEnabled = false,
    this.candidates = const [],
    this.selectedContactId,
    this.onContactSelected,
    this.createNewSelected = false,
    this.onCreateNewSelected,
    this.ledgersReady = true,
    this.pickedName,
    this.pickedPhone,
    this.onPickFromContacts,
    this.contactsPermissionDenied = false,
    this.onOpenContactsSettings,
    this.ledgerName,
    this.onLedgerNameChanged,
    this.amountMinorOverride,
    this.ttsMuted = false,
    this.ttsLocale = 'ar',
    super.key,
  });

  /// Proposal to preview.
  final AgentProposal proposal;

  /// Active ledgers for the create-contact picker.
  final List<Ledger> ledgers;

  /// Built-in currency catalog for create-contact chips.
  final List<Currency> currencies;

  /// Ledger chosen in the UI (overrides payload).
  final String? selectedLedgerId;

  /// Currency chosen in the UI (create-contact only).
  final String? selectedCurrencyCode;

  /// When true, create-contact Confirm requires a currency tap.
  final bool isMultiCurrencyEnabled;

  /// Name-search hits for debt/payment disambiguation.
  final List<ContactSearchHit> candidates;

  /// Merchant-picked contact id (overrides payload).
  final String? selectedContactId;

  /// Called when the merchant picks a candidate.
  final ValueChanged<String>? onContactSelected;

  /// True when the merchant chose Create new over a similar existing name.
  final bool createNewSelected;

  /// Called when the merchant chooses Create new. Null hides that chip.
  final VoidCallback? onCreateNewSelected;

  /// False while [ledgers] is still loading — do not treat as empty books.
  final bool ledgersReady;

  /// Phone-picker name override for create-contact.
  final String? pickedName;

  /// Phone-picker phone override for create-contact.
  final String? pickedPhone;

  /// Opens the native contacts picker. Null hides the control.
  final VoidCallback? onPickFromContacts;

  /// True after the OS denied contacts access for this pick.
  final bool contactsPermissionDenied;

  /// Opens app settings. Null hides the banner action.
  final VoidCallback? onOpenContactsSettings;

  /// Ledger name typed when the merchant has zero ledgers.
  final String? ledgerName;

  /// Called when the merchant types a new ledger name.
  final ValueChanged<String>? onLedgerNameChanged;

  /// Spoken-amount snap override for money proposals.
  final int? amountMinorOverride;

  /// When true, skip on-device TTS for this card.
  final bool ttsMuted;

  /// Settings locale (`ar` / `en`) for TTS.
  final String ttsLocale;

  /// When true, the primary verb shows a spinner.
  final bool isConfirming;

  /// Commits the proposal.
  final VoidCallback onConfirm;

  /// Skips without writing money or journal.
  final VoidCallback onSkip;

  /// Called when the merchant picks a ledger.
  final ValueChanged<String> onLedgerSelected;

  /// Called when the merchant picks a currency.
  final ValueChanged<String> onCurrencySelected;

  @override
  State<AgentConfirmCard> createState() => _AgentConfirmCardState();
}

class _AgentConfirmCardState extends State<AgentConfirmCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _breathController;
  Timer? _breathDelay;
  late final TextEditingController _ledgerNameController;

  @override
  void initState() {
    super.initState();
    _ledgerNameController = TextEditingController(
      text: widget.ledgerName ?? '',
    );
    _scheduleBreath();
    _speakReadback();
  }

  @override
  void didUpdateWidget(covariant AgentConfirmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposal.proposalId != widget.proposal.proposalId) {
      _breathDelay?.cancel();
      _breathController?.dispose();
      _breathController = null;
      _ledgerNameController.text = widget.ledgerName ?? '';
      _scheduleBreath();
      _speakReadback();
    }
  }

  void _speakReadback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.ttsMuted) {
        return;
      }
      final speechL10n = speechLocalizations(widget.ttsLocale);
      final line = _factsFor(widget.proposal).speakableReadback(speechL10n);
      if (line.isEmpty) {
        return;
      }
      unawaited(AgentSpeech.speak(line, locale: widget.ttsLocale));
    });
  }

  void _scheduleBreath() {
    final disableAnimations = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (disableAnimations) {
      return;
    }
    _breathDelay = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _breathController = AnimationController(
        vsync: this,
        duration: AppDimensions.animationBreath,
      );
      unawaited(_breathController!.repeat(reverse: true));
      setState(() {});
    });
  }

  @override
  void dispose() {
    _breathDelay?.cancel();
    _breathController?.dispose();
    _ledgerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    final facts = _factsFor(widget.proposal);
    final confirmEnabled = _confirmEnabled(facts) && !widget.isConfirming;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _IntentBadge(
              label: facts.intentLabel(l10n),
              isDark: isDark,
            ),
            const Spacer(),
            DaftarButton(
              label: l10n.closingAgentSkip,
              variant: DaftarButtonVariant.tertiary,
              size: DaftarButtonSize.small,
              onPressed: widget.isConfirming ? null : widget.onSkip,
            ),
          ],
        ),
        const Gap(AppDimensions.spacingSm),
        Text(
          facts.displayHeadline(l10n),
          style: AppTextStyles.titleLarge.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (facts.itemName != null && facts.itemName!.isNotEmpty) ...[
          const Gap(AppDimensions.spacingXxs),
          Text(
            facts.itemName!,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
        if (facts.note != null && facts.note!.isNotEmpty) ...[
          const Gap(AppDimensions.spacingXxs),
          Text(
            facts.noteLabel(l10n),
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
        if (facts.showContactPicker) ...[
          const Gap(AppDimensions.spacingMd),
          Text(
            l10n.closingAgentWhichContact,
            style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
          ),
          const Gap(AppDimensions.spacingSm),
          SizedBox(
            height: AppDimensions.minTapTarget,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
                  widget.candidates.length +
                  (facts.showCreateNewChip ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= widget.candidates.length) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppDimensions.spacingSm,
                    ),
                    child: _ConfirmChip(
                      label: l10n.closingAgentCreateNewNamed(
                        facts.spokenName,
                      ),
                      icon: Icons.person_add_rounded,
                      isSelected: widget.createNewSelected,
                      isDark: isDark,
                      onTap: () => widget.onCreateNewSelected?.call(),
                    ),
                  );
                }
                final hit = widget.candidates[index];
                final selected = hit.contact.id == facts.effectiveContactId;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm,
                  ),
                  child: _ConfirmChip(
                    label: _chipLabel(hit),
                    isSelected: selected,
                    isDark: isDark,
                    onTap: () =>
                        widget.onContactSelected?.call(hit.contact.id),
                  ),
                );
              },
            ),
          ),
        ],
        if (facts.showPhonePicker) ...[
          const Gap(AppDimensions.spacingMd),
          if (widget.contactsPermissionDenied) ...[
            DaftarPermissionBanner(
              message: l10n.closingAgentContactsPermissionDenied,
              actionLabel: l10n.closingAgentMicOpenSettings,
              onAction: widget.onOpenContactsSettings,
              semanticsLabel: l10n.closingAgentPermissionBannerSemantics,
            ),
            const Gap(AppDimensions.spacingSm),
          ],
          DaftarButton(
            label: l10n.importFromContacts,
            variant: DaftarButtonVariant.tertiary,
            isExpanded: true,
            onPressed: widget.isConfirming ? null : widget.onPickFromContacts,
          ),
        ],
        if (facts.showLedgerNameField) ...[
          const Gap(AppDimensions.spacingMd),
          DaftarTextField(
            controller: _ledgerNameController,
            label: l10n.closingAgentLedgerNameHint,
            hint: l10n.closingAgentLedgerNameHint,
            enabled: !widget.isConfirming,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            onChanged: widget.onLedgerNameChanged,
          ),
        ],
        if (facts.showLedgerPicker) ...[
          const Gap(AppDimensions.spacingMd),
          Text(
            l10n.closingAgentSelectLedger,
            style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
          ),
          const Gap(AppDimensions.spacingSm),
          SizedBox(
            height: AppDimensions.minTapTarget,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.ledgers.length,
              itemBuilder: (context, index) {
                final ledger = widget.ledgers[index];
                final selected = ledger.id == facts.effectiveLedgerId;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm,
                  ),
                  child: _ConfirmChip(
                    label: ledger.name,
                    isSelected: selected,
                    isDark: isDark,
                    onTap: () => widget.onLedgerSelected(ledger.id),
                  ),
                );
              },
            ),
          ),
        ],
        if (facts.showCurrencyPicker) ...[
          const Gap(AppDimensions.spacingMd),
          Text(
            l10n.closingAgentSelectCurrency,
            style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
          ),
          const Gap(AppDimensions.spacingSm),
          SizedBox(
            height: AppDimensions.minTapTarget,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.currencies.length,
              itemBuilder: (context, index) {
                final currency = widget.currencies[index];
                final selected = currency.code == facts.effectiveCurrencyCode;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm,
                  ),
                  child: _ConfirmChip(
                    label: currency.code,
                    isSelected: selected,
                    isDark: isDark,
                    onTap: () => widget.onCurrencySelected(currency.code),
                  ),
                );
              },
            ),
          ),
        ],
        if (facts.helperText(l10n) != null) ...[
          const Gap(AppDimensions.spacingSm),
          Text(
            facts.helperText(l10n)!,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
        const Gap(AppDimensions.spacingLg),
        Divider(
          height: AppDimensions.dividerThickness,
          thickness: AppDimensions.dividerThickness,
          color: isDark
              ? AppColors.borderSubtle
              : AppColors.borderSubtleLight,
          indent: AppDimensions.spacingXs,
          endIndent: AppDimensions.spacingXs,
        ),
        const Gap(AppDimensions.spacingMd),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: facts.amountLabel != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facts.amountLabel!,
                          textDirection: TextDirection.ltr,
                          style: AppTextStyles.amountLarge.copyWith(
                            color:
                                facts.amountColor(isDark: isDark) ??
                                inkPrimary,
                          ),
                        ),
                        if (facts.currencyCode != null) ...[
                          const Gap(AppDimensions.spacingXxs),
                          Text(
                            facts.currencyCode!,
                            textDirection: TextDirection.ltr,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: inkSecondary,
                            ),
                          ),
                        ],
                      ],
                    )
                  : () {
                      final caption = facts.footerLeadingCaption(
                        l10n,
                        widget.ledgers,
                      );
                      if (caption == null || caption.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        caption,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: inkSecondary,
                        ),
                      );
                    }(),
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: facts.verb(l10n),
              isLoading: widget.isConfirming,
              onPressed: confirmEnabled ? widget.onConfirm : null,
            ),
          ],
        ),
      ],
    );

    Widget card = _ConfirmVaultShell(
      isDark: isDark,
      child: content,
    );

    if (isDark && _breathController != null) {
      card = AnimatedBuilder(
        animation: _breathController!,
        builder: (context, child) {
          final t = _breathController!.value;
          final glow = BoxShadow.lerp(AppGlows.glowSm, AppGlows.glowMd, t)!;
          return DecoratedBox(
            decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AppDimensions.radiusLg,
                  cornerSmoothing: 0.6,
                ),
              ),
              shadows: [glow],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return RepaintBoundary(child: card);
  }

  bool _confirmEnabled(_ConfirmFacts facts) {
    if (facts.contactAlreadyExists) {
      return false;
    }
    if (facts.createIfMissing && facts.party.trim().isEmpty) {
      return false;
    }
    if (facts.contactUnresolved) {
      return false;
    }
    if (facts.needsContact &&
        (facts.effectiveContactId == null ||
            facts.effectiveContactId!.isEmpty)) {
      return false;
    }
    if (facts.needsLedger && facts.effectiveLedgerId == null) {
      return false;
    }
    if (facts.needsLedgerName &&
        (facts.ledgerName == null || facts.ledgerName!.trim().isEmpty)) {
      return false;
    }
    if (facts.needsCurrency &&
        (facts.effectiveCurrencyCode == null ||
            facts.effectiveCurrencyCode!.isEmpty)) {
      return false;
    }
    return true;
  }

  _ConfirmFacts _factsFor(AgentProposal proposal) {
    switch (proposal.payload) {
      case ProposeDebtPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
        :final contactId,
        :final note,
        :final itemName,
      ):
        return _moneyFacts(
          tool: ProposalTool.proposeDebt,
          contactHint: contactHint,
          contactId: contactId,
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          note: note,
          itemName: itemName,
        );
      case ProposePaymentPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
        :final contactId,
        :final note,
        :final itemName,
      ):
        return _moneyFacts(
          tool: ProposalTool.proposePayment,
          contactHint: contactHint,
          contactId: contactId,
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          note: note,
          itemName: itemName,
        );
      case ProposeCreateContactPayload(
        :final name,
        :final phone,
        :final ledgerId,
      ):
        final payloadLedger = ledgerId?.trim();
        final spoken = name.trim();
        final uniqueExact = _uniqueExactHit(spoken) != null;
        final alreadyExists = uniqueExact && !widget.createNewSelected;
        final pickedExisting = widget.selectedContactId?.trim();
        final hasPickedExisting =
            pickedExisting != null && pickedExisting.isNotEmpty;
        final creating =
            !alreadyExists &&
            (widget.candidates.isEmpty || widget.createNewSelected);
        final showPicker = widget.candidates.isNotEmpty && !uniqueExact;
        final ledger = _ledgerCreateFlags(
          creating: creating,
          payloadLedgerId: payloadLedger,
        );
        final currencyOverride = widget.selectedCurrencyCode?.trim();
        final effectiveCurrency =
            (currencyOverride != null && currencyOverride.isNotEmpty)
            ? currencyOverride.toUpperCase()
            : null;
        final pickedName = nonUuidHint(widget.pickedName);
        final pickedPhone = widget.pickedPhone?.trim();
        return _ConfirmFacts(
          tool: ProposalTool.proposeCreateContact,
          party: pickedName ?? (nonUuidHint(name) ?? name.trim()),
          spokenName: spoken,
          note: (pickedPhone != null && pickedPhone.isNotEmpty)
              ? pickedPhone
              : phone,
          contactAlreadyExists: alreadyExists,
          needsContact: showPicker && !hasPickedExisting && !creating,
          showContactPicker: showPicker,
          showCreateNewChip: showPicker && widget.onCreateNewSelected != null,
          effectiveContactId: hasPickedExisting ? pickedExisting : null,
          needsLedger: ledger.needsLedger,
          showLedgerPicker: ledger.showLedgerPicker,
          needsLedgerName: ledger.needsLedgerName,
          showLedgerNameField: ledger.showLedgerNameField,
          ledgerName: widget.ledgerName,
          effectiveLedgerId: ledger.effectiveLedgerId,
          needsCurrency: creating && widget.isMultiCurrencyEnabled,
          showCurrencyPicker: creating && widget.isMultiCurrencyEnabled,
          effectiveCurrencyCode: effectiveCurrency,
          showPhonePicker: widget.onPickFromContacts != null,
        );
      case ProposeCreateLedgerPayload(:final name, :final type):
        return _ConfirmFacts(
          tool: ProposalTool.proposeCreateLedger,
          party: name,
          note: type,
        );
      case ProposeStatementPayload(:final contactId, :final contactHint):
        return _statementFacts(
          contactHint: contactHint ?? '',
          contactId: contactId,
        );
      case ProposeClosingPlanPayload():
      case ParseGoalPayload():
      case GenericProposalPayload():
        return const _ConfirmFacts(
          tool: ProposalTool.proposeDebt,
          party: '',
          contactUnresolved: true,
        );
    }
  }

  _ConfirmFacts _moneyFacts({
    required ProposalTool tool,
    required String contactHint,
    required String? contactId,
    required int amountMinor,
    required String currencyCode,
    String? note,
    String? itemName,
  }) {
    final hint = contactHint.trim();
    final createNew = widget.createNewSelected;
    final selected = widget.selectedContactId?.trim();
    final payloadId = contactId?.trim();
    final uniqueExact = _uniqueExactHit(hint) != null;
    String? effectiveId;
    if (createNew) {
      effectiveId = null;
    } else if (selected != null && selected.isNotEmpty) {
      effectiveId = selected;
    } else if (payloadId != null && payloadId.isNotEmpty) {
      effectiveId = payloadId;
    } else if (uniqueExact) {
      effectiveId = widget.candidates.single.contact.id;
    }
    final bound = effectiveId != null && effectiveId.isNotEmpty;
    final createIfMissing = !bound && (widget.candidates.isEmpty || createNew);
    final showPicker = widget.candidates.isNotEmpty && !uniqueExact;
    final pickedName = nonUuidHint(widget.pickedName);
    final party = pickedName ?? _humanParty(contactHint, effectiveId);
    final currencyOverride = widget.selectedCurrencyCode?.trim();
    final payloadCurrency = currencyCode.trim();
    final effectiveCurrency = createIfMissing && widget.isMultiCurrencyEnabled
        ? ((currencyOverride != null && currencyOverride.isNotEmpty)
              ? currencyOverride.toUpperCase()
              : (payloadCurrency.isNotEmpty
                    ? payloadCurrency.toUpperCase()
                    : null))
        : null;
    final ledger = _ledgerCreateFlags(creating: createIfMissing);
    final goods = resolveAgentMoneyGoods(itemName: itemName, note: note);
    return _ConfirmFacts(
      tool: tool,
      party: party,
      spokenName: nonUuidHint(hint) ?? '',
      amountMinor: widget.amountMinorOverride ?? amountMinor,
      currencyCode: currencyCode,
      itemName: goods.itemName,
      note: goods.note,
      createIfMissing: createIfMissing,
      needsContact: !createIfMissing && !bound,
      showContactPicker: showPicker,
      showCreateNewChip: showPicker && widget.onCreateNewSelected != null,
      effectiveContactId: effectiveId,
      showPhonePicker: createIfMissing && widget.onPickFromContacts != null,
      needsLedger: ledger.needsLedger,
      showLedgerPicker: ledger.showLedgerPicker,
      needsLedgerName: ledger.needsLedgerName,
      showLedgerNameField: ledger.showLedgerNameField,
      ledgerName: widget.ledgerName,
      effectiveLedgerId: ledger.effectiveLedgerId,
      needsCurrency: createIfMissing && widget.isMultiCurrencyEnabled,
      showCurrencyPicker: createIfMissing && widget.isMultiCurrencyEnabled,
      effectiveCurrencyCode: effectiveCurrency,
    );
  }

  _ConfirmFacts _statementFacts({
    required String contactHint,
    required String contactId,
  }) {
    final hint = contactHint.trim();
    final selected = widget.selectedContactId?.trim();
    final payloadId = contactId.trim();
    final uniqueExact = _uniqueExactHit(hint) != null;
    String? effectiveId;
    if (selected != null && selected.isNotEmpty) {
      effectiveId = selected;
    } else if (widget.candidates.length > 1) {
      if (payloadId.isNotEmpty &&
          widget.candidates.any((hit) => hit.contact.id == payloadId)) {
        effectiveId = payloadId;
      }
    } else if (uniqueExact) {
      effectiveId = widget.candidates.single.contact.id;
    } else if (payloadId.isNotEmpty && widget.candidates.isEmpty) {
      effectiveId = payloadId;
    }
    final party = _humanParty(contactHint, effectiveId);
    final bound = effectiveId != null && effectiveId.isNotEmpty;
    final showPicker = widget.candidates.isNotEmpty && !uniqueExact;
    return _ConfirmFacts(
      tool: ProposalTool.proposeStatement,
      party: party,
      spokenName: nonUuidHint(hint) ?? '',
      contactUnresolved: !bound && widget.candidates.isEmpty,
      needsContact: !bound,
      showContactPicker: showPicker,
      effectiveContactId: effectiveId,
    );
  }

  ContactSearchHit? _uniqueExactHit(String hint) {
    if (widget.candidates.length != 1 || hint.trim().isEmpty) {
      return null;
    }
    final hit = widget.candidates.single;
    if (!isExactContactNameMatch(hint, hit.contact.name)) {
      return null;
    }
    return hit;
  }

  _LedgerCreateFlags _ledgerCreateFlags({
    required bool creating,
    String? payloadLedgerId,
  }) {
    if (!creating) {
      return const _LedgerCreateFlags();
    }
    if (!widget.ledgersReady) {
      return const _LedgerCreateFlags(needsLedger: true);
    }
    if (widget.ledgers.isEmpty) {
      return const _LedgerCreateFlags(
        needsLedgerName: true,
        showLedgerNameField: true,
      );
    }
    final override = widget.selectedLedgerId?.trim();
    final fromPayload = payloadLedgerId?.trim();
    final effective = (override != null && override.isNotEmpty)
        ? override
        : (fromPayload != null && fromPayload.isNotEmpty)
        ? fromPayload
        : (widget.ledgers.length == 1 ? widget.ledgers.single.id : null);
    return _LedgerCreateFlags(
      needsLedger: effective == null,
      showLedgerPicker: true,
      effectiveLedgerId: effective,
    );
  }

  String _humanParty(String hint, String? contactId) {
    final id = contactId?.trim();
    if (id != null && id.isNotEmpty) {
      for (final hit in widget.candidates) {
        if (hit.contact.id == id) {
          return hit.contact.name.trim();
        }
      }
    }
    return nonUuidHint(hint) ?? '';
  }

  static String _chipLabel(ContactSearchHit hit) {
    final ledger = hit.ledgerName.trim();
    if (ledger.isEmpty) {
      return hit.contact.name;
    }
    return '${hit.contact.name} · $ledger';
  }
}

class _LedgerCreateFlags {
  const _LedgerCreateFlags({
    this.needsLedger = false,
    this.showLedgerPicker = false,
    this.needsLedgerName = false,
    this.showLedgerNameField = false,
    this.effectiveLedgerId,
  });

  final bool needsLedger;
  final bool showLedgerPicker;
  final bool needsLedgerName;
  final bool showLedgerNameField;
  final String? effectiveLedgerId;
}

class _ConfirmFacts {
  const _ConfirmFacts({
    required this.tool,
    required this.party,
    this.spokenName = '',
    this.amountMinor,
    this.currencyCode,
    this.itemName,
    this.note,
    this.contactUnresolved = false,
    this.contactAlreadyExists = false,
    this.needsLedger = false,
    this.showLedgerPicker = false,
    this.effectiveLedgerId,
    this.needsCurrency = false,
    this.showCurrencyPicker = false,
    this.effectiveCurrencyCode,
    this.needsContact = false,
    this.showContactPicker = false,
    this.showCreateNewChip = false,
    this.effectiveContactId,
    this.showPhonePicker = false,
    this.createIfMissing = false,
    this.needsLedgerName = false,
    this.showLedgerNameField = false,
    this.ledgerName,
  });

  final ProposalTool tool;
  final String party;
  final String spokenName;
  final int? amountMinor;
  final String? currencyCode;
  final String? itemName;
  final String? note;
  final bool contactUnresolved;
  final bool contactAlreadyExists;
  final bool needsLedger;
  final bool showLedgerPicker;
  final String? effectiveLedgerId;
  final bool needsCurrency;
  final bool showCurrencyPicker;
  final String? effectiveCurrencyCode;
  final bool needsContact;
  final bool showContactPicker;
  final bool showCreateNewChip;
  final String? effectiveContactId;
  final bool showPhonePicker;
  final bool createIfMissing;
  final bool needsLedgerName;
  final bool showLedgerNameField;
  final String? ledgerName;

  String? get amountLabel {
    final amount = amountMinor;
    final code = currencyCode;
    if (amount == null || code == null || code.isEmpty) {
      return null;
    }
    return MoneyUtil.formatMinorUnitsForCode(amount, code);
  }

  String spokenDisplayName(AppLocalizations l10n) {
    return nonUuidHint(party) ??
        nonUuidHint(spokenName) ??
        l10n.closingAgentSpeakThisAccount;
  }

  String displayHeadline(AppLocalizations l10n) {
    final name = spokenDisplayName(l10n);
    if (tool == ProposalTool.proposeStatement) {
      return l10n.closingAgentStatementTitle(name);
    }
    return name;
  }

  String intentLabel(AppLocalizations l10n) {
    if (createIfMissing) {
      return l10n.closingAgentIntentNewAccount;
    }
    return switch (tool) {
      ProposalTool.proposeDebt => l10n.closingAgentIntentDebt,
      ProposalTool.proposePayment => l10n.closingAgentIntentPayment,
      ProposalTool.proposeCreateContact => l10n.closingAgentIntentNewAccount,
      ProposalTool.proposeCreateLedger => l10n.closingAgentIntentLedger,
      ProposalTool.proposeStatement => l10n.closingAgentIntentStatement,
      _ => l10n.closingAgentIntentDebt,
    };
  }

  /// Quiet footer caption when there is no monetary amount.
  String? footerLeadingCaption(AppLocalizations l10n, List<Ledger> ledgers) {
    if (amountLabel != null) {
      return null;
    }
    return switch (tool) {
      ProposalTool.proposeCreateLedger => noteLabel(l10n),
      ProposalTool.proposeCreateContact => showLedgerPicker
          ? null
          : (_ledgerCaption(ledgers) ??
                (note?.trim().isNotEmpty == true ? note!.trim() : null)),
      ProposalTool.proposeStatement => null,
      _ => null,
    };
  }

  String? _ledgerCaption(List<Ledger> ledgers) {
    final id = effectiveLedgerId;
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final ledger in ledgers) {
      if (ledger.id == id) {
        return ledger.name;
      }
    }
    return null;
  }

  /// Clerk confirm line for on-device TTS.
  String speakableReadback(AppLocalizations l10n) {
    final amount = amountMinor;
    final code = currencyCode;
    return confirmProposalSpeakable(
      l10n: l10n,
      tool: tool,
      name: spokenDisplayName(l10n),
      cta: verb(l10n),
      createIfMissing: createIfMissing,
      amountSpoken: (amount != null && code != null && code.isNotEmpty)
          ? spokenAmountLabel(
              l10n: l10n,
              amountMinor: amount,
              currencyCode: code,
            )
          : null,
      itemName: itemName,
    );
  }

  Color? amountColor({required bool isDark}) {
    return switch (tool) {
      ProposalTool.proposeDebt => isDark ? AppColors.debt : AppColors.debtLight,
      ProposalTool.proposePayment =>
        isDark ? AppColors.payment : AppColors.paymentLight,
      _ => null,
    };
  }

  String verb(AppLocalizations l10n) {
    if (createIfMissing) {
      return switch (tool) {
        ProposalTool.proposeDebt => l10n.closingAgentConfirmCreateAndRecordDebt,
        ProposalTool.proposePayment =>
          l10n.closingAgentConfirmCreateAndRecordPayment,
        _ => l10n.closingAgentConfirmDebt,
      };
    }
    return switch (tool) {
      ProposalTool.proposeDebt => l10n.closingAgentConfirmDebt,
      ProposalTool.proposePayment => l10n.closingAgentConfirmPayment,
      ProposalTool.proposeCreateContact =>
        l10n.closingAgentConfirmCreateContact,
      ProposalTool.proposeCreateLedger => l10n.closingAgentConfirmCreateLedger,
      ProposalTool.proposeStatement => l10n.shareStatement,
      _ => l10n.closingAgentConfirmDebt,
    };
  }

  String? helperText(AppLocalizations l10n) {
    final name = spokenDisplayName(l10n);
    if (contactAlreadyExists) {
      return l10n.closingAgentContactAlreadyExists(name);
    }
    if (needsLedgerName && (ledgerName == null || ledgerName!.trim().isEmpty)) {
      return l10n.closingAgentNoLedgerHelper;
    }
    if (createIfMissing) {
      return l10n.closingAgentUnknownContactHelper(name);
    }
    if (showCreateNewChip &&
        needsContact &&
        (effectiveContactId == null || effectiveContactId!.isEmpty)) {
      return l10n.closingAgentDidYouMean(name);
    }
    if (needsContact &&
        (effectiveContactId == null || effectiveContactId!.isEmpty)) {
      return l10n.closingAgentContactUnresolvedHelper;
    }
    if (contactUnresolved) {
      return l10n.closingAgentContactUnresolvedHelper;
    }
    if (needsLedger &&
        (effectiveLedgerId == null || effectiveLedgerId!.isEmpty)) {
      return l10n.closingAgentLedgerRequiredHelper;
    }
    if (needsCurrency &&
        (effectiveCurrencyCode == null || effectiveCurrencyCode!.isEmpty)) {
      return l10n.closingAgentCurrencyRequiredHelper;
    }
    return null;
  }

  String noteLabel(AppLocalizations l10n) {
    if (tool == ProposalTool.proposeDebt ||
        tool == ProposalTool.proposePayment) {
      final value = note?.trim() ?? '';
      if (value.isEmpty) {
        return '';
      }
      return '${l10n.closingAgentNoteLabel} $value';
    }
    if (tool != ProposalTool.proposeCreateLedger) {
      return note ?? '';
    }
    return switch ((note ?? 'customers').trim().toLowerCase()) {
      'suppliers' => l10n.closingAgentLedgerTypeSuppliers,
      'personal' => l10n.closingAgentLedgerTypePersonal,
      'custom' => l10n.closingAgentLedgerTypeCustom,
      _ => l10n.closingAgentLedgerTypeCustomers,
    };
  }
}

class _ConfirmChip extends StatelessWidget {
  const _ConfirmChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final border = isSelected
        ? AppColors.lapis400
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);
    final fill = isDark ? AppColors.surface3 : AppColors.surface2Light;

    return GestureDetector(
      onTap: () {
        unawaited(HapticService.selection());
        onTap();
      },
      child: DaftarTapTarget(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            border: Border.all(color: border, width: isSelected ? 1.5 : 0.5),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingMd,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: ink),
                    const SizedBox(width: AppDimensions.spacingXs),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.labelSmall.copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmVaultShell extends StatelessWidget {
  const _ConfirmVaultShell({
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg,
      cornerSmoothing: 0.6,
    );
    final glassBorder = isDark
        ? AppColors.glassBorder
        : AppColors.glassBorderLight;
    final specularRazor = isDark
        ? AppColors.specularRazorDark
        : AppColors.specularRazorLight;
    final gradientColors = isDark
        ? [AppColors.surface2, AppColors.surface0]
        : [AppColors.surface1Light, AppColors.surface0Light];

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(borderRadius: squircleRadius),
        shadows: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
      ),
      child: ClipSmoothRect(
        radius: squircleRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClosingAgentFadeDotMatrix(isDark: isDark),
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: AppDimensions.dividerThickness,
              child: ColoredBox(color: specularRazor),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                      borderRadius: squircleRadius,
                      side: BorderSide(
                        color: glassBorder,
                        width: AppDimensions.dividerThickness,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentBadge extends StatelessWidget {
  const _IntentBadge({
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final fill = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final border = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        border: Border.all(
          color: border,
          width: AppDimensions.dividerThickness,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: ink,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
