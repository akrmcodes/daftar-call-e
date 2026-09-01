import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_speakable_lines.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('confirm debt speaks intended write and CTA, not an echo', () {
    expect(
      confirmProposalSpeakable(
        l10n: en,
        tool: ProposalTool.proposeDebt,
        name: 'Mohamed',
        cta: en.closingAgentConfirmDebt,
        amountSpoken: spokenAmountLabel(
          l10n: en,
          amountMinor: 500,
          currencyCode: 'YER',
        ),
      ),
      "I'll record 500 riyals as a debt on Mohamed. Press Record debt.",
    );
    expect(
      confirmProposalSpeakable(
        l10n: ar,
        tool: ProposalTool.proposeDebt,
        name: 'محمد',
        cta: ar.closingAgentConfirmDebt,
        amountSpoken: spokenAmountLabel(
          l10n: ar,
          amountMinor: 500,
          currencyCode: 'YER',
        ),
      ),
      'سأسجل 500 ريال ديناً على محمد. اضغط سجل الدين.',
    );
  });

  test('create-if-missing debt names the missing account and create CTA', () {
    expect(
      confirmProposalSpeakable(
        l10n: en,
        tool: ProposalTool.proposeDebt,
        name: 'Mohamed',
        cta: en.closingAgentConfirmCreateAndRecordDebt,
        createIfMissing: true,
        amountSpoken: spokenAmountLabel(
          l10n: en,
          amountMinor: 500,
          currencyCode: 'YER',
        ),
      ),
      "There's no account named Mohamed. I'll create one and record a "
      '500 riyals debt. Press Create & record debt.',
    );
  });

  test('statement speakable never contains a UUID', () {
    const id = '9135114a-bad1-4415-9ae6-ea4f8c66834f';
    final spoken = confirmProposalSpeakable(
      l10n: en,
      tool: ProposalTool.proposeStatement,
      name: id,
      cta: en.shareStatement,
    );
    expect(spoken.contains(id), isFalse);
    expect(
      spoken,
      "I'll prepare a customer statement PDF for this account. "
      'Press Share Statement.',
    );
    expect(
      confirmProposalSpeakable(
        l10n: en,
        tool: ProposalTool.proposeStatement,
        name: 'Mohamed',
        cta: en.shareStatement,
      ),
      "I'll prepare a customer statement PDF for Mohamed. "
      'Press Share Statement.',
    );
  });

  test('named balance speakable uses owes / عليه and riyals', () {
    const row = AskBooksBalanceRow(
      contactId: 'c1',
      contactName: 'Mohamed',
      netBalance: -500,
      currencyCode: 'YER',
    );
    expect(
      askBooksSpeakable(const AskBooksNamedBalance(row), en),
      'Mohamed owes 500 riyals',
    );
    expect(
      askBooksSpeakable(
        const AskBooksNamedBalance(
          AskBooksBalanceRow(
            contactId: 'c1',
            contactName: 'محمد',
            netBalance: -500,
            currencyCode: 'YER',
          ),
        ),
        ar,
      ),
      'محمد عليه 500 ريال',
    );
  });

  test('overdue speakable caps at three names and adds an intro', () {
    AskBooksBalanceRow row(String id, String name, int net) {
      return AskBooksBalanceRow(
        contactId: id,
        contactName: name,
        netBalance: net,
        currencyCode: 'YER',
      );
    }

    final spoken = askBooksSpeakable(
      AskBooksOverdueList([
        row('a', 'Ali', -100),
        row('b', 'Bilal', -200),
        row('c', 'Cami', -300),
        row('d', 'Dina', -400),
      ]),
      en,
    );
    expect(
      spoken,
      '3 accounts are overdue. Ali owes 100 riyals. '
      'Bilal owes 200 riyals. Cami owes 300 riyals',
    );
    expect(spoken.contains('Dina'), isFalse);
  });

  test('last payment speakable includes currency word', () {
    final spoken = askBooksSpeakable(
      AskBooksLastTransaction(
        contactId: 'c1',
        contactName: 'Mohamed',
        amountMinor: 150,
        currencyCode: 'YER',
        transactionDate: DateTime.utc(2026, 8, 14),
        type: TransactionType.payment,
      ),
      en,
    );
    expect(spoken, 'Mohamed paid 150 riyals');
  });

  test('ambiguous ask speaks candidate names only', () {
    final now = DateTime.utc(2026, 8, 14);
    final spoken = askBooksSpeakable(
      AskBooksAmbiguous([
        ContactSearchHit(
          contact: Contact(
            id: '9135114a-bad1-4415-9ae6-ea4f8c66834f',
            ledgerId: 'l1',
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
            id: '2235114a-bad1-4415-9ae6-ea4f8c66834f',
            ledgerId: 'l2',
            name: 'Mohamed Hassan',
            avatarColor: '#000000',
            createdAt: now,
            updatedAt: now,
          ),
          ledgerName: 'Shop',
          isLedgerUserArchived: false,
        ),
      ]),
      en,
    );
    expect(spoken, 'Which account? Mohamed Ali, Mohamed Hassan.');
    expect(spoken.contains('9135114a'), isFalse);
    expect(spoken.contains('·'), isFalse);
  });
}
