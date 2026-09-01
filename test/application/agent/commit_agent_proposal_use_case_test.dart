import 'dart:async';

import 'package:daftar/application/agent/agent_confirm_gate.dart';
import 'package:daftar/application/agent/append_day_journal_entry_use_case.dart';
import 'package:daftar/application/agent/cancel_agent_proposal_use_case.dart';
import 'package:daftar/application/agent/commit_agent_proposal_use_case.dart';
import 'package:daftar/application/agent/resolve_agent_contact_use_case.dart';
import 'package:daftar/application/agent/update_agent_turn_confirm_state_use_case.dart';
import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/contact/create_contact_use_case.dart';
import 'package:daftar/application/contact/get_contact_by_id_use_case.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/application/ledger/create_ledger_use_case.dart';
import 'package:daftar/application/ledger/get_ledgers_use_case.dart';
import 'package:daftar/application/transaction/add_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/enums/confirm_proposal_status.dart';
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAgentTurnRepository extends Mock implements AgentTurnRepository {}

class MockResolveAgentContactUseCase extends Mock
    implements ResolveAgentContactUseCase {}

class MockAddTransactionUseCase extends Mock implements AddTransactionUseCase {}

class MockCreateContactUseCase extends Mock implements CreateContactUseCase {}

class MockCreateLedgerUseCase extends Mock implements CreateLedgerUseCase {}

class MockAppendDayJournalEntryUseCase extends Mock
    implements AppendDayJournalEntryUseCase {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockGetLedgersUseCase extends Mock implements GetLedgersUseCase {}

class MockGetContactByIdUseCase extends Mock implements GetContactByIdUseCase {}

class MockSearchContactsUseCase extends Mock implements SearchContactsUseCase {}

void main() {
  final now = DateTime.utc(2026, 8, 13);

  setUpAll(() {
    registerFallbackValue(TransactionType.debt);
    registerFallbackValue(LedgerType.customers);
    registerFallbackValue(DayJournalKind.note);
    registerFallbackValue(AgentTurnConfirmState.none);
    registerFallbackValue(0);
    registerFallbackValue('');
    registerFallbackValue(
      DayJournalEntry(
        id: 'fallback-journal',
        localDay: '2026-08-13',
        kind: DayJournalKind.note,
        payloadJson: '{}',
        createdAt: now,
      ),
    );
  });

  late MockAgentTurnRepository turnRepository;
  late MockResolveAgentContactUseCase resolveContact;
  late MockAddTransactionUseCase addTransaction;
  late MockCreateContactUseCase createContact;
  late MockCreateLedgerUseCase createLedger;
  late MockAppendDayJournalEntryUseCase appendJournal;
  late MockSettingsRepository settingsRepository;
  late MockGetLedgersUseCase getLedgers;
  late CommitAgentProposalUseCase commitUseCase;
  late AgentTurn pendingTurn;
  late AgentTurn confirmedTurn;
  late Contact contact;
  late Transaction transaction;

  AgentProposal debtProposal() {
    return const AgentProposal(
      proposalId: 'proposal-1',
      tool: ProposalTool.proposeDebt,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.debt(
        contactHint: 'Mohamed',
        amountMinor: 500,
        currencyCode: 'YER',
        contactId: 'contact-1',
        ledgerId: 'ledger-1',
      ),
    );
  }

  AgentProposal paymentProposal() {
    return const AgentProposal(
      proposalId: 'proposal-pay',
      tool: ProposalTool.proposePayment,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.payment(
        contactHint: 'Mohamed',
        amountMinor: 200,
        currencyCode: 'YER',
        contactId: 'contact-1',
        ledgerId: 'ledger-1',
      ),
    );
  }

  AgentProposal createLedgerProposal({
    String name = 'Suppliers book',
    String? type = 'suppliers',
  }) {
    return AgentProposal(
      proposalId: 'proposal-ledger',
      tool: ProposalTool.proposeCreateLedger,
      confirmRequired: true,
      rawEnvelope: const {},
      payload: AgentProposalPayload.createLedger(name: name, type: type),
    );
  }

  AgentProposal createContactProposal({String? ledgerId}) {
    return AgentProposal(
      proposalId: 'proposal-contact',
      tool: ProposalTool.proposeCreateContact,
      confirmRequired: true,
      rawEnvelope: const {},
      payload: AgentProposalPayload.createContact(
        name: 'سامي',
        ledgerId: ledgerId,
      ),
    );
  }

  AgentProposal statementProposal() {
    return const AgentProposal(
      proposalId: 'proposal-statement',
      tool: ProposalTool.proposeStatement,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.statement(
        contactId: 'contact-1',
        contactHint: 'Mohamed',
      ),
    );
  }

  Ledger ledger(String id) {
    return Ledger(
      id: id,
      name: 'Ledger $id',
      type: LedgerType.customers,
      icon: 'book',
      color: '#111111',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  void stubCreateContactTurn() {
    when(
      () => turnRepository.findByProposalId('proposal-contact'),
    ).thenAnswer(
      (_) async => Right(
        pendingTurn.copyWith(
          proposalId: 'proposal-contact',
          toolName: ProposalTool.proposeCreateContact.wireName,
        ),
      ),
    );
    when(() => getLedgers.execute()).thenAnswer(
      (_) => Stream.value([ledger('ledger-1')]),
    );
  }

  void stubCreateContactWrite() {
    when(
      () => createContact.execute(
        ledgerId: any(named: 'ledgerId'),
        name: any(named: 'name'),
        phone: any(named: 'phone'),
        creditCurrency: any(named: 'creditCurrency'),
      ),
    ).thenAnswer((_) async => Right(contact));
  }

  setUp(() {
    turnRepository = MockAgentTurnRepository();
    resolveContact = MockResolveAgentContactUseCase();
    addTransaction = MockAddTransactionUseCase();
    createContact = MockCreateContactUseCase();
    createLedger = MockCreateLedgerUseCase();
    appendJournal = MockAppendDayJournalEntryUseCase();
    settingsRepository = MockSettingsRepository();
    getLedgers = MockGetLedgersUseCase();

    pendingTurn = AgentTurn(
      id: 'turn-1',
      sessionId: 'session-1',
      role: AgentTurnRole.tool,
      confirmState: AgentTurnConfirmState.pending,
      createdAt: now,
      updatedAt: now,
      proposalId: 'proposal-1',
      toolName: ProposalTool.proposeDebt.wireName,
    );
    confirmedTurn = pendingTurn.copyWith(
      confirmState: AgentTurnConfirmState.confirmed,
    );
    contact = Contact(
      id: 'contact-1',
      ledgerId: 'ledger-1',
      name: 'Mohamed',
      avatarColor: '#000000',
      createdAt: now,
      updatedAt: now,
    );
    transaction = Transaction(
      id: 'txn-1',
      contactId: contact.id,
      type: TransactionType.debt,
      amount: 500,
      currency: 'YER',
      transactionDate: now,
      createdAt: now,
      updatedAt: now,
    );

    commitUseCase = CommitAgentProposalUseCase(
      confirmGate: AgentConfirmGate(),
      agentTurnRepository: turnRepository,
      updateConfirmStateUseCase: UpdateAgentTurnConfirmStateUseCase(
        turnRepository,
      ),
      resolveAgentContactUseCase: resolveContact,
      addTransactionUseCase: addTransaction,
      createContactUseCase: createContact,
      createLedgerUseCase: createLedger,
      appendDayJournalEntryUseCase: appendJournal,
      settingsRepository: settingsRepository,
      getLedgersUseCase: getLedgers,
    );

    when(() => settingsRepository.get()).thenAnswer(
      (_) async => const Right(AppSettings()),
    );
    when(
      () => turnRepository.updateConfirmState(
        turnId: any(named: 'turnId'),
        confirmState: any(named: 'confirmState'),
      ),
    ).thenAnswer((_) async => Right(confirmedTurn));
    when(
      () => appendJournal.execute(
        localDay: any(named: 'localDay'),
        kind: any(named: 'kind'),
        payloadJson: any(named: 'payloadJson'),
        ledgerId: any(named: 'ledgerId'),
        contactId: any(named: 'contactId'),
        amount: any(named: 'amount'),
        currencyCode: any(named: 'currencyCode'),
        proposalId: any(named: 'proposalId'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer(
      (_) async => Right(
        DayJournalEntry(
          id: 'journal-1',
          localDay: '2026-08-13',
          kind: DayJournalKind.debtConfirmed,
          payloadJson: '{}',
          createdAt: now,
        ),
      ),
    );
  });

  group('CommitAgentProposalUseCase', () {
    test(
      'propose_debt writes AddTransactionUseCase and journals debtConfirmed',
      () async {
        when(
          () => turnRepository.findByProposalId('proposal-1'),
        ).thenAnswer((_) async => Right(pendingTurn));
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: any(named: 'contactHint'),
          ),
        ).thenAnswer((_) async => Right(contact));
        when(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).thenAnswer(
          (_) async => Right((
            transaction: transaction,
            warningLevel: CreditWarningLevel.none,
          )),
        );

        final result = await commitUseCase.execute(proposal: debtProposal());

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => addTransaction.execute(
            contactId: 'contact-1',
            type: TransactionType.debt,
            amount: 500,
            currency: 'YER',
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).called(1);
        verify(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: DayJournalKind.debtConfirmed,
            payloadJson: any(named: 'payloadJson'),
            ledgerId: any(named: 'ledgerId'),
            contactId: 'contact-1',
            amount: 500,
            currencyCode: 'YER',
            proposalId: 'proposal-1',
            sessionId: 'session-1',
          ),
        ).called(1);
      },
    );

    test('legacy note-only juice commits as itemName not description', () async {
      when(
        () => turnRepository.findByProposalId('proposal-1'),
      ).thenAnswer((_) async => Right(pendingTurn));
      when(
        () => resolveContact.execute(
          contactId: any(named: 'contactId'),
          contactHint: any(named: 'contactHint'),
        ),
      ).thenAnswer((_) async => Right(contact));
      when(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      ).thenAnswer(
        (_) async => Right((
          transaction: transaction,
          warningLevel: CreditWarningLevel.none,
        )),
      );

      const proposal = AgentProposal(
        proposalId: 'proposal-1',
        tool: ProposalTool.proposeDebt,
        confirmRequired: true,
        rawEnvelope: {},
        payload: AgentProposalPayload.debt(
          contactHint: 'Mohamed',
          amountMinor: 500,
          currencyCode: 'YER',
          contactId: 'contact-1',
          note: 'juice',
        ),
      );

      final result = await commitUseCase.execute(proposal: proposal);
      expect(
        result.getRight().toNullable()?.status,
        ConfirmProposalStatus.committed,
      );
      verify(
        () => addTransaction.execute(
          contactId: 'contact-1',
          type: TransactionType.debt,
          amount: 500,
          currency: 'YER',
          itemName: 'juice',
        ),
      ).called(1);
    });

    test('itemName plus remark commits both columns', () async {
      when(
        () => turnRepository.findByProposalId('proposal-1'),
      ).thenAnswer((_) async => Right(pendingTurn));
      when(
        () => resolveContact.execute(
          contactId: any(named: 'contactId'),
          contactHint: any(named: 'contactHint'),
        ),
      ).thenAnswer((_) async => Right(contact));
      when(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      ).thenAnswer(
        (_) async => Right((
          transaction: transaction,
          warningLevel: CreditWarningLevel.none,
        )),
      );

      const proposal = AgentProposal(
        proposalId: 'proposal-1',
        tool: ProposalTool.proposeDebt,
        confirmRequired: true,
        rawEnvelope: {},
        payload: AgentProposalPayload.debt(
          contactHint: 'Mohamed',
          amountMinor: 500,
          currencyCode: 'YER',
          contactId: 'contact-1',
          itemName: 'juice',
          note: 'he will pay Friday',
        ),
      );

      final result = await commitUseCase.execute(proposal: proposal);
      expect(
        result.getRight().toNullable()?.status,
        ConfirmProposalStatus.committed,
      );
      verify(
        () => addTransaction.execute(
          contactId: 'contact-1',
          type: TransactionType.debt,
          amount: 500,
          currency: 'YER',
          itemName: 'juice',
          description: 'he will pay Friday',
        ),
      ).called(1);
    });

    test(
      'propose_payment writes AddTransactionUseCase and journals paymentConfirmed',
      () async {
        when(
          () => turnRepository.findByProposalId('proposal-pay'),
        ).thenAnswer(
          (_) async => Right(
            pendingTurn.copyWith(
              proposalId: 'proposal-pay',
              toolName: ProposalTool.proposePayment.wireName,
            ),
          ),
        );
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: any(named: 'contactHint'),
          ),
        ).thenAnswer((_) async => Right(contact));
        when(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).thenAnswer(
          (_) async => Right((
            transaction: transaction.copyWith(
              type: TransactionType.payment,
              amount: 200,
            ),
            warningLevel: CreditWarningLevel.none,
          )),
        );

        final result = await commitUseCase.execute(proposal: paymentProposal());

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => addTransaction.execute(
            contactId: 'contact-1',
            type: TransactionType.payment,
            amount: 200,
            currency: 'YER',
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).called(1);
        verify(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: DayJournalKind.paymentConfirmed,
            payloadJson: any(named: 'payloadJson'),
            ledgerId: any(named: 'ledgerId'),
            contactId: 'contact-1',
            amount: 200,
            currencyCode: 'YER',
            proposalId: 'proposal-pay',
            sessionId: 'session-1',
          ),
        ).called(1);
      },
    );

    test('contactIdOverride is preferred over payload contactId', () async {
      when(
        () => turnRepository.findByProposalId('proposal-1'),
      ).thenAnswer((_) async => Right(pendingTurn));
      when(
        () => resolveContact.execute(
          contactId: 'contact-2',
          contactHint: any(named: 'contactHint'),
        ),
      ).thenAnswer(
        (_) async => Right(contact.copyWith(id: 'contact-2')),
      );
      when(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      ).thenAnswer(
        (_) async => Right((
          transaction: transaction,
          warningLevel: CreditWarningLevel.none,
        )),
      );

      final result = await commitUseCase.execute(
        proposal: debtProposal(),
        contactIdOverride: 'contact-2',
      );

      expect(
        result.getRight().toNullable()?.status,
        ConfirmProposalStatus.committed,
      );
      verify(
        () => resolveContact.execute(
          contactId: 'contact-2',
          contactHint: 'Mohamed',
        ),
      ).called(1);
    });

    test(
      'create-contact nameOverride and phoneOverride are persisted',
      () async {
        stubCreateContactTurn();
        stubCreateContactWrite();

        final result = await commitUseCase.execute(
          proposal: createContactProposal(ledgerId: 'ledger-1'),
          nameOverride: 'Ali',
          phoneOverride: '+967700000001',
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createContact.execute(
            ledgerId: 'ledger-1',
            name: 'Ali',
            phone: '+967700000001',
            creditCurrency: 'YER',
          ),
        ).called(1);
      },
    );

    test(
      'propose_create_ledger writes CreateLedgerUseCase and journals',
      () async {
        when(
          () => turnRepository.findByProposalId('proposal-ledger'),
        ).thenAnswer(
          (_) async => Right(
            pendingTurn.copyWith(
              proposalId: 'proposal-ledger',
              toolName: ProposalTool.proposeCreateLedger.wireName,
            ),
          ),
        );
        when(
          () => createLedger.execute(
            name: any(named: 'name'),
            type: any(named: 'type'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
          ),
        ).thenAnswer((_) async => Right(ledger('ledger-new')));

        final result = await commitUseCase.execute(
          proposal: createLedgerProposal(),
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createLedger.execute(
            name: 'Suppliers book',
            type: LedgerType.suppliers,
            icon: 'local_shipping_rounded',
            color: 0xFF64748B,
          ),
        ).called(1);
        verify(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: DayJournalKind.ledgerCreated,
            payloadJson: any(named: 'payloadJson'),
            ledgerId: 'ledger-new',
            contactId: any(named: 'contactId'),
            amount: any(named: 'amount'),
            currencyCode: any(named: 'currencyCode'),
            proposalId: 'proposal-ledger',
            sessionId: 'session-1',
          ),
        ).called(1);
      },
    );

    test(
      'propose_create_ledger empty name returns ledger_name_required',
      () async {
        when(
          () => turnRepository.findByProposalId('proposal-ledger'),
        ).thenAnswer(
          (_) async => Right(
            pendingTurn.copyWith(
              proposalId: 'proposal-ledger',
              toolName: ProposalTool.proposeCreateLedger.wireName,
            ),
          ),
        );
        when(
          () => createLedger.execute(
            name: any(named: 'name'),
            type: any(named: 'type'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ValidationFailure(
              'Ledger name is required.',
              code: 'ledger_name_required',
            ),
          ),
        );

        final result = await commitUseCase.execute(
          proposal: createLedgerProposal(name: '  '),
        );

        expect(result.getLeft().toNullable()?.code, 'ledger_name_required');
        verifyNever(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: any(named: 'kind'),
            payloadJson: any(named: 'payloadJson'),
            ledgerId: any(named: 'ledgerId'),
            contactId: any(named: 'contactId'),
            amount: any(named: 'amount'),
            currencyCode: any(named: 'currencyCode'),
            proposalId: any(named: 'proposalId'),
            sessionId: any(named: 'sessionId'),
          ),
        );
      },
    );

    test('propose_create_ledger entitlement left is forwarded', () async {
      when(
        () => turnRepository.findByProposalId('proposal-ledger'),
      ).thenAnswer(
        (_) async => Right(
          pendingTurn.copyWith(
            proposalId: 'proposal-ledger',
            toolName: ProposalTool.proposeCreateLedger.wireName,
          ),
        ),
      );
      when(
        () => createLedger.execute(
          name: any(named: 'name'),
          type: any(named: 'type'),
          icon: any(named: 'icon'),
          color: any(named: 'color'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          LimitExceededFailure(
            'Maximum number of ledgers reached.',
            featureKey: 'unlimitedLedgers',
            currentCount: 1,
            maxAllowed: 1,
          ),
        ),
      );

      final result = await commitUseCase.execute(
        proposal: createLedgerProposal(),
      );

      expect(result.getLeft().toNullable(), isA<LimitExceededFailure>());
    });

    test('propose_statement does not call AddTransactionUseCase', () async {
      when(
        () => turnRepository.findByProposalId('proposal-statement'),
      ).thenAnswer(
        (_) async => Right(
          pendingTurn.copyWith(
            proposalId: 'proposal-statement',
            toolName: ProposalTool.proposeStatement.wireName,
          ),
        ),
      );

      final result = await commitUseCase.execute(
        proposal: statementProposal(),
      );

      expect(
        result.getRight().toNullable()?.status,
        ConfirmProposalStatus.committed,
      );
      verifyNever(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      );
      verifyNever(
        () => appendJournal.execute(
          localDay: any(named: 'localDay'),
          kind: any(named: 'kind'),
          payloadJson: any(named: 'payloadJson'),
          ledgerId: any(named: 'ledgerId'),
          contactId: any(named: 'contactId'),
          amount: any(named: 'amount'),
          currencyCode: any(named: 'currencyCode'),
          proposalId: any(named: 'proposalId'),
          sessionId: any(named: 'sessionId'),
        ),
      );
    });

    test('second confirm is noopAlreadyCommitted', () async {
      var confirmed = false;
      when(() => turnRepository.findByProposalId('proposal-1')).thenAnswer((
        _,
      ) async {
        return Right(confirmed ? confirmedTurn : pendingTurn);
      });
      when(
        () => turnRepository.updateConfirmState(
          turnId: any(named: 'turnId'),
          confirmState: AgentTurnConfirmState.confirmed,
        ),
      ).thenAnswer((_) async {
        confirmed = true;
        return Right(confirmedTurn);
      });
      when(
        () => resolveContact.execute(
          contactId: any(named: 'contactId'),
          contactHint: any(named: 'contactHint'),
        ),
      ).thenAnswer((_) async => Right(contact));
      when(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      ).thenAnswer(
        (_) async => Right((
          transaction: transaction,
          warningLevel: CreditWarningLevel.none,
        )),
      );

      final first = await commitUseCase.execute(proposal: debtProposal());
      final second = await commitUseCase.execute(proposal: debtProposal());

      expect(
        first.getRight().toNullable()?.status,
        ConfirmProposalStatus.committed,
      );
      expect(
        second.getRight().toNullable()?.status,
        ConfirmProposalStatus.noopAlreadyCommitted,
      );
      verify(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      ).called(1);
      verify(
        () => appendJournal.execute(
          localDay: any(named: 'localDay'),
          kind: any(named: 'kind'),
          payloadJson: any(named: 'payloadJson'),
          ledgerId: any(named: 'ledgerId'),
          contactId: any(named: 'contactId'),
          amount: any(named: 'amount'),
          currencyCode: any(named: 'currencyCode'),
          proposalId: any(named: 'proposalId'),
          sessionId: any(named: 'sessionId'),
        ),
      ).called(1);
    });

    test(
      'create-contact with two ledgers and no ledgerId returns ledger_required',
      () async {
        final proposal = createContactProposal();
        when(
          () => turnRepository.findByProposalId('proposal-contact'),
        ).thenAnswer(
          (_) async => Right(
            pendingTurn.copyWith(
              proposalId: 'proposal-contact',
              toolName: ProposalTool.proposeCreateContact.wireName,
            ),
          ),
        );
        when(() => getLedgers.execute()).thenAnswer(
          (_) => Stream.value([ledger('ledger-a'), ledger('ledger-b')]),
        );

        final result = await commitUseCase.execute(proposal: proposal);

        expect(result.getLeft().toNullable(), isA<ValidationFailure>());
        expect(result.getLeft().toNullable()?.code, 'ledger_required');
        verifyNever(
          () => createContact.execute(
            ledgerId: any(named: 'ledgerId'),
            name: any(named: 'name'),
            phone: any(named: 'phone'),
            creditCurrency: any(named: 'creditCurrency'),
          ),
        );
        verifyNever(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: any(named: 'kind'),
            payloadJson: any(named: 'payloadJson'),
            ledgerId: any(named: 'ledgerId'),
            contactId: any(named: 'contactId'),
            amount: any(named: 'amount'),
            currencyCode: any(named: 'currencyCode'),
            proposalId: any(named: 'proposalId'),
            sessionId: any(named: 'sessionId'),
          ),
        );
        verifyNever(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        );
      },
    );

    test(
      'parallel confirms: one committed, other rejected_in_flight',
      () async {
        final started = Completer<void>();
        final release = Completer<void>();
        var findCalls = 0;
        when(
          () => turnRepository.findByProposalId('proposal-1'),
        ).thenAnswer((_) async {
          findCalls++;
          if (!started.isCompleted) {
            started.complete();
          }
          await release.future;
          return Right(pendingTurn);
        });
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: any(named: 'contactHint'),
          ),
        ).thenAnswer((_) async => Right(contact));
        when(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).thenAnswer(
          (_) async => Right((
            transaction: transaction,
            warningLevel: CreditWarningLevel.none,
          )),
        );

        final firstFuture = commitUseCase.execute(proposal: debtProposal());
        await started.future;
        final second = await commitUseCase.execute(proposal: debtProposal());
        release.complete();
        final first = await firstFuture;

        expect(
          first.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        expect(
          second.getRight().toNullable()?.status,
          ConfirmProposalStatus.rejectedInFlight,
        );
        expect(findCalls, 1);
        verify(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).called(1);
      },
    );

    test(
      'create-contact with multi-currency off forces defaultCurrency',
      () async {
        stubCreateContactTurn();
        stubCreateContactWrite();

        final result = await commitUseCase.execute(
          proposal: createContactProposal(ledgerId: 'ledger-1'),
          currencyCodeOverride: 'SAR',
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createContact.execute(
            ledgerId: 'ledger-1',
            name: 'سامي',
            phone: any(named: 'phone'),
            creditCurrency: 'YER',
          ),
        ).called(1);
      },
    );

    test(
      'create-contact with multi-currency on and no override returns currency_required',
      () async {
        stubCreateContactTurn();
        when(() => settingsRepository.get()).thenAnswer(
          (_) async => const Right(
            AppSettings(isMultiCurrencyEnabled: true),
          ),
        );

        final result = await commitUseCase.execute(
          proposal: createContactProposal(ledgerId: 'ledger-1'),
        );

        expect(result.getLeft().toNullable(), isA<ValidationFailure>());
        expect(result.getLeft().toNullable()?.code, 'currency_required');
        verifyNever(
          () => createContact.execute(
            ledgerId: any(named: 'ledgerId'),
            name: any(named: 'name'),
            phone: any(named: 'phone'),
            creditCurrency: any(named: 'creditCurrency'),
          ),
        );
      },
    );

    test(
      'create-contact with multi-currency on persists override as creditCurrency',
      () async {
        stubCreateContactTurn();
        stubCreateContactWrite();
        when(() => settingsRepository.get()).thenAnswer(
          (_) async => const Right(
            AppSettings(isMultiCurrencyEnabled: true),
          ),
        );

        final result = await commitUseCase.execute(
          proposal: createContactProposal(ledgerId: 'ledger-1'),
          currencyCodeOverride: 'SAR',
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createContact.execute(
            ledgerId: 'ledger-1',
            name: 'سامي',
            phone: any(named: 'phone'),
            creditCurrency: 'SAR',
          ),
        ).called(1);
      },
    );

    test(
      'unknown-name money with createIfMissing writes contact then transaction',
      () async {
        const proposal = AgentProposal(
          proposalId: 'proposal-1',
          tool: ProposalTool.proposeDebt,
          confirmRequired: true,
          rawEnvelope: {},
          payload: AgentProposalPayload.debt(
            contactHint: 'Ghost',
            amountMinor: 500,
            currencyCode: 'YER',
          ),
        );
        when(
          () => turnRepository.findByProposalId('proposal-1'),
        ).thenAnswer((_) async => Right(pendingTurn));
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: 'Ghost',
          ),
        ).thenAnswer(
          (_) async => const Left(
            ValidationFailure(
              'Contact could not be resolved.',
              code: 'contact_unresolved',
            ),
          ),
        );
        when(() => getLedgers.execute()).thenAnswer(
          (_) => Stream.value([ledger('ledger-1')]),
        );
        stubCreateContactWrite();
        when(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).thenAnswer(
          (_) async => Right((
            transaction: transaction,
            warningLevel: CreditWarningLevel.none,
          )),
        );

        final result = await commitUseCase.execute(
          proposal: proposal,
          createIfMissing: true,
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createContact.execute(
            ledgerId: 'ledger-1',
            name: 'Ghost',
            phone: any(named: 'phone'),
            creditCurrency: 'YER',
          ),
        ).called(1);
        verify(
          () => addTransaction.execute(
            contactId: 'contact-1',
            type: TransactionType.debt,
            amount: 500,
            currency: 'YER',
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).called(1);
        verify(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: DayJournalKind.contactCreated,
            payloadJson: any(named: 'payloadJson'),
            ledgerId: 'ledger-1',
            contactId: 'contact-1',
            amount: any(named: 'amount'),
            currencyCode: any(named: 'currencyCode'),
            proposalId: 'proposal-1',
            sessionId: 'session-1',
          ),
        ).called(1);
        verify(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: DayJournalKind.debtConfirmed,
            payloadJson: any(named: 'payloadJson'),
            ledgerId: any(named: 'ledgerId'),
            contactId: 'contact-1',
            amount: 500,
            currencyCode: 'YER',
            proposalId: 'proposal-1',
            sessionId: 'session-1',
          ),
        ).called(1);
      },
    );

    test(
      'unknown-name money without createIfMissing does not write',
      () async {
        const proposal = AgentProposal(
          proposalId: 'proposal-1',
          tool: ProposalTool.proposeDebt,
          confirmRequired: true,
          rawEnvelope: {},
          payload: AgentProposalPayload.debt(
            contactHint: 'Ghost',
            amountMinor: 500,
            currencyCode: 'YER',
          ),
        );
        when(
          () => turnRepository.findByProposalId('proposal-1'),
        ).thenAnswer((_) async => Right(pendingTurn));
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: any(named: 'contactHint'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ValidationFailure(
              'Contact could not be resolved.',
              code: 'contact_unresolved',
            ),
          ),
        );

        final result = await commitUseCase.execute(proposal: proposal);

        expect(result.getLeft().toNullable()?.code, 'contact_unresolved');
        verifyNever(
          () => createContact.execute(
            ledgerId: any(named: 'ledgerId'),
            name: any(named: 'name'),
            phone: any(named: 'phone'),
            creditCurrency: any(named: 'creditCurrency'),
          ),
        );
        verifyNever(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        );
      },
    );

    test(
      'known-id money with createIfMissing still does not create a contact',
      () async {
        when(
          () => turnRepository.findByProposalId('proposal-1'),
        ).thenAnswer((_) async => Right(pendingTurn));
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: any(named: 'contactHint'),
          ),
        ).thenAnswer((_) async => Right(contact));
        when(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).thenAnswer(
          (_) async => Right((
            transaction: transaction,
            warningLevel: CreditWarningLevel.none,
          )),
        );

        final result = await commitUseCase.execute(
          proposal: debtProposal(),
          createIfMissing: true,
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verifyNever(
          () => createContact.execute(
            ledgerId: any(named: 'ledgerId'),
            name: any(named: 'name'),
            phone: any(named: 'phone'),
            creditCurrency: any(named: 'creditCurrency'),
          ),
        );
      },
    );

    test(
      'empty ledger name creates ledger then contact',
      () async {
        stubCreateContactTurn();
        stubCreateContactWrite();
        when(() => getLedgers.execute()).thenAnswer(
          (_) => Stream.value(const <Ledger>[]),
        );
        when(
          () => createLedger.execute(
            name: any(named: 'name'),
            type: any(named: 'type'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
          ),
        ).thenAnswer((_) async => Right(ledger('ledger-new')));

        final result = await commitUseCase.execute(
          proposal: createContactProposal(),
          ledgerNameOverride: 'Customers',
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createLedger.execute(
            name: 'Customers',
            type: LedgerType.customers,
            icon: 'people_alt_rounded',
            color: 0xFF64748B,
          ),
        ).called(1);
        verify(
          () => createContact.execute(
            ledgerId: 'ledger-new',
            name: 'سامي',
            phone: any(named: 'phone'),
            creditCurrency: 'YER',
          ),
        ).called(1);
        verify(
          () => appendJournal.execute(
            localDay: any(named: 'localDay'),
            kind: DayJournalKind.ledgerCreated,
            payloadJson: any(named: 'payloadJson'),
            ledgerId: 'ledger-new',
            contactId: any(named: 'contactId'),
            amount: any(named: 'amount'),
            currencyCode: any(named: 'currencyCode'),
            proposalId: 'proposal-contact',
            sessionId: 'session-1',
          ),
        ).called(1);
      },
    );

    test(
      'money createIfMissing with empty ledger name creates ledger then contact then txn',
      () async {
        const proposal = AgentProposal(
          proposalId: 'proposal-1',
          tool: ProposalTool.proposeDebt,
          confirmRequired: true,
          rawEnvelope: {},
          payload: AgentProposalPayload.debt(
            contactHint: 'Ghost',
            amountMinor: 500,
            currencyCode: 'YER',
          ),
        );
        when(
          () => turnRepository.findByProposalId('proposal-1'),
        ).thenAnswer((_) async => Right(pendingTurn));
        when(
          () => resolveContact.execute(
            contactId: any(named: 'contactId'),
            contactHint: any(named: 'contactHint'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ValidationFailure(
              'Contact could not be resolved.',
              code: 'contact_unresolved',
            ),
          ),
        );
        when(() => getLedgers.execute()).thenAnswer(
          (_) => Stream.value(const <Ledger>[]),
        );
        when(
          () => createLedger.execute(
            name: any(named: 'name'),
            type: any(named: 'type'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
          ),
        ).thenAnswer((_) async => Right(ledger('ledger-new')));
        stubCreateContactWrite();
        when(
          () => addTransaction.execute(
            contactId: any(named: 'contactId'),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            currency: any(named: 'currency'),
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).thenAnswer(
          (_) async => Right((
            transaction: transaction,
            warningLevel: CreditWarningLevel.none,
          )),
        );

        final result = await commitUseCase.execute(
          proposal: proposal,
          createIfMissing: true,
          ledgerNameOverride: 'Shop book',
          amountMinorOverride: 1000,
        );

        expect(
          result.getRight().toNullable()?.status,
          ConfirmProposalStatus.committed,
        );
        verify(
          () => createLedger.execute(
            name: 'Shop book',
            type: LedgerType.customers,
            icon: 'people_alt_rounded',
            color: 0xFF64748B,
          ),
        ).called(1);
        verify(
          () => addTransaction.execute(
            contactId: 'contact-1',
            type: TransactionType.debt,
            amount: 1000,
            currency: 'YER',
            description: any(named: 'description'),
            itemName: any(named: 'itemName'),
          ),
        ).called(1);
      },
    );
  });

  group('CancelAgentProposalUseCase', () {
    test('marks skipped and never writes money or journal', () async {
      final cancelUseCase = CancelAgentProposalUseCase(
        confirmGate: AgentConfirmGate(),
        agentTurnRepository: turnRepository,
        updateConfirmStateUseCase: UpdateAgentTurnConfirmStateUseCase(
          turnRepository,
        ),
      );
      when(
        () => turnRepository.findByProposalId('proposal-1'),
      ).thenAnswer((_) async => Right(pendingTurn));
      when(
        () => turnRepository.updateConfirmState(
          turnId: 'turn-1',
          confirmState: AgentTurnConfirmState.skipped,
        ),
      ).thenAnswer(
        (_) async => Right(
          pendingTurn.copyWith(confirmState: AgentTurnConfirmState.skipped),
        ),
      );

      final result = await cancelUseCase.execute(proposalId: 'proposal-1');

      expect(result.isRight(), isTrue);
      verify(
        () => turnRepository.updateConfirmState(
          turnId: 'turn-1',
          confirmState: AgentTurnConfirmState.skipped,
        ),
      ).called(1);
      verifyNever(
        () => addTransaction.execute(
          contactId: any(named: 'contactId'),
          type: any(named: 'type'),
          amount: any(named: 'amount'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          itemName: any(named: 'itemName'),
        ),
      );
      verifyNever(
        () => appendJournal.execute(
          localDay: any(named: 'localDay'),
          kind: any(named: 'kind'),
          payloadJson: any(named: 'payloadJson'),
          ledgerId: any(named: 'ledgerId'),
          contactId: any(named: 'contactId'),
          amount: any(named: 'amount'),
          currencyCode: any(named: 'currencyCode'),
          proposalId: any(named: 'proposalId'),
          sessionId: any(named: 'sessionId'),
        ),
      );
    });
  });

  group('ResolveAgentContactUseCase', () {
    late MockGetContactByIdUseCase getById;
    late MockSearchContactsUseCase search;
    late ResolveAgentContactUseCase resolve;

    setUp(() {
      getById = MockGetContactByIdUseCase();
      search = MockSearchContactsUseCase();
      resolve = ResolveAgentContactUseCase(
        getContactByIdUseCase: getById,
        searchContactsUseCase: search,
      );
    });

    test('0 or >1 search hits return contact_unresolved', () async {
      when(() => search.execute('Ali')).thenAnswer(
        (_) async => const Right([]),
      );
      final empty = await resolve.execute(contactHint: 'Ali');
      expect(empty.getLeft().toNullable()?.code, 'contact_unresolved');

      when(() => search.execute('Ali')).thenAnswer(
        (_) async => Right([
          ContactSearchHit(
            contact: contact,
            ledgerName: 'A',
            isLedgerUserArchived: false,
          ),
          ContactSearchHit(
            contact: contact.copyWith(id: 'contact-2'),
            ledgerName: 'B',
            isLedgerUserArchived: false,
          ),
        ]),
      );
      final many = await resolve.execute(contactHint: 'Ali');
      expect(many.getLeft().toNullable()?.code, 'contact_unresolved');
      verifyNever(() => getById.execute(any()));
    });

    test('exactly one search hit resolves the contact', () async {
      when(() => search.execute('Mohamed')).thenAnswer(
        (_) async => Right([
          ContactSearchHit(
            contact: contact,
            ledgerName: 'A',
            isLedgerUserArchived: false,
          ),
        ]),
      );
      final result = await resolve.execute(contactHint: 'Mohamed');
      expect(result.getRight().toNullable()?.id, 'contact-1');
    });

    test('unique prefix hit stays contact_unresolved', () async {
      when(() => search.execute('Mohammed')).thenAnswer(
        (_) async => Right([
          ContactSearchHit(
            contact: contact.copyWith(name: 'Mohammed Waleed'),
            ledgerName: 'A',
            isLedgerUserArchived: false,
          ),
        ]),
      );
      final result = await resolve.execute(contactHint: 'Mohammed');
      expect(result.getLeft().toNullable()?.code, 'contact_unresolved');
    });
  });
}
