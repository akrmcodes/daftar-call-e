import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/speech_script_locale.dart';
import 'package:daftar/core/utils/tts_sanitize.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:flutter/widgets.dart';

/// Max overdue names spoken in one utterance.
const int askBooksSpokenOverdueCap = 3;

/// [AppLocalizations] for Chirp, independent of UI locale / RTL.
AppLocalizations speechLocalizations(String locale) {
  return lookupAppLocalizations(Locale(normalizeSpeechLocale(locale)));
}

/// Spoken major units plus currency word (`500 riyals` / `500 ريال`).
String spokenAmountLabel({
  required AppLocalizations l10n,
  required int amountMinor,
  required String currencyCode,
}) {
  final formatted = MoneyUtil.formatMinorUnitsForCode(
    amountMinor,
    currencyCode,
  );
  if (currencyCode.trim().toUpperCase() == 'USD') {
    return l10n.closingAgentSpeakDollars(formatted);
  }
  return l10n.closingAgentSpeakRiyals(formatted);
}

/// Clerk confirm line: intended write + real CTA. Never an echo of the request.
String confirmProposalSpeakable({
  required AppLocalizations l10n,
  required ProposalTool tool,
  required String name,
  required String cta,
  bool createIfMissing = false,
  String? amountSpoken,
  String? itemName,
}) {
  final party = _spokenParty(name, l10n);
  final button = cta.trim();
  final amount = amountSpoken?.trim() ?? '';
  final item = itemName?.trim() ?? '';
  switch (tool) {
    case ProposalTool.proposeDebt:
      if (amount.isEmpty) {
        return party;
      }
      if (createIfMissing) {
        return item.isEmpty
            ? l10n.closingAgentSpeakConfirmDebtCreate(party, amount, button)
            : l10n.closingAgentSpeakConfirmDebtCreateItem(
                party,
                amount,
                item,
                button,
              );
      }
      return item.isEmpty
          ? l10n.closingAgentSpeakConfirmDebt(amount, party, button)
          : l10n.closingAgentSpeakConfirmDebtItem(amount, party, item, button);
    case ProposalTool.proposePayment:
      if (amount.isEmpty) {
        return party;
      }
      if (createIfMissing) {
        return item.isEmpty
            ? l10n.closingAgentSpeakConfirmPaymentCreate(party, amount, button)
            : l10n.closingAgentSpeakConfirmPaymentCreateItem(
                party,
                amount,
                item,
                button,
              );
      }
      return item.isEmpty
          ? l10n.closingAgentSpeakConfirmPayment(amount, party, button)
          : l10n.closingAgentSpeakConfirmPaymentItem(
              amount,
              party,
              item,
              button,
            );
    case ProposalTool.proposeStatement:
      return l10n.closingAgentSpeakConfirmStatement(party, button);
    case ProposalTool.proposeCreateContact:
      return l10n.closingAgentSpeakConfirmCreateContact(party, button);
    case ProposalTool.proposeCreateLedger:
      return l10n.closingAgentSpeakConfirmCreateLedger(party, button);
    case ProposalTool.proposeClosingPlan:
    case ProposalTool.parseGoal:
    case ProposalTool.proposeWhatsappDrafts:
      return party;
  }
}

/// One spoken overview for a compound capture bundle.
String captureBundleSpeakable({
  required AppLocalizations l10n,
  required List<AgentProposal> proposals,
  required String cta,
  required Map<String, int> amountMinorByProposal,
}) {
  final lines = <String>[];
  for (final proposal in proposals) {
    switch (proposal.payload) {
      case ProposeCreateLedgerPayload(:final name):
        lines.add(
          confirmProposalSpeakable(
            l10n: l10n,
            tool: ProposalTool.proposeCreateLedger,
            name: name.trim(),
            cta: cta,
          ),
        );
      case ProposeCreateContactPayload(:final name):
        lines.add(
          confirmProposalSpeakable(
            l10n: l10n,
            tool: ProposalTool.proposeCreateContact,
            name: name.trim(),
            cta: cta,
          ),
        );
      case ProposeDebtPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
      ):
        final amount = amountMinorByProposal[proposal.proposalId] ?? amountMinor;
        lines.add(
          confirmProposalSpeakable(
            l10n: l10n,
            tool: ProposalTool.proposeDebt,
            name: contactHint.trim(),
            cta: cta,
            amountSpoken: spokenAmountLabel(
              l10n: l10n,
              amountMinor: amount,
              currencyCode: currencyCode,
            ),
          ),
        );
      case ProposePaymentPayload(
        :final contactHint,
        :final amountMinor,
        :final currencyCode,
      ):
        final amount = amountMinorByProposal[proposal.proposalId] ?? amountMinor;
        lines.add(
          confirmProposalSpeakable(
            l10n: l10n,
            tool: ProposalTool.proposePayment,
            name: contactHint.trim(),
            cta: cta,
            amountSpoken: spokenAmountLabel(
              l10n: l10n,
              amountMinor: amount,
              currencyCode: currencyCode,
            ),
          ),
        );
      case ProposeStatementPayload(:final contactHint, :final contactId):
        final hint = contactHint?.trim() ?? contactId.trim();
        lines.add(
          confirmProposalSpeakable(
            l10n: l10n,
            tool: ProposalTool.proposeStatement,
            name: hint,
            cta: cta,
          ),
        );
      default:
        break;
    }
  }
  if (lines.isEmpty) {
    return cta;
  }
  if (lines.length == 1) {
    return lines.single;
  }
  return '${lines.join('. ')}. $cta';
}

/// Spoken facts for an ask-the-books card. Empty when there is nothing to say.
String askBooksSpeakable(AskBooksAnswer answer, AppLocalizations l10n) {
  return switch (answer) {
    AskBooksNamedBalance(:final row) => _namedBalanceLine(row, l10n),
    AskBooksLastTransaction(
      :final contactName,
      :final amountMinor,
      :final currencyCode,
      :final type,
    ) =>
      type == TransactionType.payment
          ? l10n.closingAgentSpeakPayment(
              _spokenParty(contactName, l10n),
              spokenAmountLabel(
                l10n: l10n,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
              ),
            )
          : l10n.closingAgentSpeakDebt(
              _spokenParty(contactName, l10n),
              spokenAmountLabel(
                l10n: l10n,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
              ),
            ),
    AskBooksNoLastTransaction(:final contactName, :final type) =>
      type == TransactionType.payment
          ? l10n.closingAgentAskNoLastPayment(_spokenParty(contactName, l10n))
          : l10n.closingAgentAskNoLastDebt(_spokenParty(contactName, l10n)),
    AskBooksOverdueList(:final rows) => _overdueSpeakable(rows, l10n),
    AskBooksLargestOutstanding(:final rows) => _overdueSpeakable(rows, l10n),
    AskBooksSmallestOutstanding(:final rows) => _overdueSpeakable(rows, l10n),
    AskBooksAmbiguous(:final candidates) => _ambiguousSpeakable(
      candidates,
      l10n,
    ),
    AskBooksUnresolved() => l10n.closingAgentAskUnresolved,
    AskBooksNeedName() => l10n.closingAgentAskNeedName,
  };
}

String _spokenParty(String name, AppLocalizations l10n) {
  return nonUuidHint(name) ?? l10n.closingAgentSpeakThisAccount;
}

String _namedBalanceLine(AskBooksBalanceRow row, AppLocalizations l10n) {
  final name = _spokenParty(row.contactName, l10n);
  final amount = spokenAmountLabel(
    l10n: l10n,
    amountMinor: row.netBalance.abs(),
    currencyCode: row.currencyCode,
  );
  if (row.netBalance < 0) {
    return l10n.closingAgentSpeakBalance(name, amount);
  }
  if (row.netBalance > 0) {
    return l10n.closingAgentSpeakCredit(name, amount);
  }
  return l10n.closingAgentSpeakSettled(name);
}

String _overdueSpeakable(
  List<AskBooksBalanceRow> rows,
  AppLocalizations l10n,
) {
  if (rows.isEmpty) {
    return l10n.closingAgentAskEmpty;
  }
  final spokenRows = rows.take(askBooksSpokenOverdueCap).toList();
  final intro = l10n.closingAgentSpeakOverdueIntro(spokenRows.length);
  final facts = [
    for (final row in spokenRows)
      l10n.closingAgentSpeakBalance(
        _spokenParty(row.contactName, l10n),
        spokenAmountLabel(
          l10n: l10n,
          amountMinor: row.owedMinor,
          currencyCode: row.currencyCode,
        ),
      ),
  ].join('. ');
  return '$intro $facts';
}

String _ambiguousSpeakable(
  List<ContactSearchHit> candidates,
  AppLocalizations l10n,
) {
  final names = <String>[];
  for (final hit in candidates) {
    final name = nonUuidHint(hit.contact.name);
    if (name == null || names.contains(name)) {
      continue;
    }
    names.add(name);
  }
  if (names.isEmpty) {
    return l10n.closingAgentWhichContact;
  }
  return l10n.closingAgentSpeakWhichCandidates(names.join(', '));
}
