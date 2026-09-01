import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_confirm_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};
  });

  tearDown(() {
    DeviceTts.debugSpeakOverride = null;
    DeviceTts.debugStopOverride = null;
    DeviceTts.debugReset();
    AgentSpeech.debugReset();
  });

  final now = DateTime.utc(2026, 8, 14);
  final ledger = Ledger(
    id: 'ledger-1',
    name: 'Customers',
    type: LedgerType.customers,
    icon: 'book',
    color: '#111111',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );

  const createContact = AgentProposal(
    proposalId: 'proposal-contact',
    tool: ProposalTool.proposeCreateContact,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.createContact(name: 'Sami'),
  );

  const debt = AgentProposal(
    proposalId: 'proposal-debt',
    tool: ProposalTool.proposeDebt,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.debt(
      contactHint: 'Mohamed',
      amountMinor: 500,
      currencyCode: 'YER',
      contactId: 'contact-1',
    ),
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required AgentProposal proposal,
    required bool isMultiCurrencyEnabled,
    String? selectedCurrencyCode,
    ValueChanged<String>? onCurrencySelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: proposal,
            ledgers: [ledger],
            currencies: BuiltInCurrencies.all,
            isMultiCurrencyEnabled: isMultiCurrencyEnabled,
            selectedCurrencyCode: selectedCurrencyCode,
            isConfirming: false,
            ttsMuted: true,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: onCurrencySelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  DaftarButton confirmButton(WidgetTester tester, String label) {
    return tester.widget<DaftarButton>(
      find.widgetWithText(DaftarButton, label),
    );
  }

  testWidgets(
    'create-contact hides currency chips when multi-currency is off',
    (tester) async {
      await pumpCard(
        tester,
        proposal: createContact,
        isMultiCurrencyEnabled: false,
      );

      expect(find.text('Choose a currency'), findsNothing);
      expect(find.text('YER'), findsNothing);
      expect(
        confirmButton(tester, 'Create account').onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'create-contact disables Confirm until a currency is tapped',
    (tester) async {
      var selected = '';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AgentConfirmCard(
                  proposal: createContact,
                  ledgers: [ledger],
                  currencies: BuiltInCurrencies.all,
                  isMultiCurrencyEnabled: true,
                  selectedCurrencyCode: selected.isEmpty ? null : selected,
                  isConfirming: false,
                  onConfirm: () {},
                  onSkip: () {},
                  onLedgerSelected: (_) {},
                  onCurrencySelected: (code) {
                    setState(() => selected = code);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Choose a currency'), findsOneWidget);
      expect(
        confirmButton(tester, 'Create account').onPressed,
        isNull,
      );
      expect(
        find.text('Choose a currency before creating this account.'),
        findsOneWidget,
      );

      await tester.tap(find.text('SAR'));
      await tester.pump();

      expect(
        confirmButton(tester, 'Create account').onPressed,
        isNotNull,
      );
      expect(
        find.text('Choose a currency before creating this account.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'debt Confirm does not show currency chips when multi-currency is on',
    (tester) async {
      await pumpCard(
        tester,
        proposal: debt,
        isMultiCurrencyEnabled: true,
      );

      expect(find.text('Choose a currency'), findsNothing);
      expect(confirmButton(tester, 'Record debt').onPressed, isNotNull);
    },
  );

  testWidgets('many name matches disable Confirm until a chip is tapped', (
    tester,
  ) async {
    const unresolvedDebt = AgentProposal(
      proposalId: 'proposal-debt',
      tool: ProposalTool.proposeDebt,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.debt(
        contactHint: 'Mohamed',
        amountMinor: 500,
        currencyCode: 'YER',
      ),
    );
    final hits = [
      ContactSearchHit(
        contact: Contact(
          id: 'contact-1',
          ledgerId: 'ledger-1',
          name: 'Mohamed Ali',
          avatarColor: '#000000',
          createdAt: now,
          updatedAt: now,
        ),
        ledgerName: 'Customers',
        isLedgerUserArchived: false,
      ),
      ContactSearchHit(
        contact: Contact(
          id: 'contact-2',
          ledgerId: 'ledger-2',
          name: 'Mohamed Hassan',
          avatarColor: '#000000',
          createdAt: now,
          updatedAt: now,
        ),
        ledgerName: 'Shop',
        isLedgerUserArchived: false,
      ),
    ];
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AgentConfirmCard(
                proposal: unresolvedDebt,
                ledgers: [ledger],
                candidates: hits,
                selectedContactId: selected.isEmpty ? null : selected,
                isConfirming: false,
                onConfirm: () {},
                onSkip: () {},
                onLedgerSelected: (_) {},
                onCurrencySelected: (_) {},
                onContactSelected: (id) => setState(() => selected = id),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Which account?'), findsOneWidget);
    expect(confirmButton(tester, 'Record debt').onPressed, isNull);
    await tester.tap(find.text('Mohamed Ali · Customers'));
    await tester.pump();
    expect(confirmButton(tester, 'Record debt').onPressed, isNotNull);
  });

  testWidgets('zero name matches enable Create & record with phone picker', (
    tester,
  ) async {
    const unresolvedDebt = AgentProposal(
      proposalId: 'proposal-debt',
      tool: ProposalTool.proposeDebt,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.debt(
        contactHint: 'Ghost',
        amountMinor: 500,
        currencyCode: 'YER',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: unresolvedDebt,
            ledgers: [ledger],
            onPickFromContacts: () {},
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      confirmButton(tester, 'Create & record debt').onPressed,
      isNotNull,
    );
    expect(
      find.text('No account named Ghost. Create it and record this amount?'),
      findsOneWidget,
    );
    expect(find.text('Import from Contacts'), findsOneWidget);
    expect(find.text('Record debt'), findsNothing);
  });

  testWidgets('phone picker callback updates displayed name and phone', (
    tester,
  ) async {
    var pickedName = '';
    var pickedPhone = '';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AgentConfirmCard(
                proposal: createContact,
                ledgers: [ledger],
                pickedName: pickedName.isEmpty ? null : pickedName,
                pickedPhone: pickedPhone.isEmpty ? null : pickedPhone,
                onPickFromContacts: () {
                  setState(() {
                    pickedName = 'Ali';
                    pickedPhone = '+967700000001';
                  });
                },
                isConfirming: false,
                onConfirm: () {},
                onSkip: () {},
                onLedgerSelected: (_) {},
                onCurrencySelected: (_) {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Sami'), findsOneWidget);
    await tester.tap(find.text('Import from Contacts'));
    await tester.pump();
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('+967700000001'), findsOneWidget);
    expect(confirmButton(tester, 'Create account').onPressed, isNotNull);
  });

  testWidgets('create-ledger Confirm is enabled', (tester) async {
    const createLedger = AgentProposal(
      proposalId: 'proposal-ledger',
      tool: ProposalTool.proposeCreateLedger,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.createLedger(
        name: 'Suppliers book',
        type: 'suppliers',
      ),
    );
    await pumpCard(
      tester,
      proposal: createLedger,
      isMultiCurrencyEnabled: false,
    );

    expect(find.text('Suppliers book'), findsOneWidget);
    expect(find.text('Create ledger'), findsOneWidget);
    expect(confirmButton(tester, 'Create ledger').onPressed, isNotNull);
  });

  testWidgets('statement with contactId enables Share Statement', (
    tester,
  ) async {
    const statement = AgentProposal(
      proposalId: 'proposal-statement',
      tool: ProposalTool.proposeStatement,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.statement(
        contactId: 'contact-1',
        contactHint: 'Mohamed',
      ),
    );
    await pumpCard(
      tester,
      proposal: statement,
      isMultiCurrencyEnabled: false,
    );

    expect(find.text('Statement for Mohamed'), findsOneWidget);
    expect(find.text('Share Statement'), findsOneWidget);
    expect(confirmButton(tester, 'Share Statement').onPressed, isNotNull);
  });

  testWidgets('statement UUID contactId is never shown or spoken', (
    tester,
  ) async {
    const id = '9135114a-bad1-4415-9ae6-ea4f8c66834f';
    const statement = AgentProposal(
      proposalId: 'proposal-statement-uuid',
      tool: ProposalTool.proposeStatement,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.statement(contactId: id),
    );
    AgentSpeech.debugReset();
    DeviceTts.debugReset();
    final spoken = <String>[];
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: statement,
            ledgers: [ledger],
            isConfirming: false,
            ttsLocale: 'en',
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(id), findsNothing);
    expect(find.textContaining(id), findsNothing);
    expect(find.text('Statement for this account'), findsOneWidget);
    expect(spoken, isNotEmpty);
    expect(spoken.single.contains(id), isFalse);
    expect(
      spoken.single,
      "I'll prepare a customer statement PDF for this account. "
      'Press Share Statement.',
    );
  });

  testWidgets('statement many chips disable Confirm until a chip is tapped', (
    tester,
  ) async {
    const statement = AgentProposal(
      proposalId: 'proposal-statement',
      tool: ProposalTool.proposeStatement,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.statement(
        contactHint: 'Mohamed',
      ),
    );
    final hits = [
      ContactSearchHit(
        contact: Contact(
          id: 'contact-1',
          ledgerId: 'ledger-1',
          name: 'Mohamed Ali',
          avatarColor: '#000000',
          createdAt: now,
          updatedAt: now,
        ),
        ledgerName: 'Customers',
        isLedgerUserArchived: false,
      ),
      ContactSearchHit(
        contact: Contact(
          id: 'contact-2',
          ledgerId: 'ledger-2',
          name: 'Mohamed Hassan',
          avatarColor: '#000000',
          createdAt: now,
          updatedAt: now,
        ),
        ledgerName: 'Shop',
        isLedgerUserArchived: false,
      ),
    ];
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AgentConfirmCard(
                proposal: statement,
                ledgers: [ledger],
                candidates: hits,
                selectedContactId: selected.isEmpty ? null : selected,
                isConfirming: false,
                onConfirm: () {},
                onSkip: () {},
                onLedgerSelected: (_) {},
                onCurrencySelected: (_) {},
                onContactSelected: (id) => setState(() => selected = id),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Which account?'), findsOneWidget);
    expect(confirmButton(tester, 'Share Statement').onPressed, isNull);
    await tester.tap(find.text('Mohamed Ali · Customers'));
    await tester.pump();
    expect(confirmButton(tester, 'Share Statement').onPressed, isNotNull);
  });

  testWidgets('statement zero hits disable Confirm', (tester) async {
    const statement = AgentProposal(
      proposalId: 'proposal-statement',
      tool: ProposalTool.proposeStatement,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.statement(contactHint: 'Ghost'),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: statement,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(confirmButton(tester, 'Share Statement').onPressed, isNull);
    expect(find.text('Resolve the account before recording.'), findsOneWidget);
  });

  testWidgets(
    'empty ledger requires a name before create-contact Confirm',
    (tester) async {
      var ledgerName = '';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AgentConfirmCard(
                  proposal: createContact,
                  ledgers: const [],
                  ledgerName: ledgerName.isEmpty ? null : ledgerName,
                  onLedgerNameChanged: (value) {
                    setState(() => ledgerName = value);
                  },
                  isConfirming: false,
                  onConfirm: () {},
                  onSkip: () {},
                  onLedgerSelected: (_) {},
                  onCurrencySelected: (_) {},
                );
              },
            ),
          ),
        ),
      );

      expect(
        find.text('There is no ledger yet. Name one to create it.'),
        findsOneWidget,
      );
      expect(find.text('Ledger name'), findsWidgets);
      expect(confirmButton(tester, 'Create account').onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Shop book');
      await tester.pump();

      expect(confirmButton(tester, 'Create account').onPressed, isNotNull);
    },
  );

  testWidgets(
    'unknown-name money with empty ledger requires a ledger name',
    (tester) async {
      const unresolvedDebt = AgentProposal(
        proposalId: 'proposal-debt',
        tool: ProposalTool.proposeDebt,
        confirmRequired: true,
        rawEnvelope: {},
        payload: AgentProposalPayload.debt(
          contactHint: 'Ghost',
          amountMinor: 500,
          currencyCode: 'YER',
        ),
      );
      var ledgerName = '';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AgentConfirmCard(
                  proposal: unresolvedDebt,
                  ledgers: const [],
                  ledgerName: ledgerName.isEmpty ? null : ledgerName,
                  onLedgerNameChanged: (value) {
                    setState(() => ledgerName = value);
                  },
                  isConfirming: false,
                  onConfirm: () {},
                  onSkip: () {},
                  onLedgerSelected: (_) {},
                  onCurrencySelected: (_) {},
                );
              },
            ),
          ),
        ),
      );

      expect(
        find.text('There is no ledger yet. Name one to create it.'),
        findsOneWidget,
      );
      expect(
        confirmButton(tester, 'Create & record debt').onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), 'Customers');
      await tester.pump();

      expect(
        confirmButton(tester, 'Create & record debt').onPressed,
        isNotNull,
      );
      expect(
        find.text('No account named Ghost. Create it and record this amount?'),
        findsOneWidget,
      );
    },
  );

  testWidgets('spoken amount override is displayed on the money card', (
    tester,
  ) async {
    const inflated = AgentProposal(
      proposalId: 'proposal-debt',
      tool: ProposalTool.proposeDebt,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.debt(
        contactHint: 'Mohamed',
        amountMinor: 10000,
        currencyCode: 'YER',
        contactId: 'contact-1',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: inflated,
            ledgers: [ledger],
            amountMinorOverride: 1000,
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('10,000'), findsNothing);
    expect(find.textContaining('1,000'), findsOneWidget);
  });

  testWidgets(
    'create-contact with two ledgers shows ledger chips without payload id',
    (tester) async {
      final shop = Ledger(
        id: 'ledger-2',
        name: 'Shop',
        type: LedgerType.customers,
        icon: 'store',
        color: '#222222',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentConfirmCard(
              proposal: createContact,
              ledgers: [ledger, shop],
              isConfirming: false,
              onConfirm: () {},
              onSkip: () {},
              onLedgerSelected: (_) {},
              onCurrencySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Choose a ledger'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(confirmButton(tester, 'Create account').onPressed, isNull);
    },
  );

  testWidgets(
    'ledgers still loading does not ask to name a new ledger',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentConfirmCard(
              proposal: createContact,
              ledgers: const [],
              ledgersReady: false,
              isConfirming: false,
              onConfirm: () {},
              onSkip: () {},
              onLedgerSelected: (_) {},
              onCurrencySelected: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text('There is no ledger yet. Name one to create it.'),
        findsNothing,
      );
      expect(find.text('Ledger name'), findsNothing);
      expect(confirmButton(tester, 'Create account').onPressed, isNull);
    },
  );

  testWidgets(
    'prefix-only unique hit requires a chip or Create new',
    (tester) async {
      const prefixDebt = AgentProposal(
        proposalId: 'proposal-debt',
        tool: ProposalTool.proposeDebt,
        confirmRequired: true,
        rawEnvelope: {},
        payload: AgentProposalPayload.debt(
          contactHint: 'Mohammed',
          amountMinor: 1000,
          currencyCode: 'YER',
        ),
      );
      final hits = [
        ContactSearchHit(
          contact: Contact(
            id: 'contact-waleed',
            ledgerId: 'ledger-1',
            name: 'Mohammed Waleed',
            avatarColor: '#000000',
            createdAt: now,
            updatedAt: now,
          ),
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ];
      var selected = '';
      var createNew = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AgentConfirmCard(
                  proposal: prefixDebt,
                  ledgers: [ledger],
                  candidates: hits,
                  selectedContactId: selected.isEmpty ? null : selected,
                  createNewSelected: createNew,
                  onCreateNewSelected: () => setState(() {
                    createNew = true;
                    selected = '';
                  }),
                  isConfirming: false,
                  onConfirm: () {},
                  onSkip: () {},
                  onLedgerSelected: (_) {},
                  onCurrencySelected: (_) {},
                  onContactSelected: (id) => setState(() {
                    selected = id;
                    createNew = false;
                  }),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Which account?'), findsOneWidget);
      expect(
        find.text(
          'Did you mean one of these, or create a new account named Mohammed?',
        ),
        findsOneWidget,
      );
      expect(find.text('Mohammed Waleed · Customers'), findsOneWidget);
      expect(find.text('Create “Mohammed”'), findsOneWidget);
      expect(confirmButton(tester, 'Record debt').onPressed, isNull);

      await tester.tap(find.text('Mohammed Waleed · Customers'));
      await tester.pump();
      expect(confirmButton(tester, 'Record debt').onPressed, isNotNull);
    },
  );

  testWidgets('Create new chip enables Create & record', (tester) async {
    const prefixDebt = AgentProposal(
      proposalId: 'proposal-debt',
      tool: ProposalTool.proposeDebt,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.debt(
        contactHint: 'Mohammed',
        amountMinor: 1000,
        currencyCode: 'YER',
      ),
    );
    final hits = [
      ContactSearchHit(
        contact: Contact(
          id: 'contact-waleed',
          ledgerId: 'ledger-1',
          name: 'Mohammed Waleed',
          avatarColor: '#000000',
          createdAt: now,
          updatedAt: now,
        ),
        ledgerName: 'Customers',
        isLedgerUserArchived: false,
      ),
    ];
    var createNew = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AgentConfirmCard(
                proposal: prefixDebt,
                ledgers: [ledger],
                candidates: hits,
                createNewSelected: createNew,
                onCreateNewSelected: () => setState(() => createNew = true),
                isConfirming: false,
                onConfirm: () {},
                onSkip: () {},
                onLedgerSelected: (_) {},
                onCurrencySelected: (_) {},
                onContactSelected: (_) {},
              );
            },
          ),
        ),
      ),
    );

    expect(confirmButton(tester, 'Record debt').onPressed, isNull);
    await tester.tap(find.text('Create “Mohammed”'));
    await tester.pump();
    expect(
      confirmButton(tester, 'Create & record debt').onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'exact unique full name auto-enables Confirm without chips',
    (tester) async {
      const exactDebt = AgentProposal(
        proposalId: 'proposal-debt',
        tool: ProposalTool.proposeDebt,
        confirmRequired: true,
        rawEnvelope: {},
        payload: AgentProposalPayload.debt(
          contactHint: 'Mohammed Waleed',
          amountMinor: 1000,
          currencyCode: 'YER',
        ),
      );
      final hits = [
        ContactSearchHit(
          contact: Contact(
            id: 'contact-waleed',
            ledgerId: 'ledger-1',
            name: 'Mohammed Waleed',
            avatarColor: '#000000',
            createdAt: now,
            updatedAt: now,
          ),
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentConfirmCard(
              proposal: exactDebt,
              ledgers: [ledger],
              candidates: hits,
              isConfirming: false,
              onConfirm: () {},
              onSkip: () {},
              onLedgerSelected: (_) {},
              onCurrencySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Which account?'), findsNothing);
      expect(confirmButton(tester, 'Record debt').onPressed, isNotNull);
    },
  );

  testWidgets('legacy note juice shows as Item Name not unlabeled note', (
    tester,
  ) async {
    const juiceDebt = AgentProposal(
      proposalId: 'proposal-debt',
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
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: juiceDebt,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('juice'), findsOneWidget);
    expect(find.text('Note juice'), findsNothing);
    expect(find.text('Item Name'), findsNothing);
  });

  testWidgets('itemName and remark show as item plus Note', (tester) async {
    const juiceDebt = AgentProposal(
      proposalId: 'proposal-debt',
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
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: juiceDebt,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('juice'), findsOneWidget);
    expect(find.text('Note he will pay Friday'), findsOneWidget);
    expect(find.text('Item Name'), findsNothing);
  });

  testWidgets('debt card speaks localized merchant line', (tester) async {
    AgentSpeech.debugReset();
    DeviceTts.debugReset();
    final spoken = <String>[];
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: debt,
            ledgers: [ledger],
            isConfirming: false,
            ttsLocale: 'en',
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      spoken,
      ["I'll record 500 riyals as a debt on Mohamed. Press Record debt."],
    );
  });

  testWidgets('dispose does not stop DeviceTts', (tester) async {
    var stops = 0;
    DeviceTts.debugStopOverride = () async {
      stops += 1;
    };
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};

    await pumpCard(
      tester,
      proposal: debt,
      isMultiCurrencyEnabled: false,
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    expect(stops, 0);
  });

  testWidgets(
    'create-contact shows contacts denied banner with Open Settings',
    (
      tester,
    ) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentConfirmCard(
              proposal: createContact,
              ledgers: [ledger],
              currencies: BuiltInCurrencies.all,
              isConfirming: false,
              contactsPermissionDenied: true,
              onPickFromContacts: () {},
              onOpenContactsSettings: () => opens++,
              onConfirm: () {},
              onSkip: () {},
              onLedgerSelected: (_) {},
              onCurrencySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Contacts access is off'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(opens, 1);
    },
  );

  testWidgets('vault card shows intent chip and footer amount with CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: debt,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Debt'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Record debt'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment intent chip differs from debt', (tester) async {
    const payment = AgentProposal(
      proposalId: 'proposal-payment',
      tool: ProposalTool.proposePayment,
      confirmRequired: true,
      rawEnvelope: {},
      payload: AgentProposalPayload.payment(
        contactHint: 'Mohamed',
        amountMinor: 500,
        currencyCode: 'YER',
        contactId: 'contact-1',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: payment,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Record payment'), findsOneWidget);
  });

  testWidgets('create-contact vault card shows new account intent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: createContact,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('New account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sami'), findsOneWidget);
  });

  testWidgets('vault card renders under RTL locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentConfirmCard(
            proposal: debt,
            ledgers: [ledger],
            isConfirming: false,
            onConfirm: () {},
            onSkip: () {},
            onLedgerSelected: (_) {},
            onCurrencySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('دين'), findsOneWidget);
    expect(find.text('تخطي'), findsOneWidget);
    expect(find.text('سجل الدين'), findsOneWidget);
  });

  testWidgets('vault card paints with reduce motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AgentConfirmCard(
              proposal: debt,
              ledgers: [ledger],
              isConfirming: false,
              onConfirm: () {},
              onSkip: () {},
              onLedgerSelected: (_) {},
              onCurrencySelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
