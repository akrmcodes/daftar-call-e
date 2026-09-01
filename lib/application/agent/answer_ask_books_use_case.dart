import 'dart:async';

import 'package:daftar/application/agent/ask_books_intent.dart';
import 'package:daftar/application/agent/contact_name_match.dart';
import 'package:daftar/application/agent/resolve_contact_hint_use_case.dart';
import 'package:daftar/application/ledger/select_contact_net_balance.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:fpdart/fpdart.dart';

/// Answers ask-the-books from Drift. Never uses model-invented amounts.
class AnswerAskBooksUseCase {
  /// Creates the use case.
  const AnswerAskBooksUseCase({
    required BalanceRepository balanceRepository,
    required ContactRepository contactRepository,
    required ResolveContactHintUseCase resolveContactHintUseCase,
    required TransactionRepository transactionRepository,
  }) : _balanceRepository = balanceRepository,
       _contactRepository = contactRepository,
       _resolveContactHintUseCase = resolveContactHintUseCase,
       _transactionRepository = transactionRepository;

  final BalanceRepository _balanceRepository;
  final ContactRepository _contactRepository;
  final ResolveContactHintUseCase _resolveContactHintUseCase;
  final TransactionRepository _transactionRepository;

  /// Conservative device classifier — capture goals with amounts stay capture.
  static bool looksLikeAsk(String goalText) {
    return classifyAsk(goalText) != null;
  }

  /// Name leftover after stripping named-ask phrasing, or null.
  static String? extractNameHint(String goalText) {
    return extractAskNameHint(goalText);
  }

  /// Returns Drift overdue, largest, named balance, or last txn.
  ///
  /// [forceAsk] is for `parse_goal(ask)`. [nameHint] is never FTS-searched raw;
  /// it is passed through [extractAskNameHint] like [goalText].
  Future<Either<Failure, AskBooksAnswer?>> execute({
    required String goalText,
    bool forceAsk = false,
    String? nameHint,
    String? lastContactId,
  }) async {
    final trimmed = goalText.trim();
    var intent = classifyAsk(trimmed);
    if (intent == null) {
      if (!forceAsk) {
        return const Right(null);
      }
      final notes = nameHint?.trim() ?? '';
      intent = classifyAsk(notes);
      if (intent == null) {
        if (_hasDigit(trimmed)) {
          return const Right(null);
        }
        intent = AskBooksIntent.namedBalance;
      }
    }

    if (intent == AskBooksIntent.overdueList) {
      return _outstandingList(AskBooksIntent.overdueList);
    }
    if (intent == AskBooksIntent.largestOutstanding) {
      return _outstandingList(AskBooksIntent.largestOutstanding);
    }
    if (intent == AskBooksIntent.smallestOutstanding) {
      return _outstandingList(AskBooksIntent.smallestOutstanding);
    }

    final raw = (nameHint != null && nameHint.trim().isNotEmpty)
        ? nameHint.trim()
        : trimmed;
    final hint = extractAskNameHint(raw);
    if (hint == null || hint.isEmpty) {
      final prior = lastContactId?.trim();
      if (prior != null && prior.isNotEmpty) {
        return _namedForContactId(prior, intent);
      }
      return const Right(AskBooksNeedName());
    }
    return _namedForHint(hint, intent);
  }

  /// Resolves a merchant-picked candidate to a named Drift balance.
  Future<Either<Failure, AskBooksAnswer>> balanceForContact(
    String contactId, {
    AskBooksIntent intent = AskBooksIntent.namedBalance,
  }) async {
    return _namedForContactId(contactId, intent);
  }

  Future<Either<Failure, AskBooksAnswer>> _namedForContactId(
    String contactId,
    AskBooksIntent intent,
  ) async {
    final contactResult = await _contactRepository.getById(contactId);
    if (contactResult.isLeft()) {
      return Left(contactResult.getLeft().toNullable()!);
    }
    final contact = contactResult.getRight().toNullable()!;
    return _answerForContact(contact, intent);
  }

  Future<Either<Failure, AskBooksAnswer>> _namedForHint(
    String hint,
    AskBooksIntent intent,
  ) async {
    final resolved = await _resolveContactHintUseCase.execute(hint);
    if (resolved.isLeft()) {
      return Left(resolved.getLeft().toNullable()!);
    }
    final hits = resolved.getRight().toNullable() ?? const <ContactSearchHit>[];
    if (hits.isEmpty) {
      return const Right(AskBooksUnresolved());
    }
    if (hits.length > 1) {
      return Right(AskBooksAmbiguous(hits));
    }
    if (!isExactContactNameMatch(hint, hits.single.contact.name)) {
      return Right(AskBooksAmbiguous(hits));
    }
    return _answerForContact(hits.single.contact, intent);
  }

  Future<Either<Failure, AskBooksAnswer>> _answerForContact(
    Contact contact,
    AskBooksIntent intent,
  ) {
    return switch (intent) {
      AskBooksIntent.lastPayment =>
        _lastTransaction(contact, TransactionType.payment),
      AskBooksIntent.lastDebt =>
        _lastTransaction(contact, TransactionType.debt),
      _ => _rowForContact(contact),
    };
  }

  Future<Either<Failure, AskBooksAnswer>> _lastTransaction(
    Contact contact,
    TransactionType type,
  ) async {
    final txns = await _transactionRepository.getByContact(
      contact.id,
      limit: 50,
    );
    if (txns.isLeft()) {
      return Left(txns.getLeft().toNullable()!);
    }
    final rows = txns.getRight().toNullable() ?? const [];
    for (final txn in rows) {
      if (txn.type != type) {
        continue;
      }
      return Right(
        AskBooksLastTransaction(
          contactId: contact.id,
          contactName: contact.name,
          amountMinor: txn.amount,
          currencyCode: txn.currency.trim().toUpperCase(),
          transactionDate: txn.transactionDate,
          type: type,
        ),
      );
    }
    return Right(
      AskBooksNoLastTransaction(
        contactId: contact.id,
        contactName: contact.name,
        type: type,
      ),
    );
  }

  Future<Either<Failure, AskBooksAnswer>> _outstandingList(
    AskBooksIntent intent,
  ) async {
    final balances = await _balanceRepository.watchAllBalances().first;
    final overdue = <ContactBalance>[
      for (final row in balances)
        if (row.netBalance < 0) row,
    ];
    if (overdue.isEmpty) {
      return Right(_emptyOutstanding(intent));
    }

    final names = <String, String>{};
    final rows = <AskBooksBalanceRow>[];
    for (final balance in overdue) {
      var name = names[balance.contactId];
      if (name == null) {
        final contactResult = await _contactRepository.getById(
          balance.contactId,
        );
        if (contactResult.isLeft()) {
          continue;
        }
        name = contactResult.getRight().toNullable()?.name.trim() ?? '';
        if (name.isEmpty) {
          continue;
        }
        names[balance.contactId] = name;
      }
      rows.add(
        AskBooksBalanceRow(
          contactId: balance.contactId,
          contactName: name,
          netBalance: balance.netBalance,
          currencyCode: balance.currencyCode.trim().toUpperCase(),
        ),
      );
    }
    final smallest = intent == AskBooksIntent.smallestOutstanding;
    rows.sort((left, right) {
      final byOwed = smallest
          ? left.owedMinor.compareTo(right.owedMinor)
          : right.owedMinor.compareTo(left.owedMinor);
      if (byOwed != 0) {
        return byOwed;
      }
      final byName = left.contactName.compareTo(right.contactName);
      if (byName != 0) {
        return byName;
      }
      return left.currencyCode.compareTo(right.currencyCode);
    });
    return Right(_outstandingAnswer(intent, rows));
  }

  static AskBooksAnswer _emptyOutstanding(AskBooksIntent intent) {
    return switch (intent) {
      AskBooksIntent.largestOutstanding => const AskBooksLargestOutstanding([]),
      AskBooksIntent.smallestOutstanding =>
        const AskBooksSmallestOutstanding([]),
      _ => const AskBooksOverdueList([]),
    };
  }

  static AskBooksAnswer _outstandingAnswer(
    AskBooksIntent intent,
    List<AskBooksBalanceRow> rows,
  ) {
    return switch (intent) {
      AskBooksIntent.largestOutstanding => AskBooksLargestOutstanding(rows),
      AskBooksIntent.smallestOutstanding => AskBooksSmallestOutstanding(rows),
      _ => AskBooksOverdueList(rows),
    };
  }

  Future<Either<Failure, AskBooksAnswer>> _rowForContact(Contact contact) async {
    final balancesResult = await _balanceRepository.getByContact(contact.id);
    if (balancesResult.isLeft()) {
      return Left(balancesResult.getLeft().toNullable()!);
    }
    final balances =
        balancesResult.getRight().toNullable() ?? const <ContactBalance>[];
    final net = selectContactNetBalance(contact, balances);
    final currency = selectContactDisplayCurrency(contact, balances);
    return Right(
      AskBooksNamedBalance(
        AskBooksBalanceRow(
          contactId: contact.id,
          contactName: contact.name,
          netBalance: net,
          currencyCode: currency.isEmpty ? 'YER' : currency,
        ),
      ),
    );
  }

  static bool _hasDigit(String text) {
    return RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]').hasMatch(text);
  }
}
