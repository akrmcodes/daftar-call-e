import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_capture_bundle_card.dart';
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
  final customersLedger = Ledger(
    id: 'ledger-customers',
    name: 'Customers',
    type: LedgerType.customers,
    icon: 'book',
    color: '#111111',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
  final suppliersLedger = Ledger(
    id: 'ledger-suppliers',
    name: 'Suppliers',
    type: LedgerType.suppliers,
    icon: 'book',
    color: '#222222',
    sortOrder: 1,
    createdAt: now,
    updatedAt: now,
  );

  const ledgerProposal = AgentProposal(
    proposalId: 'ledger-1',
    tool: ProposalTool.proposeCreateLedger,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.createLedger(name: 'Distributors'),
  );

  const contactProposal = AgentProposal(
    proposalId: 'contact-1',
    tool: ProposalTool.proposeCreateContact,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.createContact(name: 'Mohamed'),
  );

  const debtProposal = AgentProposal(
    proposalId: 'debt-1',
    tool: ProposalTool.proposeDebt,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.debt(
      contactHint: 'Mohamed',
      amountMinor: 50000,
      currencyCode: 'YER',
    ),
  );

  Future<void> pumpBundle(
    WidgetTester tester, {
    required bool isMultiCurrencyEnabled,
    VoidCallback? onConfirm,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentCaptureBundleCard(
            proposals: const [ledgerProposal, contactProposal, debtProposal],
            ledgers: [customersLedger, suppliersLedger],
            isMultiCurrencyEnabled: isMultiCurrencyEnabled,
            isConfirming: false,
            onConfirm: onConfirm ?? () {},
            onSkip: () {},
            onLedgerSelected: (_, _) {},
            onCurrencySelected: (_, _) {},
            onLedgerNameChanged: (_, _) {},
            onContactSelected: (_, _) {},
            onCreateNewSelected: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('compound bundle shows ledger, account once, and amount only', (
    tester,
  ) async {
    await pumpBundle(tester, isMultiCurrencyEnabled: false);
    await tester.pumpAndSettle();

    expect(find.text('Distributors'), findsNWidgets(2));
    expect(find.text('Mohamed'), findsOneWidget);
    expect(find.text('Customers'), findsNothing);
    expect(find.text('Suppliers'), findsNothing);
    expect(find.text('Choose a ledger'), findsNothing);
    expect(find.text('Choose a currency'), findsNothing);
    expect(
      find.widgetWithText(DaftarButton, 'Create & record debt'),
      findsOneWidget,
    );
  });

  testWidgets('confirm is enabled without picking an existing ledger', (
    tester,
  ) async {
    var confirms = 0;
    await pumpBundle(
      tester,
      isMultiCurrencyEnabled: false,
      onConfirm: () => confirms += 1,
    );
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(
      DaftarButton,
      'Create & record debt',
    );
    expect(tester.widget<DaftarButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pump();
    expect(confirms, 1);
  });

  testWidgets('shows one currency picker when multi-currency is enabled', (
    tester,
  ) async {
    await pumpBundle(tester, isMultiCurrencyEnabled: true);
    await tester.pumpAndSettle();

    expect(find.text('Choose a currency'), findsOneWidget);
    expect(find.text('Choose a ledger'), findsNothing);
  });
}
