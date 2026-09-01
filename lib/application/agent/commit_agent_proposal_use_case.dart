import 'dart:convert';

import 'package:daftar/application/agent/agent_confirm_gate.dart';
import 'package:daftar/application/agent/append_day_journal_entry_use_case.dart';
import 'package:daftar/application/agent/resolve_agent_contact_use_case.dart';
import 'package:daftar/application/agent/resolve_agent_money_goods.dart';
import 'package:daftar/application/agent/update_agent_turn_confirm_state_use_case.dart';
import 'package:daftar/application/contact/create_contact_use_case.dart';
import 'package:daftar/application/ledger/create_ledger_use_case.dart';
import 'package:daftar/application/ledger/get_ledgers_use_case.dart';
import 'package:daftar/application/transaction/add_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/confirm_proposal_status.dart';
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/confirm_proposal_result.dart';
import 'package:fpdart/fpdart.dart';

/// Confirms a proposal: money/contact writes + Day Journal + confirm-state.
class CommitAgentProposalUseCase {
  /// Creates the use case.
  const CommitAgentProposalUseCase({
    required AgentConfirmGate confirmGate,
    required AgentTurnRepository agentTurnRepository,
    required UpdateAgentTurnConfirmStateUseCase updateConfirmStateUseCase,
    required ResolveAgentContactUseCase resolveAgentContactUseCase,
    required AddTransactionUseCase addTransactionUseCase,
    required CreateContactUseCase createContactUseCase,
    required CreateLedgerUseCase createLedgerUseCase,
    required AppendDayJournalEntryUseCase appendDayJournalEntryUseCase,
    required SettingsRepository settingsRepository,
    required GetLedgersUseCase getLedgersUseCase,
  }) : _confirmGate = confirmGate,
       _agentTurnRepository = agentTurnRepository,
       _updateConfirmStateUseCase = updateConfirmStateUseCase,
       _resolveAgentContactUseCase = resolveAgentContactUseCase,
       _addTransactionUseCase = addTransactionUseCase,
       _createContactUseCase = createContactUseCase,
       _createLedgerUseCase = createLedgerUseCase,
       _appendDayJournalEntryUseCase = appendDayJournalEntryUseCase,
       _settingsRepository = settingsRepository,
       _getLedgersUseCase = getLedgersUseCase;

  final AgentConfirmGate _confirmGate;
  final AgentTurnRepository _agentTurnRepository;
  final UpdateAgentTurnConfirmStateUseCase _updateConfirmStateUseCase;
  final ResolveAgentContactUseCase _resolveAgentContactUseCase;
  final AddTransactionUseCase _addTransactionUseCase;
  final CreateContactUseCase _createContactUseCase;
  final CreateLedgerUseCase _createLedgerUseCase;
  final AppendDayJournalEntryUseCase _appendDayJournalEntryUseCase;
  final SettingsRepository _settingsRepository;
  final GetLedgersUseCase _getLedgersUseCase;

  /// Commits [proposal] by id.
  Future<Either<Failure, ConfirmProposalResult>> execute({
    required AgentProposal proposal,
    String? ledgerIdOverride,
    String? currencyCodeOverride,
    String? contactIdOverride,
    String? nameOverride,
    String? phoneOverride,
    String? ledgerNameOverride,
    int? amountMinorOverride,
    bool createIfMissing = false,
  }) async {
    final proposalId = proposal.proposalId.trim();
    if (proposalId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Proposal id is required.',
          code: 'proposal_id_required',
        ),
      );
    }

    return _confirmGate.runExclusive(
      proposalId: proposalId,
      onInFlight: () => ConfirmProposalResult(
        proposalId: proposalId,
        status: ConfirmProposalStatus.rejectedInFlight,
        message: 'Confirm already in flight for this proposal.',
      ),
      action: () => _commit(
        proposal: proposal,
        ledgerIdOverride: ledgerIdOverride,
        currencyCodeOverride: currencyCodeOverride,
        contactIdOverride: contactIdOverride,
        nameOverride: nameOverride,
        phoneOverride: phoneOverride,
        ledgerNameOverride: ledgerNameOverride,
        amountMinorOverride: amountMinorOverride,
        createIfMissing: createIfMissing,
      ),
    );
  }

  Future<Either<Failure, ConfirmProposalResult>> _commit({
    required AgentProposal proposal,
    required bool createIfMissing,
    String? ledgerIdOverride,
    String? currencyCodeOverride,
    String? contactIdOverride,
    String? nameOverride,
    String? phoneOverride,
    String? ledgerNameOverride,
    int? amountMinorOverride,
  }) async {
    final existing = await _agentTurnRepository.findByProposalId(
      proposal.proposalId,
    );
    if (existing.isLeft()) {
      return Left(existing.getLeft().toNullable()!);
    }
    final turn = existing.getRight().toNullable();
    if (turn == null) {
      return const Left(
        ValidationFailure(
          'Proposal turn not found.',
          code: 'proposal_not_found',
        ),
      );
    }
    if (turn.confirmState == AgentTurnConfirmState.confirmed) {
      return Right(
        ConfirmProposalResult(
          proposalId: proposal.proposalId,
          status: ConfirmProposalStatus.noopAlreadyCommitted,
          entityId: turn.id,
        ),
      );
    }

    final settingsResult = await _settingsRepository.get();
    if (settingsResult.isLeft()) {
      return Left(settingsResult.getLeft().toNullable()!);
    }
    final settings = settingsResult.getRight().toNullable()!;

    final writeResult = await _applyTool(
      proposal: proposal,
      turn: turn,
      settings: settings,
      ledgerIdOverride: ledgerIdOverride,
      currencyCodeOverride: currencyCodeOverride,
      contactIdOverride: contactIdOverride,
      nameOverride: nameOverride,
      phoneOverride: phoneOverride,
      ledgerNameOverride: ledgerNameOverride,
      amountMinorOverride: amountMinorOverride,
      createIfMissing: createIfMissing,
    );
    if (writeResult.isLeft()) {
      return Left(writeResult.getLeft().toNullable()!);
    }
    final entityId = writeResult.getRight().toNullable();

    final updated = await _updateConfirmStateUseCase.execute(
      turnId: turn.id,
      confirmState: AgentTurnConfirmState.confirmed,
    );
    if (updated.isLeft()) {
      return Left(updated.getLeft().toNullable()!);
    }

    return Right(
      ConfirmProposalResult(
        proposalId: proposal.proposalId,
        status: ConfirmProposalStatus.committed,
        entityId: entityId ?? turn.id,
      ),
    );
  }

  Future<Either<Failure, String?>> _applyTool({
    required AgentProposal proposal,
    required AgentTurn turn,
    required AppSettings settings,
    required bool createIfMissing,
    String? ledgerIdOverride,
    String? currencyCodeOverride,
    String? contactIdOverride,
    String? nameOverride,
    String? phoneOverride,
    String? ledgerNameOverride,
    int? amountMinorOverride,
  }) async {
    switch (proposal.payload) {
      case ProposeDebtPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
        :final contactId,
        :final note,
        :final itemName,
        :final ledgerId,
      ):
        return _commitMoney(
          proposal: proposal,
          turn: turn,
          settings: settings,
          type: TransactionType.debt,
          kind: DayJournalKind.debtConfirmed,
          contactHint: contactHint,
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          contactId: contactId,
          contactIdOverride: contactIdOverride,
          note: note,
          itemName: itemName,
          ledgerId: ledgerId,
          ledgerIdOverride: ledgerIdOverride,
          ledgerNameOverride: ledgerNameOverride,
          currencyCodeOverride: currencyCodeOverride,
          nameOverride: nameOverride,
          phoneOverride: phoneOverride,
          amountMinorOverride: amountMinorOverride,
          createIfMissing: createIfMissing,
        );
      case ProposePaymentPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
        :final contactId,
        :final note,
        :final itemName,
        :final ledgerId,
      ):
        return _commitMoney(
          proposal: proposal,
          turn: turn,
          settings: settings,
          type: TransactionType.payment,
          kind: DayJournalKind.paymentConfirmed,
          contactHint: contactHint,
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          contactId: contactId,
          contactIdOverride: contactIdOverride,
          note: note,
          itemName: itemName,
          ledgerId: ledgerId,
          ledgerIdOverride: ledgerIdOverride,
          ledgerNameOverride: ledgerNameOverride,
          currencyCodeOverride: currencyCodeOverride,
          nameOverride: nameOverride,
          phoneOverride: phoneOverride,
          amountMinorOverride: amountMinorOverride,
          createIfMissing: createIfMissing,
        );
      case ProposeCreateContactPayload(
        :final name,
        :final phone,
        :final ledgerId,
      ):
        return _commitCreateContact(
          proposal: proposal,
          turn: turn,
          settings: settings,
          name: name,
          phone: phone,
          ledgerId: ledgerId,
          ledgerIdOverride: ledgerIdOverride,
          currencyCodeOverride: currencyCodeOverride,
          nameOverride: nameOverride,
          phoneOverride: phoneOverride,
          ledgerNameOverride: ledgerNameOverride,
        );
      case ProposeClosingPlanPayload():
        final journal = await _appendJournal(
          kind: DayJournalKind.closingPlanConfirmed,
          proposal: proposal,
          turn: turn,
        );
        if (journal.isLeft()) {
          return Left(journal.getLeft().toNullable()!);
        }
        return Right(turn.id);
      case ProposeCreateLedgerPayload(:final name, :final type):
        return _commitCreateLedger(
          proposal: proposal,
          turn: turn,
          name: name,
          type: type,
        );
      case ParseGoalPayload():
      case ProposeStatementPayload():
      case GenericProposalPayload():
        return Right(turn.id);
    }
  }

  Future<Either<Failure, String?>> _commitMoney({
    required AgentProposal proposal,
    required AgentTurn turn,
    required AppSettings settings,
    required TransactionType type,
    required DayJournalKind kind,
    required String contactHint,
    required int amountMinor,
    required String currencyCode,
    required bool createIfMissing,
    String? contactId,
    String? contactIdOverride,
    String? note,
    String? itemName,
    String? ledgerId,
    String? ledgerIdOverride,
    String? ledgerNameOverride,
    String? currencyCodeOverride,
    String? nameOverride,
    String? phoneOverride,
    int? amountMinorOverride,
  }) async {
    final amount = amountMinorOverride ?? amountMinor;
    final resolved = await _resolveAgentContactUseCase.execute(
      contactId: _firstNonEmpty([contactIdOverride, contactId]),
      contactHint: contactHint,
    );

    late final Contact contact;
    if (resolved.isRight()) {
      contact = resolved.getRight().toNullable()!;
    } else {
      final failure = resolved.getLeft().toNullable()!;
      final unresolved =
          failure is ValidationFailure && failure.code == 'contact_unresolved';
      if (!createIfMissing || !unresolved) {
        return Left(failure);
      }
      final createdContact = await _createMissingContact(
        proposal: proposal,
        turn: turn,
        settings: settings,
        name: _firstNonEmpty([nameOverride, contactHint]) ?? '',
        phone: phoneOverride,
        payloadLedgerId: ledgerId,
        ledgerIdOverride: ledgerIdOverride,
        ledgerNameOverride: ledgerNameOverride,
        currencyCodeOverride: currencyCodeOverride,
        payloadCurrencyCode: currencyCode,
      );
      if (createdContact.isLeft()) {
        return Left(createdContact.getLeft().toNullable()!);
      }
      contact = createdContact.getRight().toNullable()!;
    }

    final currency = _currency(settings, currencyCodeOverride ?? currencyCode);
    final goods = resolveAgentMoneyGoods(itemName: itemName, note: note);

    final created = await _addTransactionUseCase.execute(
      contactId: contact.id,
      type: type,
      amount: amount,
      currency: currency,
      description: goods.note,
      itemName: goods.itemName,
    );
    if (created.isLeft()) {
      return Left(created.getLeft().toNullable()!);
    }
    final transaction = created.getRight().toNullable()!.transaction;

    final journal = await _appendJournal(
      kind: kind,
      proposal: proposal,
      turn: turn,
      contactId: contact.id,
      ledgerId: ledgerId ?? contact.ledgerId,
      amount: amount,
      currencyCode: currency,
      entityId: transaction.id,
    );
    if (journal.isLeft()) {
      return Left(journal.getLeft().toNullable()!);
    }
    return Right(transaction.id);
  }

  Future<Either<Failure, String?>> _commitCreateContact({
    required AgentProposal proposal,
    required AgentTurn turn,
    required AppSettings settings,
    required String name,
    String? phone,
    String? ledgerId,
    String? ledgerIdOverride,
    String? currencyCodeOverride,
    String? nameOverride,
    String? phoneOverride,
    String? ledgerNameOverride,
  }) async {
    final createdContact = await _createMissingContact(
      proposal: proposal,
      turn: turn,
      settings: settings,
      name: _firstNonEmpty([nameOverride, name]) ?? '',
      phone: _firstNonEmpty([phoneOverride, phone]),
      payloadLedgerId: ledgerId,
      ledgerIdOverride: ledgerIdOverride,
      ledgerNameOverride: ledgerNameOverride,
      currencyCodeOverride: currencyCodeOverride,
      payloadCurrencyCode: '',
      requireCurrencyTap: true,
    );
    if (createdContact.isLeft()) {
      return Left(createdContact.getLeft().toNullable()!);
    }
    return Right(createdContact.getRight().toNullable()!.id);
  }

  Future<Either<Failure, Contact>> _createMissingContact({
    required AgentProposal proposal,
    required AgentTurn turn,
    required AppSettings settings,
    required String name,
    required String payloadCurrencyCode,
    String? phone,
    String? payloadLedgerId,
    String? ledgerIdOverride,
    String? ledgerNameOverride,
    String? currencyCodeOverride,
    bool requireCurrencyTap = false,
  }) async {
    final resolvedLedger = await _resolveLedgerId(
      proposal: proposal,
      turn: turn,
      payloadLedgerId: payloadLedgerId,
      overrideLedgerId: ledgerIdOverride,
      ledgerNameOverride: ledgerNameOverride,
    );
    if (resolvedLedger.isLeft()) {
      return Left(resolvedLedger.getLeft().toNullable()!);
    }
    final ledger = resolvedLedger.getRight().toNullable()!;

    if (settings.isMultiCurrencyEnabled && requireCurrencyTap) {
      final override = currencyCodeOverride?.trim() ?? '';
      if (override.isEmpty) {
        return const Left(
          ValidationFailure(
            'Select a currency before creating this contact.',
            code: 'currency_required',
          ),
        );
      }
    }
    if (settings.isMultiCurrencyEnabled && !requireCurrencyTap) {
      final override = currencyCodeOverride?.trim() ?? '';
      final payload = payloadCurrencyCode.trim();
      if (override.isEmpty && payload.isEmpty) {
        return const Left(
          ValidationFailure(
            'Select a currency before creating this contact.',
            code: 'currency_required',
          ),
        );
      }
    }
    final creditCurrency = _currency(
      settings,
      currencyCodeOverride ?? payloadCurrencyCode,
    );

    final created = await _createContactUseCase.execute(
      ledgerId: ledger,
      name: name,
      phone: phone,
      creditCurrency: creditCurrency,
    );
    if (created.isLeft()) {
      return Left(created.getLeft().toNullable()!);
    }
    final contact = created.getRight().toNullable()!;

    final journal = await _appendJournal(
      kind: DayJournalKind.contactCreated,
      proposal: proposal,
      turn: turn,
      contactId: contact.id,
      ledgerId: ledger,
      entityId: contact.id,
    );
    if (journal.isLeft()) {
      return Left(journal.getLeft().toNullable()!);
    }
    return Right(contact);
  }

  Future<Either<Failure, String?>> _commitCreateLedger({
    required AgentProposal proposal,
    required AgentTurn turn,
    required String name,
    String? type,
  }) async {
    final ledgerType = _ledgerType(type);
    final created = await _createLedgerUseCase.execute(
      name: name,
      type: ledgerType,
      icon: _ledgerIcon(ledgerType),
      color: _ledgerColor,
    );
    if (created.isLeft()) {
      return Left(created.getLeft().toNullable()!);
    }
    final ledger = created.getRight().toNullable()!;

    final journal = await _appendJournal(
      kind: DayJournalKind.ledgerCreated,
      proposal: proposal,
      turn: turn,
      ledgerId: ledger.id,
      entityId: ledger.id,
    );
    if (journal.isLeft()) {
      return Left(journal.getLeft().toNullable()!);
    }
    return Right(ledger.id);
  }

  Future<Either<Failure, String>> _resolveLedgerId({
    required AgentProposal proposal,
    required AgentTurn turn,
    String? payloadLedgerId,
    String? overrideLedgerId,
    String? ledgerNameOverride,
  }) async {
    final override = overrideLedgerId?.trim();
    if (override != null && override.isNotEmpty) {
      return Right(override);
    }
    final payload = payloadLedgerId?.trim();
    if (payload != null && payload.isNotEmpty) {
      return Right(payload);
    }
    final ledgers = await _getLedgersUseCase.execute().first;
    if (ledgers.length == 1) {
      return Right(ledgers.single.id);
    }
    final name = ledgerNameOverride?.trim();
    if (name != null && name.isNotEmpty) {
      return _createLedgerFromName(
        proposal: proposal,
        turn: turn,
        name: name,
      );
    }
    return const Left(
      ValidationFailure(
        'Select a ledger before creating this contact.',
        code: 'ledger_required',
      ),
    );
  }

  Future<Either<Failure, String>> _createLedgerFromName({
    required AgentProposal proposal,
    required AgentTurn turn,
    required String name,
  }) async {
    final created = await _createLedgerUseCase.execute(
      name: name,
      type: LedgerType.customers,
      icon: _ledgerIcon(LedgerType.customers),
      color: _ledgerColor,
    );
    if (created.isLeft()) {
      return Left(created.getLeft().toNullable()!);
    }
    final ledger = created.getRight().toNullable()!;
    final journal = await _appendJournal(
      kind: DayJournalKind.ledgerCreated,
      proposal: proposal,
      turn: turn,
      ledgerId: ledger.id,
      entityId: ledger.id,
    );
    if (journal.isLeft()) {
      return Left(journal.getLeft().toNullable()!);
    }
    return Right(ledger.id);
  }

  Future<Either<Failure, DayJournalEntry>> _appendJournal({
    required DayJournalKind kind,
    required AgentProposal proposal,
    required AgentTurn turn,
    String? contactId,
    String? ledgerId,
    int? amount,
    String? currencyCode,
    String? entityId,
  }) {
    return _appendDayJournalEntryUseCase.execute(
      localDay: ClosingAgentConstants.merchantLocalDay(),
      kind: kind,
      payloadJson: jsonEncode(<String, Object?>{
        'proposalId': proposal.proposalId,
        'tool': proposal.tool.wireName,
        'entityId': entityId,
      }),
      ledgerId: ledgerId,
      contactId: contactId,
      amount: amount,
      currencyCode: currencyCode,
      proposalId: proposal.proposalId,
      sessionId: turn.sessionId,
    );
  }

  static String _currency(AppSettings settings, String proposed) {
    if (!settings.isMultiCurrencyEnabled) {
      return settings.defaultCurrency.trim().toUpperCase();
    }
    final trimmed = proposed.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return settings.defaultCurrency.trim().toUpperCase();
    }
    return trimmed;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static LedgerType _ledgerType(String? raw) {
    switch ((raw ?? 'customers').trim().toLowerCase()) {
      case 'suppliers':
        return LedgerType.suppliers;
      case 'personal':
        return LedgerType.personal;
      case 'custom':
        return LedgerType.custom;
      default:
        return LedgerType.customers;
    }
  }

  static String _ledgerIcon(LedgerType type) {
    return switch (type) {
      LedgerType.customers => 'people_alt_rounded',
      LedgerType.suppliers => 'local_shipping_rounded',
      LedgerType.personal => 'person_rounded',
      LedgerType.custom => 'folder_special_rounded',
    };
  }

  static const int _ledgerColor = 0xFF64748B;
}
