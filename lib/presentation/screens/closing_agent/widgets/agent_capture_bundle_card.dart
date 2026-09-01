import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/agent/contact_name_match.dart';
import 'package:daftar/application/agent/group_capture_proposals.dart';
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
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// One Confirm card for a compound capture turn (ledger + contact + money).
class AgentCaptureBundleCard extends StatefulWidget {
  /// Creates a compound capture Confirm card.
  const AgentCaptureBundleCard({
    required this.proposals,
    required this.ledgers,
    required this.isConfirming,
    required this.onConfirm,
    required this.onSkip,
    required this.onLedgerSelected,
    required this.onCurrencySelected,
    required this.onLedgerNameChanged,
    required this.onContactSelected,
    required this.onCreateNewSelected,
    this.currencies = const [],
    this.isMultiCurrencyEnabled = false,
    this.ledgersReady = true,
    this.ledgerIdByProposal = const {},
    this.currencyCodeByProposal = const {},
    this.contactIdByProposal = const {},
    this.createNewByProposal = const {},
    this.candidatesByProposal = const {},
    this.ledgerNameByProposal = const {},
    this.amountMinorByProposal = const {},
    this.nameByProposal = const {},
    this.phoneByProposal = const {},
    this.ttsMuted = false,
    this.ttsLocale = 'ar',
    super.key,
  });

  /// Ordered capture proposals in the bundle.
  final List<AgentProposal> proposals;

  /// Active ledgers for pickers.
  final List<Ledger> ledgers;

  /// Built-in currency catalog.
  final List<Currency> currencies;

  /// When true, create steps require a currency tap.
  final bool isMultiCurrencyEnabled;

  /// False while [ledgers] is still loading.
  final bool ledgersReady;

  /// Ledger overrides keyed by proposal id.
  final Map<String, String> ledgerIdByProposal;

  /// Currency overrides keyed by proposal id.
  final Map<String, String> currencyCodeByProposal;

  /// Contact overrides keyed by proposal id.
  final Map<String, String> contactIdByProposal;

  /// Proposal ids where the merchant chose Create new.
  final Set<String> createNewByProposal;

  /// Name-search hits keyed by proposal id.
  final Map<String, List<ContactSearchHit>> candidatesByProposal;

  /// Ledger names keyed by proposal id.
  final Map<String, String> ledgerNameByProposal;

  /// Spoken-amount snap overrides keyed by proposal id.
  final Map<String, int> amountMinorByProposal;

  /// Phone-picker names keyed by proposal id.
  final Map<String, String> nameByProposal;

  /// Phone-picker phones keyed by proposal id.
  final Map<String, String> phoneByProposal;

  /// When true, skip on-device TTS for this card.
  final bool ttsMuted;

  /// Settings locale (`ar` / `en`) for TTS.
  final String ttsLocale;

  /// When true, the primary verb shows a spinner.
  final bool isConfirming;

  /// Commits the whole bundle.
  final VoidCallback onConfirm;

  /// Skips every pending proposal in the bundle.
  final VoidCallback onSkip;

  /// Called when the merchant picks a ledger for `proposalId`.
  final void Function(String proposalId, String ledgerId) onLedgerSelected;

  /// Called when the merchant picks a currency for `proposalId`.
  final void Function(String proposalId, String currencyCode) onCurrencySelected;

  /// Called when the merchant types a ledger name for `proposalId`.
  final void Function(String proposalId, String name) onLedgerNameChanged;

  /// Called when the merchant picks a contact for `proposalId`.
  final void Function(String proposalId, String contactId) onContactSelected;

  /// Called when the merchant chooses Create new for `proposalId`.
  final void Function(String proposalId) onCreateNewSelected;

  @override
  State<AgentCaptureBundleCard> createState() => _AgentCaptureBundleCardState();
}

class _AgentCaptureBundleCardState extends State<AgentCaptureBundleCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _breathController;
  Timer? _breathDelay;
  final Map<String, TextEditingController> _ledgerNameControllers = {};

  List<AgentProposal> get _ordered => orderCaptureProposals(widget.proposals);

  bool get _hasCreateLedger => _ordered.any(
    (proposal) => proposal.tool == ProposalTool.proposeCreateLedger,
  );

  bool get _hasCreateContact => _ordered.any(
    (proposal) => proposal.tool == ProposalTool.proposeCreateContact,
  );

  AgentProposal? get _createLedgerProposal {
    for (final proposal in _ordered) {
      if (proposal.tool == ProposalTool.proposeCreateLedger) {
        return proposal;
      }
    }
    return null;
  }

  String? get _pendingLedgerName {
    final proposal = _createLedgerProposal;
    if (proposal == null) {
      return null;
    }
    final typed =
        widget.ledgerNameByProposal[proposal.proposalId]?.trim() ??
        _ledgerNameControllers[proposal.proposalId]?.text.trim();
    if (typed != null && typed.isNotEmpty) {
      return typed;
    }
    return _ledgerName(proposal).isEmpty ? null : _ledgerName(proposal);
  }

  /// Currency picker belongs on the contact row when the bundle creates one.
  bool get _currencyOnContactRow => _hasCreateContact && widget.isMultiCurrencyEnabled;

  @override
  void initState() {
    super.initState();
    _syncLedgerControllers();
    _scheduleBreath();
    _speakReadback();
  }

  @override
  void didUpdateWidget(covariant AgentCaptureBundleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposals.map((p) => p.proposalId).join() !=
        widget.proposals.map((p) => p.proposalId).join()) {
      _breathDelay?.cancel();
      _breathController?.dispose();
      _breathController = null;
      _syncLedgerControllers();
      _scheduleBreath();
      _speakReadback();
    }
  }

  void _syncLedgerControllers() {
    for (final proposal in _ordered) {
      if (proposal.tool != ProposalTool.proposeCreateLedger) {
        continue;
      }
      final id = proposal.proposalId;
      final text = widget.ledgerNameByProposal[id] ?? _ledgerName(proposal);
      _ledgerNameControllers.putIfAbsent(
        id,
        () => TextEditingController(text: text),
      );
      if (_ledgerNameControllers[id]!.text != text) {
        _ledgerNameControllers[id]!.text = text;
      }
    }
  }

  void _speakReadback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.ttsMuted) {
        return;
      }
      final speechL10n = speechLocalizations(widget.ttsLocale);
      final line = captureBundleSpeakable(
        l10n: speechL10n,
        proposals: _ordered,
        cta: _ctaLabel(speechL10n),
        amountMinorByProposal: widget.amountMinorByProposal,
      );
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
    for (final controller in _ledgerNameControllers.values) {
      controller.dispose();
    }
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
    final confirmEnabled = _confirmEnabled(l10n) && !widget.isConfirming;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _IntentBadge(
              label: l10n.closingAgentConfirmAll,
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
        const Gap(AppDimensions.spacingMd),
        for (final proposal in _ordered) ...[
          _BundleFactRow(
            proposal: proposal,
            l10n: l10n,
            isDark: isDark,
            inkPrimary: inkPrimary,
            inkSecondary: inkSecondary,
            ledgers: widget.ledgers,
            ledgersReady: widget.ledgersReady,
            currencies: widget.currencies,
            isMultiCurrencyEnabled: widget.isMultiCurrencyEnabled,
            hasCreateLedger: _hasCreateLedger,
            hasCreateContact: _hasCreateContact,
            pendingLedgerName: _pendingLedgerName,
            showCurrencyPicker: _shouldShowCurrencyPicker(proposal),
            ledgerId: widget.ledgerIdByProposal[proposal.proposalId],
            currencyCode: widget.currencyCodeByProposal[proposal.proposalId],
            contactId: widget.contactIdByProposal[proposal.proposalId],
            createNewSelected: widget.createNewByProposal.contains(
              proposal.proposalId,
            ),
            candidates:
                widget.candidatesByProposal[proposal.proposalId] ?? const [],
            ledgerName:
                widget.ledgerNameByProposal[proposal.proposalId] ??
                _ledgerName(proposal),
            amountMinorOverride: widget.amountMinorByProposal[proposal.proposalId],
            pickedName: widget.nameByProposal[proposal.proposalId],
            ledgerNameController: _ledgerNameControllers[proposal.proposalId],
            onLedgerSelected: (ledgerId) {
              widget.onLedgerSelected(proposal.proposalId, ledgerId);
            },
            onCurrencySelected: (currencyCode) {
              widget.onCurrencySelected(proposal.proposalId, currencyCode);
            },
            onLedgerNameChanged: (name) {
              widget.onLedgerNameChanged(proposal.proposalId, name);
            },
            onContactSelected: (contactId) {
              widget.onContactSelected(proposal.proposalId, contactId);
            },
            onCreateNewSelected: () {
              widget.onCreateNewSelected(proposal.proposalId);
            },
          ),
          if (proposal != _ordered.last) const Gap(AppDimensions.spacingMd),
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
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DaftarButton(
            label: _ctaLabel(l10n),
            isLoading: widget.isConfirming,
            onPressed: confirmEnabled ? widget.onConfirm : null,
          ),
        ),
      ],
    );

    Widget card = _BundleVaultShell(isDark: isDark, child: content);

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

  bool _shouldShowCurrencyPicker(AgentProposal proposal) {
    if (!widget.isMultiCurrencyEnabled) {
      return false;
    }
    if (_currencyOnContactRow) {
      return proposal.tool == ProposalTool.proposeCreateContact;
    }
    return proposal.tool == ProposalTool.proposeDebt ||
        proposal.tool == ProposalTool.proposePayment;
  }

  String _ctaLabel(AppLocalizations l10n) {
    final hasContact = _ordered.any(
      (proposal) => proposal.tool == ProposalTool.proposeCreateContact,
    );
    final hasDebt = _ordered.any(
      (proposal) => proposal.tool == ProposalTool.proposeDebt,
    );
    final hasPayment = _ordered.any(
      (proposal) => proposal.tool == ProposalTool.proposePayment,
    );
    if (hasContact && hasDebt) {
      return l10n.closingAgentConfirmCreateAndRecordDebt;
    }
    if (hasContact && hasPayment) {
      return l10n.closingAgentConfirmCreateAndRecordPayment;
    }
    return l10n.closingAgentConfirmAll;
  }

  bool _confirmEnabled(AppLocalizations l10n) {
    for (final proposal in _ordered) {
      if (!_rowReady(proposal, l10n)) {
        return false;
      }
    }
    return true;
  }

  bool _rowReady(AgentProposal proposal, AppLocalizations l10n) {
    switch (proposal.payload) {
      case ProposeCreateLedgerPayload(:final name):
        final typed =
            widget.ledgerNameByProposal[proposal.proposalId]?.trim() ??
            _ledgerNameControllers[proposal.proposalId]?.text.trim() ??
            name.trim();
        return typed.isNotEmpty;
      case ProposeCreateContactPayload(:final ledgerId):
        if (widget.isMultiCurrencyEnabled && _currencyOnContactRow) {
          final currency =
              widget.currencyCodeByProposal[proposal.proposalId]?.trim();
          if (currency == null || currency.isEmpty) {
            return false;
          }
        }
        if (!_hasCreateLedger) {
          final ledgerFlags = _ledgerFlags(
            proposal: proposal,
            creating: true,
            payloadLedgerId: ledgerId,
          );
          if (ledgerFlags.needsLedgerName &&
              (widget.ledgerNameByProposal[proposal.proposalId]
                      ?.trim()
                      .isEmpty ??
                  true)) {
            return false;
          }
          if (ledgerFlags.needsLedger && ledgerFlags.effectiveLedgerId == null) {
            return false;
          }
        }
        final candidates =
            widget.candidatesByProposal[proposal.proposalId] ?? const [];
        if (candidates.isNotEmpty &&
            !widget.createNewByProposal.contains(proposal.proposalId)) {
          final unique = _uniqueExactHit(proposal, candidates);
          if (unique == null) {
            final picked =
                widget.contactIdByProposal[proposal.proposalId]?.trim();
            if (picked == null || picked.isEmpty) {
              return false;
            }
          }
        }
        return true;
      case ProposeDebtPayload(:final contactId, :final contactHint):
      case ProposePaymentPayload(:final contactId, :final contactHint):
        if (_hasCreateContact) {
          if (widget.isMultiCurrencyEnabled && !_currencyOnContactRow) {
            final currency =
                widget.currencyCodeByProposal[proposal.proposalId]?.trim();
            if (currency == null || currency.isEmpty) {
              return false;
            }
          }
          return true;
        }
        return _moneyReady(
          proposal,
          contactId: contactId,
          contactHint: contactHint,
        );
      case ProposeStatementPayload(:final contactId, :final contactHint):
        final picked = widget.contactIdByProposal[proposal.proposalId]?.trim();
        if (picked != null && picked.isNotEmpty) {
          return true;
        }
        final id = contactId.trim();
        if (id.isNotEmpty) {
          return true;
        }
        final candidates =
            widget.candidatesByProposal[proposal.proposalId] ?? const [];
        if (candidates.isEmpty) {
          return false;
        }
        return _uniqueExactHit(proposal, candidates, hint: contactHint) != null ||
            (widget.contactIdByProposal[proposal.proposalId]?.trim().isNotEmpty ??
                false);
      default:
        return false;
    }
  }

  bool _moneyReady(
    AgentProposal proposal, {
    required String? contactId,
    required String contactHint,
  }) {
    final createNew = widget.createNewByProposal.contains(proposal.proposalId);
    final picked = widget.contactIdByProposal[proposal.proposalId]?.trim();
    final payloadId = contactId?.trim();
    final candidates =
        widget.candidatesByProposal[proposal.proposalId] ?? const [];
    final unique = _uniqueExactHit(proposal, candidates, hint: contactHint);
    final bound =
        (picked != null && picked.isNotEmpty) ||
        (payloadId != null && payloadId.isNotEmpty) ||
        unique != null;
    final createIfMissing = !bound && (candidates.isEmpty || createNew);
    if (!bound && !createIfMissing) {
      return false;
    }
    if (createIfMissing) {
      if (widget.isMultiCurrencyEnabled && _shouldShowCurrencyPicker(proposal)) {
        final currency =
            widget.currencyCodeByProposal[proposal.proposalId]?.trim();
        if (currency == null || currency.isEmpty) {
          return false;
        }
      }
      if (!_hasCreateLedger) {
        final ledgerFlags = _ledgerFlags(proposal: proposal, creating: true);
        if (ledgerFlags.needsLedgerName &&
            (widget.ledgerNameByProposal[proposal.proposalId]?.trim().isEmpty ??
                true)) {
          return false;
        }
        if (ledgerFlags.needsLedger && ledgerFlags.effectiveLedgerId == null) {
          return false;
        }
      }
    }
    return true;
  }

  _LedgerCreateFlags _ledgerFlags({
    required AgentProposal proposal,
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
    final override = widget.ledgerIdByProposal[proposal.proposalId]?.trim();
    final fromPayload = payloadLedgerId?.trim();
    final effective = (override != null && override.isNotEmpty)
        ? override
        : (fromPayload != null && fromPayload.isNotEmpty)
        ? fromPayload
        : (widget.ledgers.length == 1 ? widget.ledgers.single.id : null);
    return _LedgerCreateFlags(
      needsLedger: effective == null,
      showLedgerPicker: effective == null && widget.ledgers.isNotEmpty,
      effectiveLedgerId: effective,
    );
  }

  ContactSearchHit? _uniqueExactHit(
    AgentProposal proposal,
    List<ContactSearchHit> candidates, {
    String? hint,
  }) {
    if (candidates.length != 1) {
      return null;
    }
    final spoken = switch (proposal.payload) {
      ProposeDebtPayload(:final contactHint) ||
      ProposePaymentPayload(:final contactHint) =>
        contactHint.trim(),
      ProposeStatementPayload(:final contactHint) =>
        contactHint?.trim() ?? '',
      _ => hint?.trim() ?? '',
    };
    if (spoken.isEmpty) {
      return null;
    }
    final hit = candidates.single;
    if (!isExactContactNameMatch(spoken, hit.contact.name)) {
      return null;
    }
    return hit;
  }

  String _ledgerName(AgentProposal proposal) {
    return switch (proposal.payload) {
      ProposeCreateLedgerPayload(:final name) => name.trim(),
      _ => '',
    };
  }
}

class _BundleFactRow extends StatelessWidget {
  const _BundleFactRow({
    required this.proposal,
    required this.l10n,
    required this.isDark,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.ledgers,
    required this.ledgersReady,
    required this.currencies,
    required this.isMultiCurrencyEnabled,
    required this.hasCreateLedger,
    required this.hasCreateContact,
    required this.showCurrencyPicker,
    required this.createNewSelected,
    required this.candidates,
    required this.onLedgerSelected,
    required this.onCurrencySelected,
    required this.onLedgerNameChanged,
    required this.onContactSelected,
    required this.onCreateNewSelected,
    this.pendingLedgerName,
    this.ledgerId,
    this.currencyCode,
    this.contactId,
    this.ledgerName,
    this.amountMinorOverride,
    this.pickedName,
    this.ledgerNameController,
  });

  final AgentProposal proposal;
  final AppLocalizations l10n;
  final bool isDark;
  final Color inkPrimary;
  final Color inkSecondary;
  final List<Ledger> ledgers;
  final bool ledgersReady;
  final List<Currency> currencies;
  final bool isMultiCurrencyEnabled;
  final bool hasCreateLedger;
  final bool hasCreateContact;
  final String? pendingLedgerName;
  final bool showCurrencyPicker;
  final String? ledgerId;
  final String? currencyCode;
  final String? contactId;
  final bool createNewSelected;
  final List<ContactSearchHit> candidates;
  final String? ledgerName;
  final int? amountMinorOverride;
  final String? pickedName;
  final TextEditingController? ledgerNameController;
  final ValueChanged<String> onLedgerSelected;
  final ValueChanged<String> onCurrencySelected;
  final ValueChanged<String> onLedgerNameChanged;
  final ValueChanged<String> onContactSelected;
  final VoidCallback onCreateNewSelected;

  @override
  Widget build(BuildContext context) {
    return switch (proposal.payload) {
      ProposeCreateLedgerPayload(:final name, :final type) => _ledgerRow(
        name: ledgerName ?? name,
        type: type,
        editable: ledgerNameController != null,
      ),
      ProposeCreateContactPayload(:final name, :final phone, :final ledgerId) =>
        _contactRow(name: pickedName ?? name, phone: phone, ledgerId: ledgerId),
      ProposeDebtPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
        :final contactId,
        :final note,
        :final itemName,
      ) =>
        _moneyRow(
          tool: ProposalTool.proposeDebt,
          contactHint: contactHint,
          contactId: contactId,
          amountMinor: amountMinorOverride ?? amountMinor,
          currencyCode: currencyCode,
          note: note,
          itemName: itemName,
        ),
      ProposePaymentPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
        :final contactId,
        :final note,
        :final itemName,
      ) =>
        _moneyRow(
          tool: ProposalTool.proposePayment,
          contactHint: contactHint,
          contactId: contactId,
          amountMinor: amountMinorOverride ?? amountMinor,
          currencyCode: currencyCode,
          note: note,
          itemName: itemName,
        ),
      ProposeStatementPayload(:final contactHint, :final contactId) => _statementRow(
        contactHint: contactHint ?? '',
        contactId: contactId,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _ledgerRow({
    required String name,
    required String? type,
    required bool editable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowHeader(l10n.closingAgentIntentLedger),
        const Gap(AppDimensions.spacingXxs),
        if (editable && ledgerNameController != null)
          DaftarTextField(
            controller: ledgerNameController,
            label: l10n.closingAgentIntentLedger,
            onChanged: onLedgerNameChanged,
          )
        else
          Text(
            name,
            style: AppTextStyles.titleMedium.copyWith(
              color: inkPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (type != null && type.trim().isNotEmpty) ...[
          const Gap(AppDimensions.spacingXxs),
          Text(
            _ledgerTypeLabel(type),
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
      ],
    );
  }

  Widget _contactRow({
    required String name,
    required String? phone,
    required String? ledgerId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowHeader(l10n.closingAgentIntentNewAccount),
        const Gap(AppDimensions.spacingXxs),
        Text(
          nonUuidHint(name) ?? name.trim(),
          style: AppTextStyles.titleMedium.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (phone?.trim().isNotEmpty == true) ...[
          const Gap(AppDimensions.spacingXxs),
          Text(
            phone!.trim(),
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
        if (hasCreateLedger &&
            pendingLedgerName != null &&
            pendingLedgerName!.trim().isNotEmpty) ...[
          const Gap(AppDimensions.spacingXxs),
          Text(
            pendingLedgerName!.trim(),
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
        ..._contactPickers(),
        if (!hasCreateLedger)
          ..._ledgerPickers(
            creating: true,
            payloadLedgerId: ledgerId,
          ),
        if (showCurrencyPicker) ..._currencyPickers(),
      ],
    );
  }

  Widget _moneyRow({
    required ProposalTool tool,
    required String contactHint,
    required String? contactId,
    required int amountMinor,
    required String currencyCode,
    String? note,
    String? itemName,
  }) {
    final goods = resolveAgentMoneyGoods(itemName: itemName, note: note);
    final amountLabel = MoneyUtil.formatMinorUnitsForCode(
      amountMinor,
      currencyCode,
    );
    final amountColor = switch (tool) {
      ProposalTool.proposeDebt =>
        isDark ? AppColors.debt : AppColors.debtLight,
      ProposalTool.proposePayment =>
        isDark ? AppColors.payment : AppColors.paymentLight,
      _ => inkPrimary,
    };
    final intent = switch (tool) {
      ProposalTool.proposeDebt => l10n.closingAgentIntentDebt,
      ProposalTool.proposePayment => l10n.closingAgentIntentPayment,
      _ => '',
    };
    final party = pickedName ?? nonUuidHint(contactHint) ?? contactHint.trim();
    final createIfMissing = !hasCreateContact && (candidates.isEmpty || createNewSelected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasCreateContact) ...[
          _rowHeader(intent),
          const Gap(AppDimensions.spacingXxs),
          Text(
            party,
            style: AppTextStyles.titleMedium.copyWith(
              color: inkPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else
          _rowHeader(intent),
        if (goods.itemName != null && goods.itemName!.isNotEmpty) ...[
          const Gap(AppDimensions.spacingXxs),
          Text(
            goods.itemName!,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ],
        if (!hasCreateContact) ..._contactPickers(),
        if (createIfMissing) ...[
          if (!hasCreateLedger)
            ..._ledgerPickers(creating: true),
          if (showCurrencyPicker) ..._currencyPickers(),
        ],
        const Gap(AppDimensions.spacingSm),
        Text(
          amountLabel,
          textDirection: TextDirection.ltr,
          style: AppTextStyles.amountLarge.copyWith(color: amountColor),
        ),
        Text(
          currencyCode,
          textDirection: TextDirection.ltr,
          style: AppTextStyles.labelSmall.copyWith(color: inkSecondary),
        ),
      ],
    );
  }

  Widget _statementRow({
    required String contactHint,
    required String contactId,
  }) {
    final party = nonUuidHint(contactHint) ?? contactHint.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowHeader(l10n.closingAgentIntentStatement),
        const Gap(AppDimensions.spacingXxs),
        Text(
          party.isNotEmpty ? party : contactId,
          style: AppTextStyles.titleMedium.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        ..._contactPickers(),
      ],
    );
  }

  Widget _rowHeader(String label) {
    return Text(
      label,
      style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
    );
  }

  String _ledgerTypeLabel(String type) {
    return switch (type.trim().toLowerCase()) {
      'suppliers' => l10n.closingAgentLedgerTypeSuppliers,
      'personal' => l10n.closingAgentLedgerTypePersonal,
      'custom' => l10n.closingAgentLedgerTypeCustom,
      _ => l10n.closingAgentLedgerTypeCustomers,
    };
  }

  List<Widget> _contactPickers() {
    if (candidates.isEmpty) {
      return const [];
    }
    final hint = switch (proposal.payload) {
      ProposeDebtPayload(:final contactHint) ||
      ProposePaymentPayload(:final contactHint) =>
        contactHint.trim(),
      ProposeStatementPayload(:final contactHint) =>
        contactHint?.trim() ?? '',
      ProposeCreateContactPayload(:final name) => name.trim(),
      _ => '',
    };
    final unique =
        candidates.length == 1 && isExactContactNameMatch(hint, candidates.single.contact.name);
    if (unique) {
      return const [];
    }
    return [
      const Gap(AppDimensions.spacingSm),
      Text(
        l10n.closingAgentWhichContact,
        style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
      ),
      const Gap(AppDimensions.spacingSm),
      SizedBox(
        height: AppDimensions.minTapTarget,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: candidates.length + 1,
          itemBuilder: (context, index) {
            if (index >= candidates.length) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.spacingSm,
                ),
                child: _BundleChip(
                  label: l10n.closingAgentCreateNewNamed(hint),
                  icon: Icons.person_add_rounded,
                  isSelected: createNewSelected,
                  isDark: isDark,
                  onTap: onCreateNewSelected,
                ),
              );
            }
            final hit = candidates[index];
            final selected = hit.contact.id == contactId;
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingSm,
              ),
              child: _BundleChip(
                label: _chipLabel(hit),
                isSelected: selected,
                isDark: isDark,
                onTap: () => onContactSelected(hit.contact.id),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _ledgerPickers({
    required bool creating,
    String? payloadLedgerId,
  }) {
    if (!creating || !ledgersReady || ledgers.isEmpty) {
      return const [];
    }
    final override = ledgerId?.trim();
    final fromPayload = payloadLedgerId?.trim();
    final effective = (override != null && override.isNotEmpty)
        ? override
        : (fromPayload != null && fromPayload.isNotEmpty)
        ? fromPayload
        : (ledgers.length == 1 ? ledgers.single.id : null);
    if (effective != null) {
      return const [];
    }
    return [
      const Gap(AppDimensions.spacingSm),
      Text(
        l10n.closingAgentSelectLedger,
        style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
      ),
      const Gap(AppDimensions.spacingSm),
      SizedBox(
        height: AppDimensions.minTapTarget,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: ledgers.length,
          itemBuilder: (context, index) {
            final ledger = ledgers[index];
            final selected = ledger.id == effective;
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingSm,
              ),
              child: _BundleChip(
                label: ledger.name,
                isSelected: selected,
                isDark: isDark,
                onTap: () => onLedgerSelected(ledger.id),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _currencyPickers() {
    return [
      const Gap(AppDimensions.spacingSm),
      Text(
        l10n.closingAgentSelectCurrency,
        style: AppTextStyles.labelMedium.copyWith(color: inkSecondary),
      ),
      const Gap(AppDimensions.spacingSm),
      SizedBox(
        height: AppDimensions.minTapTarget,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: currencies.length,
          itemBuilder: (context, index) {
            final currency = currencies[index];
            final selected = currency.code == currencyCode;
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.spacingSm,
              ),
              child: _BundleChip(
                label: currency.code,
                isSelected: selected,
                isDark: isDark,
                onTap: () => onCurrencySelected(currency.code),
              ),
            );
          },
        ),
      ),
    ];
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

class _BundleVaultShell extends StatelessWidget {
  const _BundleVaultShell({
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

class _BundleChip extends StatelessWidget {
  const _BundleChip({
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
