import 'package:daftar/application/agent/answer_ask_books_use_case.dart';
import 'package:daftar/application/agent/resolve_contact_hint_use_case.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockBalanceRepository extends Mock implements BalanceRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockSearchContactsUseCase extends Mock implements SearchContactsUseCase {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });
  final now = DateTime.utc(2026, 8, 14);
  final mohamed = Contact(
    id: 'contact-1',
    ledgerId: 'ledger-1',
    name: 'Mohamed',
    avatarColor: '#000000',
    createdAt: now,
    updatedAt: now,
    creditCurrency: 'YER',
  );

  ContactBalance balance({
    required String contactId,
    required int net,
    String currency = 'YER',
  }) {
    final debt = net < 0 ? -net : 0;
    final payment = net > 0 ? net : 0;
    return ContactBalance(
      contactId: contactId,
      currencyCode: currency,
      totalDebt: debt,
      totalPayment: payment,
      netBalance: net,
      lastUpdatedAt: now,
    );
  }

  late MockBalanceRepository balances;
  late MockContactRepository contacts;
  late MockSearchContactsUseCase search;
  late MockTransactionRepository transactions;
  late AnswerAskBooksUseCase useCase;

  setUp(() {
    balances = MockBalanceRepository();
    contacts = MockContactRepository();
    search = MockSearchContactsUseCase();
    transactions = MockTransactionRepository();
    useCase = AnswerAskBooksUseCase(
      balanceRepository: balances,
      contactRepository: contacts,
      resolveContactHintUseCase: ResolveContactHintUseCase(
        searchContactsUseCase: search,
      ),
      transactionRepository: transactions,
    );
  });

  group('looksLikeAsk', () {
    test('capture goals with amounts are not ask', () {
      expect(AnswerAskBooksUseCase.looksLikeAsk('Mohamed owes 500'), isFalse);
      expect(AnswerAskBooksUseCase.looksLikeAsk('عليه خمسمائة'), isFalse);
    });

    test('overdue phrasing is ask', () {
      expect(AnswerAskBooksUseCase.looksLikeAsk("who hasn't paid"), isTrue);
      expect(AnswerAskBooksUseCase.looksLikeAsk('من ما سدد'), isTrue);
      expect(AnswerAskBooksUseCase.looksLikeAsk('المتأخرين'), isTrue);
    });

    test('named balance phrasing without digits is ask', () {
      expect(
        AnswerAskBooksUseCase.looksLikeAsk("what's Mohamed's balance"),
        isTrue,
      );
      expect(AnswerAskBooksUseCase.looksLikeAsk('كم على محمد'), isTrue);
    });
  });

  test('overdue list keeps only netBalance < 0', () async {
    when(balances.watchAllBalances).thenAnswer(
      (_) => Stream.value([
        balance(contactId: 'contact-1', net: -500),
        balance(contactId: 'contact-2', net: 100),
        balance(contactId: 'contact-3', net: 0),
      ]),
    );
    when(() => contacts.getById('contact-1')).thenAnswer(
      (_) async => Right(mohamed),
    );

    final result = await useCase.execute(goalText: "who hasn't paid");
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksOverdueList>());
    final rows = (answer! as AskBooksOverdueList).rows;
    expect(rows, hasLength(1));
    expect(rows.single.contactId, 'contact-1');
    expect(rows.single.netBalance, -500);
    expect(rows.single.owedMinor, 500);
  });

  test('overdue list empty is success', () async {
    when(balances.watchAllBalances).thenAnswer(
      (_) => Stream.value([balance(contactId: 'contact-2', net: 100)]),
    );

    final result = await useCase.execute(goalText: 'overdue');
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksOverdueList>());
    expect((answer! as AskBooksOverdueList).rows, isEmpty);
  });

  test('named balance unique hit uses Drift net', () async {
    when(
      () => search.execute(
        'Mohamed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed,
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => Right([balance(contactId: 'contact-1', net: -200)]),
    );

    final result = await useCase.execute(
      goalText: "what's Mohamed's balance",
    );
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksNamedBalance>());
    expect((answer! as AskBooksNamedBalance).row.netBalance, -200);
  });

  test('named balance unique prefix hit is ambiguous', () async {
    when(
      () => search.execute(
        'Mohammed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed.copyWith(name: 'Mohammed Waleed'),
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );

    final result = await useCase.execute(
      goalText: "what's Mohammed's balance",
    );
    expect(result.getRight().toNullable(), isA<AskBooksAmbiguous>());
  });

  test('mutabaqi phrasing searches محمد leftover', () async {
    when(
      () => search.execute(
        'محمد',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed.copyWith(name: 'محمد'),
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => Right([balance(contactId: 'contact-1', net: -200)]),
    );

    final result = await useCase.execute(goalText: 'كم متبقي دين على محمد');
    expect(result.getRight().toNullable(), isA<AskBooksNamedBalance>());
  });

  test('named balance for وليد searches وليد not ليد', () async {
    final walid = mohamed.copyWith(id: 'contact-walid', name: 'وليد');
    when(
      () => search.execute(
        any(),
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as String;
      if (query == 'وليد') {
        return Right([
          ContactSearchHit(
            contact: walid,
            ledgerName: 'Customers',
            isLedgerUserArchived: false,
          ),
        ]);
      }
      return const Right([]);
    });
    when(() => balances.getByContact('contact-walid')).thenAnswer(
      (_) async => Right([balance(contactId: 'contact-walid', net: -300)]),
    );

    final result = await useCase.execute(goalText: 'كم على وليد');
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksNamedBalance>());
    expect((answer! as AskBooksNamedBalance).row.contactName, 'وليد');
    verifyNever(
      () => search.execute(
        'ليد',
        excludeUserArchivedLedgers: true,
      ),
    );
  });

  test('named balance many hits is ambiguous', () async {
    when(
      () => search.execute(
        'محمد',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed,
          ledgerName: 'A',
          isLedgerUserArchived: false,
        ),
        ContactSearchHit(
          contact: mohamed.copyWith(id: 'contact-2'),
          ledgerName: 'B',
          isLedgerUserArchived: false,
        ),
      ]),
    );

    final result = await useCase.execute(goalText: 'كم على محمد');
    expect(result.getRight().toNullable(), isA<AskBooksAmbiguous>());
  });

  test('named balance zero hits is unresolved', () async {
    when(
      () => search.execute(
        'Ghost',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((_) async => const Right([]));

    final result = await useCase.execute(goalText: "what's Ghost's balance");
    expect(result.getRight().toNullable(), isA<AskBooksUnresolved>());
  });

  test('capture goal returns null without reading books', () async {
    final result = await useCase.execute(goalText: 'Mohamed owes 500');
    expect(result.getRight().toNullable(), isNull);
    verifyNever(balances.watchAllBalances);
  });

  test('empty leftover named ask is need-name not overdue', () async {
    final result = await useCase.execute(goalText: 'what is the balance');
    expect(result.getRight().toNullable(), isA<AskBooksNeedName>());
    verifyNever(balances.watchAllBalances);
  });

  test('remaining leftover searches Mohamed not remaining AND', () async {
    when(
      () => search.execute(
        any(),
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((invocation) async {
      final query = invocation.positionalArguments.first as String;
      if (query == 'mohamed' || query == 'Mohamed') {
        return Right([
          ContactSearchHit(
            contact: mohamed,
            ledgerName: 'Customers',
            isLedgerUserArchived: false,
          ),
        ]);
      }
      return const Right([]);
    });
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => Right([balance(contactId: 'contact-1', net: -200)]),
    );

    final result = await useCase.execute(
      goalText: "What is Mohammed's remaining balance?",
    );
    expect(result.getRight().toNullable(), isA<AskBooksAmbiguous>());
    verifyNever(
      () => search.execute(
        'Mohammed remaining',
        excludeUserArchivedLedgers: true,
      ),
    );
  });

  test('forceAsk notes are extracted not FTS-searched raw', () async {
    when(
      () => search.execute(
        'Mohamed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed,
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => Right([balance(contactId: 'contact-1', net: -50)]),
    );

    const utterance = "what's Mohamed remaining balance";
    final result = await useCase.execute(
      goalText: utterance,
      forceAsk: true,
      nameHint: utterance,
    );
    expect(result.getRight().toNullable(), isA<AskBooksNamedBalance>());
    verifyNever(
      () => search.execute(
        utterance,
        excludeUserArchivedLedgers: true,
      ),
    );
  });

  test('largest outstanding sorts by owedMinor descending', () async {
    when(balances.watchAllBalances).thenAnswer(
      (_) => Stream.value([
        balance(contactId: 'contact-1', net: -200),
        balance(contactId: 'contact-2', net: -900),
      ]),
    );
    when(() => contacts.getById('contact-1')).thenAnswer(
      (_) async => Right(mohamed),
    );
    when(() => contacts.getById('contact-2')).thenAnswer(
      (_) async => Right(mohamed.copyWith(id: 'contact-2', name: 'Ali')),
    );

    final result = await useCase.execute(
      goalText: 'Who has a large outstanding debt?',
    );
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksLargestOutstanding>());
    final rows = (answer! as AskBooksLargestOutstanding).rows;
    expect(rows.first.contactId, 'contact-2');
    expect(rows.first.owedMinor, 900);
  });

  test('smallest outstanding sorts by owedMinor ascending', () async {
    when(balances.watchAllBalances).thenAnswer(
      (_) => Stream.value([
        balance(contactId: 'contact-1', net: -200),
        balance(contactId: 'contact-2', net: -900),
      ]),
    );
    when(() => contacts.getById('contact-1')).thenAnswer(
      (_) async => Right(mohamed),
    );
    when(() => contacts.getById('contact-2')).thenAnswer(
      (_) async => Right(mohamed.copyWith(id: 'contact-2', name: 'Ali')),
    );

    final result = await useCase.execute(goalText: 'من صاحب أقل دين؟');
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksSmallestOutstanding>());
    final rows = (answer! as AskBooksSmallestOutstanding).rows;
    expect(rows.first.contactId, 'contact-1');
    expect(rows.first.owedMinor, 200);
  });

  test('last payment uses newest payment integer', () async {
    when(
      () => search.execute(
        'Mohamed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed,
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );
    when(
      () => transactions.getByContact('contact-1', limit: 50),
    ).thenAnswer(
      (_) async => Right([
        Transaction(
          id: 'txn-debt',
          contactId: 'contact-1',
          type: TransactionType.debt,
          amount: 800,
          currency: 'YER',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        Transaction(
          id: 'txn-pay',
          contactId: 'contact-1',
          type: TransactionType.payment,
          amount: 150,
          currency: 'YER',
          transactionDate: now.subtract(const Duration(days: 1)),
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    final result = await useCase.execute(
      goalText: "what's Mohamed last payment",
    );
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksLastTransaction>());
    final row = answer! as AskBooksLastTransaction;
    expect(row.amountMinor, 150);
    expect(row.type, TransactionType.payment);
  });

  test('last payment with no payments is empty success', () async {
    when(
      () => search.execute(
        'Mohamed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed,
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );
    when(
      () => transactions.getByContact('contact-1', limit: 50),
    ).thenAnswer((_) async => const Right([]));

    final result = await useCase.execute(
      goalText: "what's Mohamed last payment",
    );
    expect(result.getRight().toNullable(), isA<AskBooksNoLastTransaction>());
  });

  test('pronoun last payment uses lastContactId', () async {
    when(() => contacts.getById('contact-1')).thenAnswer(
      (_) async => Right(mohamed),
    );
    when(
      () => transactions.getByContact('contact-1', limit: 50),
    ).thenAnswer(
      (_) async => Right([
        Transaction(
          id: 'txn-pay',
          contactId: 'contact-1',
          type: TransactionType.payment,
          amount: 75,
          currency: 'YER',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    final result = await useCase.execute(
      goalText: 'What was his last payment amount?',
      lastContactId: 'contact-1',
    );
    final answer = result.getRight().toNullable();
    expect(answer, isA<AskBooksLastTransaction>());
    expect((answer! as AskBooksLastTransaction).amountMinor, 75);
  });

  test('first-token fallback finds Mohamed when extra leftover tokens miss', () async {
    when(
      () => search.execute(
        'Mohammed Extra',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => search.execute(
        'Mohammed',
        excludeUserArchivedLedgers: true,
      ),
    ).thenAnswer(
      (_) async => Right([
        ContactSearchHit(
          contact: mohamed,
          ledgerName: 'Customers',
          isLedgerUserArchived: false,
        ),
      ]),
    );
    when(() => balances.getByContact('contact-1')).thenAnswer(
      (_) async => Right([balance(contactId: 'contact-1', net: -200)]),
    );

    final result = await useCase.execute(
      goalText: 'What is Mohammed Extra remaining balance?',
    );
    expect(result.getRight().toNullable(), isA<AskBooksAmbiguous>());
  });
}
